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

    axicb_slv_switch_wr
    #(
        .AXI_ADDR_W      (AXI_ADDR_W),
        .AXI_ID_W        (AXI_ID_W),
        .AXI_SIGNALING   (AXI_SIGNALING),
        .SLV_NB          (SLV_NB),
        .MST_ROUTES      (MST_ROUTES),
        .TIMEOUT_ENABLE  (TIMEOUT_ENABLE),
        .SLV0_START_ADDR (SLV0_START_ADDR),
        .SLV0_END_ADDR   (SLV0_END_ADDR),
        .SLV1_START_ADDR (SLV1_START_ADDR),
        .SLV1_END_ADDR   (SLV1_END_ADDR),
        .SLV2_START_ADDR (SLV2_START_ADDR),
        .SLV2_END_ADDR   (SLV2_END_ADDR),
        .SLV3_START_ADDR (SLV3_START_ADDR),
        .SLV3_END_ADDR   (SLV3_END_ADDR),
        .AWCH_W          (AWCH_W),
        .WCH_W           (WCH_W),
        .BCH_W           (BCH_W),
        .ARCH_W          (ARCH_W),
        .RCH_W           (RCH_W)
    )
    slv_switch_wr
    (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .srst      (srst),
        .i_awvalid (i_awvalid),
        .i_awready (i_awready),
        .i_awch    (i_awch   ),
        .i_wvalid  (i_wvalid ),
        .i_wready  (i_wready ),
        .i_wlast   (i_wlast  ),
        .i_wch     (i_wch    ),
        .i_bvalid  (i_bvalid ),
        .i_bready  (i_bready ),
        .i_bch     (i_bch    ),
        .o_awvalid (o_awvalid),
        .o_awready (o_awready),
        .o_awch    (o_awch   ),
        .o_wvalid  (o_wvalid ),
        .o_wready  (o_wready ),
        .o_wlast   (o_wlast  ),
        .o_wch     (o_wch    ),
        .o_bvalid  (o_bvalid ),
        .o_bready  (o_bready ),
        .o_bch     (o_bch    )
    );

    axicb_slv_switch_rd
    #(
        .AXI_ADDR_W      (AXI_ADDR_W),
        .AXI_ID_W        (AXI_ID_W),
        .AXI_SIGNALING   (AXI_SIGNALING),
        .SLV_NB          (SLV_NB),
        .MST_ROUTES      (MST_ROUTES),
        .TIMEOUT_ENABLE  (TIMEOUT_ENABLE),
        .SLV0_START_ADDR (SLV0_START_ADDR),
        .SLV0_END_ADDR   (SLV0_END_ADDR),
        .SLV1_START_ADDR (SLV1_START_ADDR),
        .SLV1_END_ADDR   (SLV1_END_ADDR),
        .SLV2_START_ADDR (SLV2_START_ADDR),
        .SLV2_END_ADDR   (SLV2_END_ADDR),
        .SLV3_START_ADDR (SLV3_START_ADDR),
        .SLV3_END_ADDR   (SLV3_END_ADDR),
        .AWCH_W          (AWCH_W),
        .WCH_W           (WCH_W),
        .BCH_W           (BCH_W),
        .ARCH_W          (ARCH_W),
        .RCH_W           (RCH_W)
    )
    slv_switch_rd
    (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .srst      (srst),
        .i_arvalid (i_arvalid),
        .i_arready (i_arready),
        .i_arch    (i_arch   ),
        .i_rvalid  (i_rvalid ),
        .i_rready  (i_rready ),
        .i_rlast   (i_rlast  ),
        .i_rch     (i_rch    ),
        .o_arvalid (o_arvalid),
        .o_arready (o_arready),
        .o_arch    (o_arch   ),
        .o_rvalid  (o_rvalid ),
        .o_rready  (o_rready ),
        .o_rlast   (o_rlast  ),
        .o_rch     (o_rch    )
    );

endmodule

`resetall
