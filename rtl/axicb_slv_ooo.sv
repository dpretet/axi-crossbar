// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_slv_ooo

    #(
        // Read setup stores ALEN
        parameter RD_PATH = 0,
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Number of slave(s)
        parameter SLV_NB = 4,
        // Max Outstanding Request
        parameter MST_OSTDREQ_NUM = 4,
        // Master ID mask
        parameter [AXI_ID_W-1:0] MST_ID_MASK = 'h00,
        // Completion Channels' width (concatenated, either read or write)
        parameter CCH_W = 8
    )(
        // Global interface
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interface from master:
        // - address channel handshake (valid/ready)
        // - full flag (one ID FIFOs is full)
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
        // - completion length
        // - completion id
        input  wire                           c_en,
        output logic [SLV_NB            -1:0] c_grant,
        output logic                          c_mr,
        output logic [8                 -1:0] c_len,
        output logic [AXI_ID_W          -1:0] c_id,
        output logic [SLV_NB            -1:0] c_ix,
        // Completion channel from slaves (either read or write)
        input  wire  [SLV_NB            -1:0] c_valid,
        input  wire                           c_ready,
        input  wire  [CCH_W*SLV_NB      -1:0] c_ch
    );

    ////////////////////////////////////////////////////////////////
    // Localparam & signals
    ////////////////////////////////////////////////////////////////

    localparam NB_ID      = MST_OSTDREQ_NUM;
    localparam FIFO_DEPTH = (MST_OSTDREQ_NUM < 2) ? 1 : $clog2(MST_OSTDREQ_NUM);
    localparam FIFO_WIDTH = (RD_PATH) ? 8 + SLV_NB + 1 + AXI_ID_W : SLV_NB + 1 + AXI_ID_W;

    logic [           NB_ID-1:0] push;
    logic [           NB_ID-1:0] pull;
    logic [           NB_ID-1:0] id_full;
    logic [           NB_ID-1:0] id_empty;
    logic [      FIFO_WIDTH-1:0] fifo_in;
    logic [FIFO_WIDTH*NB_ID-1:0] fifo_out;
    logic [      FIFO_WIDTH-1:0] c_select;
    logic [           NB_ID-1:0] c_reqs;
    logic [           NB_ID-1:0] id_grant;

    logic [AXI_ID_W        -1:0] a_id_m;
    logic [AXI_ID_W        -1:0] c_id_m;

    ////////////////////////////////////////////////////////////////

    // FIFO Input path: for read, we store along the slave index
    // and misroute flag the ALEN, not necessary for write completion
    generate
    if (RD_PATH) begin : IN_RD_PATH_FIFO
        always_comb fifo_in = {a_len,a_ix,a_mr,a_id};
    end else begin: IN_WR_PATH_FIFO
        always_comb fifo_in = {a_ix,a_mr,a_id};
    end
    endgenerate

    // Unmasked Address Channel ID
    always_comb a_id_m = a_id ^ MST_ID_MASK;

    generate

    // FIFO storing per ID the transaction attributes
    for (genvar i=0; i<NB_ID; i++) begin: FIFOS_GEN

        assign push[i] = (a_id_m == i[0+:AXI_ID_W]) ? a_valid : 1'b0;

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
            .data_in  (fifo_in),
            .push     (push[i]),
            .full     (id_full[i]),
            .data_out (fifo_out[i*FIFO_WIDTH+:FIFO_WIDTH]),
            .pull     (pull[i]),
            .empty    (id_empty[i])
        );

    end

    endgenerate

    // Drive aready by selecting the ID FIFO full
    // Could be replaced by ORing full vector if AID
    // doesn't come from a FFD
    always @ (*) begin
        a_ready = 1'b0;
        for (int i=0; i<NB_ID; i++)
            if (a_id_m == i[AXI_ID_W-1:0])
                a_ready = !id_full[i];
    end

    always_comb a_full = |id_full;


    // Round robin grants fairly the IDs, not the slaves, so we marry per-ID
    // the ID FIFOs status with the slave carrying an ID-matching completion
    always @ (*) begin
        for (int i=0; i<NB_ID; i++) begin
            c_reqs[i] = '0;
            for (int j=0; j<SLV_NB; j++) begin
                // Unmasked Address Channel ID
                c_id_m = c_ch[j*CCH_W+:AXI_ID_W] ^ MST_ID_MASK;
                if (c_id_m == i[0+:AXI_ID_W])
                    c_reqs[i] = c_valid[j] & !id_empty[i];
            end
        end
    end

    axicb_round_robin_core
    #(
        .REQ_NB  (NB_ID)
    )
    cch_round_robin
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      ('1),
        .req     (push),
        .grant   (id_grant)
    );

    always_comb c_select = fifo_out[id_grant*FIFO_WIDTH +: FIFO_WIDTH];

    generate
    if (RD_PATH) begin: OUT_RD_PATH_CPL
        always @ (*) begin
            {c_len,c_ix,c_mr,c_id} = c_select;
        end
    end else begin: OUT_WR_PATH_CPL
        always @ (*) begin
            {c_ix,c_mr,c_id} = c_select;
            c_len = '0;
        end
    end
    endgenerate

endmodule

`resetall
