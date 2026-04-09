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

        // Slave Memory Mapping
        parameter [AXI_ADDR_W * SLV_NB - 1:0] SLV_START_ADDR = '0,
        parameter [AXI_ADDR_W * SLV_NB - 1:0] SLV_END_ADDR = '0,

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
    logic                  rfirst;
    logic                  rch_mr;
    logic [AXI_ID_W  -1:0] rch_id;
    logic [8         -1:0] rch_len;
    logic [SLV_NB    -1:0] rch_grant;
    logic [8         -1:0] rlen;
    logic                  rch_full;
    logic                  c_end;

    // Extract start/end addresses from packed parameters (generic for SLV_NB)
    logic [AXI_ADDR_W-1:0] slv_start_addr [0:SLV_NB-1];
    logic [AXI_ADDR_W-1:0] slv_end_addr   [0:SLV_NB-1];

    generate
    genvar i;
        for (i = 0; i < SLV_NB; i = i + 1) begin : SLV_ADDR_EXTRACT
            assign slv_start_addr[i] = SLV_START_ADDR[i*AXI_ADDR_W+:AXI_ADDR_W];
            assign slv_end_addr[i]   = SLV_END_ADDR[i*AXI_ADDR_W+:AXI_ADDR_W];
        end
    endgenerate


    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    // Address decoding
    generate
    genvar j;
    for (j = 0; j < SLV_NB; j = j + 1) begin : SLV_AR_ROUTE
        if (MST_ROUTES[j]==1'b1) begin : ROUTE_ON
            assign slv_ar_targeted[j] = (i_arch[0+:AXI_ADDR_W] >= slv_start_addr[j] &&
                                         i_arch[0+:AXI_ADDR_W] <= slv_end_addr[j]) ? 1'b1 : 1'b0;
        end else begin : ROUTE_OFF
            assign slv_ar_targeted[j] = 1'b0;
        end
    end
    endgenerate

    // AR channel assignments
    generate
    genvar n;
        for (n = 0; n < SLV_NB; n = n + 1) begin : SLV_AR_VALID
            assign o_arvalid[n] = (slv_ar_targeted[n]) ? i_arvalid & !rch_full : 1'b0;
        end
    endgenerate

    // Ready back-pressure selection
    always_comb begin

        if (slv_ar_targeted == '0)
            i_arready = ar_misrouting;
        else
            i_arready = '0;
            for (int i = 0; i < SLV_NB; i++)
                if (slv_ar_targeted[i])
                    i_arready = o_arready[i] & !rch_full;
    end

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

    // Follow-up completion len for misrouted traffic
    // to create RLAST flag
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

    // Activates the arbiter in OoO module on first read completion dataphase
    assign rch_en = rfirst;

    // Switching logic for RRESP channel

    always_comb begin

        i_rvalid = '0;
        i_rlast = '0;
        i_rch = '0;

        // RVALID Signal
        if (rch_mr)
            i_rvalid = '1;
        else if (rch_grant == '0)
            i_rvalid = '0;
        else
            for (int i=0;i<SLV_NB;i++)
                if (rch_grant[i])
                    i_rvalid = o_rvalid[i];

        // RLAST Signal
        if (rch_mr)
            i_rlast = (rlen==rch_len) & i_rvalid & i_rready;
        else if (rch_grant == '0)
            i_rlast = '0;
        else
            for (int i=0;i<SLV_NB;i++)
                if (rch_grant[i])
                    i_rlast = o_rlast[i];

        // RRESP / RDATA / RUSER
        if (rch_mr)
            i_rch = {'0, 2'h3, rch_id} ;
        else if (rch_grant == '0)
            i_rch = '0;
        else
            for (int i=0;i<SLV_NB;i++)
                if (rch_grant[i])
                    i_rch = o_rch[i*RCH_W+:RCH_W];
    end

    generate
    genvar m;
        for (m = 0; m < SLV_NB; m = m + 1) begin : SLV_R_READY
            assign o_rready[m] = rch_grant[m] & i_rready & !rch_mr;
        end
    endgenerate

endmodule

`resetall
