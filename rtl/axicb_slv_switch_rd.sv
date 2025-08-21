// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_slv_switch_rd

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
        parameter BCH_W = 8,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // Global interface
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interface from master
        input  wire                           i_arvalid,
        output logic                          i_arready,
        input  wire  [ARCH_W            -1:0] i_arch,
        output logic                          i_rvalid,
        input  wire                           i_rready,
        output logic                          i_rlast,
        output logic [RCH_W             -1:0] i_rch,
        // Output interfaces to slaves
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


    logic [SLV_NB    -1:0] slv_ar_targeted;
    logic                  ar_misrouting_c;
    logic                  ar_misrouting;
    logic [8         -1:0] a_len;

    logic                  rch_en;
    logic                  rch_en_r;
    logic                  rfirst;
    logic                  rch_mr;
    logic [AXI_ID_W  -1:0] rch_id;
    logic [8         -1:0] rch_len;
    logic [SLV_NB    -1:0] rch_grant;
    logic [8         -1:0] rlen;
    logic                  rch_running;
    logic                  rch_full;
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
                                              ar_misrouting;

    assign o_arch = i_arch;

    assign ar_misrouting_c = slv_ar_targeted=='0;

    // Create a fake ready handshake in case a master agent targets a
    // forbidden or undefined memory space
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ar_misrouting <= 1'b0;
        end else if (srst) begin
            ar_misrouting <= 1'b0;
        end else begin
            if (ar_misrouting) begin
                ar_misrouting <= 1'b0;
            end else if (i_arvalid && ar_misrouting_c) begin
                ar_misrouting <= 1'b1;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Read Data Channel
    ///////////////////////////////////////////////////////////////////////////

    generate
    if (AXI_SIGNALING) begin: AXI4_ALEN
        assign a_len = i_arch[AXI_ADDR_W+AXI_ID_W+:8];
    end else begin: AXI4LITE_ALEN0
        assign a_len = '0;
    end
    endgenerate

    // OoO ID Management
    axicb_slv_ooo 
    #(
        .RD_PATH         (1),
        .AXI_ID_W        (AXI_ID_W),
        .SLV_NB          (SLV_NB),
        .MST_OSTDREQ_NUM (MST_OSTDREQ_NUM),
        .MST_ID_MASK     (MST_ID_MASK),
        .CCH_W           (RCH_W)
    )
    rresp_ooo 
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .a_valid (i_arvalid),
        .a_ready (i_arready),
        .a_full  (rch_full),
        .a_id    (i_arch[AXI_ADDR_W+:AXI_ID_W]),
        .a_len   (a_len),
        .a_ix    (slv_ar_targeted),
        .a_mr    (ar_misrouting_c),
        .c_en    (rch_en),
        .c_grant (rch_grant),
        .c_mr    (rch_mr),
        .c_id    (rch_id),
        .c_len   (rch_len),
        .c_valid (o_rvalid),
        .c_ready (i_rready),
        .c_ch    (o_rch),
        .c_end   (c_end)
    );


    assign c_end = i_rvalid & i_rready & i_rlast;

    // Follow-up rcompletion len for mis-routed traffic 
    // which need to be recreated
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rlen <= 8'h0;
        end else if (srst) begin
            rlen <= 8'h0;
        end else begin

            if (i_rvalid && i_rready && i_rlast) begin
                rlen <= 8'h0;
            end else begin
                if (i_rvalid && i_rready) begin
                    rlen <= rlen + 1'b1;
                end
            end
        end
    end

    // Indicates the first read completion dataphase
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rfirst <= 1'b1;
        end else if (srst) begin
            rfirst <= 1'b1;
        end else begin
            if (i_rvalid && i_rready) begin
                if (i_rlast) rfirst <= 1'b1;
                else         rfirst <= 1'b0;
            end
        end
    end

    
    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rch_en_r <= '0;
        end else if (srst) begin
            rch_en_r <= '0;
        end else begin
            if (rch_grant=='0) rch_en_r <= 1'b1;
            else               rch_en_r <= 1'b0;
        end
    end


    assign rch_en = rfirst | rch_en_r;

    assign i_rvalid = (rch_mr)       ? 1'b1 :
                      (rch_grant[0]) ? o_rvalid[0] :
                      (rch_grant[1]) ? o_rvalid[1] :
                      (rch_grant[2]) ? o_rvalid[2] :
                      (rch_grant[3]) ? o_rvalid[3] :
                                       1'b0;

    assign i_rlast = (rch_mr)        ? (rlen==rch_len) & i_rvalid & i_rready :
                     (rch_grant[0])  ? o_rlast[0] :
                     (rch_grant[1])  ? o_rlast[1] :
                     (rch_grant[2])  ? o_rlast[2] :
                     (rch_grant[3])  ? o_rlast[3] :
                                       1'b0;

    assign o_rready[0] = rch_grant[0] & i_rready & !rch_mr;
    assign o_rready[1] = rch_grant[1] & i_rready & !rch_mr;
    assign o_rready[2] = rch_grant[2] & i_rready & !rch_mr;
    assign o_rready[3] = rch_grant[3] & i_rready & !rch_mr;

    assign i_rch = (rch_mr)       ? {'0, 2'h3, rch_id} :
                   (rch_grant[0]) ? o_rch[0*RCH_W+:RCH_W] :
                   (rch_grant[1]) ? o_rch[1*RCH_W+:RCH_W] :
                   (rch_grant[2]) ? o_rch[2*RCH_W+:RCH_W] :
                   (rch_grant[3]) ? o_rch[3*RCH_W+:RCH_W] :
                                    {RCH_W{1'b0}};

endmodule

`resetall
