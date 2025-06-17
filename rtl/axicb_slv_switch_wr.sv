// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_slv_switch_wr

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

        // Max Outstanding Request
        parameter MST_OSTDREQ_NUM = 4,

        // Master ID mask
        parameter [AXI_ID_W-1:0] MST_ID_MASK = 'h00,

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
        parameter BCH_W = 10,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // Global interface
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interface from master
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
        input  wire  [SLV_NB*BCH_W      -1:0] o_bch
    );


    ///////////////////////////////////////////////////////////////////////////
    // Local declarations
    ///////////////////////////////////////////////////////////////////////////

    logic [SLV_NB    -1:0] slv_aw_targeted;
    logic [SLV_NB    -1:0] slv_w_targeted;
    logic                  aw_misrouting;
    logic                  aw_misrouting_c;

    logic                  wch_full;
    logic                  bch_full;
    logic                  wch_empty;

    logic                  bch_en;
    logic                  bch_en_c;
    logic                  bch_en_r;
    logic [SLV_NB    -1:0] bch_grant;
    logic                  bch_mr;
    logic [AXI_ID_W  -1:0] bch_id;
    logic                  c_end;

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
                                     i_awch[0+:AXI_ADDR_W] <= slv1_end_addr[0+:AXI_ADDR_W]) ? 1'b1:
                                                                                              1'b0;
    end else begin : SLV1_AW_ROUTE_OFF
        assign slv_aw_targeted[1] = 1'b0;
    end

    if (MST_ROUTES[2]==1'b1) begin : SLV2_AW_ROUTE_ON
        assign slv_aw_targeted[2] = (i_awch[0+:AXI_ADDR_W] >= slv2_start_addr[0+:AXI_ADDR_W] &&
                                     i_awch[0+:AXI_ADDR_W] <= slv2_end_addr[0+:AXI_ADDR_W]) ? 1'b1:
                                                                                              1'b0;
    end else begin : SLV2_AW_ROUTE_OFF
        assign slv_aw_targeted[2] = 1'b0;
    end

    if (MST_ROUTES[3]==1'b1) begin : SLV3_AW_ROUTE_ON
        assign slv_aw_targeted[3] = (i_awch[0+:AXI_ADDR_W] >= slv3_start_addr[0+:AXI_ADDR_W] &&
                                     i_awch[0+:AXI_ADDR_W] <= slv3_end_addr[0+:AXI_ADDR_W]) ? 1'b1:
                                                                                              1'b0;
    end else begin : SLV3_AW_ROUTE_OFF
        assign slv_aw_targeted[3] = 1'b0;
    end

    endgenerate

    assign o_awvalid[0] = (slv_aw_targeted[0]) ? i_awvalid & !bch_full & !wch_full : 1'b0;
    assign o_awvalid[1] = (slv_aw_targeted[1]) ? i_awvalid & !bch_full & !wch_full : 1'b0;
    assign o_awvalid[2] = (slv_aw_targeted[2]) ? i_awvalid & !bch_full & !wch_full : 1'b0;
    assign o_awvalid[3] = (slv_aw_targeted[3]) ? i_awvalid & !bch_full & !wch_full : 1'b0;

    assign i_awready = (slv_aw_targeted[0]) ? o_awready[0] & !bch_full & !wch_full :
                       (slv_aw_targeted[1]) ? o_awready[1] & !bch_full & !wch_full :
                       (slv_aw_targeted[2]) ? o_awready[2] & !bch_full & !wch_full :
                       (slv_aw_targeted[3]) ? o_awready[3] & !bch_full & !wch_full :
                                              aw_misrouting;

    assign o_awch = i_awch;
    
    assign aw_misrouting_c = slv_aw_targeted=='0;

    // Create a fake ready handshake in case a master agent targets a
    // forbidden or undefined memory space
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_misrouting <= 1'b0;
        end else if (srst) begin
            aw_misrouting <= 1'b0;
        end else begin
            if (aw_misrouting) begin
                aw_misrouting <= 1'b0;
            end else if (i_awvalid && aw_misrouting_c) begin
                aw_misrouting <= 1'b1;
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

    assign o_wvalid[0] = (!wch_empty & slv_w_targeted[0]) ? i_wvalid : 1'b0;
    assign o_wvalid[1] = (!wch_empty & slv_w_targeted[1]) ? i_wvalid : 1'b0;
    assign o_wvalid[2] = (!wch_empty & slv_w_targeted[2]) ? i_wvalid : 1'b0;
    assign o_wvalid[3] = (!wch_empty & slv_w_targeted[3]) ? i_wvalid : 1'b0;

    assign i_wready = (!wch_empty & slv_w_targeted[0]) ? o_wready[0] :
                      (!wch_empty & slv_w_targeted[1]) ? o_wready[1] :
                      (!wch_empty & slv_w_targeted[2]) ? o_wready[2] :
                      (!wch_empty & slv_w_targeted[3]) ? o_wready[3] :
                      // Targets an undefined or forbidden memory space
                      (!wch_empty                    ) ? 1'b1 :
                                                         1'b0;

    assign o_wlast[0] = (!wch_empty & slv_w_targeted[0]) ? i_wlast : 1'b0;
    assign o_wlast[1] = (!wch_empty & slv_w_targeted[1]) ? i_wlast : 1'b0;
    assign o_wlast[2] = (!wch_empty & slv_w_targeted[2]) ? i_wlast : 1'b0;
    assign o_wlast[3] = (!wch_empty & slv_w_targeted[3]) ? i_wlast : 1'b0;

    assign o_wch = i_wch;


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    // OoO ID Management
    axicb_slv_ooo 
    #(
        .RD_PATH         (0),
        .AXI_ID_W        (AXI_ID_W),
        .SLV_NB          (SLV_NB),
        .MST_OSTDREQ_NUM (MST_OSTDREQ_NUM),
        .MST_ID_MASK     (MST_ID_MASK),
        .CCH_W           (BCH_W)
    )
    bresp_ooo 
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .a_valid (i_awvalid),
        .a_ready (i_awready),
        .a_full  (bch_full),
        .a_id    (i_awch[AXI_ADDR_W+:AXI_ID_W]),
        .a_len   ('0),
        .a_ix    (slv_aw_targeted),
        .a_mr    (aw_misrouting_c),
        .c_en    (bch_en),
        .c_grant (bch_grant),
        .c_mr    (bch_mr),
        .c_id    (bch_id),
        .c_len   (/*unused*/),
        .c_valid (o_bvalid),
        .c_ready (i_bready),
        .c_last  ('1),
        .c_ch    (o_bch),
        .c_end   (c_end),
        .mr_last (1'b1)
    );

    assign c_end = i_bvalid & i_bready;

    // Control of the OoO ID management stage

    assign bch_en_c = |o_bvalid & i_bready;

    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            bch_en_r <= '0;
        end else if (srst) begin
            bch_en_r <= '0;
        end else begin
            if (bch_grant=='0) bch_en_r <= 1'b1;
            else               bch_en_r <= 1'b0;
        end
    end

    assign bch_en = bch_en_c | bch_en_r;

    // Switching logic for BRESP channel

    assign i_bvalid = (bch_mr) ? 1'b1 :
                      (bch_grant[0]) ? o_bvalid[0] :
                      (bch_grant[1]) ? o_bvalid[1] :
                      (bch_grant[2]) ? o_bvalid[2] :
                      (bch_grant[3]) ? o_bvalid[3] :
                                       1'b0;

    assign o_bready[0] = bch_grant[0] & i_bready;
    assign o_bready[1] = bch_grant[1] & i_bready;
    assign o_bready[2] = bch_grant[2] & i_bready;
    assign o_bready[3] = bch_grant[3] & i_bready;

    assign i_bch = (bch_mr)        ? {2'h3, bch_id}:
                   (bch_grant[0])  ? o_bch[0*BCH_W+:BCH_W] :
                   (bch_grant[1])  ? o_bch[1*BCH_W+:BCH_W] :
                   (bch_grant[2])  ? o_bch[2*BCH_W+:BCH_W] :
                   (bch_grant[3])  ? o_bch[3*BCH_W+:BCH_W] :
                                     {BCH_W{1'b0}};


endmodule

`resetall
