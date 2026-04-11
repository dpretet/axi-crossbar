// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_mst_switch_wr

    #(
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // Number of master(s)
        parameter MST_NB = 4,

        // Maximum number of priority in Round-Robin for Masters selections
        parameter NUM_PRIORITY_LVL = 4,

        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,

        // Masters ID mask
        parameter [AXI_ID_W*MST_NB-1:0] MST_ID_MASK = 'h30_20_10_00,

        // Masters priorities
        parameter PRIORITY_W = 2,
        parameter [PRIORITY_W*MST_NB-1:0] MST_PRIORITY = 0,

        // Channels' width (concatenated)
        parameter AWCH_W = 8,
        parameter WCH_W = 8,
        parameter BCH_W = 8,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // Global interface
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interfaces from masters
        input  wire  [MST_NB            -1:0] i_awvalid,
        output logic [MST_NB            -1:0] i_awready,
        input  wire  [MST_NB*AWCH_W     -1:0] i_awch,
        input  wire  [MST_NB            -1:0] i_wvalid,
        output logic [MST_NB            -1:0] i_wready,
        input  wire  [MST_NB            -1:0] i_wlast,
        input  wire  [MST_NB*WCH_W      -1:0] i_wch,
        output logic [MST_NB            -1:0] i_bvalid,
        input  wire  [MST_NB            -1:0] i_bready,
        output logic [BCH_W             -1:0] i_bch,
        // Output interfaces to slaves
        output logic                          o_awvalid,
        input  wire                           o_awready,
        output logic [AWCH_W            -1:0] o_awch,
        output logic                          o_wvalid,
        input  wire                           o_wready,
        output logic                          o_wlast,
        output logic [WCH_W             -1:0] o_wch,
        input  wire                           o_bvalid,
        output logic                          o_bready,
        input  wire  [BCH_W             -1:0] o_bch
    );


    ///////////////////////////////////////////////////////////////////////////
    // Local declarations
    ///////////////////////////////////////////////////////////////////////////

    logic                  awch_en;
    logic                  awch_en_c;
    logic                  awch_en_r;
    logic [MST_NB    -1:0] awch_req;
    logic [MST_NB    -1:0] awch_grant;

    logic [MST_NB    -1:0] wch_grant;

    logic [MST_NB    -1:0] mst_bch_targeted;

    logic                  wch_full;
    logic                  wch_empty;


    ///////////////////////////////////////////////////////////////////////////
    // Write Address Channel
    ///////////////////////////////////////////////////////////////////////////

    assign awch_req = i_awvalid;

    axicb_round_robin
    #(
        .REQ_NB           (MST_NB),
        .PRIORITY_W       (PRIORITY_W),
        .NUM_PRIORITY_LVL (NUM_PRIORITY_LVL),
        .PRIORITY         (MST_PRIORITY)
    )
    awch_round_robin
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (awch_en),
        .req     (awch_req),
        .grant   (awch_grant)
    );

    always_comb begin

        o_awvalid = '0;

        for (int i=0; i<MST_NB; i++)
            if (awch_grant[i])
                o_awvalid = i_awvalid[i];
    end

    assign i_awready = awch_grant & {MST_NB{o_awready & !wch_full}};

    assign awch_en_c = |i_awvalid & o_awready;

    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awch_en_r <= '0;
        end else if (srst) begin
            awch_en_r <= '0;
        end else begin
            if (awch_grant=='0) awch_en_r <= 1'b1;
            else                awch_en_r <= 1'b0;
        end
    end

    assign awch_en = awch_en_c | awch_en_r;

    always_comb begin

        o_awch = '0;

        if (awch_grant == '0)
            o_awch = '0;
        else
            for (int i=0;i<MST_NB;i++)
                if (awch_grant[i])
                    o_awch = i_awch[i*AWCH_W+:AWCH_W];
    end



    ///////////////////////////////////////////////////////////////////////////
    // Write Data Channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_scfifo
    #(
    .PASS_THRU  (0),
    .ADDR_WIDTH (8),
    .DATA_WIDTH (MST_NB)
    )
    wch_gnt_fifo
    (
    .aclk     (aclk),
    .aresetn  (aresetn),
    .srst     (srst),
    .flush    (1'b0),
    .data_in  (awch_grant),
    .push     (o_awvalid & o_awready),
    .full     (wch_full),
    .data_out (wch_grant),
    .pull     (o_wvalid & o_wready & o_wlast),
    .empty    (wch_empty)
    );

    assign i_wready = (wch_empty) ? {MST_NB{1'b0}} :
                                     wch_grant & {MST_NB{o_wready}};

    always_comb begin

        o_wvalid = '0;
        o_wlast = '0;
        o_wch = '0;

        if (wch_empty) begin
            o_wvalid = '0;
            o_wlast = '0;
            o_wch = '0;
        end else if (wch_grant == '0) begin
            o_wvalid = '0;
            o_wlast = '0;
            o_wch = '0;
        end else begin
            for (int i=0;i<MST_NB;i++) begin
                if (wch_grant[i]) begin
                    o_wvalid = i_wvalid[i];
                    o_wlast = i_wlast[i];
                    o_wch = i_wch[i*WCH_W+:WCH_W];
                end
            end
        end 
    end


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    // BCH = {RESP, ID}

    generate
    genvar i;
        for (i = 0; i < MST_NB; i = i + 1) begin : MST_BCH_TARGET
            assign mst_bch_targeted[i] = ((MST_ID_MASK[i*AXI_ID_W+:AXI_ID_W] & o_bch[0+:AXI_ID_W]) == MST_ID_MASK[i*AXI_ID_W+:AXI_ID_W]);
            assign i_bvalid[i] = (mst_bch_targeted[i]) ? o_bvalid : 1'b0;
        end
    endgenerate

    always_comb begin
        o_bready = '0;
        if (mst_bch_targeted == '0)
            o_bready = '0;
        else for (int i=0; i<MST_NB; i++)
            if (mst_bch_targeted[i])
                o_bready = i_bready[i];
    end

    assign i_bch = o_bch;

endmodule

`resetall
