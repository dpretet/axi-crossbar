// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_mst_switch

    #(
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // Number of master(s)
        parameter MST_NB = 4,

        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,

        // Masters ID mask
        parameter [AXI_ID_W-1:0] MST0_ID_MASK = 'h00,
        parameter [AXI_ID_W-1:0] MST1_ID_MASK = 'h10,
        parameter [AXI_ID_W-1:0] MST2_ID_MASK = 'h20,
        parameter [AXI_ID_W-1:0] MST3_ID_MASK = 'h30,

        // Masters priorities
        parameter MST0_PRIORITY = 0,
        parameter MST1_PRIORITY = 0,
        parameter MST2_PRIORITY = 0,
        parameter MST3_PRIORITY = 0,

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
        input  wire  [MST_NB            -1:0] i_arvalid,
        output logic [MST_NB            -1:0] i_arready,
        input  wire  [MST_NB*ARCH_W     -1:0] i_arch,
        output logic [MST_NB            -1:0] i_rvalid,
        input  wire  [MST_NB            -1:0] i_rready,
        output logic [MST_NB            -1:0] i_rlast,
        output logic [RCH_W             -1:0] i_rch,
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
        input  wire  [BCH_W             -1:0] o_bch,
        output logic                          o_arvalid,
        input  wire                           o_arready,
        output logic [ARCH_W            -1:0] o_arch,
        input  wire                           o_rvalid,
        output logic                          o_rready,
        input  wire                           o_rlast,
        input  wire  [RCH_W             -1:0] o_rch
    );


    ///////////////////////////////////////////////////////////////////////////
    // Local declarations
    ///////////////////////////////////////////////////////////////////////////

    logic                  awch_en;
    logic [MST_NB    -1:0] awch_req;
    logic [MST_NB    -1:0] awch_grant;

    logic [MST_NB    -1:0] wch_grant;

    logic                  arch_en;
    logic [MST_NB    -1:0] arch_req;
    logic [MST_NB    -1:0] arch_grant;

    logic                  mst0_bch_targeted;
    logic                  mst1_bch_targeted;
    logic                  mst2_bch_targeted;
    logic                  mst3_bch_targeted;

    logic                  mst0_rch_targeted;
    logic                  mst1_rch_targeted;
    logic                  mst2_rch_targeted;
    logic                  mst3_rch_targeted;

    logic                  wch_full;
    logic                  wch_empty;


    ///////////////////////////////////////////////////////////////////////////
    // Write Address Channel
    ///////////////////////////////////////////////////////////////////////////

    assign awch_req = i_awvalid;

    axicb_round_robin
    #(
        .REQ_NB        (MST_NB),
        .REQ0_PRIORITY (MST0_PRIORITY),
        .REQ1_PRIORITY (MST1_PRIORITY),
        .REQ2_PRIORITY (MST2_PRIORITY),
        .REQ3_PRIORITY (MST3_PRIORITY)
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

    assign o_awvalid = (awch_grant[0]) ? i_awvalid[0] :
                       (awch_grant[1]) ? i_awvalid[1] :
                       (awch_grant[2]) ? i_awvalid[2] :
                       (awch_grant[3]) ? i_awvalid[3] :
                                         1'b0;

    assign i_awready = awch_grant & {MST_NB{o_awready & !wch_full}};

    assign awch_en = o_awvalid & o_awready;

    assign o_awch = (awch_grant[0]) ? i_awch[0*AWCH_W+:AWCH_W] :
                    (awch_grant[1]) ? i_awch[1*AWCH_W+:AWCH_W] :
                    (awch_grant[2]) ? i_awch[2*AWCH_W+:AWCH_W] :
                    (awch_grant[3]) ? i_awch[3*AWCH_W+:AWCH_W] :
                                      {AWCH_W{1'b0}};


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

    assign o_wvalid = (~wch_empty & wch_grant[0]) ? i_wvalid[0] :
                      (~wch_empty & wch_grant[1]) ? i_wvalid[1] :
                      (~wch_empty & wch_grant[2]) ? i_wvalid[2] :
                      (~wch_empty & wch_grant[3]) ? i_wvalid[3] :
                                                    1'b0;

    assign o_wlast = (~wch_empty & wch_grant[0]) ? i_wlast[0] :
                     (~wch_empty & wch_grant[1]) ? i_wlast[1] :
                     (~wch_empty & wch_grant[2]) ? i_wlast[2] :
                     (~wch_empty & wch_grant[3]) ? i_wlast[3] :
                                                   1'b0;

    assign i_wready = (wch_empty) ? {MST_NB{1'b0}} :
                                     wch_grant & {MST_NB{o_wready}};

    assign o_wch = (~wch_empty & wch_grant[0]) ? i_wch[0*WCH_W+:WCH_W] :
                   (~wch_empty & wch_grant[1]) ? i_wch[1*WCH_W+:WCH_W] :
                   (~wch_empty & wch_grant[2]) ? i_wch[2*WCH_W+:WCH_W] :
                   (~wch_empty & wch_grant[3]) ? i_wch[3*WCH_W+:WCH_W] :
                                                 {WCH_W{1'b0}};


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    // BCH = {RESP, ID}

    assign mst0_bch_targeted = ((MST0_ID_MASK & o_bch[0+:AXI_ID_W]) == MST0_ID_MASK);
    assign mst1_bch_targeted = ((MST1_ID_MASK & o_bch[0+:AXI_ID_W]) == MST1_ID_MASK);
    assign mst2_bch_targeted = ((MST2_ID_MASK & o_bch[0+:AXI_ID_W]) == MST2_ID_MASK);
    assign mst3_bch_targeted = ((MST3_ID_MASK & o_bch[0+:AXI_ID_W]) == MST3_ID_MASK);

    assign i_bvalid[0] = (mst0_bch_targeted) ? o_bvalid : 1'b0;
    assign i_bvalid[1] = (mst1_bch_targeted) ? o_bvalid : 1'b0;
    assign i_bvalid[2] = (mst2_bch_targeted) ? o_bvalid : 1'b0;
    assign i_bvalid[3] = (mst3_bch_targeted) ? o_bvalid : 1'b0;

    assign o_bready = (mst0_bch_targeted) ? i_bready[0] :
                      (mst1_bch_targeted) ? i_bready[1] :
                      (mst2_bch_targeted) ? i_bready[2] :
                      (mst3_bch_targeted) ? i_bready[3] :
                                            1'b0;

    assign i_bch = o_bch;


    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    assign arch_req = i_arvalid;

    axicb_round_robin
    #(
        .REQ_NB        (MST_NB),
        .REQ0_PRIORITY (MST0_PRIORITY),
        .REQ1_PRIORITY (MST1_PRIORITY),
        .REQ2_PRIORITY (MST2_PRIORITY),
        .REQ3_PRIORITY (MST3_PRIORITY)
    )
    arch_round_robin
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (arch_en),
        .req     (arch_req),
        .grant   (arch_grant)
    );

    assign o_arvalid = (arch_grant[0]) ? i_arvalid[0] :
                       (arch_grant[1]) ? i_arvalid[1] :
                       (arch_grant[2]) ? i_arvalid[2] :
                       (arch_grant[3]) ? i_arvalid[3] :
                                         1'b0;

    assign i_arready = arch_grant & {MST_NB{o_arready}};

    assign arch_en = o_arvalid & o_arready;

    assign o_arch = (arch_grant[0]) ? i_arch[0*ARCH_W+:ARCH_W] :
                    (arch_grant[1]) ? i_arch[1*ARCH_W+:ARCH_W] :
                    (arch_grant[2]) ? i_arch[2*ARCH_W+:ARCH_W] :
                    (arch_grant[3]) ? i_arch[3*ARCH_W+:ARCH_W] :
                                      {ARCH_W{1'b0}};

    ///////////////////////////////////////////////////////////////////////////
    // Read Response Channel
    ///////////////////////////////////////////////////////////////////////////

    // RCH = {RESP, ID, DATA}

    assign mst0_rch_targeted = ((MST0_ID_MASK & o_rch[0+:AXI_ID_W]) == MST0_ID_MASK);
    assign mst1_rch_targeted = ((MST1_ID_MASK & o_rch[0+:AXI_ID_W]) == MST1_ID_MASK);
    assign mst2_rch_targeted = ((MST2_ID_MASK & o_rch[0+:AXI_ID_W]) == MST2_ID_MASK);
    assign mst3_rch_targeted = ((MST3_ID_MASK & o_rch[0+:AXI_ID_W]) == MST3_ID_MASK);

    assign i_rvalid[0] = (mst0_rch_targeted) ? o_rvalid : 1'b0;
    assign i_rvalid[1] = (mst1_rch_targeted) ? o_rvalid : 1'b0;
    assign i_rvalid[2] = (mst2_rch_targeted) ? o_rvalid : 1'b0;
    assign i_rvalid[3] = (mst3_rch_targeted) ? o_rvalid : 1'b0;

    assign i_rlast[0] = (mst0_rch_targeted) ? o_rlast : 1'b0;
    assign i_rlast[1] = (mst1_rch_targeted) ? o_rlast : 1'b0;
    assign i_rlast[2] = (mst2_rch_targeted) ? o_rlast : 1'b0;
    assign i_rlast[3] = (mst3_rch_targeted) ? o_rlast : 1'b0;

    assign o_rready = (mst0_rch_targeted) ? i_rready[0] :
                      (mst1_rch_targeted) ? i_rready[1] :
                      (mst2_rch_targeted) ? i_rready[2] :
                      (mst3_rch_targeted) ? i_rready[3] :
                                            1'b0;

    assign i_rch = o_rch;

endmodule

`resetall
