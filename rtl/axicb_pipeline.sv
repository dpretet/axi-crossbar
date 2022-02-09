// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_pipeline

    #(
        // Bus width in bits
        parameter DATA_BUS_W = 8,
        // Number of pipeline stage
        parameter NB_PIPELINE = 1
    )(
        input  wire                       aclk,
        input  wire                       aresetn,
        input  wire                       srst,
        input  wire                       i_valid,
        output logic                      i_ready,
        input  wire  [DATA_BUS_W    -1:0] i_data,
        output logic                      o_valid,
        input  wire                       o_ready,
        output logic [DATA_BUS_W    -1:0] o_data
    );

    generate

    if (NB_PIPELINE==0) begin: NO_PIPELINE

        assign o_valid = i_valid;
        assign o_data = i_data;
        assign i_ready = o_ready;

    end else if (NB_PIPELINE==1) begin: ONE_STAGE_PIPELINE

        logic full;

        always @ (posedge aclk or negedge aresetn) begin

            if (~aresetn) begin
                o_valid <= 1'b0;
                o_data <= {DATA_BUS_W{1'b0}};
            end else if (srst) begin
                o_valid <= 1'b0;
                o_data <= {DATA_BUS_W{1'b0}};
            end else if (~full) begin
                o_valid <= i_valid;
                o_data <= i_data;
            end
        end

        assign full = (o_valid & ~o_ready);
        assign i_ready = !full;

    end else begin: N_STAGE_PIPELINE

        logic                      pipe_valid;
        logic                      pipe_ready;
        logic [DATA_BUS_W    -1:0] pipe_data;

        axicb_pipeline
        #(
            .DATA_BUS_W  (DATA_BUS_W),
            .NB_PIPELINE (1)
        )
        pipe_n
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (i_valid),
            .i_ready (i_ready),
            .i_data  (i_data),
            .o_valid (pipe_valid),
            .o_ready (pipe_ready),
            .o_data  (pipe_data)
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (DATA_BUS_W),
            .NB_PIPELINE (NB_PIPELINE-1)
        )
        pipe_n_m1
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (pipe_valid),
            .i_ready (pipe_ready),
            .i_data  (pipe_data),
            .o_valid (o_valid),
            .o_ready (o_ready),
            .o_data  (o_data)
        );

    end
    endgenerate


endmodule

`resetall
