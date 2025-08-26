// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////
//
// Manage read or write response channel ordering
//
//////////////////////////////////////////////////////////////////////////////

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
        // - address channel valid
        // - ID FIFOs full flag (=1 if any FIFO is full)
        // - address channel burst length and ID
        // - slave index targeted (one-hot encoded)
        // - misrouted flag
        input  wire                           a_valid,
        input  wire                           a_ready,
        output logic                          a_full,
        input  wire  [8                 -1:0] a_len,
        input  wire  [AXI_ID_W          -1:0] a_id,
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
        // Completion channel from slaves (either read or write)
        // - valid / ready / last from r/w completion
        // - ch: the concatenated completion channel
        // - end: combination of valid/ready/last from input
        //        side to avoid comb loop
        input  wire  [SLV_NB            -1:0] c_valid,
        input  wire                           c_ready,
        input  wire  [CCH_W*SLV_NB      -1:0] c_ch,
        input  wire                           c_end
    );

    ////////////////////////////////////////////////////////////////
    // Localparam & signals
    ////////////////////////////////////////////////////////////////

    localparam OSTDREQ_NUM = (MST_OSTDREQ_NUM < 2) ? 1 : MST_OSTDREQ_NUM;
    localparam NB_ID      = OSTDREQ_NUM;
    localparam FIFO_DEPTH = $clog2(OSTDREQ_NUM);
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
    logic [        AXI_ID_W-1:0] a_id_m;
    logic                        c_empty;
    logic [           NB_ID-1:0] mr_reqs;

    ////////////////////////////////////////////////////////////////


    //--------------------------------------------------------------- 
    // First stage grabs the read or write address channel and stores
    // the transaction attributes to a FIFO per ID target. When a 
    // single OR is supported by a master, it's not necessary and so
    // this stage is not existing
    //--------------------------------------------------------------- 

    generate

    if (OSTDREQ_NUM==1) begin : NO_ID_FIFO

        assign fifo_in = '0;
        assign fifo_out = '0;
        assign id_full = '0;
        assign id_empty = '0;
        assign a_id_m = '0;
        assign mr_reqs = '0;

    end else begin : W_ID_FIFO

        // FIFO Input path: for read, we store along the slave index
        // and misroute flag the ALEN, not necessary for write completion
        // a_id is stored for misrouted completion
        if (RD_PATH) begin : IN_RD_PATH_FIFO
            always_comb fifo_in = {a_len,a_ix,a_mr,a_id};
        end else begin: IN_WR_PATH_FIFO
            always_comb fifo_in = {a_ix,a_mr,a_id};
        end

        // Unmasked Address Channel ID to target the right FIFO
        always_comb a_id_m = a_id ^ MST_ID_MASK;

        // FIFO storing per ID the transaction attributes
        for (genvar i=0; i<NB_ID; i++) begin: FIFOS_GEN

            assign push[i] = (a_id_m == i[0+:AXI_ID_W]) ? a_valid & a_ready : 1'b0;

            axicb_scfifo
            #(
                .BLOCK      ("REGFILE"),
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

            // Indicates when an ID FIFO is ready to pass a completion for
            // a misrouted transaction. Used later on arbitration stage
            assign mr_reqs[i] = (id_empty[i]) ? 1'b0 : fifo_out[i*FIFO_WIDTH+AXI_ID_W];

        end

        // Back pressure to address channel, block any further transaction
        // as soon an ID FIFO is full.
        always_comb a_full = |id_full;

    end
    endgenerate
    //-------------------------------------------------------------------------


    //-------------------------------------------------------------------------
    // Second stage, doing the arbitration between the completion channels from
    // the slaves. We grant the completion channel when they match the index
    // an ID FIFO indicates
    //-------------------------------------------------------------------------
    generate
    if (OSTDREQ_NUM==1) begin : NO_CPL_PATH

        assign c_reqs = '0;
        assign pull = '0;
        assign id_grant = '0;
        assign c_select = '0;
        assign c_empty = '0;

    end else begin : CPL_PATH

        // Round robin grants fairly the IDs, not the slaves, so we marry per-ID
        // the ID FIFOs status with the slave carrying an ID-matching completion
        always @ (*) begin

            // Serves misrouted IDs first
            if (|mr_reqs) begin
                c_reqs = mr_reqs;

            // Then serves completion channels
            end else begin

                for (int i=0; i<NB_ID; i++) begin : CREQS

                    c_reqs[i] = '0;

                    for (int j=0; j<SLV_NB; j++) begin
                        if (fifo_out[i*FIFO_WIDTH+AXI_ID_W + 1 + j] && !id_empty[i] && c_valid[j])
                            // Unmasked Address Channel ID
                            if ((c_ch[j*CCH_W+:AXI_ID_W] ^ MST_ID_MASK) == i[0+:AXI_ID_W])
                                c_reqs[i] = c_valid[j];
                    end
                end
            end
        end


        assign pull = (c_end) ? id_grant : '0;

        axicb_round_robin_core
        #(
            .REQ_NB  (NB_ID)
        )
        cch_round_robin
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .en      (c_en),
            .req     (c_reqs),
            .grant   (id_grant)
        );

        // Multiplexer to extract the right FIFO and its corresponding empty flag
        always_comb begin
            c_select = '0;
            c_empty = '0;
            for (int i=0; i<NB_ID; i++) begin
                if (id_grant[i]) begin
                    c_select = fifo_out[i*FIFO_WIDTH +: FIFO_WIDTH];
                    c_empty = id_empty[i];
                end
            end
        end

    end
    endgenerate
    //--------------------------------------------------------------------------


    //--------------------------------------------------------------------------
    // Third stage, we drive the completion attribute back to the slave switch
    // When only a single OR is supported, just put here a pipeline to store the
    // transaction attribute and drive back to the switch once the initiator
    // is ready to accept a completion
    //--------------------------------------------------------------------------
    generate

    // Single oustanding request management
    if (OSTDREQ_NUM==1) begin : NO_PATH_CPL

        localparam PIPE_W = (RD_PATH) ? 1 + AXI_ID_W + 8 : 
                                        1 + AXI_ID_W;

        logic [PIPE_W-1:0] pipe_in;
        logic [PIPE_W-1:0] pipe_out;
        logic              pipe_aready;
        logic              pipe_valid;

        assign pipe_in = (RD_PATH) ? {a_len, a_id, a_mr} : {a_id, a_mr};
        assign a_full = !pipe_aready;

        // Pass the tansaction attributes to a pipeline to store them
        axicb_pipeline 
        #(
            .DATA_BUS_W  (PIPE_W),
            .NB_PIPELINE (1)
        )
        rd_cpl_pipe_no_or 
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (a_valid & a_ready),
            .i_ready (pipe_aready),
            .i_data  (pipe_in),
            .o_valid (pipe_valid),
            .o_ready (c_end),
            .o_data  (pipe_out)
        );

        // Granted completion is just the one active
        assign c_grant = c_valid;

        if (RD_PATH) begin: C_LEN_RD_PATH
            always @ (*) begin
                // Read completion path also comprise the ALEN
                if (pipe_valid)
                    c_len = pipe_out[(1+AXI_ID_W)+:8];
                else
                    c_len = '0;
            end
        end else begin: NO_C_LEN_WR_PATH
            assign c_len = '0;
        end

        always @ (*) begin
            // For read and write completion path
            // pass back the ID and misrouteed flag
            if (pipe_valid) begin
                c_id = pipe_out[1+:AXI_ID_W];
                c_mr = pipe_out[0];
            end else begin
                c_id = '0;
                c_mr = '0;
            end
        end

    // OR > 1, Read completion path 
    end else if (RD_PATH) begin: RD_PATH_CPL

        always @ (*) begin
            if (c_empty)
                {c_len,c_grant,c_mr,c_id} = '0;
            else
                {c_len,c_grant,c_mr,c_id} = c_select;
        end

    // OR > 1, Write completion path (no ALEN)
    end else begin: WR_PATH_CPL

        always @ (*) begin
            if (c_empty)
                {c_grant,c_mr,c_id} = '0;
            else
                {c_grant,c_mr,c_id} = c_select;
            c_len = '0;
        end

    end


    endgenerate

endmodule

`resetall
