// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_slv_ooo

    #(
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Number of slave(s)
        parameter SLV_NB = 4,
        // Max Outstanding Request
        parameter MST_OSTDREQ_NUM = 4,
        // Completion Channels' width (concatenated, either read or write)
        parameter CCH_W = 8
    )(
        // Global interface
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interface from master:
        // - address channel handshake (valid/ready)
        // - full flag (all ID FIFOs full)
        // - address channel burst length and ID
        // - slave index targeted (one-hot encoded)
        // - misrouted flag
        input  wire                           a_valid,
        output logic                          a_ready,
        output logic                          a_full,
        input  wire  [AXI_ID_W          -1:0] a_id,
        input  wire  [8                 -1:0] a_len,
        input  wire  [SLV_NB            -1:0] a_ix,
        input  wire                           a_mr,
        // Grant interface:
        // - enable arbiter
        // - granted slave
        // - misrouted flag
        input  wire                           c_en,
        output logic [SLV_NB            -1:0] c_grant,
        output logic                          c_mr,
        // Completion channel from slaves (either read or write)
        input  wire  [SLV_NB            -1:0] c_valid,
        input  wire                           c_ready,
        input  wire  [CCH_W*SLV_NB      -1:0] c_ch
    );

    localparam NB_ID = $clog2(AXI_ID_W);
    localparam FIFO_DEPTH = $clog2(MST_OSTDREQ_NUM);
    localparam FIFO_WIDTH = 8 + SLV_NB + 1;

    logic [           NB_ID-1:0] push;
    logic [           NB_ID-1:0] pull;
    logic [           NB_ID-1:0] full;
    logic [           NB_ID-1:0] empty;
    logic [FIFO_WIDTH*NB_ID-1:0] fifo_out;


    generate

    for (genvar i=0; i<NB_ID; i++) begin: FIFOS_GEN

        axicb_scfifo 
        #(
            .ADDR_WIDTH (FIFO_DEPTH),
            .DATA_WIDTH (FIFO_WIDTH)
        )
        id_fifo 
        (
            .aclk     (aclk),
            .aresetn  (aresetn),
            .srst     (srst),
            .flush    (1'b0),
            .data_in  ({a_len,a_ix,a_mr}),
            .push     (push[i]),
            .full     (full[i]),
            .data_out (fifo_out[i*FIFO_WIDTH+:FIFO_WIDTH]),
            .pull     (pull[i]),
            .empty    (empty[i])
        );

    end

    endgenerate

    // Drive aready by selecting the ID FIFO full
    // Could be replaced by ORing full vector if AID
    // doesn't come from a FFD
    always @ (*) begin
        a_ready = 1'b0;
        for (int i=0; i<NB_ID; i++)
            if (a_id == i[AXI_ID_W-1:0])
                a_ready = !full[i];
    end


endmodule

`resetall
