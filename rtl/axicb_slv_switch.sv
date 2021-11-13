// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_slv_switch


    #(
        // Address width in bits
        parameter AXI_ADDR_W = 8,

        // Number of slave(s)
        parameter SLV_NB = 4,
            //
        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,
        
        // Slaves memory mapping
        parameter SLV0_START_ADDR = 0,
        parameter SLV0_END_ADDR = 4095,
        parameter SLV1_START_ADDR = 4096,
        parameter SLV1_END_ADDR = 8191,
        parameter SLV2_START_ADDR = 8192,
        parameter SLV2_END_ADDR = 12287,
        parameter SLV3_START_ADDR = 12288,
        parameter SLV3_END_ADDR = 16383,

        // Channels' width (concatenated)
        parameter AWCH_W = 8,
        parameter WCH_W = 8,
        parameter BCH_W = 8,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // Global interface
        input  logic                          aclk,
        input  logic                          aresetn,
        input  logic                          srst,
        // Input interfaces from masters
        input  logic                          i_awvalid,
        output logic                          i_awready,
        input  logic [AWCH_W            -1:0] i_awch,
        input  logic                          i_wvalid,
        output logic                          i_wready,
        input  logic                          i_wlast,
        input  logic [WCH_W             -1:0] i_wch,
        output logic                          i_bvalid,
        input  logic                          i_bready,
        output logic [BCH_W             -1:0] i_bch,
        input  logic                          i_arvalid,
        output logic                          i_arready,
        input  logic [ARCH_W            -1:0] i_arch,
        output logic                          i_rvalid,
        input  logic                          i_rready,
        output logic                          i_rlast,
        output logic [RCH_W             -1:0] i_rch,
        // Output interfaces to slaves
        output logic [SLV_NB            -1:0] o_awvalid,
        input  logic [SLV_NB            -1:0] o_awready,
        output logic [AWCH_W            -1:0] o_awch,
        output logic [SLV_NB            -1:0] o_wvalid,
        input  logic [SLV_NB            -1:0] o_wready,
        output logic [SLV_NB            -1:0] o_wlast,
        output logic [WCH_W             -1:0] o_wch,
        input  logic [SLV_NB            -1:0] o_bvalid,
        output logic [SLV_NB            -1:0] o_bready,
        input  logic [SLV_NB*BCH_W      -1:0] o_bch,
        output logic [SLV_NB            -1:0] o_arvalid,
        input  logic [SLV_NB            -1:0] o_arready,
        output logic [ARCH_W            -1:0] o_arch,
        input  logic [SLV_NB            -1:0] o_rvalid,
        output logic [SLV_NB            -1:0] o_rready,
        input  logic [SLV_NB            -1:0] o_rlast,
        input  logic [SLV_NB*RCH_W      -1:0] o_rch
    );


    ///////////////////////////////////////////////////////////////////////////
    // Local declarations
    ///////////////////////////////////////////////////////////////////////////


    logic                  wch_full;
    logic                  wch_empty;
    logic [SLV_NB    -1:0] slv_aw_targeted;
    logic [SLV_NB    -1:0] slv_w_targeted;
    logic [SLV_NB    -1:0] slv_ar_targeted;

    logic                  bch_en;
    logic [SLV_NB    -1:0] bch_req;
    logic [SLV_NB    -1:0] bch_grant;

    logic                  rch_en;
    logic [SLV_NB    -1:0] rch_req;
    logic [SLV_NB    -1:0] rch_grant;

    logic [AXI_ADDR_W-1:0] slv0_start_addr = SLV0_START_ADDR[0+:AXI_ADDR_W];
    logic [AXI_ADDR_W-1:0] slv0_end_addr =   SLV0_END_ADDR[0+:AXI_ADDR_W];
    logic [AXI_ADDR_W-1:0] slv1_start_addr = SLV1_START_ADDR[0+:AXI_ADDR_W];
    logic [AXI_ADDR_W-1:0] slv1_end_addr =   SLV1_END_ADDR[0+:AXI_ADDR_W];
    logic [AXI_ADDR_W-1:0] slv2_start_addr = SLV2_START_ADDR[0+:AXI_ADDR_W];
    logic [AXI_ADDR_W-1:0] slv2_end_addr =   SLV2_END_ADDR[0+:AXI_ADDR_W];
    logic [AXI_ADDR_W-1:0] slv3_start_addr = SLV3_START_ADDR[0+:AXI_ADDR_W];
    logic [AXI_ADDR_W-1:0] slv3_end_addr =   SLV3_END_ADDR[0+:AXI_ADDR_W];


    ///////////////////////////////////////////////////////////////////////////
    // Write Address Channel
    ///////////////////////////////////////////////////////////////////////////

    assign slv_aw_targeted[0] = (i_awch[0+:AXI_ADDR_W] >= slv0_start_addr[0+:AXI_ADDR_W] &&
                                 i_awch[0+:AXI_ADDR_W] <= slv0_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;

    assign slv_aw_targeted[1] = (i_awch[0+:AXI_ADDR_W] >= slv1_start_addr[0+:AXI_ADDR_W] &&
                                 i_awch[0+:AXI_ADDR_W] <= slv1_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;

    assign slv_aw_targeted[2] = (i_awch[0+:AXI_ADDR_W] >= slv2_start_addr[0+:AXI_ADDR_W] &&
                                 i_awch[0+:AXI_ADDR_W] <= slv2_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;

    assign slv_aw_targeted[3] = (i_awch[0+:AXI_ADDR_W] >= slv3_start_addr[0+:AXI_ADDR_W] &&
                                 i_awch[0+:AXI_ADDR_W] <= slv3_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;

    assign o_awvalid[0] = (slv_aw_targeted[0]) ? i_awvalid : 1'b0;
    assign o_awvalid[1] = (slv_aw_targeted[1]) ? i_awvalid : 1'b0;
    assign o_awvalid[2] = (slv_aw_targeted[2]) ? i_awvalid : 1'b0;
    assign o_awvalid[3] = (slv_aw_targeted[3]) ? i_awvalid : 1'b0;

    assign i_awready = (slv_aw_targeted[0]) ? o_awready[0] & !wch_full:
                       (slv_aw_targeted[1]) ? o_awready[1] & !wch_full:
                       (slv_aw_targeted[2]) ? o_awready[2] & !wch_full:
                       (slv_aw_targeted[3]) ? o_awready[3] & !wch_full:
                                              1'b0;

    assign o_awch = i_awch;


    ///////////////////////////////////////////////////////////////////////////
    // Write Data Channel
    ///////////////////////////////////////////////////////////////////////////

    // Store in a FIFO the slave agent targeted because address and data
    // channels are not always synchronized, data possibly coming later
    // after the write request
    axicb_scfifo 
    #(
    .PASS_THRU  (0),
    .ADDR_WIDTH (8),
    .DATA_WIDTH (SLV_NB)
    )
    wch_gnt_fifo 
    (
    .aclk     (aclk),
    .aresetn  (aresetn),
    .srst     (srst),
    .flush    (1'b0),
    .data_in  (slv_aw_targeted),
    .push     (i_awvalid & i_awready),
    .full     (wch_full),
    .data_out (slv_w_targeted),
    .pull     (i_wvalid & i_wready & i_wlast),
    .empty    (wch_empty)
    );

    assign o_wvalid[0] = (~wch_empty & slv_w_targeted[0]) ? i_wvalid : 1'b0;
    assign o_wvalid[1] = (~wch_empty & slv_w_targeted[1]) ? i_wvalid : 1'b0;
    assign o_wvalid[2] = (~wch_empty & slv_w_targeted[2]) ? i_wvalid : 1'b0;
    assign o_wvalid[3] = (~wch_empty & slv_w_targeted[3]) ? i_wvalid : 1'b0;

    assign i_wready = (~wch_empty & slv_w_targeted[0]) ? o_wready[0] :
                      (~wch_empty & slv_w_targeted[1]) ? o_wready[1] :
                      (~wch_empty & slv_w_targeted[2]) ? o_wready[2] :
                      (~wch_empty & slv_w_targeted[3]) ? o_wready[3] :
                                                         1'b0;

    assign o_wlast[0] = (~wch_empty & slv_w_targeted[0]) ? i_wlast : 1'b0;
    assign o_wlast[1] = (~wch_empty & slv_w_targeted[1]) ? i_wlast : 1'b0;
    assign o_wlast[2] = (~wch_empty & slv_w_targeted[2]) ? i_wlast : 1'b0;
    assign o_wlast[3] = (~wch_empty & slv_w_targeted[3]) ? i_wlast : 1'b0;

    assign o_wch = i_wch;


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_round_robin
    #(
        .REQ_NB        (SLV_NB),
        .REQ0_PRIORITY (0),
        .REQ1_PRIORITY (0),
        .REQ2_PRIORITY (0),
        .REQ3_PRIORITY (0)
    )
    bch_round_robin
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (bch_en),
        .req     (bch_req),
        .grant   (bch_grant)
    );

    assign bch_en = i_bvalid & i_bready;

    assign bch_req = o_bvalid;

    assign i_bvalid = (bch_grant[0]) ? o_bvalid[0] :
                      (bch_grant[1]) ? o_bvalid[1] :
                      (bch_grant[2]) ? o_bvalid[2] :
                      (bch_grant[3]) ? o_bvalid[3] :
                                       1'b0;

    assign o_bready[0] = bch_grant[0] & i_bready;
    assign o_bready[1] = bch_grant[1] & i_bready;
    assign o_bready[2] = bch_grant[2] & i_bready;
    assign o_bready[3] = bch_grant[3] & i_bready;

    assign i_bch = (bch_grant[0]) ? o_bch[0*BCH_W+:BCH_W] :
                   (bch_grant[1]) ? o_bch[1*BCH_W+:BCH_W] :
                   (bch_grant[2]) ? o_bch[2*BCH_W+:BCH_W] :
                   (bch_grant[3]) ? o_bch[3*BCH_W+:BCH_W] :
                                    {BCH_W{1'b0}};


    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    assign slv_ar_targeted[0] = (i_arch[0+:AXI_ADDR_W] >= slv0_start_addr[0+:AXI_ADDR_W] &&
                                 i_arch[0+:AXI_ADDR_W] <= slv0_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;
                                                                                                     
    assign slv_ar_targeted[1] = (i_arch[0+:AXI_ADDR_W] >= slv1_start_addr[0+:AXI_ADDR_W] &&
                                 i_arch[0+:AXI_ADDR_W] <= slv1_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;
                                                                                                     
    assign slv_ar_targeted[2] = (i_arch[0+:AXI_ADDR_W] >= slv2_start_addr[0+:AXI_ADDR_W] &&
                                 i_arch[0+:AXI_ADDR_W] <= slv2_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;
                                                                                                     
    assign slv_ar_targeted[3] = (i_arch[0+:AXI_ADDR_W] >= slv3_start_addr[0+:AXI_ADDR_W] &&
                                 i_arch[0+:AXI_ADDR_W] <= slv3_end_addr[0+:AXI_ADDR_W]) ? 1'b1 : 1'b0;

    assign o_arvalid[0] = (slv_ar_targeted[0]) ? i_arvalid : 1'b0;
    assign o_arvalid[1] = (slv_ar_targeted[1]) ? i_arvalid : 1'b0;
    assign o_arvalid[2] = (slv_ar_targeted[2]) ? i_arvalid : 1'b0;
    assign o_arvalid[3] = (slv_ar_targeted[3]) ? i_arvalid : 1'b0;

    assign i_arready = (slv_ar_targeted[0]) ? o_arready[0] :
                       (slv_ar_targeted[1]) ? o_arready[1] :
                       (slv_ar_targeted[2]) ? o_arready[2] :
                       (slv_ar_targeted[3]) ? o_arready[3] :
                                              1'b0;

    assign o_arch = i_arch;


    ///////////////////////////////////////////////////////////////////////////
    // Read Data Channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_round_robin
    #(
        .REQ_NB        (SLV_NB),
        .REQ0_PRIORITY (0),
        .REQ1_PRIORITY (0),
        .REQ2_PRIORITY (0),
        .REQ3_PRIORITY (0)
    )
    rch_round_robin
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (rch_en),
        .req     (rch_req),
        .grant   (rch_grant)
    );

    assign rch_en = i_rvalid & i_rready;

    assign rch_req = o_rvalid;

    assign i_rvalid = (rch_grant[0]) ? o_rvalid[0] :
                      (rch_grant[1]) ? o_rvalid[1] :
                      (rch_grant[2]) ? o_rvalid[2] :
                      (rch_grant[3]) ? o_rvalid[3] :
                                       1'b0;

    assign i_rlast = (rch_grant[0]) ? o_rlast[0] :
                     (rch_grant[1]) ? o_rlast[1] :
                     (rch_grant[2]) ? o_rlast[2] :
                     (rch_grant[3]) ? o_rlast[3] :
                                      1'b0;

    assign o_rready[0] = rch_grant[0] & i_rready;
    assign o_rready[1] = rch_grant[1] & i_rready;
    assign o_rready[2] = rch_grant[2] & i_rready;
    assign o_rready[3] = rch_grant[3] & i_rready;

    assign i_rch = (rch_grant[0]) ? o_rch[0*RCH_W+:RCH_W] :
                   (rch_grant[1]) ? o_rch[1*RCH_W+:RCH_W] :
                   (rch_grant[2]) ? o_rch[2*RCH_W+:RCH_W] :
                   (rch_grant[3]) ? o_rch[3*RCH_W+:RCH_W] :
                                    {RCH_W{1'b0}};

endmodule

`resetall
