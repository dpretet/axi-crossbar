// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_slv_switch


    #(
        // Address width in bits
        parameter AXI_ADDR_W = 8,
        // ID width in bits
        parameter AXI_ID_W = 8,

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI4
        parameter AXI_SIGNALING = 0,

        // Number of slave(s)
        parameter SLV_NB = 4,

        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,

        // Routes allowed to use by this master
        parameter MST_ROUTES = 4'b1_1_1_1,

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
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interfaces from masters
        input  wire                           i_awvalid,
        output logic                          i_awready,
        input  wire  [AWCH_W            -1:0] i_awch,
        input  wire                           i_wvalid,
        output logic                          i_wready,
        input  wire                           i_wlast,
        input  wire  [WCH_W             -1:0] i_wch,
        output logic                          i_bvalid,
        input  wire                           i_bready,
        output logic [BCH_W             -1:0] i_bch,
        input  wire                           i_arvalid,
        output logic                          i_arready,
        input  wire  [ARCH_W            -1:0] i_arch,
        output logic                          i_rvalid,
        input  wire                           i_rready,
        output logic                          i_rlast,
        output logic [RCH_W             -1:0] i_rch,
        // Output interfaces to slaves
        output logic [SLV_NB            -1:0] o_awvalid,
        input  wire  [SLV_NB            -1:0] o_awready,
        output logic [AWCH_W            -1:0] o_awch,
        output logic [SLV_NB            -1:0] o_wvalid,
        input  wire  [SLV_NB            -1:0] o_wready,
        output logic [SLV_NB            -1:0] o_wlast,
        output logic [WCH_W             -1:0] o_wch,
        input  wire  [SLV_NB            -1:0] o_bvalid,
        output logic [SLV_NB            -1:0] o_bready,
        input  wire  [SLV_NB*BCH_W      -1:0] o_bch,
        output logic [SLV_NB            -1:0] o_arvalid,
        input  wire  [SLV_NB            -1:0] o_arready,
        output logic [ARCH_W            -1:0] o_arch,
        input  wire  [SLV_NB            -1:0] o_rvalid,
        output logic [SLV_NB            -1:0] o_rready,
        input  wire  [SLV_NB            -1:0] o_rlast,
        input  wire  [SLV_NB*RCH_W      -1:0] o_rch
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

    logic                  w_misrouting;
    logic                  r_misrouting;

    logic                  bch_mr_full;
    logic                  bch_mr_empty;
    logic [AXI_ID_W  -1:0] bch_mr_id;

    logic                  rch_mr_full;
    logic                  rch_mr_empty;

    logic [AXI_ID_W+8-1:0] rch_mr_info;
    logic [AXI_ID_W  -1:0] rch_mr_id;
    logic [8         -1:0] rch_mr_len;
    logic [8         -1:0] rlen;
    logic                  rch_running;

    logic [SLV_NB    -1:0] routes = MST_ROUTES;

    ///////////////////////////////////////////////////////////////////////////
    // Write Address Channel
    ///////////////////////////////////////////////////////////////////////////

    generate

    if (MST_ROUTES[0]==1'b1) begin : SLV0_AW_ROUTE_ON
        assign slv_aw_targeted[0] = (i_awch[0+:AXI_ADDR_W] >= slv0_start_addr[0+:AXI_ADDR_W] &&
                                     i_awch[0+:AXI_ADDR_W] <= slv0_end_addr[0+:AXI_ADDR_W]) ? 1'b1:
                                                                                              1'b0;
    end else begin : SLV0_AW_ROUTE_OFF
        assign slv_aw_targeted[0] = 1'b0;
    end

    if (MST_ROUTES[1]==1'b1) begin : SLV1_AW_ROUTE_ON
        assign slv_aw_targeted[1] = (i_awch[0+:AXI_ADDR_W] >= slv1_start_addr[0+:AXI_ADDR_W] &&
                                     i_awch[0+:AXI_ADDR_W] <= slv1_end_addr[0+:AXI_ADDR_W]) ? 1'b1 :
                                                                                              1'b0;
    end else begin : SLV1_AW_ROUTE_OFF
        assign slv_aw_targeted[1] = 1'b0;
    end

    if (MST_ROUTES[2]==1'b1) begin : SLV2_AW_ROUTE_ON
        assign slv_aw_targeted[2] = (i_awch[0+:AXI_ADDR_W] >= slv2_start_addr[0+:AXI_ADDR_W] &&
                                     i_awch[0+:AXI_ADDR_W] <= slv2_end_addr[0+:AXI_ADDR_W]) ? 1'b1 :
                                                                                              1'b0;
    end else begin : SLV2_AW_ROUTE_OFF
        assign slv_aw_targeted[2] = 1'b0;
    end

    if (MST_ROUTES[3]==1'b1) begin : SLV3_AW_ROUTE_ON
        assign slv_aw_targeted[3] = (i_awch[0+:AXI_ADDR_W] >= slv3_start_addr[0+:AXI_ADDR_W] &&
                                     i_awch[0+:AXI_ADDR_W] <= slv3_end_addr[0+:AXI_ADDR_W]) ? 1'b1 :
                                                                                              1'b0;
    end else begin : SLV3_AW_ROUTE_OFF
        assign slv_aw_targeted[3] = 1'b0;
    end

    endgenerate

    assign o_awvalid[0] = (slv_aw_targeted[0]) ? i_awvalid : 1'b0;
    assign o_awvalid[1] = (slv_aw_targeted[1]) ? i_awvalid : 1'b0;
    assign o_awvalid[2] = (slv_aw_targeted[2]) ? i_awvalid : 1'b0;
    assign o_awvalid[3] = (slv_aw_targeted[3]) ? i_awvalid : 1'b0;

    assign i_awready = (slv_aw_targeted[0]) ? o_awready[0] & !wch_full:
                       (slv_aw_targeted[1]) ? o_awready[1] & !wch_full:
                       (slv_aw_targeted[2]) ? o_awready[2] & !wch_full:
                       (slv_aw_targeted[3]) ? o_awready[3] & !wch_full:
                                              w_misrouting;

    assign o_awch = i_awch;

    // Create a fake ready handshake in case a master agent targets a
    // forbidden or undefined memory space
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_misrouting <= 1'b0;
        end else if (srst) begin
            w_misrouting <= 1'b0;
        end else begin
            if (w_misrouting) begin
                w_misrouting <= 1'b0;
            end else if (i_awvalid && |slv_aw_targeted==1'b0 && !bch_mr_full) begin
                w_misrouting <= 1'b1;
            end
        end
    end


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
                      // Targets an undefined or forbidden memory space
                      (~wch_empty                    ) ? 1'b1 :
                                                         1'b0;

    assign o_wlast[0] = (~wch_empty & slv_w_targeted[0]) ? i_wlast : 1'b0;
    assign o_wlast[1] = (~wch_empty & slv_w_targeted[1]) ? i_wlast : 1'b0;
    assign o_wlast[2] = (~wch_empty & slv_w_targeted[2]) ? i_wlast : 1'b0;
    assign o_wlast[3] = (~wch_empty & slv_w_targeted[3]) ? i_wlast : 1'b0;

    assign o_wch = i_wch;


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_scfifo
    #(
    .PASS_THRU  (0),
    .ADDR_WIDTH (2),
    .DATA_WIDTH (AXI_ID_W)
    )
    bch_mr_fifo
    (
    .aclk     (aclk),
    .aresetn  (aresetn),
    .srst     (srst),
    .flush    (1'b0),
    .data_in  (i_awch[AXI_ADDR_W+:AXI_ID_W]),
    .push     (w_misrouting),
    .full     (bch_mr_full),
    .data_out (bch_mr_id),
    .pull     (i_bvalid & i_bready),
    .empty    (bch_mr_empty)
    );

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

    assign bch_en = i_bvalid & i_bready & bch_mr_empty;

    assign bch_req = o_bvalid;

    assign i_bvalid = (!bch_mr_empty) ? 1'b1 :
                      (bch_grant[0]) ? o_bvalid[0] :
                      (bch_grant[1]) ? o_bvalid[1] :
                      (bch_grant[2]) ? o_bvalid[2] :
                      (bch_grant[3]) ? o_bvalid[3] :
                                       1'b0;

    assign o_bready[0] = bch_grant[0] & i_bready & bch_mr_empty;
    assign o_bready[1] = bch_grant[1] & i_bready & bch_mr_empty;
    assign o_bready[2] = bch_grant[2] & i_bready & bch_mr_empty;
    assign o_bready[3] = bch_grant[3] & i_bready & bch_mr_empty;

    assign i_bch = (!bch_mr_empty) ? {2'h3, bch_mr_id}:
                   (bch_grant[0])  ? o_bch[0*BCH_W+:BCH_W] :
                   (bch_grant[1])  ? o_bch[1*BCH_W+:BCH_W] :
                   (bch_grant[2])  ? o_bch[2*BCH_W+:BCH_W] :
                   (bch_grant[3])  ? o_bch[3*BCH_W+:BCH_W] :
                                     {BCH_W{1'b0}};


    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    generate

    if (MST_ROUTES[0]==1'b1) begin : SLV0_AR_ROUTE_ON
        assign slv_ar_targeted[0] = (i_arch[0+:AXI_ADDR_W] >= slv0_start_addr[0+:AXI_ADDR_W] &&
                                     i_arch[0+:AXI_ADDR_W] <= slv0_end_addr[0+:AXI_ADDR_W]) ? 1'b1:
                                                                                              1'b0;
    end else begin : SLV0_AR_ROUTE_OFF
        assign slv_ar_targeted[0] = 1'b0;
    end

    if (MST_ROUTES[1]==1'b1) begin : SLV1_AR_ROUTE_ON
        assign slv_ar_targeted[1] = (i_arch[0+:AXI_ADDR_W] >= slv1_start_addr[0+:AXI_ADDR_W] &&
                                     i_arch[0+:AXI_ADDR_W] <= slv1_end_addr[0+:AXI_ADDR_W]) ? 1'b1 :
                                                                                              1'b0;
    end else begin : SLV1_AR_ROUTE_OFF
        assign slv_ar_targeted[1] = 1'b0;
    end

    if (MST_ROUTES[2]==1'b1) begin : SLV2_AR_ROUTE_ON
        assign slv_ar_targeted[2] = (i_arch[0+:AXI_ADDR_W] >= slv2_start_addr[0+:AXI_ADDR_W] &&
                                     i_arch[0+:AXI_ADDR_W] <= slv2_end_addr[0+:AXI_ADDR_W]) ? 1'b1 :
                                                                                              1'b0;
    end else begin : SLV2_AR_ROUTE_OFF
        assign slv_ar_targeted[2] = 1'b0;
    end

    if (MST_ROUTES[3]==1'b1) begin : SLV3_AR_ROUTE_ON
        assign slv_ar_targeted[3] = (i_arch[0+:AXI_ADDR_W] >= slv3_start_addr[0+:AXI_ADDR_W] &&
                                     i_arch[0+:AXI_ADDR_W] <= slv3_end_addr[0+:AXI_ADDR_W]) ? 1'b1 :
                                                                                              1'b0;
    end else begin : SLV3_AR_ROUTE_OFF
        assign slv_ar_targeted[3] = 1'b0;
    end

    endgenerate

    assign o_arvalid[0] = (slv_ar_targeted[0]) ? i_arvalid : 1'b0;
    assign o_arvalid[1] = (slv_ar_targeted[1]) ? i_arvalid : 1'b0;
    assign o_arvalid[2] = (slv_ar_targeted[2]) ? i_arvalid : 1'b0;
    assign o_arvalid[3] = (slv_ar_targeted[3]) ? i_arvalid : 1'b0;

    assign i_arready = (slv_ar_targeted[0]) ? o_arready[0]:
                       (slv_ar_targeted[1]) ? o_arready[1]:
                       (slv_ar_targeted[2]) ? o_arready[2]:
                       (slv_ar_targeted[3]) ? o_arready[3]:
                                              r_misrouting;

    assign o_arch = i_arch;

    // Create a fake ready handshake in case a master agent targets a
    // forbidden or undefined memory space
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_misrouting <= 1'b0;
        end else if (srst) begin
            r_misrouting <= 1'b0;
        end else begin
            if (r_misrouting) begin
                r_misrouting <= 1'b0;
            end else if (i_arvalid && |slv_ar_targeted==1'b0 && !rch_mr_full) begin
                r_misrouting <= 1'b1;
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////
    // Read Data Channel
    ///////////////////////////////////////////////////////////////////////////

    generate
    // Gather ARID and ARLEN to pass them to the completion circuit returning
    // the DECERR completion in case of misrouting
    if (AXI_SIGNALING>0)
    begin: AXI_SUPPORT
        assign rch_mr_info = {i_arch[AXI_ADDR_W+AXI_ID_W+:8], i_arch[AXI_ADDR_W+:AXI_ID_W]};
    end else
    begin: AXI4_LITE_SUPPORT
        assign rch_mr_info = {8'h0, i_arch[AXI_ADDR_W+:AXI_ID_W]};
    end
    endgenerate


    // FIFO storing the misrouting completion to return
    axicb_scfifo
    #(
    .PASS_THRU  (0),
    .ADDR_WIDTH (4),
    .DATA_WIDTH (AXI_ID_W+8)
    )
    rch_mr_fifo
    (
    .aclk     (aclk),
    .aresetn  (aresetn),
    .srst     (srst),
    .flush    (1'b0),
    .data_in  (rch_mr_info),
    .push     (r_misrouting),
    .full     (rch_mr_full),
    .data_out ({rch_mr_len, rch_mr_id}),
    .pull     (i_rvalid & i_rready & i_rlast & !rch_running),
    .empty    (rch_mr_empty)
    );


    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rlen <= 8'h0;
            rch_running <= 1'b0;
        end else if (srst) begin
            rlen <= 8'h0;
            rch_running <= 1'b0;
        end else begin

            if (rch_running && i_rvalid && i_rready && i_rlast) begin
                rch_running <= 1'b0;
            end else if (rch_mr_empty && i_rvalid && !i_rlast) begin
                rch_running <= 1'b1;
            end

            if (rch_mr_empty) begin
                rlen <= 8'h0;
            end else if (i_rvalid && i_rready && i_rlast && !rch_running) begin
                rlen <= 8'h0;
            end else begin
                if (i_rvalid && i_rready && !rch_running) begin
                    rlen <= rlen + 1'b1;
                end
            end
        end
    end

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

    assign rch_en = i_rvalid & i_rready & rch_running;

    assign rch_req = o_rvalid;

    assign i_rvalid = (!rch_mr_empty && !rch_running) ? 1'b1 :
                      (rch_grant[0]) ? o_rvalid[0] :
                      (rch_grant[1]) ? o_rvalid[1] :
                      (rch_grant[2]) ? o_rvalid[2] :
                      (rch_grant[3]) ? o_rvalid[3] :
                                       1'b0;

    assign i_rlast = (!rch_mr_empty && !rch_running) ? (rlen==rch_mr_len) & i_rvalid & i_rready :
                     (rch_grant[0]) ? o_rlast[0] :
                     (rch_grant[1]) ? o_rlast[1] :
                     (rch_grant[2]) ? o_rlast[2] :
                     (rch_grant[3]) ? o_rlast[3] :
                                      1'b0;

    assign o_rready[0] = rch_grant[0] & i_rready & (rch_mr_empty | rch_running);
    assign o_rready[1] = rch_grant[1] & i_rready & (rch_mr_empty | rch_running);
    assign o_rready[2] = rch_grant[2] & i_rready & (rch_mr_empty | rch_running);
    assign o_rready[3] = rch_grant[3] & i_rready & (rch_mr_empty | rch_running);

    assign i_rch = (!rch_mr_empty && !rch_running) ? {{RCH_W-AXI_ID_W-2{1'b0}}, 2'h3, rch_mr_id} :
                   (rch_grant[0]) ? o_rch[0*RCH_W+:RCH_W] :
                   (rch_grant[1]) ? o_rch[1*RCH_W+:RCH_W] :
                   (rch_grant[2]) ? o_rch[2*RCH_W+:RCH_W] :
                   (rch_grant[3]) ? o_rch[3*RCH_W+:RCH_W] :
                                    {RCH_W{1'b0}};

endmodule

`resetall
