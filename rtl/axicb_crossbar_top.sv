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

module axicb_crossbar_top

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

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI
        parameter AXI_SIGNALING = 0,

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
        //   - MSTx_OSTDREQ_SIZE: size of an outstanding request in dataphase
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
        //   - MSTx_RW: Slect if the interface is 
        //         - Read/Write (=0)
        //         - Read-only (=1) 
        //         - Write-only (=2)
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
        parameter MST0_OSTDREQ_SIZE = 1,
        parameter MST0_PRIORITY = 0,
        parameter [SLV_NB-1:0] MST0_ROUTES = 4'b1_1_1_1,
        parameter [AXI_ID_W-1:0] MST0_ID_MASK = 'h10,
        parameter MST0_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 1 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST1_CDC = 0,
        parameter MST1_OSTDREQ_NUM = 4,
        parameter MST1_OSTDREQ_SIZE = 1,
        parameter MST1_PRIORITY = 0,
        parameter [SLV_NB-1:0] MST1_ROUTES = 4'b1_1_1_1,
        parameter [AXI_ID_W-1:0] MST1_ID_MASK = 'h20,
        parameter MST1_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 2 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST2_CDC = 0,
        parameter MST2_OSTDREQ_NUM = 4,
        parameter MST2_OSTDREQ_SIZE = 1,
        parameter MST2_PRIORITY = 0,
        parameter [SLV_NB-1:0] MST2_ROUTES = 4'b1_1_1_1,
        parameter [AXI_ID_W-1:0] MST2_ID_MASK = 'h30,
        parameter MST2_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 3 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST3_CDC = 0,
        parameter MST3_OSTDREQ_NUM = 4,
        parameter MST3_OSTDREQ_SIZE = 1,
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
        //   - SLVx_OSTDREQ_SIZE: size of an outstanding request in dataphase
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
        parameter SLV0_OSTDREQ_SIZE = 1,
        parameter SLV0_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 1 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV1_CDC = 0,
        parameter SLV1_START_ADDR = 4096,
        parameter SLV1_END_ADDR = 8191,
        parameter SLV1_OSTDREQ_NUM = 4,
        parameter SLV1_OSTDREQ_SIZE = 1,
        parameter SLV1_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 2 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV2_CDC = 0,
        parameter SLV2_START_ADDR = 8192,
        parameter SLV2_END_ADDR = 12287,
        parameter SLV2_OSTDREQ_NUM = 4,
        parameter SLV2_OSTDREQ_SIZE = 1,
        parameter SLV2_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 3 configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV3_CDC = 0,
        parameter SLV3_START_ADDR = 12288,
        parameter SLV3_END_ADDR = 16383,
        parameter SLV3_OSTDREQ_NUM = 4,
        parameter SLV3_OSTDREQ_SIZE = 1,
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
        input  wire  [8             -1:0] slv0_awlen,
        input  wire  [3             -1:0] slv0_awsize,
        input  wire  [2             -1:0] slv0_awburst,
        input  wire  [2             -1:0] slv0_awlock,
        input  wire  [4             -1:0] slv0_awcache,
        input  wire  [3             -1:0] slv0_awprot,
        input  wire  [4             -1:0] slv0_awqos,
        input  wire  [4             -1:0] slv0_awregion,
        input  wire  [AXI_ID_W      -1:0] slv0_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv0_awuser,
        input  wire                       slv0_wvalid,
        output logic                      slv0_wready,
        input  wire                       slv0_wlast,
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
        input  wire  [8             -1:0] slv0_arlen,
        input  wire  [3             -1:0] slv0_arsize,
        input  wire  [2             -1:0] slv0_arburst,
        input  wire  [2             -1:0] slv0_arlock,
        input  wire  [4             -1:0] slv0_arcache,
        input  wire  [3             -1:0] slv0_arprot,
        input  wire  [4             -1:0] slv0_arqos,
        input  wire  [4             -1:0] slv0_arregion,
        input  wire  [AXI_ID_W      -1:0] slv0_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv0_aruser,
        output logic                      slv0_rvalid,
        input  wire                       slv0_rready,
        output logic [AXI_ID_W      -1:0] slv0_rid,
        output logic [2             -1:0] slv0_rresp,
        output logic [AXI_DATA_W    -1:0] slv0_rdata,
        output logic                      slv0_rlast,
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
        input  wire  [8             -1:0] slv1_awlen,
        input  wire  [3             -1:0] slv1_awsize,
        input  wire  [2             -1:0] slv1_awburst,
        input  wire  [2             -1:0] slv1_awlock,
        input  wire  [4             -1:0] slv1_awcache,
        input  wire  [3             -1:0] slv1_awprot,
        input  wire  [4             -1:0] slv1_awqos,
        input  wire  [4             -1:0] slv1_awregion,
        input  wire  [AXI_ID_W      -1:0] slv1_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv1_awuser,
        input  wire                       slv1_wvalid,
        output logic                      slv1_wready,
        input  wire                       slv1_wlast,
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
        input  wire  [8             -1:0] slv1_arlen,
        input  wire  [3             -1:0] slv1_arsize,
        input  wire  [2             -1:0] slv1_arburst,
        input  wire  [2             -1:0] slv1_arlock,
        input  wire  [4             -1:0] slv1_arcache,
        input  wire  [3             -1:0] slv1_arprot,
        input  wire  [4             -1:0] slv1_arqos,
        input  wire  [4             -1:0] slv1_arregion,
        input  wire  [AXI_ID_W      -1:0] slv1_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv1_aruser,
        output logic                      slv1_rvalid,
        input  wire                       slv1_rready,
        output logic [AXI_ID_W      -1:0] slv1_rid,
        output logic [2             -1:0] slv1_rresp,
        output logic [AXI_DATA_W    -1:0] slv1_rdata,
        output logic                      slv1_rlast,
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
        input  wire  [8             -1:0] slv2_awlen,
        input  wire  [3             -1:0] slv2_awsize,
        input  wire  [2             -1:0] slv2_awburst,
        input  wire  [2             -1:0] slv2_awlock,
        input  wire  [4             -1:0] slv2_awcache,
        input  wire  [3             -1:0] slv2_awprot,
        input  wire  [4             -1:0] slv2_awqos,
        input  wire  [4             -1:0] slv2_awregion,
        input  wire  [AXI_ID_W      -1:0] slv2_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv2_awuser,
        input  wire                       slv2_wvalid,
        output logic                      slv2_wready,
        input  wire                       slv2_wlast,
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
        input  wire  [8             -1:0] slv2_arlen,
        input  wire  [3             -1:0] slv2_arsize,
        input  wire  [2             -1:0] slv2_arburst,
        input  wire  [2             -1:0] slv2_arlock,
        input  wire  [4             -1:0] slv2_arcache,
        input  wire  [3             -1:0] slv2_arprot,
        input  wire  [4             -1:0] slv2_arqos,
        input  wire  [4             -1:0] slv2_arregion,
        input  wire  [AXI_ID_W      -1:0] slv2_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv2_aruser,
        output logic                      slv2_rvalid,
        input  wire                       slv2_rready,
        output logic [AXI_ID_W      -1:0] slv2_rid,
        output logic [2             -1:0] slv2_rresp,
        output logic [AXI_DATA_W    -1:0] slv2_rdata,
        output logic                      slv2_rlast,
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
        input  wire  [8             -1:0] slv3_awlen,
        input  wire  [3             -1:0] slv3_awsize,
        input  wire  [2             -1:0] slv3_awburst,
        input  wire  [2             -1:0] slv3_awlock,
        input  wire  [4             -1:0] slv3_awcache,
        input  wire  [3             -1:0] slv3_awprot,
        input  wire  [4             -1:0] slv3_awqos,
        input  wire  [4             -1:0] slv3_awregion,
        input  wire  [AXI_ID_W      -1:0] slv3_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv3_awuser,
        input  wire                       slv3_wvalid,
        output logic                      slv3_wready,
        input  wire                       slv3_wlast,
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
        input  wire  [8             -1:0] slv3_arlen,
        input  wire  [3             -1:0] slv3_arsize,
        input  wire  [2             -1:0] slv3_arburst,
        input  wire  [2             -1:0] slv3_arlock,
        input  wire  [4             -1:0] slv3_arcache,
        input  wire  [3             -1:0] slv3_arprot,
        input  wire  [4             -1:0] slv3_arqos,
        input  wire  [4             -1:0] slv3_arregion,
        input  wire  [AXI_ID_W      -1:0] slv3_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv3_aruser,
        output logic                      slv3_rvalid,
        input  wire                       slv3_rready,
        output logic [AXI_ID_W      -1:0] slv3_rid,
        output logic [2             -1:0] slv3_rresp,
        output logic [AXI_DATA_W    -1:0] slv3_rdata,
        output logic                      slv3_rlast,
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
        output logic [8             -1:0] mst0_awlen,
        output logic [3             -1:0] mst0_awsize,
        output logic [2             -1:0] mst0_awburst,
        output logic [2             -1:0] mst0_awlock,
        output logic [4             -1:0] mst0_awcache,
        output logic [3             -1:0] mst0_awprot,
        output logic [4             -1:0] mst0_awqos,
        output logic [4             -1:0] mst0_awregion,
        output logic [AXI_ID_W      -1:0] mst0_awid,
        output logic [AXI_AUSER_W   -1:0] mst0_awuser,
        output logic                      mst0_wvalid,
        input  wire                       mst0_wready,
        output logic                      mst0_wlast,
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
        output logic [8             -1:0] mst0_arlen,
        output logic [3             -1:0] mst0_arsize,
        output logic [2             -1:0] mst0_arburst,
        output logic [2             -1:0] mst0_arlock,
        output logic [4             -1:0] mst0_arcache,
        output logic [3             -1:0] mst0_arprot,
        output logic [4             -1:0] mst0_arqos,
        output logic [4             -1:0] mst0_arregion,
        output logic [AXI_ID_W      -1:0] mst0_arid,
        output logic [AXI_AUSER_W   -1:0] mst0_aruser,
        input  wire                       mst0_rvalid,
        output logic                      mst0_rready,
        input  wire  [AXI_ID_W      -1:0] mst0_rid,
        input  wire  [2             -1:0] mst0_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst0_rdata,
        input  wire                       mst0_rlast,
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
        output logic [8             -1:0] mst1_awlen,
        output logic [3             -1:0] mst1_awsize,
        output logic [2             -1:0] mst1_awburst,
        output logic [2             -1:0] mst1_awlock,
        output logic [4             -1:0] mst1_awcache,
        output logic [3             -1:0] mst1_awprot,
        output logic [4             -1:0] mst1_awqos,
        output logic [4             -1:0] mst1_awregion,
        output logic [AXI_ID_W      -1:0] mst1_awid,
        output logic [AXI_AUSER_W   -1:0] mst1_awuser,
        output logic                      mst1_wvalid,
        input  wire                       mst1_wready,
        output logic                      mst1_wlast,
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
        output logic [8             -1:0] mst1_arlen,
        output logic [3             -1:0] mst1_arsize,
        output logic [2             -1:0] mst1_arburst,
        output logic [2             -1:0] mst1_arlock,
        output logic [4             -1:0] mst1_arcache,
        output logic [3             -1:0] mst1_arprot,
        output logic [4             -1:0] mst1_arqos,
        output logic [4             -1:0] mst1_arregion,
        output logic [AXI_ID_W      -1:0] mst1_arid,
        output logic [AXI_AUSER_W   -1:0] mst1_aruser,
        input  wire                       mst1_rvalid,
        output logic                      mst1_rready,
        input  wire  [AXI_ID_W      -1:0] mst1_rid,
        input  wire  [2             -1:0] mst1_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst1_rdata,
        input  wire                       mst1_rlast,
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
        output logic [8             -1:0] mst2_awlen,
        output logic [3             -1:0] mst2_awsize,
        output logic [2             -1:0] mst2_awburst,
        output logic [2             -1:0] mst2_awlock,
        output logic [4             -1:0] mst2_awcache,
        output logic [3             -1:0] mst2_awprot,
        output logic [4             -1:0] mst2_awqos,
        output logic [4             -1:0] mst2_awregion,
        output logic [AXI_ID_W      -1:0] mst2_awid,
        output logic [AXI_AUSER_W   -1:0] mst2_awuser,
        output logic                      mst2_wvalid,
        input  wire                       mst2_wready,
        output logic                      mst2_wlast,
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
        output logic [8             -1:0] mst2_arlen,
        output logic [3             -1:0] mst2_arsize,
        output logic [2             -1:0] mst2_arburst,
        output logic [2             -1:0] mst2_arlock,
        output logic [4             -1:0] mst2_arcache,
        output logic [3             -1:0] mst2_arprot,
        output logic [4             -1:0] mst2_arqos,
        output logic [4             -1:0] mst2_arregion,
        output logic [AXI_ID_W      -1:0] mst2_arid,
        output logic [AXI_AUSER_W   -1:0] mst2_aruser,
        input  wire                       mst2_rvalid,
        output logic                      mst2_rready,
        input  wire  [AXI_ID_W      -1:0] mst2_rid,
        input  wire  [2             -1:0] mst2_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst2_rdata,
        input  wire                       mst2_rlast,
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
        output logic [8             -1:0] mst3_awlen,
        output logic [3             -1:0] mst3_awsize,
        output logic [2             -1:0] mst3_awburst,
        output logic [2             -1:0] mst3_awlock,
        output logic [4             -1:0] mst3_awcache,
        output logic [3             -1:0] mst3_awprot,
        output logic [4             -1:0] mst3_awqos,
        output logic [4             -1:0] mst3_awregion,
        output logic [AXI_ID_W      -1:0] mst3_awid,
        output logic [AXI_AUSER_W   -1:0] mst3_awuser,
        output logic                      mst3_wvalid,
        input  wire                       mst3_wready,
        output logic                      mst3_wlast,
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
        output logic [8             -1:0] mst3_arlen,
        output logic [3             -1:0] mst3_arsize,
        output logic [2             -1:0] mst3_arburst,
        output logic [2             -1:0] mst3_arlock,
        output logic [4             -1:0] mst3_arcache,
        output logic [3             -1:0] mst3_arprot,
        output logic [4             -1:0] mst3_arqos,
        output logic [4             -1:0] mst3_arregion,
        output logic [AXI_ID_W      -1:0] mst3_arid,
        output logic [AXI_AUSER_W   -1:0] mst3_aruser,
        input  wire                       mst3_rvalid,
        output logic                      mst3_rready,
        input  wire  [AXI_ID_W      -1:0] mst3_rid,
        input  wire  [2             -1:0] mst3_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst3_rdata,
        input  wire                       mst3_rlast,
        input  wire  [AXI_RUSER_W   -1:0] mst3_ruser
    );


    ///////////////////////////////////////////////////////////////////////////
    // Parameters setup checks
    ///////////////////////////////////////////////////////////////////////////

    initial begin

        `CHECKER((MST0_OSTDREQ_NUM>0 && MST0_OSTDREQ_SIZE==0),
            "MST0 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((MST1_OSTDREQ_NUM>0 && MST1_OSTDREQ_SIZE==0),
            "MST1 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((MST2_OSTDREQ_NUM>0 && MST2_OSTDREQ_SIZE==0),
            "MST2 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((MST3_OSTDREQ_NUM>0 && MST3_OSTDREQ_SIZE==0),
            "MST3 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((SLV0_OSTDREQ_NUM>0 && SLV0_OSTDREQ_SIZE==0),
            "SLV0 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((SLV1_OSTDREQ_NUM>0 && SLV1_OSTDREQ_SIZE==0),
            "SLV1 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((SLV2_OSTDREQ_NUM>0 && SLV2_OSTDREQ_SIZE==0),
            "SLV2 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((SLV3_OSTDREQ_NUM>0 && SLV3_OSTDREQ_SIZE==0),
            "SLV3 is setup with oustanding request but their size must be greater than 0");

        `CHECKER((MST0_ID_MASK==0), "MST0 mask ID must be greater than 0");

        `CHECKER((MST1_ID_MASK==0), "MST1 mask ID must be greater than 0");

        `CHECKER((MST2_ID_MASK==0), "MST2 mask ID must be greater than 0");

        `CHECKER((MST3_ID_MASK==0), "MST3 mask ID must be greater than 0");

    end


    ///////////////////////////////////////////////////////////////////////////
    // Local declarations
    ///////////////////////////////////////////////////////////////////////////

    localparam AUSER_W = (USER_SUPPORT > 0) ? AXI_AUSER_W : 0;

    localparam WUSER_W = (USER_SUPPORT > 0) ? AXI_WUSER_W : 0;

    localparam BUSER_W = (USER_SUPPORT > 0) ? AXI_BUSER_W : 0;

    localparam RUSER_W = (USER_SUPPORT > 0) ? AXI_RUSER_W : 0;

                                             // AXI4-lite signaling
    localparam AWCH_W = (AXI_SIGNALING==0) ? AXI_ADDR_W + AXI_ID_W + 3 + AUSER_W :
                                             // AXI4 signaling
                                             AXI_ADDR_W + AXI_ID_W + 30 + AUSER_W;

    localparam WCH_W = AXI_DATA_W + AXI_DATA_W/8 + WUSER_W;

    localparam BCH_W = AXI_ID_W + 2 + BUSER_W;

    localparam ARCH_W = AWCH_W;

    localparam RCH_W = AXI_DATA_W + AXI_ID_W + 2 + RUSER_W;

    localparam MST_ROUTES = {MST3_ROUTES,
                             MST2_ROUTES,
                             MST1_ROUTES,
                             MST0_ROUTES};

    logic [MST_NB            -1:0] i_awvalid;
    logic [MST_NB            -1:0] i_awready;
    logic [MST_NB*AWCH_W     -1:0] i_awch;
    logic [MST_NB            -1:0] i_wvalid;
    logic [MST_NB            -1:0] i_wready;
    logic [MST_NB            -1:0] i_wlast;
    logic [MST_NB*WCH_W      -1:0] i_wch;
    logic [MST_NB            -1:0] i_bvalid;
    logic [MST_NB            -1:0] i_bready;
    logic [MST_NB*BCH_W      -1:0] i_bch;
    logic [MST_NB            -1:0] i_arvalid;
    logic [MST_NB            -1:0] i_arready;
    logic [MST_NB*ARCH_W     -1:0] i_arch;
    logic [MST_NB            -1:0] i_rvalid;
    logic [MST_NB            -1:0] i_rready;
    logic [MST_NB            -1:0] i_rlast;
    logic [MST_NB*RCH_W      -1:0] i_rch;
    logic [SLV_NB            -1:0] o_awvalid;
    logic [SLV_NB            -1:0] o_awready;
    logic [SLV_NB*AWCH_W     -1:0] o_awch;
    logic [SLV_NB            -1:0] o_wvalid;
    logic [SLV_NB            -1:0] o_wready;
    logic [SLV_NB            -1:0] o_wlast;
    logic [SLV_NB*WCH_W      -1:0] o_wch;
    logic [SLV_NB            -1:0] o_bvalid;
    logic [SLV_NB            -1:0] o_bready;
    logic [SLV_NB*BCH_W      -1:0] o_bch;
    logic [SLV_NB            -1:0] o_arvalid;
    logic [SLV_NB            -1:0] o_arready;
    logic [SLV_NB*ARCH_W     -1:0] o_arch;
    logic [SLV_NB            -1:0] o_rvalid;
    logic [SLV_NB            -1:0] o_rready;
    logic [SLV_NB            -1:0] o_rlast;
    logic [SLV_NB*RCH_W      -1:0] o_rch;


    ///////////////////////////////////////////////////////////////////////////
    // Slave interface 0
    ///////////////////////////////////////////////////////////////////////////

    axicb_slv_if
    #(
    .AXI_ADDR_W        (AXI_ADDR_W),
    .AXI_ID_W          (AXI_ID_W),
    .AXI_DATA_W        (AXI_DATA_W),
    .SLV_NB            (SLV_NB),
    .STRB_MODE         (STRB_MODE),
    .AXI_SIGNALING     (AXI_SIGNALING),
    .MST_CDC           (MST0_CDC),
    .MST_OSTDREQ_NUM   (MST0_OSTDREQ_NUM),
    .MST_OSTDREQ_SIZE  (MST0_OSTDREQ_SIZE),
    .USER_SUPPORT      (USER_SUPPORT),
    .AXI_AUSER_W       (AXI_AUSER_W),
    .AXI_WUSER_W       (AXI_WUSER_W),
    .AXI_BUSER_W       (AXI_BUSER_W),
    .AXI_RUSER_W       (AXI_RUSER_W),
    .AWCH_W            (AWCH_W),
    .WCH_W             (WCH_W),
    .BCH_W             (BCH_W),
    .ARCH_W            (ARCH_W),
    .RCH_W             (RCH_W)
    )
    slv0_if
    (
    .i_aclk       (slv0_aclk),
    .i_aresetn    (slv0_aresetn),
    .i_srst       (slv0_srst),
    .i_awvalid    (slv0_awvalid),
    .i_awready    (slv0_awready),
    .i_awaddr     (slv0_awaddr),
    .i_awlen      (slv0_awlen),
    .i_awsize     (slv0_awsize),
    .i_awburst    (slv0_awburst),
    .i_awlock     (slv0_awlock),
    .i_awcache    (slv0_awcache),
    .i_awprot     (slv0_awprot),
    .i_awqos      (slv0_awqos),
    .i_awregion   (slv0_awregion),
    .i_awid       (slv0_awid),
    .i_awuser     (slv0_awuser),
    .i_wvalid     (slv0_wvalid),
    .i_wready     (slv0_wready),
    .i_wlast      (slv0_wlast ),
    .i_wdata      (slv0_wdata),
    .i_wstrb      (slv0_wstrb),
    .i_wuser      (slv0_wuser),
    .i_bvalid     (slv0_bvalid),
    .i_bready     (slv0_bready),
    .i_bid        (slv0_bid),
    .i_bresp      (slv0_bresp),
    .i_buser      (slv0_buser),
    .i_arvalid    (slv0_arvalid),
    .i_arready    (slv0_arready),
    .i_araddr     (slv0_araddr),
    .i_arlen      (slv0_arlen),
    .i_arsize     (slv0_arsize),
    .i_arburst    (slv0_arburst),
    .i_arlock     (slv0_arlock),
    .i_arcache    (slv0_arcache),
    .i_arprot     (slv0_arprot),
    .i_arqos      (slv0_arqos),
    .i_arregion   (slv0_arregion),
    .i_arid       (slv0_arid),
    .i_aruser     (slv0_aruser),
    .i_rvalid     (slv0_rvalid),
    .i_rready     (slv0_rready),
    .i_rid        (slv0_rid),
    .i_rresp      (slv0_rresp),
    .i_rdata      (slv0_rdata),
    .i_rlast      (slv0_rlast),
    .i_ruser      (slv0_ruser),
    .o_aclk       (aclk),
    .o_aresetn    (aresetn),
    .o_srst       (srst),
    .o_awvalid    (i_awvalid[0]),
    .o_awready    (i_awready[0]),
    .o_awch       (i_awch[0*AWCH_W+:AWCH_W]),
    .o_wvalid     (i_wvalid[0]),
    .o_wready     (i_wready[0]),
    .o_wlast      (i_wlast[0]),
    .o_wch        (i_wch[0*WCH_W+:WCH_W]),
    .o_bvalid     (i_bvalid[0]),
    .o_bready     (i_bready[0]),
    .o_bch        (i_bch[0*BCH_W+:BCH_W]),
    .o_arvalid    (i_arvalid[0]),
    .o_arready    (i_arready[0]),
    .o_arch       (i_arch[0*ARCH_W+:ARCH_W]),
    .o_rvalid     (i_rvalid[0]),
    .o_rready     (i_rready[0]),
    .o_rlast      (i_rlast[0]),
    .o_rch        (i_rch[0*RCH_W+:RCH_W])
    );

    ///////////////////////////////////////////////////////////////////////////
    // Slave interface 1
    ///////////////////////////////////////////////////////////////////////////

    axicb_slv_if
    #(
    .AXI_ADDR_W        (AXI_ADDR_W),
    .AXI_ID_W          (AXI_ID_W),
    .AXI_DATA_W        (AXI_DATA_W),
    .SLV_NB            (SLV_NB),
    .STRB_MODE         (STRB_MODE),
    .AXI_SIGNALING     (AXI_SIGNALING),
    .MST_CDC           (MST1_CDC),
    .MST_OSTDREQ_NUM   (MST1_OSTDREQ_NUM),
    .MST_OSTDREQ_SIZE  (MST1_OSTDREQ_SIZE),
    .USER_SUPPORT      (USER_SUPPORT),
    .AXI_AUSER_W       (AXI_AUSER_W),
    .AXI_WUSER_W       (AXI_WUSER_W),
    .AXI_BUSER_W       (AXI_BUSER_W),
    .AXI_RUSER_W       (AXI_RUSER_W),
    .AWCH_W            (AWCH_W),
    .WCH_W             (WCH_W),
    .BCH_W             (BCH_W),
    .ARCH_W            (ARCH_W),
    .RCH_W             (RCH_W)
    )
    slv1_if
    (
    .i_aclk       (slv1_aclk),
    .i_aresetn    (slv1_aresetn),
    .i_srst       (slv1_srst),
    .i_awvalid    (slv1_awvalid),
    .i_awready    (slv1_awready),
    .i_awaddr     (slv1_awaddr),
    .i_awlen      (slv1_awlen),
    .i_awsize     (slv1_awsize),
    .i_awburst    (slv1_awburst),
    .i_awlock     (slv1_awlock),
    .i_awcache    (slv1_awcache),
    .i_awprot     (slv1_awprot),
    .i_awqos      (slv1_awqos),
    .i_awregion   (slv1_awregion),
    .i_awid       (slv1_awid),
    .i_awuser     (slv1_awuser),
    .i_wvalid     (slv1_wvalid),
    .i_wready     (slv1_wready),
    .i_wlast      (slv1_wlast ),
    .i_wdata      (slv1_wdata),
    .i_wstrb      (slv1_wstrb),
    .i_wuser      (slv1_wuser),
    .i_bvalid     (slv1_bvalid),
    .i_bready     (slv1_bready),
    .i_bid        (slv1_bid),
    .i_bresp      (slv1_bresp),
    .i_buser      (slv1_buser),
    .i_arvalid    (slv1_arvalid),
    .i_arready    (slv1_arready),
    .i_araddr     (slv1_araddr),
    .i_arlen      (slv1_arlen),
    .i_arsize     (slv1_arsize),
    .i_arburst    (slv1_arburst),
    .i_arlock     (slv1_arlock),
    .i_arcache    (slv1_arcache),
    .i_arprot     (slv1_arprot),
    .i_arqos      (slv1_arqos),
    .i_arregion   (slv1_arregion),
    .i_arid       (slv1_arid),
    .i_aruser     (slv1_aruser),
    .i_rvalid     (slv1_rvalid),
    .i_rready     (slv1_rready),
    .i_rid        (slv1_rid),
    .i_rresp      (slv1_rresp),
    .i_rdata      (slv1_rdata),
    .i_rlast      (slv1_rlast),
    .i_ruser      (slv1_ruser),
    .o_aclk       (aclk),
    .o_aresetn    (aresetn),
    .o_srst       (srst),
    .o_awvalid    (i_awvalid[1]),
    .o_awready    (i_awready[1]),
    .o_awch       (i_awch[1*AWCH_W+:AWCH_W]),
    .o_wvalid     (i_wvalid[1]),
    .o_wready     (i_wready[1]),
    .o_wlast      (i_wlast[1]),
    .o_wch        (i_wch[1*WCH_W+:WCH_W]),
    .o_bvalid     (i_bvalid[1]),
    .o_bready     (i_bready[1]),
    .o_bch        (i_bch[1*BCH_W+:BCH_W]),
    .o_arvalid    (i_arvalid[1]),
    .o_arready    (i_arready[1]),
    .o_arch       (i_arch[1*ARCH_W+:ARCH_W]),
    .o_rvalid     (i_rvalid[1]),
    .o_rready     (i_rready[1]),
    .o_rlast      (i_rlast[1]),
    .o_rch        (i_rch[1*RCH_W+:RCH_W])
    );

    ///////////////////////////////////////////////////////////////////////////
    // Slave interface 2
    ///////////////////////////////////////////////////////////////////////////

    axicb_slv_if
    #(
    .AXI_ADDR_W        (AXI_ADDR_W),
    .AXI_ID_W          (AXI_ID_W),
    .AXI_DATA_W        (AXI_DATA_W),
    .SLV_NB            (SLV_NB),
    .STRB_MODE         (STRB_MODE),
    .AXI_SIGNALING     (AXI_SIGNALING),
    .MST_CDC           (MST2_CDC),
    .MST_OSTDREQ_NUM   (MST2_OSTDREQ_NUM),
    .MST_OSTDREQ_SIZE  (MST2_OSTDREQ_SIZE),
    .USER_SUPPORT      (USER_SUPPORT),
    .AXI_AUSER_W       (AXI_AUSER_W),
    .AXI_WUSER_W       (AXI_WUSER_W),
    .AXI_BUSER_W       (AXI_BUSER_W),
    .AXI_RUSER_W       (AXI_RUSER_W),
    .AWCH_W            (AWCH_W),
    .WCH_W             (WCH_W),
    .BCH_W             (BCH_W),
    .ARCH_W            (ARCH_W),
    .RCH_W             (RCH_W)
    )
    slv2_if
    (
    .i_aclk       (slv2_aclk),
    .i_aresetn    (slv2_aresetn),
    .i_srst       (slv2_srst),
    .i_awvalid    (slv2_awvalid),
    .i_awready    (slv2_awready),
    .i_awaddr     (slv2_awaddr),
    .i_awlen      (slv2_awlen),
    .i_awsize     (slv2_awsize),
    .i_awburst    (slv2_awburst),
    .i_awlock     (slv2_awlock),
    .i_awcache    (slv2_awcache),
    .i_awprot     (slv2_awprot),
    .i_awqos      (slv2_awqos),
    .i_awregion   (slv2_awregion),
    .i_awid       (slv2_awid),
    .i_awuser     (slv2_awuser),
    .i_wvalid     (slv2_wvalid),
    .i_wready     (slv2_wready),
    .i_wlast      (slv2_wlast ),
    .i_wdata      (slv2_wdata),
    .i_wstrb      (slv2_wstrb),
    .i_wuser      (slv2_wuser),
    .i_bvalid     (slv2_bvalid),
    .i_bready     (slv2_bready),
    .i_bid        (slv2_bid),
    .i_bresp      (slv2_bresp),
    .i_buser      (slv2_buser),
    .i_arvalid    (slv2_arvalid),
    .i_arready    (slv2_arready),
    .i_araddr     (slv2_araddr),
    .i_arlen      (slv2_arlen),
    .i_arsize     (slv2_arsize),
    .i_arburst    (slv2_arburst),
    .i_arlock     (slv2_arlock),
    .i_arcache    (slv2_arcache),
    .i_arprot     (slv2_arprot),
    .i_arqos      (slv2_arqos),
    .i_arregion   (slv2_arregion),
    .i_arid       (slv2_arid),
    .i_aruser     (slv3_aruser),
    .i_rvalid     (slv2_rvalid),
    .i_rready     (slv2_rready),
    .i_rid        (slv2_rid),
    .i_rresp      (slv2_rresp),
    .i_rdata      (slv2_rdata),
    .i_rlast      (slv2_rlast),
    .i_ruser      (slv2_ruser),
    .o_aclk       (aclk),
    .o_aresetn    (aresetn),
    .o_srst       (srst),
    .o_awvalid    (i_awvalid[2]),
    .o_awready    (i_awready[2]),
    .o_awch       (i_awch[2*AWCH_W+:AWCH_W]),
    .o_wvalid     (i_wvalid[2]),
    .o_wready     (i_wready[2]),
    .o_wlast      (i_wlast[2]),
    .o_wch        (i_wch[2*WCH_W+:WCH_W]),
    .o_bvalid     (i_bvalid[2]),
    .o_bready     (i_bready[2]),
    .o_bch        (i_bch[2*BCH_W+:BCH_W]),
    .o_arvalid    (i_arvalid[2]),
    .o_arready    (i_arready[2]),
    .o_arch       (i_arch[2*ARCH_W+:ARCH_W]),
    .o_rvalid     (i_rvalid[2]),
    .o_rready     (i_rready[2]),
    .o_rlast      (i_rlast[2]),
    .o_rch        (i_rch[2*RCH_W+:RCH_W])
    );

    ///////////////////////////////////////////////////////////////////////////
    // Slave interface 3
    ///////////////////////////////////////////////////////////////////////////

    axicb_slv_if
    #(
    .AXI_ADDR_W        (AXI_ADDR_W),
    .AXI_ID_W          (AXI_ID_W),
    .AXI_DATA_W        (AXI_DATA_W),
    .SLV_NB            (SLV_NB),
    .STRB_MODE         (STRB_MODE),
    .AXI_SIGNALING     (AXI_SIGNALING),
    .MST_CDC           (MST3_CDC),
    .MST_OSTDREQ_NUM   (MST3_OSTDREQ_NUM),
    .MST_OSTDREQ_SIZE  (MST3_OSTDREQ_SIZE),
    .USER_SUPPORT      (USER_SUPPORT),
    .AXI_AUSER_W       (AXI_AUSER_W),
    .AXI_WUSER_W       (AXI_WUSER_W),
    .AXI_BUSER_W       (AXI_BUSER_W),
    .AXI_RUSER_W       (AXI_RUSER_W),
    .AWCH_W            (AWCH_W),
    .WCH_W             (WCH_W),
    .BCH_W             (BCH_W),
    .ARCH_W            (ARCH_W),
    .RCH_W             (RCH_W)
    )
    slv3_if
    (
    .i_aclk       (slv3_aclk),
    .i_aresetn    (slv3_aresetn),
    .i_srst       (slv3_srst),
    .i_awvalid    (slv3_awvalid),
    .i_awready    (slv3_awready),
    .i_awaddr     (slv3_awaddr),
    .i_awlen      (slv3_awlen),
    .i_awsize     (slv3_awsize),
    .i_awburst    (slv3_awburst),
    .i_awlock     (slv3_awlock),
    .i_awcache    (slv3_awcache),
    .i_awprot     (slv3_awprot),
    .i_awqos      (slv3_awqos),
    .i_awregion   (slv3_awregion),
    .i_awid       (slv3_awid),
    .i_awuser     (slv3_awuser),
    .i_wvalid     (slv3_wvalid),
    .i_wready     (slv3_wready),
    .i_wlast      (slv3_wlast ),
    .i_wdata      (slv3_wdata),
    .i_wstrb      (slv3_wstrb),
    .i_wuser      (slv3_wuser),
    .i_bvalid     (slv3_bvalid),
    .i_bready     (slv3_bready),
    .i_bid        (slv3_bid),
    .i_bresp      (slv3_bresp),
    .i_buser      (slv3_buser),
    .i_arvalid    (slv3_arvalid),
    .i_arready    (slv3_arready),
    .i_araddr     (slv3_araddr),
    .i_arlen      (slv3_arlen),
    .i_arsize     (slv3_arsize),
    .i_arburst    (slv3_arburst),
    .i_arlock     (slv3_arlock),
    .i_arcache    (slv3_arcache),
    .i_arprot     (slv3_arprot),
    .i_arqos      (slv3_arqos),
    .i_arregion   (slv3_arregion),
    .i_arid       (slv3_arid),
    .i_aruser     (slv3_aruser),
    .i_rvalid     (slv3_rvalid),
    .i_rready     (slv3_rready),
    .i_rid        (slv3_rid),
    .i_rresp      (slv3_rresp),
    .i_rdata      (slv3_rdata),
    .i_rlast      (slv3_rlast),
    .i_ruser      (slv3_ruser),
    .o_aclk       (aclk),
    .o_aresetn    (aresetn),
    .o_srst       (srst),
    .o_awvalid    (i_awvalid[3]),
    .o_awready    (i_awready[3]),
    .o_awch       (i_awch[3*AWCH_W+:AWCH_W]),
    .o_wvalid     (i_wvalid[3]),
    .o_wready     (i_wready[3]),
    .o_wlast      (i_wlast[3]),
    .o_wch        (i_wch[3*WCH_W+:WCH_W]),
    .o_bvalid     (i_bvalid[3]),
    .o_bready     (i_bready[3]),
    .o_bch        (i_bch[3*BCH_W+:BCH_W]),
    .o_arvalid    (i_arvalid[3]),
    .o_arready    (i_arready[3]),
    .o_arch       (i_arch[3*ARCH_W+:ARCH_W]),
    .o_rvalid     (i_rvalid[3]),
    .o_rready     (i_rready[3]),
    .o_rlast      (i_rlast[3]),
    .o_rch        (i_rch[3*RCH_W+:RCH_W])
    );

    ///////////////////////////////////////////////////////////////////////////
    // AXI switching logic
    ///////////////////////////////////////////////////////////////////////////

    axicb_switch_top
    #(
    .AXI_ADDR_W         (AXI_ADDR_W),
    .AXI_ID_W           (AXI_ID_W),
    .AXI_DATA_W         (AXI_DATA_W),
    .AXI_SIGNALING      (AXI_SIGNALING),
    .MST_NB             (MST_NB),
    .SLV_NB             (SLV_NB),
    .MST_PIPELINE       (MST_PIPELINE),
    .SLV_PIPELINE       (SLV_PIPELINE),
    .TIMEOUT_ENABLE     (TIMEOUT_ENABLE),
    .MST0_ID_MASK       (MST0_ID_MASK),
    .MST1_ID_MASK       (MST1_ID_MASK),
    .MST2_ID_MASK       (MST2_ID_MASK),
    .MST3_ID_MASK       (MST3_ID_MASK),
    .MST_ROUTES         (MST_ROUTES),
    .MST0_PRIORITY      (MST0_PRIORITY),
    .MST1_PRIORITY      (MST1_PRIORITY),
    .MST2_PRIORITY      (MST2_PRIORITY),
    .MST3_PRIORITY      (MST3_PRIORITY),
    .SLV0_START_ADDR    (SLV0_START_ADDR),
    .SLV0_END_ADDR      (SLV0_END_ADDR),
    .SLV1_START_ADDR    (SLV1_START_ADDR),
    .SLV1_END_ADDR      (SLV1_END_ADDR),
    .SLV2_START_ADDR    (SLV2_START_ADDR),
    .SLV2_END_ADDR      (SLV2_END_ADDR),
    .SLV3_START_ADDR    (SLV3_START_ADDR),
    .SLV3_END_ADDR      (SLV3_END_ADDR),
    .AWCH_W             (AWCH_W),
    .WCH_W              (WCH_W),
    .BCH_W              (BCH_W),
    .ARCH_W             (ARCH_W),
    .RCH_W              (RCH_W)
    )
    switchs
    (
    .aclk      (aclk),
    .aresetn   (aresetn),
    .srst      (srst),
    .i_awvalid (i_awvalid),
    .i_awready (i_awready),
    .i_awch    (i_awch),
    .i_wvalid  (i_wvalid),
    .i_wready  (i_wready),
    .i_wlast   (i_wlast),
    .i_wch     (i_wch),
    .i_bvalid  (i_bvalid),
    .i_bready  (i_bready),
    .i_bch     (i_bch),
    .i_arvalid (i_arvalid),
    .i_arready (i_arready),
    .i_arch    (i_arch),
    .i_rvalid  (i_rvalid),
    .i_rready  (i_rready),
    .i_rlast   (i_rlast),
    .i_rch     (i_rch),
    .o_awvalid (o_awvalid),
    .o_awready (o_awready),
    .o_awch    (o_awch),
    .o_wvalid  (o_wvalid),
    .o_wready  (o_wready),
    .o_wlast   (o_wlast),
    .o_wch     (o_wch),
    .o_bvalid  (o_bvalid),
    .o_bready  (o_bready),
    .o_bch     (o_bch),
    .o_arvalid (o_arvalid),
    .o_arready (o_arready),
    .o_arch    (o_arch),
    .o_rvalid  (o_rvalid),
    .o_rready  (o_rready),
    .o_rlast   (o_rlast),
    .o_rch     (o_rch)
    );


    ///////////////////////////////////////////////////////////////////////////
    // Master 0 interface
    ///////////////////////////////////////////////////////////////////////////

    axicb_mst_if
    #(
    .AXI_ADDR_W       (AXI_ADDR_W),
    .AXI_ID_W         (AXI_ID_W),
    .AXI_DATA_W       (AXI_DATA_W),
    .STRB_MODE        (STRB_MODE),
    .AXI_SIGNALING    (AXI_SIGNALING),
    .SLV_CDC          (SLV0_CDC),
    .SLV_OSTDREQ_NUM  (SLV0_OSTDREQ_NUM),
    .SLV_OSTDREQ_SIZE (SLV0_OSTDREQ_SIZE),
    .USER_SUPPORT     (USER_SUPPORT),
    .KEEP_BASE_ADDR   (SLV0_KEEP_BASE_ADDR),
    .BASE_ADDR        (SLV0_START_ADDR),
    .AXI_AUSER_W      (AXI_AUSER_W),
    .AXI_WUSER_W      (AXI_WUSER_W),
    .AXI_BUSER_W      (AXI_BUSER_W),
    .AXI_RUSER_W      (AXI_RUSER_W),
    .AWCH_W           (AWCH_W),
    .WCH_W            (WCH_W),
    .BCH_W            (BCH_W),
    .ARCH_W           (ARCH_W),
    .RCH_W            (RCH_W)
    )
    mst0_if
    (
    .i_aclk       (slv0_aclk),
    .i_aresetn    (slv0_aresetn),
    .i_srst       (slv0_srst),
    .i_awvalid    (o_awvalid[0]),
    .i_awready    (o_awready[0]),
    .i_awch       (o_awch[0*AWCH_W+:AWCH_W]),
    .i_wvalid     (o_wvalid[0]),
    .i_wready     (o_wready[0]),
    .i_wlast      (o_wlast[0]),
    .i_wch        (o_wch[0*WCH_W+:WCH_W]),
    .i_bvalid     (o_bvalid[0]),
    .i_bready     (o_bready[0]),
    .i_bch        (o_bch[0*BCH_W+:BCH_W]),
    .i_arvalid    (o_arvalid[0]),
    .i_arready    (o_arready[0]),
    .i_arch       (o_arch[0*ARCH_W+:ARCH_W]),
    .i_rvalid     (o_rvalid[0]),
    .i_rready     (o_rready[0]),
    .i_rlast      (o_rlast[0]),
    .i_rch        (o_rch[0*RCH_W+:RCH_W]),
    .o_aclk       (mst0_aclk),
    .o_aresetn    (mst0_aresetn),
    .o_srst       (mst0_srst),
    .o_awvalid    (mst0_awvalid),
    .o_awready    (mst0_awready),
    .o_awaddr     (mst0_awaddr),
    .o_awlen      (mst0_awlen),
    .o_awsize     (mst0_awsize),
    .o_awburst    (mst0_awburst),
    .o_awlock     (mst0_awlock),
    .o_awcache    (mst0_awcache),
    .o_awprot     (mst0_awprot),
    .o_awqos      (mst0_awqos),
    .o_awregion   (mst0_awregion),
    .o_awid       (mst0_awid),
    .o_awuser     (mst0_awuser),
    .o_wvalid     (mst0_wvalid),
    .o_wready     (mst0_wready),
    .o_wlast      (mst0_wlast),
    .o_wdata      (mst0_wdata),
    .o_wstrb      (mst0_wstrb),
    .o_wuser      (mst0_wuser),
    .o_bvalid     (mst0_bvalid),
    .o_bready     (mst0_bready),
    .o_bid        (mst0_bid),
    .o_bresp      (mst0_bresp),
    .o_buser      (mst0_buser),
    .o_arvalid    (mst0_arvalid),
    .o_arready    (mst0_arready),
    .o_araddr     (mst0_araddr),
    .o_arlen      (mst0_arlen),
    .o_arsize     (mst0_arsize),
    .o_arburst    (mst0_arburst),
    .o_arlock     (mst0_arlock),
    .o_arcache    (mst0_arcache),
    .o_arprot     (mst0_arprot),
    .o_arqos      (mst0_arqos),
    .o_arregion   (mst0_arregion),
    .o_arid       (mst0_arid),
    .o_aruser     (mst0_aruser),
    .o_rvalid     (mst0_rvalid),
    .o_rready     (mst0_rready),
    .o_rid        (mst0_rid),
    .o_rresp      (mst0_rresp),
    .o_rdata      (mst0_rdata),
    .o_rlast      (mst0_rlast),
    .o_ruser      (mst0_ruser)
    );

    ///////////////////////////////////////////////////////////////////////////
    // Master 1 interface
    ///////////////////////////////////////////////////////////////////////////

    axicb_mst_if
    #(
    .AXI_ADDR_W       (AXI_ADDR_W),
    .AXI_ID_W         (AXI_ID_W),
    .AXI_DATA_W       (AXI_DATA_W),
    .STRB_MODE        (STRB_MODE),
    .AXI_SIGNALING    (AXI_SIGNALING),
    .SLV_CDC          (SLV1_CDC),
    .SLV_OSTDREQ_NUM  (SLV1_OSTDREQ_NUM),
    .SLV_OSTDREQ_SIZE (SLV1_OSTDREQ_SIZE),
    .USER_SUPPORT     (USER_SUPPORT),
    .KEEP_BASE_ADDR   (SLV1_KEEP_BASE_ADDR),
    .BASE_ADDR        (SLV1_START_ADDR),
    .AXI_AUSER_W      (AXI_AUSER_W),
    .AXI_WUSER_W      (AXI_WUSER_W),
    .AXI_BUSER_W      (AXI_BUSER_W),
    .AXI_RUSER_W      (AXI_RUSER_W),
    .AWCH_W           (AWCH_W),
    .WCH_W            (WCH_W),
    .BCH_W            (BCH_W),
    .ARCH_W           (ARCH_W),
    .RCH_W            (RCH_W)
    )
    mst1_if
    (
    .i_aclk       (slv1_aclk),
    .i_aresetn    (slv1_aresetn),
    .i_srst       (slv1_srst),
    .i_awvalid    (o_awvalid[1]),
    .i_awready    (o_awready[1]),
    .i_awch       (o_awch[1*AWCH_W+:AWCH_W]),
    .i_wvalid     (o_wvalid[1]),
    .i_wready     (o_wready[1]),
    .i_wlast      (o_wlast[1]),
    .i_wch        (o_wch[1*WCH_W+:WCH_W]),
    .i_bvalid     (o_bvalid[1]),
    .i_bready     (o_bready[1]),
    .i_bch        (o_bch[1*BCH_W+:BCH_W]),
    .i_arvalid    (o_arvalid[1]),
    .i_arready    (o_arready[1]),
    .i_arch       (o_arch[1*ARCH_W+:ARCH_W]),
    .i_rvalid     (o_rvalid[1]),
    .i_rready     (o_rready[1]),
    .i_rlast      (o_rlast[1]),
    .i_rch        (o_rch[1*RCH_W+:RCH_W]),
    .o_aclk       (mst1_aclk),
    .o_aresetn    (mst1_aresetn),
    .o_srst       (mst1_srst),
    .o_awvalid    (mst1_awvalid),
    .o_awready    (mst1_awready),
    .o_awaddr     (mst1_awaddr),
    .o_awlen      (mst1_awlen),
    .o_awsize     (mst1_awsize),
    .o_awburst    (mst1_awburst),
    .o_awlock     (mst1_awlock),
    .o_awcache    (mst1_awcache),
    .o_awprot     (mst1_awprot),
    .o_awqos      (mst1_awqos),
    .o_awregion   (mst1_awregion),
    .o_awid       (mst1_awid),
    .o_awuser     (mst1_awuser),
    .o_wvalid     (mst1_wvalid),
    .o_wready     (mst1_wready),
    .o_wlast      (mst1_wlast),
    .o_wdata      (mst1_wdata),
    .o_wstrb      (mst1_wstrb),
    .o_wuser      (mst1_wuser),
    .o_bvalid     (mst1_bvalid),
    .o_bready     (mst1_bready),
    .o_bid        (mst1_bid),
    .o_bresp      (mst1_bresp),
    .o_buser      (mst1_buser),
    .o_arvalid    (mst1_arvalid),
    .o_arready    (mst1_arready),
    .o_araddr     (mst1_araddr),
    .o_arlen      (mst1_arlen),
    .o_arsize     (mst1_arsize),
    .o_arburst    (mst1_arburst),
    .o_arlock     (mst1_arlock),
    .o_arcache    (mst1_arcache),
    .o_arprot     (mst1_arprot),
    .o_arqos      (mst1_arqos),
    .o_arregion   (mst1_arregion),
    .o_arid       (mst1_arid),
    .o_aruser     (mst1_aruser),
    .o_rvalid     (mst1_rvalid),
    .o_rready     (mst1_rready),
    .o_rid        (mst1_rid),
    .o_rresp      (mst1_rresp),
    .o_rdata      (mst1_rdata),
    .o_rlast      (mst1_rlast),
    .o_ruser      (mst1_ruser)
    );

    ///////////////////////////////////////////////////////////////////////////
    // Master 2 Interface
    ///////////////////////////////////////////////////////////////////////////

    axicb_mst_if
    #(
    .AXI_ADDR_W       (AXI_ADDR_W),
    .AXI_ID_W         (AXI_ID_W),
    .AXI_DATA_W       (AXI_DATA_W),
    .STRB_MODE        (STRB_MODE),
    .AXI_SIGNALING    (AXI_SIGNALING),
    .SLV_CDC          (SLV2_CDC),
    .SLV_OSTDREQ_NUM  (SLV2_OSTDREQ_NUM),
    .SLV_OSTDREQ_SIZE (SLV2_OSTDREQ_SIZE),
    .USER_SUPPORT     (USER_SUPPORT),
    .KEEP_BASE_ADDR   (SLV2_KEEP_BASE_ADDR),
    .BASE_ADDR        (SLV2_START_ADDR),
    .AXI_AUSER_W      (AXI_AUSER_W),
    .AXI_WUSER_W      (AXI_WUSER_W),
    .AXI_BUSER_W      (AXI_BUSER_W),
    .AXI_RUSER_W      (AXI_RUSER_W),
    .AWCH_W           (AWCH_W),
    .WCH_W            (WCH_W),
    .BCH_W            (BCH_W),
    .ARCH_W           (ARCH_W),
    .RCH_W            (RCH_W)
    )
    mst2_if
    (
    .i_aclk       (slv2_aclk),
    .i_aresetn    (slv2_aresetn),
    .i_srst       (slv2_srst),
    .i_awvalid    (o_awvalid[2]),
    .i_awready    (o_awready[2]),
    .i_awch       (o_awch[2*AWCH_W+:AWCH_W]),
    .i_wvalid     (o_wvalid[2]),
    .i_wready     (o_wready[2]),
    .i_wlast      (o_wlast[2]),
    .i_wch        (o_wch[2*WCH_W+:WCH_W]),
    .i_bvalid     (o_bvalid[2]),
    .i_bready     (o_bready[2]),
    .i_bch        (o_bch[2*BCH_W+:BCH_W]),
    .i_arvalid    (o_arvalid[2]),
    .i_arready    (o_arready[2]),
    .i_arch       (o_arch[2*ARCH_W+:ARCH_W]),
    .i_rvalid     (o_rvalid[2]),
    .i_rready     (o_rready[2]),
    .i_rlast      (o_rlast[2]),
    .i_rch        (o_rch[2*RCH_W+:RCH_W]),
    .o_aclk       (mst2_aclk),
    .o_aresetn    (mst2_aresetn),
    .o_srst       (mst2_srst),
    .o_awvalid    (mst2_awvalid),
    .o_awready    (mst2_awready),
    .o_awaddr     (mst2_awaddr),
    .o_awlen      (mst2_awlen),
    .o_awsize     (mst2_awsize),
    .o_awburst    (mst2_awburst),
    .o_awlock     (mst2_awlock),
    .o_awcache    (mst2_awcache),
    .o_awprot     (mst2_awprot),
    .o_awqos      (mst2_awqos),
    .o_awregion   (mst2_awregion),
    .o_awid       (mst2_awid),
    .o_awuser     (mst2_awuser),
    .o_wvalid     (mst2_wvalid),
    .o_wready     (mst2_wready),
    .o_wlast      (mst2_wlast),
    .o_wdata      (mst2_wdata),
    .o_wstrb      (mst2_wstrb),
    .o_wuser      (mst2_wuser),
    .o_bvalid     (mst2_bvalid),
    .o_bready     (mst2_bready),
    .o_bid        (mst2_bid),
    .o_bresp      (mst2_bresp),
    .o_buser      (mst2_buser),
    .o_arvalid    (mst2_arvalid),
    .o_arready    (mst2_arready),
    .o_araddr     (mst2_araddr),
    .o_arlen      (mst2_arlen),
    .o_arsize     (mst2_arsize),
    .o_arburst    (mst2_arburst),
    .o_arlock     (mst2_arlock),
    .o_arcache    (mst2_arcache),
    .o_arprot     (mst2_arprot),
    .o_arqos      (mst2_arqos),
    .o_arregion   (mst2_arregion),
    .o_arid       (mst2_arid),
    .o_aruser     (mst2_aruser),
    .o_rvalid     (mst2_rvalid),
    .o_rready     (mst2_rready),
    .o_rid        (mst2_rid),
    .o_rresp      (mst2_rresp),
    .o_rdata      (mst2_rdata),
    .o_rlast      (mst2_rlast),
    .o_ruser      (mst2_ruser)
    );

    ///////////////////////////////////////////////////////////////////////////
    // Master 3 Interface
    ///////////////////////////////////////////////////////////////////////////

    axicb_mst_if
    #(
    .AXI_ADDR_W       (AXI_ADDR_W),
    .AXI_ID_W         (AXI_ID_W),
    .AXI_DATA_W       (AXI_DATA_W),
    .STRB_MODE        (STRB_MODE),
    .AXI_SIGNALING    (AXI_SIGNALING),
    .SLV_CDC          (SLV3_CDC),
    .SLV_OSTDREQ_NUM  (SLV3_OSTDREQ_NUM),
    .SLV_OSTDREQ_SIZE (SLV3_OSTDREQ_SIZE),
    .KEEP_BASE_ADDR   (SLV3_KEEP_BASE_ADDR),
    .BASE_ADDR        (SLV3_START_ADDR),
    .USER_SUPPORT     (USER_SUPPORT),
    .AXI_AUSER_W      (AXI_AUSER_W),
    .AXI_WUSER_W      (AXI_WUSER_W),
    .AXI_BUSER_W      (AXI_BUSER_W),
    .AXI_RUSER_W      (AXI_RUSER_W),
    .AWCH_W           (AWCH_W),
    .WCH_W            (WCH_W),
    .BCH_W            (BCH_W),
    .ARCH_W           (ARCH_W),
    .RCH_W            (RCH_W)
    )
    mst3_if
    (
    .i_aclk       (slv3_aclk),
    .i_aresetn    (slv3_aresetn),
    .i_srst       (slv3_srst),
    .i_awvalid    (o_awvalid[3]),
    .i_awready    (o_awready[3]),
    .i_awch       (o_awch[3*AWCH_W+:AWCH_W]),
    .i_wvalid     (o_wvalid[3]),
    .i_wready     (o_wready[3]),
    .i_wlast      (o_wlast[3]),
    .i_wch        (o_wch[3*WCH_W+:WCH_W]),
    .i_bvalid     (o_bvalid[3]),
    .i_bready     (o_bready[3]),
    .i_bch        (o_bch[3*BCH_W+:BCH_W]),
    .i_arvalid    (o_arvalid[3]),
    .i_arready    (o_arready[3]),
    .i_arch       (o_arch[3*ARCH_W+:ARCH_W]),
    .i_rvalid     (o_rvalid[3]),
    .i_rready     (o_rready[3]),
    .i_rlast      (o_rlast[3]),
    .i_rch        (o_rch[3*RCH_W+:RCH_W]),
    .o_aclk       (mst3_aclk),
    .o_aresetn    (mst3_aresetn),
    .o_srst       (mst3_srst),
    .o_awvalid    (mst3_awvalid),
    .o_awready    (mst3_awready),
    .o_awaddr     (mst3_awaddr),
    .o_awlen      (mst3_awlen),
    .o_awsize     (mst3_awsize),
    .o_awburst    (mst3_awburst),
    .o_awlock     (mst3_awlock),
    .o_awcache    (mst3_awcache),
    .o_awprot     (mst3_awprot),
    .o_awqos      (mst3_awqos),
    .o_awregion   (mst3_awregion),
    .o_awid       (mst3_awid),
    .o_awuser     (mst3_awuser),
    .o_wvalid     (mst3_wvalid),
    .o_wready     (mst3_wready),
    .o_wlast      (mst3_wlast),
    .o_wdata      (mst3_wdata),
    .o_wstrb      (mst3_wstrb),
    .o_wuser      (mst3_wuser),
    .o_bvalid     (mst3_bvalid),
    .o_bready     (mst3_bready),
    .o_bid        (mst3_bid),
    .o_bresp      (mst3_bresp),
    .o_buser      (mst3_buser),
    .o_arvalid    (mst3_arvalid),
    .o_arready    (mst3_arready),
    .o_araddr     (mst3_araddr),
    .o_arlen      (mst3_arlen),
    .o_arsize     (mst3_arsize),
    .o_arburst    (mst3_arburst),
    .o_arlock     (mst3_arlock),
    .o_arcache    (mst3_arcache),
    .o_arprot     (mst3_arprot),
    .o_arqos      (mst3_arqos),
    .o_arregion   (mst3_arregion),
    .o_arid       (mst3_arid),
    .o_aruser     (mst3_aruser),
    .o_rvalid     (mst3_rvalid),
    .o_rready     (mst3_rready),
    .o_rid        (mst3_rid),
    .o_rresp      (mst3_rresp),
    .o_rdata      (mst3_rdata),
    .o_rlast      (mst3_rlast),
    .o_ruser      (mst3_ruser)
    );

endmodule

`resetall
