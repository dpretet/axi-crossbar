`timescale 1 ns / 1 ps
`default_nettype none

module pipeline_checker

    #(
        // Bus width in bits
        parameter DATA_BUS_W = 32,
        // 32 bits value to init the LFSRs
        parameter KEY = 32'h4A5B3C86
    )(
        input  logic                      aclk,
        input  logic                      aresetn,
        input  logic                      srst,
        output logic                      i_valid,
        input  logic                      i_ready,
        output logic [DATA_BUS_W    -1:0] i_data,
        input  logic                      o_valid,
        output logic                      o_ready,
        input  logic [DATA_BUS_W    -1:0] o_data,
        output logic                      error
    );

    logic [DATA_BUS_W    -1:0] i_data_gen;
    logic [DATA_BUS_W    -1:0] o_data_gen;

    logic [32            -1:0] i_valid_lfsr;
    logic [32            -1:0] o_ready_lfsr;


    lfsr32
    #(
    .KEY (KEY)
    )
    i_valid_generator
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (i_valid & i_ready),
    .lfsr    (i_data_gen)
    );

    lfsr32
    #(
    .KEY (KEY)
    )
    o_ready_generator
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (o_valid & o_ready),
    .lfsr    (o_data_gen)
    );


    // i_valid generation
    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            i_valid_lfsr <= 32'b0;
        end else if (srst) begin
            i_valid_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (i_valid_lfsr==32'b0) begin
                i_valid_lfsr <= i_data_gen;
            // Use to randomly assert valid
            end else if (~i_valid) begin
                i_valid_lfsr <= i_valid_lfsr << 1;
            end else if (i_ready) begin
                i_valid_lfsr <= i_data_gen;
            end
        end
    end

    // o_ready generation
    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            o_ready_lfsr <= 32'b0;
        end else if (srst) begin
            o_ready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (o_ready_lfsr==32'b0) begin
                o_ready_lfsr <= o_data_gen;
            // Use to randomly assert ready
            end else if (~o_ready) begin
                o_ready_lfsr <= o_ready_lfsr >> 1;
            end else if (o_valid) begin
                o_ready_lfsr <= o_data_gen;
            end
        end
    end

    // error checking
    always @ (posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            error <= 1'b0;
        end else if (srst) begin
            error <= 1'b0;
        end else begin
            if (o_valid && o_ready) begin
                if (o_data != o_data_gen) error <= 1'b1;
                else error <= 1'b0;
            end
        end
    end

    assign i_valid = i_valid_lfsr[31];
    assign i_data = i_data_gen;
    assign o_ready = o_ready_lfsr[0];


endmodule

`resetall

