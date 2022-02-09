// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

///////////////////////////////////////////////////////////////////////////////
//
// AXI4 crossbar top level, instanciating the global infrastructure of the
// core. All the master and slave interfaces are instanciated here along the
// switching logic.
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ps
`default_nettype none

`include "axicb_checker.sv"

module axicb_crossbar_lite_top

    #(
        ///////////////////////////////////////////////////////////////////////
        // Global configuration
        ///////////////////////////////////////////////////////////////////////

        // Address width in bits
        parameter AXI_ADDR_W = 8,
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // Number of master(s)
        parameter MST_NB = 4,
        // Number of slave(s)
        parameter SLV_NB = 4,

        // Switching logic pipelining (0 deactivate, 1 enable)
        parameter MST_PIPELINE = 0,
        parameter SLV_PIPELINE = 0,

        // STRB support:
        //   - 0: contiguous wstrb (store only 1st/last dataphase)
        //   - 1: full wstrb transport
        parameter STRB_MODE = 1,

        // USER fields transport enabling (0 deactivate, 1 activate)
        parameter USER_SUPPORT = 0,
        // USER fields width in bits
        parameter AXI_AUSER_W = 1,
        parameter AXI_WUSER_W = 1,
        parameter AXI_BUSER_W = 1,
        parameter AXI_RUSER_W = 1,

        // Timeout configuration in clock cycles, applied to all channels
        parameter TIMEOUT_VALUE = 10000,
        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,


        ///////////////////////////////////////////////////////////////////////
        //
        // Master agent configurations:
        //
        //   - MSTx_CDC: implement input CDC stage, 0 or 1
        //
        //   - MSTx_OSTDREQ_NUM: maximum number of requests a master can
        //                       store internally
        //
        //   - MSTx_PRIORITY: priority applied to this master in the arbitrers,
        //                    from 0 to 3 included
        //   - MSTx_ROUTES: routing from the master to the slaves allowed in
        //                  the switching logic. Bit 0 for slave 0, bit 1 for
        //                  slave 1, ...
        //
        //   - MSTx_ID_MASK : A mask applied in slave completion channel to
        //                    determine which master to route back the
        //                    BRESP/RRESP completions.
        //
        // The size of a master's internal buffer is equal to:
        //
        // SIZE = AXI_DATA_W * MSTx_OSTDREQ_NUM * MSTx_OSTDREQ_SIZE (in bits)
        //
        ///////////////////////////////////////////////////////////////////////


        ///////////////////////////////////////////////////////////////////////
        // Master 0 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST0_CDC = 0,
        parameter MST0_OSTDREQ_NUM = 4,
        parameter MST0_PRIORITY = 0,
        parameter [SLV_NB-1:0] MST0_ROUTES = 4'b1_1_1_1,
        parameter [AXI_ID_W-1:0] MST0_ID_MASK = 'h10,
        parameter MST0_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 1 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST1_CDC = 0,
        parameter MST1_OSTDREQ_NUM = 4,
        parameter MST1_PRIORITY = 0,
        parameter [SLV_NB-1:0] MST1_ROUTES = 4'b1_1_1_1,
        parameter [AXI_ID_W-1:0] MST1_ID_MASK = 'h20,
        parameter MST1_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 2 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST2_CDC = 0,
        parameter MST2_OSTDREQ_NUM = 4,
        parameter MST2_PRIORITY = 0,
        parameter [SLV_NB-1:0] MST2_ROUTES = 4'b1_1_1_1,
        parameter [AXI_ID_W-1:0] MST2_ID_MASK = 'h30,
        parameter MST2_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 3 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST3_CDC = 0,
        parameter MST3_OSTDREQ_NUM = 4,
        parameter MST3_PRIORITY = 0,
        parameter [SLV_NB-1:0] MST3_ROUTES = 4'b1_1_1_1,
        parameter [AXI_ID_W-1:0] MST3_ID_MASK = 'h40,
        parameter MST3_RW = 0,


        ///////////////////////////////////////////////////////////////////////
        //
        // Slave agent configurations:
        //
        //   - SLVx_CDC: implement input CDC stage, 0 or 1
        //
        //   - SLVx_OSTDREQ_NUM: maximum number of requests slave can
        //                       store internally
        //
        //   - SLVx_START_ADDR: Start address allocated to the slave, in byte
        //
        //   - SLVx_END_ADDR: End address allocated to the slave, in byte
        //
        //   - SLVx_KEEP_BASE_ADDR: Keep the absolute address of the slave in
        //     the memory map. Default to 0.
        //
        // The size of a slave's internal buffer is equal to:
        //
        //   AXI_DATA_W * SLVx_OSTDREQ_NUM * SLVx_OSTDREQ_SIZE (in bits)
        //
        // A request is routed to a slave if:
        //
        //   START_ADDR <= ADDR <= END_ADDR
        //
        ///////////////////////////////////////////////////////////////////////


        ///////////////////////////////////////////////////////////////////////
        // Slave 0 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV0_CDC = 0,
        parameter SLV0_START_ADDR = 0,
        parameter SLV0_END_ADDR = 4095,
        parameter SLV0_OSTDREQ_NUM = 4,
        parameter SLV0_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 1 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV1_CDC = 0,
        parameter SLV1_START_ADDR = 4096,
        parameter SLV1_END_ADDR = 8191,
        parameter SLV1_OSTDREQ_NUM = 4,
        parameter SLV1_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 2 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV2_CDC = 0,
        parameter SLV2_START_ADDR = 8192,
        parameter SLV2_END_ADDR = 12287,
        parameter SLV2_OSTDREQ_NUM = 4,
        parameter SLV2_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 3 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV3_CDC = 0,
        parameter SLV3_START_ADDR = 12288,
        parameter SLV3_END_ADDR = 16383,
        parameter SLV3_OSTDREQ_NUM = 4,
        parameter SLV3_KEEP_BASE_ADDR = 0
    )(
        ///////////////////////////////////////////////////////////////////////
        // Interconnect global interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       aclk,
        input  wire                       aresetn,
        input  wire                       srst,

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 0 interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       slv0_aclk,
        input  wire                       slv0_aresetn,
        input  wire                       slv0_srst,
        input  wire                       slv0_awvalid,
        output logic                      slv0_awready,
        input  wire  [AXI_ADDR_W    -1:0] slv0_awaddr,
        input  wire  [3             -1:0] slv0_awprot,
        input  wire  [AXI_ID_W      -1:0] slv0_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv0_awuser,
        input  wire                       slv0_wvalid,
        output logic                      slv0_wready,
        input  wire  [AXI_DATA_W    -1:0] slv0_wdata,
        input  wire  [AXI_DATA_W/8  -1:0] slv0_wstrb,
        input  wire  [AXI_WUSER_W   -1:0] slv0_wuser,
        output logic                      slv0_bvalid,
        input  wire                       slv0_bready,
        output logic [AXI_ID_W      -1:0] slv0_bid,
        output logic [2             -1:0] slv0_bresp,
        output logic [AXI_BUSER_W   -1:0] slv0_buser,
        input  wire                       slv0_arvalid,
        output logic                      slv0_arready,
        input  wire  [AXI_ADDR_W    -1:0] slv0_araddr,
        input  wire  [3             -1:0] slv0_arprot,
        input  wire  [AXI_ID_W      -1:0] slv0_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv0_aruser,
        output logic                      slv0_rvalid,
        input  wire                       slv0_rready,
        output logic [AXI_ID_W      -1:0] slv0_rid,
        output logic [2             -1:0] slv0_rresp,
        output logic [AXI_DATA_W    -1:0] slv0_rdata,
        output logic [AXI_RUSER_W   -1:0] slv0_ruser,

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 1 interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       slv1_aclk,
        input  wire                       slv1_aresetn,
        input  wire                       slv1_srst,
        input  wire                       slv1_awvalid,
        output logic                      slv1_awready,
        input  wire  [AXI_ADDR_W    -1:0] slv1_awaddr,
        input  wire  [3             -1:0] slv1_awprot,
        input  wire  [AXI_ID_W      -1:0] slv1_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv1_awuser,
        input  wire                       slv1_wvalid,
        output logic                      slv1_wready,
        input  wire  [AXI_DATA_W    -1:0] slv1_wdata,
        input  wire  [AXI_DATA_W/8  -1:0] slv1_wstrb,
        input  wire  [AXI_WUSER_W   -1:0] slv1_wuser,
        output logic                      slv1_bvalid,
        input  wire                       slv1_bready,
        output logic [AXI_ID_W      -1:0] slv1_bid,
        output logic [2             -1:0] slv1_bresp,
        output logic [AXI_BUSER_W   -1:0] slv1_buser,
        input  wire                       slv1_arvalid,
        output logic                      slv1_arready,
        input  wire  [AXI_ADDR_W    -1:0] slv1_araddr,
        input  wire  [3             -1:0] slv1_arprot,
        input  wire  [AXI_ID_W      -1:0] slv1_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv1_aruser,
        output logic                      slv1_rvalid,
        input  wire                       slv1_rready,
        output logic [AXI_ID_W      -1:0] slv1_rid,
        output logic [2             -1:0] slv1_rresp,
        output logic [AXI_DATA_W    -1:0] slv1_rdata,
        output logic [AXI_RUSER_W   -1:0] slv1_ruser,

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 2 interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       slv2_aclk,
        input  wire                       slv2_aresetn,
        input  wire                       slv2_srst,
        input  wire                       slv2_awvalid,
        output logic                      slv2_awready,
        input  wire  [AXI_ADDR_W    -1:0] slv2_awaddr,
        input  wire  [3             -1:0] slv2_awprot,
        input  wire  [AXI_ID_W      -1:0] slv2_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv2_awuser,
        input  wire                       slv2_wvalid,
        output logic                      slv2_wready,
        input  wire  [AXI_DATA_W    -1:0] slv2_wdata,
        input  wire  [AXI_DATA_W/8  -1:0] slv2_wstrb,
        input  wire  [AXI_WUSER_W   -1:0] slv2_wuser,
        output logic                      slv2_bvalid,
        input  wire                       slv2_bready,
        output logic [AXI_ID_W      -1:0] slv2_bid,
        output logic [2             -1:0] slv2_bresp,
        output logic [AXI_BUSER_W   -1:0] slv2_buser,
        input  wire                       slv2_arvalid,
        output logic                      slv2_arready,
        input  wire  [AXI_ADDR_W    -1:0] slv2_araddr,
        input  wire  [3             -1:0] slv2_arprot,
        input  wire  [AXI_ID_W      -1:0] slv2_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv2_aruser,
        output logic                      slv2_rvalid,
        input  wire                       slv2_rready,
        output logic [AXI_ID_W      -1:0] slv2_rid,
        output logic [2             -1:0] slv2_rresp,
        output logic [AXI_DATA_W    -1:0] slv2_rdata,
        output logic [AXI_RUSER_W   -1:0] slv2_ruser,

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 3 interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       slv3_aclk,
        input  wire                       slv3_aresetn,
        input  wire                       slv3_srst,
        input  wire                       slv3_awvalid,
        output logic                      slv3_awready,
        input  wire  [AXI_ADDR_W    -1:0] slv3_awaddr,
        input  wire  [3             -1:0] slv3_awprot,
        input  wire  [AXI_ID_W      -1:0] slv3_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv3_awuser,
        input  wire                       slv3_wvalid,
        output logic                      slv3_wready,
        input  wire  [AXI_DATA_W    -1:0] slv3_wdata,
        input  wire  [AXI_DATA_W/8  -1:0] slv3_wstrb,
        input  wire  [AXI_WUSER_W   -1:0] slv3_wuser,
        output logic                      slv3_bvalid,
        input  wire                       slv3_bready,
        output logic [AXI_ID_W      -1:0] slv3_bid,
        output logic [2             -1:0] slv3_bresp,
        output logic [AXI_BUSER_W   -1:0] slv3_buser,
        input  wire                       slv3_arvalid,
        output logic                      slv3_arready,
        input  wire  [AXI_ADDR_W    -1:0] slv3_araddr,
        input  wire  [3             -1:0] slv3_arprot,
        input  wire  [AXI_ID_W      -1:0] slv3_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv3_aruser,
        output logic                      slv3_rvalid,
        input  wire                       slv3_rready,
        output logic [AXI_ID_W      -1:0] slv3_rid,
        output logic [2             -1:0] slv3_rresp,
        output logic [AXI_DATA_W    -1:0] slv3_rdata,
        output logic [AXI_RUSER_W   -1:0] slv3_ruser,

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 0 interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       mst0_aclk,
        input  wire                       mst0_aresetn,
        input  wire                       mst0_srst,
        output logic                      mst0_awvalid,
        input  wire                       mst0_awready,
        output logic [AXI_ADDR_W    -1:0] mst0_awaddr,
        output logic [3             -1:0] mst0_awprot,
        output logic [AXI_ID_W      -1:0] mst0_awid,
        output logic [AXI_AUSER_W   -1:0] mst0_awuser,
        output logic                      mst0_wvalid,
        input  wire                       mst0_wready,
        output logic [AXI_DATA_W    -1:0] mst0_wdata,
        output logic [AXI_DATA_W/8  -1:0] mst0_wstrb,
        output logic [AXI_WUSER_W   -1:0] mst0_wuser,
        input  wire                       mst0_bvalid,
        output logic                      mst0_bready,
        input  wire  [AXI_ID_W      -1:0] mst0_bid,
        input  wire  [2             -1:0] mst0_bresp,
        input  wire  [AXI_BUSER_W   -1:0] mst0_buser,
        output logic                      mst0_arvalid,
        input  wire                       mst0_arready,
        output logic [AXI_ADDR_W    -1:0] mst0_araddr,
        output logic [3             -1:0] mst0_arprot,
        output logic [AXI_ID_W      -1:0] mst0_arid,
        output logic [AXI_AUSER_W   -1:0] mst0_aruser,
        input  wire                       mst0_rvalid,
        output logic                      mst0_rready,
        input  wire  [AXI_ID_W      -1:0] mst0_rid,
        input  wire  [2             -1:0] mst0_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst0_rdata,
        input  wire  [AXI_RUSER_W   -1:0] mst0_ruser,

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 1 interface
        ///////////////////////////////////////////////////////////////////////


        input  wire                       mst1_aclk,
        input  wire                       mst1_aresetn,
        input  wire                       mst1_srst,
        output logic                      mst1_awvalid,
        input  wire                       mst1_awready,
        output logic [AXI_ADDR_W    -1:0] mst1_awaddr,
        output logic [3             -1:0] mst1_awprot,
        output logic [AXI_ID_W      -1:0] mst1_awid,
        output logic [AXI_AUSER_W   -1:0] mst1_awuser,
        output logic                      mst1_wvalid,
        input  wire                       mst1_wready,
        output logic [AXI_DATA_W    -1:0] mst1_wdata,
        output logic [AXI_DATA_W/8  -1:0] mst1_wstrb,
        output logic [AXI_WUSER_W   -1:0] mst1_wuser,
        input  wire                       mst1_bvalid,
        output logic                      mst1_bready,
        input  wire  [AXI_ID_W      -1:0] mst1_bid,
        input  wire  [2             -1:0] mst1_bresp,
        input  wire  [AXI_BUSER_W   -1:0] mst1_buser,
        output logic                      mst1_arvalid,
        input  wire                       mst1_arready,
        output logic [AXI_ADDR_W    -1:0] mst1_araddr,
        output logic [3             -1:0] mst1_arprot,
        output logic [AXI_ID_W      -1:0] mst1_arid,
        output logic [AXI_AUSER_W   -1:0] mst1_aruser,
        input  wire                       mst1_rvalid,
        output logic                      mst1_rready,
        input  wire  [AXI_ID_W      -1:0] mst1_rid,
        input  wire  [2             -1:0] mst1_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst1_rdata,
        input  wire  [AXI_RUSER_W   -1:0] mst1_ruser,


        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 2 interface
        ///////////////////////////////////////////////////////////////////////


        input  wire                       mst2_aclk,
        input  wire                       mst2_aresetn,
        input  wire                       mst2_srst,
        output logic                      mst2_awvalid,
        input  wire                       mst2_awready,
        output logic [AXI_ADDR_W    -1:0] mst2_awaddr,
        output logic [3             -1:0] mst2_awprot,
        output logic [AXI_ID_W      -1:0] mst2_awid,
        output logic [AXI_AUSER_W   -1:0] mst2_awuser,
        output logic                      mst2_wvalid,
        input  wire                       mst2_wready,
        output logic [AXI_DATA_W    -1:0] mst2_wdata,
        output logic [AXI_DATA_W/8  -1:0] mst2_wstrb,
        output logic [AXI_WUSER_W   -1:0] mst2_wuser,
        input  wire                       mst2_bvalid,
        output logic                      mst2_bready,
        input  wire  [AXI_ID_W      -1:0] mst2_bid,
        input  wire  [2             -1:0] mst2_bresp,
        input  wire  [AXI_BUSER_W   -1:0] mst2_buser,
        output logic                      mst2_arvalid,
        input  wire                       mst2_arready,
        output logic [AXI_ADDR_W    -1:0] mst2_araddr,
        output logic [3             -1:0] mst2_arprot,
        output logic [AXI_ID_W      -1:0] mst2_arid,
        output logic [AXI_AUSER_W   -1:0] mst2_aruser,
        input  wire                       mst2_rvalid,
        output logic                      mst2_rready,
        input  wire  [AXI_ID_W      -1:0] mst2_rid,
        input  wire  [2             -1:0] mst2_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst2_rdata,
        input  wire  [AXI_RUSER_W   -1:0] mst2_ruser,

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 3 interface
        ///////////////////////////////////////////////////////////////////////


        input  wire                       mst3_aclk,
        input  wire                       mst3_aresetn,
        input  wire                       mst3_srst,
        output logic                      mst3_awvalid,
        input  wire                       mst3_awready,
        output logic [AXI_ADDR_W    -1:0] mst3_awaddr,
        output logic [3             -1:0] mst3_awprot,
        output logic [AXI_ID_W      -1:0] mst3_awid,
        output logic [AXI_AUSER_W   -1:0] mst3_awuser,
        output logic                      mst3_wvalid,
        input  wire                       mst3_wready,
        output logic [AXI_DATA_W    -1:0] mst3_wdata,
        output logic [AXI_DATA_W/8  -1:0] mst3_wstrb,
        output logic [AXI_WUSER_W   -1:0] mst3_wuser,
        input  wire                       mst3_bvalid,
        output logic                      mst3_bready,
        input  wire  [AXI_ID_W      -1:0] mst3_bid,
        input  wire  [2             -1:0] mst3_bresp,
        input  wire  [AXI_BUSER_W   -1:0] mst3_buser,
        output logic                      mst3_arvalid,
        input  wire                       mst3_arready,
        output logic [AXI_ADDR_W    -1:0] mst3_araddr,
        output logic [3             -1:0] mst3_arprot,
        output logic [AXI_ID_W      -1:0] mst3_arid,
        output logic [AXI_AUSER_W   -1:0] mst3_aruser,
        input  wire                       mst3_rvalid,
        output logic                      mst3_rready,
        input  wire  [AXI_ID_W      -1:0] mst3_rid,
        input  wire  [2             -1:0] mst3_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst3_rdata,
        input  wire  [AXI_RUSER_W   -1:0] mst3_ruser
    );


    axicb_crossbar_top
    #(
    .AXI_ADDR_W          (AXI_ADDR_W),
    .AXI_ID_W            (AXI_ID_W),
    .AXI_DATA_W          (AXI_DATA_W),
    .MST_NB              (MST_NB),
    .SLV_NB              (SLV_NB),
    .MST_PIPELINE        (MST_PIPELINE),
    .SLV_PIPELINE        (SLV_PIPELINE),
    .STRB_MODE           (STRB_MODE),
    .AXI_SIGNALING       (0),
    .USER_SUPPORT        (USER_SUPPORT),
    .AXI_AUSER_W         (AXI_AUSER_W),
    .AXI_WUSER_W         (AXI_WUSER_W),
    .AXI_BUSER_W         (AXI_BUSER_W),
    .AXI_RUSER_W         (AXI_RUSER_W),
    .TIMEOUT_VALUE       (TIMEOUT_VALUE),
    .TIMEOUT_ENABLE      (TIMEOUT_ENABLE),
    .MST0_CDC            (MST0_CDC),
    .MST0_OSTDREQ_NUM    (MST0_OSTDREQ_NUM),
    .MST0_OSTDREQ_SIZE   (1),
    .MST0_PRIORITY       (MST0_PRIORITY),
    .MST0_ROUTES         (MST0_ROUTES),
    .MST0_ID_MASK        (MST0_ID_MASK),
    .MST0_RW             (MST0_RW),
    .MST1_CDC            (MST1_CDC),
    .MST1_OSTDREQ_NUM    (MST1_OSTDREQ_NUM),
    .MST1_OSTDREQ_SIZE   (1),
    .MST1_PRIORITY       (MST1_PRIORITY),
    .MST1_ROUTES         (MST1_ROUTES),
    .MST1_ID_MASK        (MST1_ID_MASK),
    .MST1_RW             (MST1_RW),
    .MST2_CDC            (MST2_CDC),
    .MST2_OSTDREQ_NUM    (MST2_OSTDREQ_NUM),
    .MST2_OSTDREQ_SIZE   (1),
    .MST2_PRIORITY       (MST2_PRIORITY),
    .MST2_ROUTES         (MST2_ROUTES),
    .MST2_ID_MASK        (MST2_ID_MASK),
    .MST2_RW             (MST2_RW),
    .MST3_CDC            (MST3_CDC),
    .MST3_OSTDREQ_NUM    (MST3_OSTDREQ_NUM),
    .MST3_OSTDREQ_SIZE   (1),
    .MST3_PRIORITY       (MST3_PRIORITY),
    .MST3_ROUTES         (MST3_ROUTES),
    .MST3_ID_MASK        (MST3_ID_MASK),
    .MST3_RW             (MST3_RW),
    .SLV0_CDC            (SLV0_CDC),
    .SLV0_START_ADDR     (SLV0_START_ADDR),
    .SLV0_END_ADDR       (SLV0_END_ADDR),
    .SLV0_OSTDREQ_NUM    (SLV0_OSTDREQ_NUM),
    .SLV0_OSTDREQ_SIZE   (1),
    .SLV0_KEEP_BASE_ADDR (SLV0_KEEP_BASE_ADDR),
    .SLV1_CDC            (SLV1_CDC),
    .SLV1_START_ADDR     (SLV1_START_ADDR),
    .SLV1_END_ADDR       (SLV1_END_ADDR),
    .SLV1_OSTDREQ_NUM    (SLV1_OSTDREQ_NUM),
    .SLV1_OSTDREQ_SIZE   (1),
    .SLV1_KEEP_BASE_ADDR (SLV1_KEEP_BASE_ADDR),
    .SLV2_CDC            (SLV2_CDC),
    .SLV2_START_ADDR     (SLV2_START_ADDR),
    .SLV2_END_ADDR       (SLV2_END_ADDR),
    .SLV2_OSTDREQ_NUM    (SLV2_OSTDREQ_NUM),
    .SLV2_OSTDREQ_SIZE   (1),
    .SLV2_KEEP_BASE_ADDR (SLV2_KEEP_BASE_ADDR),
    .SLV3_CDC            (SLV3_CDC),
    .SLV3_START_ADDR     (SLV3_START_ADDR),
    .SLV3_END_ADDR       (SLV3_END_ADDR),
    .SLV3_OSTDREQ_NUM    (SLV3_OSTDREQ_NUM),
    .SLV3_OSTDREQ_SIZE   (1),
    .SLV3_KEEP_BASE_ADDR (SLV3_KEEP_BASE_ADDR)
    )
    axi4lite_crossbar_inst
    (
    .aclk          (aclk),
    .aresetn       (aresetn),
    .srst          (srst),
    .slv0_aclk     (slv0_aclk),
    .slv0_aresetn  (slv0_aresetn),
    .slv0_srst     (slv0_srst),
    .slv0_awvalid  (slv0_awvalid),
    .slv0_awready  (slv0_awready),
    .slv0_awaddr   (slv0_awaddr),
    .slv0_awlen    (8'h0),
    .slv0_awsize   (3'b0),
    .slv0_awburst  (2'b0),
    .slv0_awlock   (2'b0),
    .slv0_awcache  (4'b0),
    .slv0_awprot   (slv0_awprot),
    .slv0_awqos    (4'b0),
    .slv0_awregion (4'b0),
    .slv0_awid     (slv0_awid),
    .slv0_awuser   (slv0_awuser),
    .slv0_wvalid   (slv0_wvalid),
    .slv0_wready   (slv0_wready),
    .slv0_wlast    (1'b1),
    .slv0_wdata    (slv0_wdata),
    .slv0_wstrb    (slv0_wstrb),
    .slv0_wuser    (slv0_wuser),
    .slv0_bvalid   (slv0_bvalid),
    .slv0_bready   (slv0_bready),
    .slv0_bid      (slv0_bid),
    .slv0_bresp    (slv0_bresp),
    .slv0_buser    (slv0_buser),
    .slv0_arvalid  (slv0_arvalid),
    .slv0_arready  (slv0_arready),
    .slv0_araddr   (slv0_araddr),
    .slv0_arlen    (8'h0),
    .slv0_arsize   (3'h0),
    .slv0_arburst  (2'b0),
    .slv0_arlock   (2'b0),
    .slv0_arcache  (4'h0),
    .slv0_arprot   (slv0_arprot),
    .slv0_arqos    (4'h0),
    .slv0_arregion (4'h0),
    .slv0_arid     (slv0_arid),
    .slv0_aruser   (slv0_aruser),
    .slv0_rvalid   (slv0_rvalid),
    .slv0_rready   (slv0_rready),
    .slv0_rid      (slv0_rid),
    .slv0_rresp    (slv0_rresp),
    .slv0_rdata    (slv0_rdata),
    .slv0_rlast    (),
    .slv0_ruser    (slv0_ruser),
    .slv1_aclk     (slv1_aclk),
    .slv1_aresetn  (slv1_aresetn),
    .slv1_srst     (slv1_srst),
    .slv1_awvalid  (slv1_awvalid),
    .slv1_awready  (slv1_awready),
    .slv1_awaddr   (slv1_awaddr),
    .slv1_awlen    (8'h0),
    .slv1_awsize   (3'b0),
    .slv1_awburst  (2'b0),
    .slv1_awlock   (2'b0),
    .slv1_awcache  (4'b0),
    .slv1_awprot   (slv1_awprot),
    .slv1_awqos    (4'b0),
    .slv1_awregion (4'b0),
    .slv1_awid     (slv1_awid),
    .slv1_awuser   (slv1_awuser),
    .slv1_wvalid   (slv1_wvalid),
    .slv1_wready   (slv1_wready),
    .slv1_wlast    (1'b1),
    .slv1_wdata    (slv1_wdata),
    .slv1_wstrb    (slv1_wstrb),
    .slv1_wuser    (slv1_wuser),
    .slv1_bvalid   (slv1_bvalid),
    .slv1_bready   (slv1_bready),
    .slv1_bid      (slv1_bid),
    .slv1_bresp    (slv1_bresp),
    .slv1_buser    (slv1_buser),
    .slv1_arvalid  (slv1_arvalid),
    .slv1_arready  (slv1_arready),
    .slv1_araddr   (slv1_araddr),
    .slv1_arlen    (8'h0),
    .slv1_arsize   (3'h0),
    .slv1_arburst  (2'b0),
    .slv1_arlock   (2'b0),
    .slv1_arcache  (4'h0),
    .slv1_arprot   (slv1_arprot),
    .slv1_arqos    (4'h0),
    .slv1_arregion (4'h0),
    .slv1_arid     (slv1_arid),
    .slv1_aruser   (slv1_aruser),
    .slv1_rvalid   (slv1_rvalid),
    .slv1_rready   (slv1_rready),
    .slv1_rid      (slv1_rid),
    .slv1_rresp    (slv1_rresp),
    .slv1_rdata    (slv1_rdata),
    .slv1_rlast    (),
    .slv1_ruser    (slv1_ruser),
    .slv2_aclk     (slv2_aclk),
    .slv2_aresetn  (slv2_aresetn),
    .slv2_srst     (slv2_srst),
    .slv2_awvalid  (slv2_awvalid),
    .slv2_awready  (slv2_awready),
    .slv2_awaddr   (slv2_awaddr),
    .slv2_awlen    (8'h0),
    .slv2_awsize   (3'b0),
    .slv2_awburst  (2'b0),
    .slv2_awlock   (2'b0),
    .slv2_awcache  (4'b0),
    .slv2_awprot   (slv2_awprot),
    .slv2_awqos    (4'b0),
    .slv2_awregion (4'b0),
    .slv2_awid     (slv2_awid),
    .slv2_awuser   (slv2_awuser),
    .slv2_wvalid   (slv2_wvalid),
    .slv2_wready   (slv2_wready),
    .slv2_wlast    (1'b1),
    .slv2_wdata    (slv2_wdata),
    .slv2_wstrb    (slv2_wstrb),
    .slv2_wuser    (slv2_wuser),
    .slv2_bvalid   (slv2_bvalid),
    .slv2_bready   (slv2_bready),
    .slv2_bid      (slv2_bid),
    .slv2_bresp    (slv2_bresp),
    .slv2_buser    (slv2_buser),
    .slv2_arvalid  (slv2_arvalid),
    .slv2_arready  (slv2_arready),
    .slv2_araddr   (slv2_araddr),
    .slv2_arlen    (8'h0),
    .slv2_arsize   (3'h0),
    .slv2_arburst  (2'b0),
    .slv2_arlock   (2'b0),
    .slv2_arcache  (4'h0),
    .slv2_arprot   (slv2_arprot),
    .slv2_arqos    (4'h0),
    .slv2_arregion (4'h0),
    .slv2_arid     (slv2_arid),
    .slv2_aruser   (slv2_aruser),
    .slv2_rvalid   (slv2_rvalid),
    .slv2_rready   (slv2_rready),
    .slv2_rid      (slv2_rid),
    .slv2_rresp    (slv2_rresp),
    .slv2_rdata    (slv2_rdata),
    .slv2_rlast    (),
    .slv2_ruser    (slv2_ruser),
    .slv3_aclk     (slv3_aclk),
    .slv3_aresetn  (slv3_aresetn),
    .slv3_srst     (slv3_srst),
    .slv3_awvalid  (slv3_awvalid),
    .slv3_awready  (slv3_awready),
    .slv3_awaddr   (slv3_awaddr),
    .slv3_awlen    (8'h0),
    .slv3_awsize   (3'b0),
    .slv3_awburst  (2'b0),
    .slv3_awlock   (2'b0),
    .slv3_awcache  (4'b0),
    .slv3_awprot   (slv3_awprot),
    .slv3_awqos    (4'b0),
    .slv3_awregion (4'b0),
    .slv3_awid     (slv3_awid),
    .slv3_awuser   (slv3_awuser),
    .slv3_wvalid   (slv3_wvalid),
    .slv3_wready   (slv3_wready),
    .slv3_wlast    (1'b1),
    .slv3_wdata    (slv3_wdata),
    .slv3_wstrb    (slv3_wstrb),
    .slv3_wuser    (slv3_wuser),
    .slv3_bvalid   (slv3_bvalid),
    .slv3_bready   (slv3_bready),
    .slv3_bid      (slv3_bid),
    .slv3_bresp    (slv3_bresp),
    .slv3_buser    (slv3_buser),
    .slv3_arvalid  (slv3_arvalid),
    .slv3_arready  (slv3_arready),
    .slv3_araddr   (slv3_araddr),
    .slv3_arlen    (8'h0),
    .slv3_arsize   (3'h0),
    .slv3_arburst  (2'b0),
    .slv3_arlock   (2'b0),
    .slv3_arcache  (4'h0),
    .slv3_arprot   (slv3_arprot),
    .slv3_arqos    (4'h0),
    .slv3_arregion (4'h0),
    .slv3_arid     (slv3_arid),
    .slv3_aruser   (slv3_aruser),
    .slv3_rvalid   (slv3_rvalid),
    .slv3_rready   (slv3_rready),
    .slv3_rid      (slv3_rid),
    .slv3_rresp    (slv3_rresp),
    .slv3_rdata    (slv3_rdata),
    .slv3_rlast    (),
    .slv3_ruser    (slv3_ruser),
    .mst0_aclk     (mst0_aclk),
    .mst0_aresetn  (mst0_aresetn),
    .mst0_srst     (mst0_srst),
    .mst0_awvalid  (mst0_awvalid),
    .mst0_awready  (mst0_awready),
    .mst0_awaddr   (mst0_awaddr),
    .mst0_awlen    (),
    .mst0_awsize   (),
    .mst0_awburst  (),
    .mst0_awlock   (),
    .mst0_awcache  (),
    .mst0_awprot   (mst0_awprot),
    .mst0_awqos    (),
    .mst0_awregion (),
    .mst0_awid     (mst0_awid),
    .mst0_awuser   (mst0_awuser),
    .mst0_wvalid   (mst0_wvalid),
    .mst0_wready   (mst0_wready),
    .mst0_wlast    (),
    .mst0_wdata    (mst0_wdata),
    .mst0_wstrb    (mst0_wstrb),
    .mst0_wuser    (mst0_wuser),
    .mst0_bvalid   (mst0_bvalid),
    .mst0_bready   (mst0_bready),
    .mst0_bid      (mst0_bid),
    .mst0_bresp    (mst0_bresp),
    .mst0_buser    (mst0_buser),
    .mst0_arvalid  (mst0_arvalid),
    .mst0_arready  (mst0_arready),
    .mst0_araddr   (mst0_araddr),
    .mst0_arlen    (),
    .mst0_arsize   (),
    .mst0_arburst  (),
    .mst0_arlock   (),
    .mst0_arcache  (),
    .mst0_arprot   (mst0_arprot),
    .mst0_arqos    (),
    .mst0_arregion (),
    .mst0_arid     (mst0_arid),
    .mst0_aruser   (mst0_aruser),
    .mst0_rvalid   (mst0_rvalid),
    .mst0_rready   (mst0_rready),
    .mst0_rid      (mst0_rid),
    .mst0_rresp    (mst0_rresp),
    .mst0_rdata    (mst0_rdata),
    .mst0_rlast    (1'b1),
    .mst0_ruser    (mst0_ruser),
    .mst1_aclk     (mst1_aclk),
    .mst1_aresetn  (mst1_aresetn),
    .mst1_srst     (mst1_srst),
    .mst1_awvalid  (mst1_awvalid),
    .mst1_awready  (mst1_awready),
    .mst1_awaddr   (mst1_awaddr),
    .mst1_awlen    (),
    .mst1_awsize   (),
    .mst1_awburst  (),
    .mst1_awlock   (),
    .mst1_awcache  (),
    .mst1_awprot   (mst1_awprot),
    .mst1_awqos    (),
    .mst1_awregion (),
    .mst1_awid     (mst1_awid),
    .mst1_awuser   (mst1_awuser),
    .mst1_wvalid   (mst1_wvalid),
    .mst1_wready   (mst1_wready),
    .mst1_wlast    (),
    .mst1_wdata    (mst1_wdata),
    .mst1_wstrb    (mst1_wstrb),
    .mst1_wuser    (mst1_wuser),
    .mst1_bvalid   (mst1_bvalid),
    .mst1_bready   (mst1_bready),
    .mst1_bid      (mst1_bid),
    .mst1_bresp    (mst1_bresp),
    .mst1_buser    (mst1_buser),
    .mst1_arvalid  (mst1_arvalid),
    .mst1_arready  (mst1_arready),
    .mst1_araddr   (mst1_araddr),
    .mst1_arlen    (),
    .mst1_arsize   (),
    .mst1_arburst  (),
    .mst1_arlock   (),
    .mst1_arcache  (),
    .mst1_arprot   (mst1_arprot),
    .mst1_arqos    (),
    .mst1_arregion (),
    .mst1_arid     (mst1_arid),
    .mst1_aruser   (mst1_aruser),
    .mst1_rvalid   (mst1_rvalid),
    .mst1_rready   (mst1_rready),
    .mst1_rid      (mst1_rid),
    .mst1_rresp    (mst1_rresp),
    .mst1_rdata    (mst1_rdata),
    .mst1_rlast    (1'b1),
    .mst1_ruser    (mst1_ruser),
    .mst2_aclk     (mst2_aclk),
    .mst2_aresetn  (mst2_aresetn),
    .mst2_srst     (mst2_srst),
    .mst2_awvalid  (mst2_awvalid),
    .mst2_awready  (mst2_awready),
    .mst2_awaddr   (mst2_awaddr),
    .mst2_awlen    (),
    .mst2_awsize   (),
    .mst2_awburst  (),
    .mst2_awlock   (),
    .mst2_awcache  (),
    .mst2_awprot   (mst2_awprot),
    .mst2_awqos    (),
    .mst2_awregion (),
    .mst2_awid     (mst2_awid),
    .mst2_awuser   (mst2_awuser),
    .mst2_wvalid   (mst2_wvalid),
    .mst2_wready   (mst2_wready),
    .mst2_wlast    (),
    .mst2_wdata    (mst2_wdata),
    .mst2_wstrb    (mst2_wstrb),
    .mst2_wuser    (mst2_wuser),
    .mst2_bvalid   (mst2_bvalid),
    .mst2_bready   (mst2_bready),
    .mst2_bid      (mst2_bid),
    .mst2_bresp    (mst2_bresp),
    .mst2_buser    (mst2_buser),
    .mst2_arvalid  (mst2_arvalid),
    .mst2_arready  (mst2_arready),
    .mst2_araddr   (mst2_araddr),
    .mst2_arlen    (),
    .mst2_arsize   (),
    .mst2_arburst  (),
    .mst2_arlock   (),
    .mst2_arcache  (),
    .mst2_arprot   (mst2_arprot),
    .mst2_arqos    (),
    .mst2_arregion (),
    .mst2_arid     (mst2_arid),
    .mst2_aruser   (mst2_aruser),
    .mst2_rvalid   (mst2_rvalid),
    .mst2_rready   (mst2_rready),
    .mst2_rid      (mst2_rid),
    .mst2_rresp    (mst2_rresp),
    .mst2_rdata    (mst2_rdata),
    .mst2_rlast    (1'b1),
    .mst2_ruser    (mst2_ruser),
    .mst3_aclk     (mst3_aclk),
    .mst3_aresetn  (mst3_aresetn),
    .mst3_srst     (mst3_srst),
    .mst3_awvalid  (mst3_awvalid),
    .mst3_awready  (mst3_awready),
    .mst3_awaddr   (mst3_awaddr),
    .mst3_awlen    (),
    .mst3_awsize   (),
    .mst3_awburst  (),
    .mst3_awlock   (),
    .mst3_awcache  (),
    .mst3_awprot   (mst3_awprot),
    .mst3_awqos    (),
    .mst3_awregion (),
    .mst3_awid     (mst3_awid),
    .mst3_awuser   (mst3_awuser),
    .mst3_wvalid   (mst3_wvalid),
    .mst3_wready   (mst3_wready),
    .mst3_wlast    (),
    .mst3_wdata    (mst3_wdata),
    .mst3_wstrb    (mst3_wstrb),
    .mst3_wuser    (mst3_wuser),
    .mst3_bvalid   (mst3_bvalid),
    .mst3_bready   (mst3_bready),
    .mst3_bid      (mst3_bid),
    .mst3_bresp    (mst3_bresp),
    .mst3_buser    (mst3_buser),
    .mst3_arvalid  (mst3_arvalid),
    .mst3_arready  (mst3_arready),
    .mst3_araddr   (mst3_araddr),
    .mst3_arlen    (),
    .mst3_arsize   (),
    .mst3_arburst  (),
    .mst3_arlock   (),
    .mst3_arcache  (),
    .mst3_arprot   (mst3_arprot),
    .mst3_arqos    (),
    .mst3_arregion (),
    .mst3_arid     (mst3_arid),
    .mst3_aruser   (mst3_aruser),
    .mst3_rvalid   (mst3_rvalid),
    .mst3_rready   (mst3_rready),
    .mst3_rid      (mst3_rid),
    .mst3_rresp    (mst3_rresp),
    .mst3_rdata    (mst3_rdata),
    .mst3_rlast    (1'b1),
    .mst3_ruser    (mst3_ruser)
    );

endmodule

`resetall
