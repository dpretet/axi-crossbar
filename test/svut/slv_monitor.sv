// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

`include "functions.sv"

module slv_monitor

    #(
        // Address width in bits
        parameter AXI_ADDR_W = 8,
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // Enable completion check and log
        parameter CHECK_REPORT = 1, 

        // LFSR key init
        parameter KEY = 'hFFFFFFFF
    )(
        input  logic                      aclk,
        input  logic                      aresetn,
        input  logic                      srst,
        output logic                      error,
        input  logic                      awvalid,
        output logic                      awready,
        input  logic [AXI_ADDR_W    -1:0] awaddr,
        input  logic [8             -1:0] awlen,
        input  logic [3             -1:0] awsize,
        input  logic [2             -1:0] awburst,
        input  logic [2             -1:0] awlock,
        input  logic [4             -1:0] awcache,
        input  logic [3             -1:0] awprot,
        input  logic [4             -1:0] awqos,
        input  logic [4             -1:0] awregion,
        input  logic [AXI_ID_W      -1:0] awid,
        input  logic                      wvalid,
        output logic                      wready,
        input  logic                      wlast,
        input  logic [AXI_DATA_W    -1:0] wdata,
        input  logic [AXI_DATA_W/8  -1:0] wstrb,
        output logic                      bvalid,
        input  logic                      bready,
        output logic [AXI_ID_W      -1:0] bid,
        output logic [2             -1:0] bresp,
        input  logic                      arvalid,
        output logic                      arready,
        input  logic [AXI_ADDR_W    -1:0] araddr,
        input  logic [8             -1:0] arlen,
        input  logic [3             -1:0] arsize,
        input  logic [2             -1:0] arburst,
        input  logic [2             -1:0] arlock,
        input  logic [4             -1:0] arcache,
        input  logic [3             -1:0] arprot,
        input  logic [4             -1:0] arqos,
        input  logic [4             -1:0] arregion,
        input  logic [AXI_ID_W      -1:0] arid,
        output logic                      rvalid,
        input  logic                      rready,
        output logic [AXI_ID_W      -1:0] rid,
        output logic [2             -1:0] rresp,
        output logic [AXI_DATA_W    -1:0] rdata,
        output logic                      rlast
    );

    logic [32                          -1:0] aw_lfsr;
    logic [32                          -1:0] ar_lfsr;
    logic [32                          -1:0] b_lfsr;
    logic [32                          -1:0] awready_lfsr;
    logic [32                          -1:0] bvalid_lfsr;
    logic [32                          -1:0] arready_lfsr;
    logic [32                          -1:0] rvalid_lfsr;
    logic                                    b_full;
    logic                                    b_empty;
    logic [2+AXI_ID_W                  -1:0] b_fifo_i;
    logic [2+AXI_ID_W                  -1:0] b_fifo_o;
    logic [32                          -1:0] bresp_exp;

    assign error = 1'b0;

    ///////////////////////////////////////////////////////////////////////////////
    // Write channels
    ///////////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            awready_lfsr <= 32'b0;
        end else if (srst) begin
            awready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value 
            if (awready_lfsr==32'b0) begin
                awready_lfsr <= aw_lfsr;
            // Use to randomly assert awready/wready
            end else if (~awready) begin
                awready_lfsr <= awready_lfsr >> 1;
            end else if (awvalid) begin
                awready_lfsr <= aw_lfsr;
            end
        end
    end

    lfsr32 
    #(
    .KEY (KEY)
    )
    awch_lfsr
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (awvalid & awready & wready),
    .lfsr    (aw_lfsr)
    );

    assign awready = awready_lfsr[0] & ~b_full;
    assign wready = awready_lfsr[0] & ~b_full;

    assign bresp_exp = gen_resp(awaddr);
    assign b_fifo_i = {awid, bresp_exp[1:0]};

    axicb_scfifo 
    #(
    .PASS_THRU  (0),
    .ADDR_WIDTH (2),
    .DATA_WIDTH (AXI_ID_W+2)
    )
    bfifo 
    (
    .aclk     (aclk),
    .aresetn  (aresetn),
    .srst     (srst),
    .flush    (1'b0),
    .data_in  (b_fifo_i),
    .push     (awvalid & awready),
    .full     (b_full),
    .data_out (b_fifo_o),
    .pull     (bvalid & bready),
    .empty    (b_empty)
    );

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            bvalid_lfsr <= 32'b0;
        end else if (srst) begin
            bvalid_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value 
            if (bvalid_lfsr==32'b0) begin
                bvalid_lfsr <= b_lfsr;
            // Use to randomly assert bvalid/wready
            end else if (~bvalid) begin
                bvalid_lfsr <= bvalid_lfsr >> 1;
            end else if (bready) begin
                bvalid_lfsr <= b_lfsr;
            end
        end
    end

    lfsr32 
    #(
    .KEY (KEY)
    )
    bch_lfsr
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (bvalid & bready),
    .lfsr    (b_lfsr)
    );

    assign bvalid = ~b_empty & bvalid_lfsr[0];
    assign bresp = b_fifo_o[1:0];
    assign bid = b_fifo_o[2+:AXI_ID_W];


    ///////////////////////////////////////////////////////////////////////////////
    // Read channels
    ///////////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            arready_lfsr <= 32'b0;
        end else if (srst) begin
            arready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value 
            if (arready_lfsr==32'b0) begin
                arready_lfsr <= ar_lfsr;
            // Use to randomly assert arready
            end else if (~arready) begin
                arready_lfsr <= arready_lfsr >> 1;
            end else begin
                arready_lfsr <= ar_lfsr;
            end
        end
    end

    assign arready = arready_lfsr[0];

    lfsr32 
    #(
    .KEY (KEY)
    )
    arch_lfsr
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (arvalid & arready),
    .lfsr    (ar_lfsr)
    );

endmodule

`resetall

