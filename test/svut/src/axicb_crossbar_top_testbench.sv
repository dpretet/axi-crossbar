// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

`timescale 1 ns / 1 ps

module axicb_crossbar_top_testbench();

    `SVUT_SETUP

    `ifndef TIMEOUT
    `define TIMEOUT 1000
    `endif

    `ifndef OR_TIMEOUT
    `define OR_TIMEOUT 100
    `endif

    `ifndef MAX_TRAFFIC
    `define MAX_TRAFFIC 10
    `endif

    parameter AXI_ADDR_W = `AXI_ADDR_W;
    parameter AXI_ID_W = `AXI_ID_W;
    parameter AXI_DATA_W = `AXI_DATA_W;
    parameter MST_NB = 4;
    parameter SLV_NB = 4;
    parameter MST_PIPELINE = `MST_PIPELINE;
    parameter SLV_PIPELINE = `SLV_PIPELINE;
    parameter STRB_MODE = 1;
    parameter AXI_SIGNALING = `AXI_SIGNALING;
    parameter USER_SUPPORT = `USER_SUPPORT;
    parameter AXI_AUSER_W = 4;
    parameter AXI_WUSER_W = 4;
    parameter AXI_BUSER_W = 4;
    parameter AXI_RUSER_W = 4;
    parameter TIMEOUT_VALUE = `TIMEOUT;
    parameter TIMEOUT_ENABLE = 1;
    parameter MST0_CDC = `MST0_CDC;
    parameter MST0_OSTDREQ_NUM = `MST0_OSTDREQ_NUM;
    parameter MST0_OSTDREQ_SIZE = `MST0_OSTDREQ_SIZE;
    parameter MST0_PRIORITY = `MST0_PRIORITY;
    parameter MST0_ROUTES = `MST0_ROUTES;
    parameter [AXI_ID_W-1:0] MST0_ID_MASK = 'h10;
    parameter MST1_CDC = `MST1_CDC;
    parameter MST1_OSTDREQ_NUM = `MST1_OSTDREQ_NUM;
    parameter MST1_OSTDREQ_SIZE = `MST1_OSTDREQ_SIZE;
    parameter MST1_PRIORITY = `MST1_PRIORITY;
    parameter MST1_ROUTES = `MST1_ROUTES;
    parameter [AXI_ID_W-1:0] MST1_ID_MASK = 'h20;
    parameter MST2_CDC = `MST2_CDC;
    parameter MST2_OSTDREQ_NUM = `MST2_OSTDREQ_NUM;
    parameter MST2_OSTDREQ_SIZE = `MST2_OSTDREQ_SIZE;
    parameter MST2_PRIORITY = `MST2_PRIORITY;
    parameter MST2_ROUTES = `MST2_ROUTES;
    parameter [AXI_ID_W-1:0] MST2_ID_MASK = 'h40;
    parameter MST3_CDC = `MST3_CDC;
    parameter MST3_OSTDREQ_NUM = `MST3_OSTDREQ_NUM;
    parameter MST3_OSTDREQ_SIZE = `MST3_OSTDREQ_SIZE;
    parameter MST3_PRIORITY = `MST3_PRIORITY;
    parameter MST3_ROUTES = `MST3_ROUTES;
    parameter [AXI_ID_W-1:0] MST3_ID_MASK = 'h80;
    parameter SLV0_CDC = `SLV0_CDC;
    parameter SLV0_START_ADDR = `SLV0_START_ADDR;
    parameter SLV0_END_ADDR = `SLV0_END_ADDR;
    parameter SLV0_OSTDREQ_NUM = `SLV0_OSTDREQ_NUM;
    parameter SLV0_OSTDREQ_SIZE = `SLV0_OSTDREQ_SIZE;
    parameter SLV1_CDC =`SLV1_CDC;
    parameter SLV1_START_ADDR = `SLV1_START_ADDR;
    parameter SLV1_END_ADDR = `SLV1_END_ADDR;
    parameter SLV1_OSTDREQ_NUM = `SLV1_OSTDREQ_NUM;
    parameter SLV1_OSTDREQ_SIZE = `SLV1_OSTDREQ_SIZE;
    parameter SLV2_CDC =`SLV2_CDC;
    parameter SLV2_START_ADDR = `SLV2_START_ADDR;
    parameter SLV2_END_ADDR = `SLV2_END_ADDR;
    parameter SLV2_OSTDREQ_NUM = `SLV2_OSTDREQ_NUM;
    parameter SLV2_OSTDREQ_SIZE = `SLV2_OSTDREQ_SIZE;
    parameter SLV3_CDC =`SLV3_CDC;
    parameter SLV3_START_ADDR = `SLV3_START_ADDR;
    parameter SLV3_END_ADDR = `SLV3_END_ADDR;
    parameter SLV3_OSTDREQ_NUM = `SLV3_OSTDREQ_NUM;
    parameter SLV3_OSTDREQ_SIZE = `SLV3_OSTDREQ_SIZE;

    parameter CHECK_REPORT = 1;

    logic                      aclk;
    logic                      aresetn;
    logic                      srst;
    logic [4             -1:0] mst_en;
    logic [8             -1:0] error;

    logic                      mst0_aclk;
    logic                      mst0_aresetn;
    logic                      mst0_srst;
    logic                      mst0_awvalid;
    logic                      mst0_awready;
    logic [AXI_ADDR_W    -1:0] mst0_awaddr;
    logic [8             -1:0] mst0_awlen;
    logic [3             -1:0] mst0_awsize;
    logic [2             -1:0] mst0_awburst;
    logic                      mst0_awlock;
    logic [4             -1:0] mst0_awcache;
    logic [3             -1:0] mst0_awprot;
    logic [4             -1:0] mst0_awqos;
    logic [4             -1:0] mst0_awregion;
    logic [AXI_ID_W      -1:0] mst0_awid;
    logic [AXI_AUSER_W   -1:0] mst0_awuser;
    logic                      mst0_wvalid;
    logic                      mst0_wready;
    logic                      mst0_wlast;
    logic [AXI_DATA_W    -1:0] mst0_wdata;
    logic [AXI_DATA_W/8  -1:0] mst0_wstrb;
    logic [AXI_WUSER_W   -1:0] mst0_wuser;
    logic                      mst0_bvalid;
    logic                      mst0_bready;
    logic [AXI_ID_W      -1:0] mst0_bid;
    logic [2             -1:0] mst0_bresp;
    logic [AXI_BUSER_W   -1:0] mst0_buser;
    logic                      mst0_arvalid;
    logic                      mst0_arready;
    logic [AXI_ADDR_W    -1:0] mst0_araddr;
    logic [8             -1:0] mst0_arlen;
    logic [3             -1:0] mst0_arsize;
    logic [2             -1:0] mst0_arburst;
    logic                      mst0_arlock;
    logic [4             -1:0] mst0_arcache;
    logic [3             -1:0] mst0_arprot;
    logic [4             -1:0] mst0_arqos;
    logic [4             -1:0] mst0_arregion;
    logic [AXI_ID_W      -1:0] mst0_arid;
    logic [AXI_AUSER_W   -1:0] mst0_aruser;
    logic                      mst0_rvalid;
    logic                      mst0_rready;
    logic [AXI_ID_W      -1:0] mst0_rid;
    logic [2             -1:0] mst0_rresp;
    logic [AXI_DATA_W    -1:0] mst0_rdata;
    logic                      mst0_rlast;
    logic [AXI_RUSER_W   -1:0] mst0_ruser;
    logic                      mst1_aclk;
    logic                      mst1_aresetn;
    logic                      mst1_srst;
    logic                      mst1_awvalid;
    logic                      mst1_awready;
    logic [AXI_ADDR_W    -1:0] mst1_awaddr;
    logic [8             -1:0] mst1_awlen;
    logic [3             -1:0] mst1_awsize;
    logic [2             -1:0] mst1_awburst;
    logic                      mst1_awlock;
    logic [4             -1:0] mst1_awcache;
    logic [3             -1:0] mst1_awprot;
    logic [4             -1:0] mst1_awqos;
    logic [4             -1:0] mst1_awregion;
    logic [AXI_ID_W      -1:0] mst1_awid;
    logic [AXI_AUSER_W   -1:0] mst1_awuser;
    logic                      mst1_wvalid;
    logic                      mst1_wready;
    logic                      mst1_wlast;
    logic [AXI_DATA_W    -1:0] mst1_wdata;
    logic [AXI_DATA_W/8  -1:0] mst1_wstrb;
    logic [AXI_WUSER_W   -1:0] mst1_wuser;
    logic                      mst1_bvalid;
    logic                      mst1_bready;
    logic [AXI_ID_W      -1:0] mst1_bid;
    logic [2             -1:0] mst1_bresp;
    logic [AXI_BUSER_W   -1:0] mst1_buser;
    logic                      mst1_arvalid;
    logic                      mst1_arready;
    logic [AXI_ADDR_W    -1:0] mst1_araddr;
    logic [8             -1:0] mst1_arlen;
    logic [3             -1:0] mst1_arsize;
    logic [2             -1:0] mst1_arburst;
    logic                      mst1_arlock;
    logic [4             -1:0] mst1_arcache;
    logic [3             -1:0] mst1_arprot;
    logic [4             -1:0] mst1_arqos;
    logic [4             -1:0] mst1_arregion;
    logic [AXI_ID_W      -1:0] mst1_arid;
    logic [AXI_AUSER_W   -1:0] mst1_aruser;
    logic                      mst1_rvalid;
    logic                      mst1_rready;
    logic [AXI_ID_W      -1:0] mst1_rid;
    logic [2             -1:0] mst1_rresp;
    logic [AXI_DATA_W    -1:0] mst1_rdata;
    logic                      mst1_rlast;
    logic [AXI_RUSER_W   -1:0] mst1_ruser;
    logic                      mst2_aclk;
    logic                      mst2_aresetn;
    logic                      mst2_srst;
    logic                      mst2_awvalid;
    logic                      mst2_awready;
    logic [AXI_ADDR_W    -1:0] mst2_awaddr;
    logic [8             -1:0] mst2_awlen;
    logic [3             -1:0] mst2_awsize;
    logic [2             -1:0] mst2_awburst;
    logic                      mst2_awlock;
    logic [4             -1:0] mst2_awcache;
    logic [3             -1:0] mst2_awprot;
    logic [4             -1:0] mst2_awqos;
    logic [4             -1:0] mst2_awregion;
    logic [AXI_ID_W      -1:0] mst2_awid;
    logic [AXI_AUSER_W   -1:0] mst2_awuser;
    logic                      mst2_wvalid;
    logic                      mst2_wready;
    logic                      mst2_wlast;
    logic [AXI_DATA_W    -1:0] mst2_wdata;
    logic [AXI_DATA_W/8  -1:0] mst2_wstrb;
    logic [AXI_WUSER_W   -1:0] mst2_wuser;
    logic                      mst2_bvalid;
    logic                      mst2_bready;
    logic [AXI_ID_W      -1:0] mst2_bid;
    logic [2             -1:0] mst2_bresp;
    logic [AXI_BUSER_W   -1:0] mst2_buser;
    logic                      mst2_arvalid;
    logic                      mst2_arready;
    logic [AXI_ADDR_W    -1:0] mst2_araddr;
    logic [8             -1:0] mst2_arlen;
    logic [3             -1:0] mst2_arsize;
    logic [2             -1:0] mst2_arburst;
    logic                      mst2_arlock;
    logic [4             -1:0] mst2_arcache;
    logic [3             -1:0] mst2_arprot;
    logic [4             -1:0] mst2_arqos;
    logic [4             -1:0] mst2_arregion;
    logic [AXI_ID_W      -1:0] mst2_arid;
    logic [AXI_AUSER_W   -1:0] mst2_aruser;
    logic                      mst2_rvalid;
    logic                      mst2_rready;
    logic [AXI_ID_W      -1:0] mst2_rid;
    logic [2             -1:0] mst2_rresp;
    logic [AXI_DATA_W    -1:0] mst2_rdata;
    logic                      mst2_rlast;
    logic [AXI_RUSER_W   -1:0] mst2_ruser;
    logic                      mst3_aclk;
    logic                      mst3_aresetn;
    logic                      mst3_srst;
    logic                      mst3_awvalid;
    logic                      mst3_awready;
    logic [AXI_ADDR_W    -1:0] mst3_awaddr;
    logic [8             -1:0] mst3_awlen;
    logic [3             -1:0] mst3_awsize;
    logic [2             -1:0] mst3_awburst;
    logic                      mst3_awlock;
    logic [4             -1:0] mst3_awcache;
    logic [3             -1:0] mst3_awprot;
    logic [4             -1:0] mst3_awqos;
    logic [4             -1:0] mst3_awregion;
    logic [AXI_ID_W      -1:0] mst3_awid;
    logic [AXI_AUSER_W   -1:0] mst3_awuser;
    logic                      mst3_wvalid;
    logic                      mst3_wready;
    logic                      mst3_wlast;
    logic [AXI_DATA_W    -1:0] mst3_wdata;
    logic [AXI_DATA_W/8  -1:0] mst3_wstrb;
    logic [AXI_WUSER_W   -1:0] mst3_wuser;
    logic                      mst3_bvalid;
    logic                      mst3_bready;
    logic [AXI_ID_W      -1:0] mst3_bid;
    logic [2             -1:0] mst3_bresp;
    logic [AXI_BUSER_W   -1:0] mst3_buser;
    logic                      mst3_arvalid;
    logic                      mst3_arready;
    logic [AXI_ADDR_W    -1:0] mst3_araddr;
    logic [8             -1:0] mst3_arlen;
    logic [3             -1:0] mst3_arsize;
    logic [2             -1:0] mst3_arburst;
    logic                      mst3_arlock;
    logic [4             -1:0] mst3_arcache;
    logic [3             -1:0] mst3_arprot;
    logic [4             -1:0] mst3_arqos;
    logic [4             -1:0] mst3_arregion;
    logic [AXI_ID_W      -1:0] mst3_arid;
    logic [AXI_AUSER_W   -1:0] mst3_aruser;
    logic                      mst3_rvalid;
    logic                      mst3_rready;
    logic [AXI_ID_W      -1:0] mst3_rid;
    logic [2             -1:0] mst3_rresp;
    logic [AXI_DATA_W    -1:0] mst3_rdata;
    logic                      mst3_rlast;
    logic [AXI_RUSER_W   -1:0] mst3_ruser;
    logic                      slv0_aclk;
    logic                      slv0_aresetn;
    logic                      slv0_srst;
    logic                      slv0_awvalid;
    logic                      slv0_awready;
    logic [AXI_ADDR_W    -1:0] slv0_awaddr;
    logic [8             -1:0] slv0_awlen;
    logic [3             -1:0] slv0_awsize;
    logic [2             -1:0] slv0_awburst;
    logic                      slv0_awlock;
    logic [4             -1:0] slv0_awcache;
    logic [3             -1:0] slv0_awprot;
    logic [4             -1:0] slv0_awqos;
    logic [4             -1:0] slv0_awregion;
    logic [AXI_ID_W      -1:0] slv0_awid;
    logic [AXI_AUSER_W   -1:0] slv0_awuser;
    logic                      slv0_wvalid;
    logic                      slv0_wready;
    logic                      slv0_wlast;
    logic [AXI_DATA_W    -1:0] slv0_wdata;
    logic [AXI_DATA_W/8  -1:0] slv0_wstrb;
    logic [AXI_WUSER_W   -1:0] slv0_wuser;
    logic                      slv0_bvalid;
    logic                      slv0_bready;
    logic [AXI_ID_W      -1:0] slv0_bid;
    logic [2             -1:0] slv0_bresp;
    logic [AXI_BUSER_W   -1:0] slv0_buser;
    logic                      slv0_arvalid;
    logic                      slv0_arready;
    logic [AXI_ADDR_W    -1:0] slv0_araddr;
    logic [8             -1:0] slv0_arlen;
    logic [3             -1:0] slv0_arsize;
    logic [2             -1:0] slv0_arburst;
    logic                      slv0_arlock;
    logic [4             -1:0] slv0_arcache;
    logic [3             -1:0] slv0_arprot;
    logic [4             -1:0] slv0_arqos;
    logic [4             -1:0] slv0_arregion;
    logic [AXI_ID_W      -1:0] slv0_arid;
    logic [AXI_AUSER_W   -1:0] slv0_aruser;
    logic                      slv0_rvalid;
    logic                      slv0_rready;
    logic [AXI_ID_W      -1:0] slv0_rid;
    logic [2             -1:0] slv0_rresp;
    logic [AXI_DATA_W    -1:0] slv0_rdata;
    logic                      slv0_rlast;
    logic [AXI_RUSER_W   -1:0] slv0_ruser;
    logic                      slv1_aclk;
    logic                      slv1_aresetn;
    logic                      slv1_srst;
    logic                      slv1_awvalid;
    logic                      slv1_awready;
    logic [AXI_ADDR_W    -1:0] slv1_awaddr;
    logic [8             -1:0] slv1_awlen;
    logic [3             -1:0] slv1_awsize;
    logic [2             -1:0] slv1_awburst;
    logic                      slv1_awlock;
    logic [4             -1:0] slv1_awcache;
    logic [3             -1:0] slv1_awprot;
    logic [4             -1:0] slv1_awqos;
    logic [4             -1:0] slv1_awregion;
    logic [AXI_ID_W      -1:0] slv1_awid;
    logic [AXI_AUSER_W   -1:0] slv1_awuser;
    logic                      slv1_wvalid;
    logic                      slv1_wready;
    logic                      slv1_wlast;
    logic [AXI_DATA_W    -1:0] slv1_wdata;
    logic [AXI_DATA_W/8  -1:0] slv1_wstrb;
    logic [AXI_WUSER_W   -1:0] slv1_wuser;
    logic                      slv1_bvalid;
    logic                      slv1_bready;
    logic [AXI_ID_W      -1:0] slv1_bid;
    logic [2             -1:0] slv1_bresp;
    logic [AXI_BUSER_W   -1:0] slv1_buser;
    logic                      slv1_arvalid;
    logic                      slv1_arready;
    logic [AXI_ADDR_W    -1:0] slv1_araddr;
    logic [8             -1:0] slv1_arlen;
    logic [3             -1:0] slv1_arsize;
    logic [2             -1:0] slv1_arburst;
    logic                      slv1_arlock;
    logic [4             -1:0] slv1_arcache;
    logic [3             -1:0] slv1_arprot;
    logic [4             -1:0] slv1_arqos;
    logic [4             -1:0] slv1_arregion;
    logic [AXI_ID_W      -1:0] slv1_arid;
    logic [AXI_AUSER_W   -1:0] slv1_aruser;
    logic                      slv1_rvalid;
    logic                      slv1_rready;
    logic [AXI_ID_W      -1:0] slv1_rid;
    logic [2             -1:0] slv1_rresp;
    logic [AXI_DATA_W    -1:0] slv1_rdata;
    logic                      slv1_rlast;
    logic [AXI_RUSER_W   -1:0] slv1_ruser;
    logic                      slv2_aclk;
    logic                      slv2_aresetn;
    logic                      slv2_srst;
    logic                      slv2_awvalid;
    logic                      slv2_awready;
    logic [AXI_ADDR_W    -1:0] slv2_awaddr;
    logic [8             -1:0] slv2_awlen;
    logic [3             -1:0] slv2_awsize;
    logic [2             -1:0] slv2_awburst;
    logic                      slv2_awlock;
    logic [4             -1:0] slv2_awcache;
    logic [3             -1:0] slv2_awprot;
    logic [4             -1:0] slv2_awqos;
    logic [4             -1:0] slv2_awregion;
    logic [AXI_ID_W      -1:0] slv2_awid;
    logic [AXI_AUSER_W   -1:0] slv2_awuser;
    logic                      slv2_wvalid;
    logic                      slv2_wready;
    logic                      slv2_wlast;
    logic [AXI_DATA_W    -1:0] slv2_wdata;
    logic [AXI_DATA_W/8  -1:0] slv2_wstrb;
    logic [AXI_WUSER_W   -1:0] slv2_wuser;
    logic                      slv2_bvalid;
    logic                      slv2_bready;
    logic [AXI_ID_W      -1:0] slv2_bid;
    logic [2             -1:0] slv2_bresp;
    logic [AXI_BUSER_W   -1:0] slv2_buser;
    logic                      slv2_arvalid;
    logic                      slv2_arready;
    logic [AXI_ADDR_W    -1:0] slv2_araddr;
    logic [8             -1:0] slv2_arlen;
    logic [3             -1:0] slv2_arsize;
    logic [2             -1:0] slv2_arburst;
    logic                      slv2_arlock;
    logic [4             -1:0] slv2_arcache;
    logic [3             -1:0] slv2_arprot;
    logic [4             -1:0] slv2_arqos;
    logic [4             -1:0] slv2_arregion;
    logic [AXI_ID_W      -1:0] slv2_arid;
    logic [AXI_AUSER_W   -1:0] slv2_aruser;
    logic                      slv2_rvalid;
    logic                      slv2_rready;
    logic [AXI_ID_W      -1:0] slv2_rid;
    logic [2             -1:0] slv2_rresp;
    logic [AXI_DATA_W    -1:0] slv2_rdata;
    logic                      slv2_rlast;
    logic [AXI_RUSER_W   -1:0] slv2_ruser;
    logic                      slv3_aclk;
    logic                      slv3_aresetn;
    logic                      slv3_srst;
    logic                      slv3_awvalid;
    logic                      slv3_awready;
    logic [AXI_ADDR_W    -1:0] slv3_awaddr;
    logic [8             -1:0] slv3_awlen;
    logic [3             -1:0] slv3_awsize;
    logic [2             -1:0] slv3_awburst;
    logic                      slv3_awlock;
    logic [4             -1:0] slv3_awcache;
    logic [3             -1:0] slv3_awprot;
    logic [4             -1:0] slv3_awqos;
    logic [4             -1:0] slv3_awregion;
    logic [AXI_ID_W      -1:0] slv3_awid;
    logic [AXI_AUSER_W   -1:0] slv3_awuser;
    logic                      slv3_wvalid;
    logic                      slv3_wready;
    logic                      slv3_wlast;
    logic [AXI_DATA_W    -1:0] slv3_wdata;
    logic [AXI_DATA_W/8  -1:0] slv3_wstrb;
    logic [AXI_WUSER_W   -1:0] slv3_wuser;
    logic                      slv3_bvalid;
    logic                      slv3_bready;
    logic [AXI_ID_W      -1:0] slv3_bid;
    logic [2             -1:0] slv3_bresp;
    logic [AXI_BUSER_W   -1:0] slv3_buser;
    logic                      slv3_arvalid;
    logic                      slv3_arready;
    logic [AXI_ADDR_W    -1:0] slv3_araddr;
    logic [8             -1:0] slv3_arlen;
    logic [3             -1:0] slv3_arsize;
    logic [2             -1:0] slv3_arburst;
    logic                      slv3_arlock;
    logic [4             -1:0] slv3_arcache;
    logic [3             -1:0] slv3_arprot;
    logic [4             -1:0] slv3_arqos;
    logic [4             -1:0] slv3_arregion;
    logic [AXI_ID_W      -1:0] slv3_arid;
    logic [AXI_AUSER_W   -1:0] slv3_aruser;
    logic                      slv3_rvalid;
    logic                      slv3_rready;
    logic [AXI_ID_W      -1:0] slv3_rid;
    logic [2             -1:0] slv3_rresp;
    logic [AXI_DATA_W    -1:0] slv3_rdata;
    logic                      slv3_rlast;
    logic [AXI_RUSER_W   -1:0] slv3_ruser;

    integer                    nb_reqs;
    integer                    timeout;
    logic [AXI_ADDR_W    -1:0] addr_min;
    logic [AXI_ADDR_W    -1:0] addr_max;

    string                     tsname;


    //////////////////////////////////////////////////////////////////////////
    // Instances
    //////////////////////////////////////////////////////////////////////////

    axicb_crossbar_top
    #(
    .AXI_ADDR_W             (AXI_ADDR_W),
    .AXI_ID_W               (AXI_ID_W),
    .AXI_DATA_W             (AXI_DATA_W),
    .MST_NB                 (MST_NB),
    .SLV_NB                 (SLV_NB),
    .MST_PIPELINE           (MST_PIPELINE),
    .SLV_PIPELINE           (SLV_PIPELINE),
    .STRB_MODE              (STRB_MODE),
    .AXI_SIGNALING          (AXI_SIGNALING),
    .USER_SUPPORT           (USER_SUPPORT),
    .AXI_AUSER_W            (AXI_AUSER_W),
    .AXI_WUSER_W            (AXI_WUSER_W),
    .AXI_BUSER_W            (AXI_BUSER_W),
    .AXI_RUSER_W            (AXI_RUSER_W),
    .TIMEOUT_VALUE          (TIMEOUT_VALUE),
    .TIMEOUT_ENABLE         (TIMEOUT_ENABLE),
    .MST0_CDC               (MST0_CDC),
    .MST0_OSTDREQ_NUM       (MST0_OSTDREQ_NUM),
    .MST0_OSTDREQ_SIZE      (MST0_OSTDREQ_SIZE),
    .MST0_PRIORITY          (MST0_PRIORITY),
    .MST0_ROUTES            (MST0_ROUTES),
    .MST0_ID_MASK           (MST0_ID_MASK),
    .MST1_CDC               (MST1_CDC),
    .MST1_OSTDREQ_NUM       (MST1_OSTDREQ_NUM),
    .MST1_OSTDREQ_SIZE      (MST1_OSTDREQ_SIZE),
    .MST1_PRIORITY          (MST1_PRIORITY),
    .MST1_ROUTES            (MST1_ROUTES),
    .MST1_ID_MASK           (MST1_ID_MASK),
    .MST2_CDC               (MST2_CDC),
    .MST2_OSTDREQ_NUM       (MST2_OSTDREQ_NUM),
    .MST2_OSTDREQ_SIZE      (MST2_OSTDREQ_SIZE),
    .MST2_PRIORITY          (MST2_PRIORITY),
    .MST2_ROUTES            (MST2_ROUTES),
    .MST2_ID_MASK           (MST2_ID_MASK),
    .MST3_CDC               (MST3_CDC),
    .MST3_OSTDREQ_NUM       (MST3_OSTDREQ_NUM),
    .MST3_OSTDREQ_SIZE      (MST3_OSTDREQ_SIZE),
    .MST3_PRIORITY          (MST3_PRIORITY),
    .MST3_ROUTES            (MST3_ROUTES),
    .MST3_ID_MASK           (MST3_ID_MASK),
    .SLV0_CDC               (SLV0_CDC),
    .SLV0_START_ADDR        (SLV0_START_ADDR),
    .SLV0_END_ADDR          (SLV0_END_ADDR),
    .SLV0_KEEP_BASE_ADDR    (1),
    .SLV0_OSTDREQ_NUM       (SLV0_OSTDREQ_NUM),
    .SLV0_OSTDREQ_SIZE      (SLV0_OSTDREQ_SIZE),
    .SLV1_CDC               (SLV1_CDC),
    .SLV1_START_ADDR        (SLV1_START_ADDR),
    .SLV1_END_ADDR          (SLV1_END_ADDR),
    .SLV1_KEEP_BASE_ADDR    (1),
    .SLV1_OSTDREQ_NUM       (SLV1_OSTDREQ_NUM),
    .SLV1_OSTDREQ_SIZE      (SLV1_OSTDREQ_SIZE),
    .SLV2_CDC               (SLV2_CDC),
    .SLV2_START_ADDR        (SLV2_START_ADDR),
    .SLV2_END_ADDR          (SLV2_END_ADDR),
    .SLV2_KEEP_BASE_ADDR    (1),
    .SLV2_OSTDREQ_NUM       (SLV2_OSTDREQ_NUM),
    .SLV2_OSTDREQ_SIZE      (SLV2_OSTDREQ_SIZE),
    .SLV3_CDC               (SLV3_CDC),
    .SLV3_START_ADDR        (SLV3_START_ADDR),
    .SLV3_END_ADDR          (SLV3_END_ADDR),
    .SLV3_KEEP_BASE_ADDR    (1),
    .SLV3_OSTDREQ_NUM       (SLV3_OSTDREQ_NUM),
    .SLV3_OSTDREQ_SIZE      (SLV3_OSTDREQ_SIZE)
    )
    dut
    (
    .aclk            (aclk),
    .aresetn         (aresetn),
    .srst            (srst),
    .slv0_aclk       (mst0_aclk),
    .slv0_aresetn    (mst0_aresetn),
    .slv0_srst       (mst0_srst),
    .slv0_awvalid    (mst0_awvalid),
    .slv0_awready    (mst0_awready),
    .slv0_awaddr     (mst0_awaddr),
    .slv0_awlen      (mst0_awlen),
    .slv0_awsize     (mst0_awsize),
    .slv0_awburst    (mst0_awburst),
    .slv0_awlock     (mst0_awlock),
    .slv0_awcache    (mst0_awcache),
    .slv0_awprot     (mst0_awprot),
    .slv0_awqos      (mst0_awqos),
    .slv0_awregion   (mst0_awregion),
    .slv0_awid       (mst0_awid),
    .slv0_awuser     (mst0_awuser),
    .slv0_wvalid     (mst0_wvalid),
    .slv0_wready     (mst0_wready),
    .slv0_wlast      (mst0_wlast),
    .slv0_wdata      (mst0_wdata),
    .slv0_wstrb      (mst0_wstrb),
    .slv0_wuser      (mst0_wuser),
    .slv0_bvalid     (mst0_bvalid),
    .slv0_bready     (mst0_bready),
    .slv0_bid        (mst0_bid),
    .slv0_bresp      (mst0_bresp),
    .slv0_buser      (mst0_buser),
    .slv0_arvalid    (mst0_arvalid),
    .slv0_arready    (mst0_arready),
    .slv0_araddr     (mst0_araddr),
    .slv0_arlen      (mst0_arlen),
    .slv0_arsize     (mst0_arsize),
    .slv0_arburst    (mst0_arburst),
    .slv0_arlock     (mst0_arlock),
    .slv0_arcache    (mst0_arcache),
    .slv0_arprot     (mst0_arprot),
    .slv0_arqos      (mst0_arqos),
    .slv0_arregion   (mst0_arregion),
    .slv0_arid       (mst0_arid),
    .slv0_aruser     (mst0_aruser),
    .slv0_rvalid     (mst0_rvalid),
    .slv0_rready     (mst0_rready),
    .slv0_rid        (mst0_rid),
    .slv0_rresp      (mst0_rresp),
    .slv0_rdata      (mst0_rdata),
    .slv0_rlast      (mst0_rlast),
    .slv0_ruser      (mst0_ruser),
    .slv1_aclk       (mst1_aclk),
    .slv1_aresetn    (mst1_aresetn),
    .slv1_srst       (mst1_srst),
    .slv1_awvalid    (mst1_awvalid),
    .slv1_awready    (mst1_awready),
    .slv1_awaddr     (mst1_awaddr),
    .slv1_awlen      (mst1_awlen),
    .slv1_awsize     (mst1_awsize),
    .slv1_awburst    (mst1_awburst),
    .slv1_awlock     (mst1_awlock),
    .slv1_awcache    (mst1_awcache),
    .slv1_awprot     (mst1_awprot),
    .slv1_awqos      (mst1_awqos),
    .slv1_awregion   (mst1_awregion),
    .slv1_awid       (mst1_awid),
    .slv1_awuser     (mst1_awuser),
    .slv1_wvalid     (mst1_wvalid),
    .slv1_wready     (mst1_wready),
    .slv1_wlast      (mst1_wlast),
    .slv1_wdata      (mst1_wdata),
    .slv1_wstrb      (mst1_wstrb),
    .slv1_wuser      (mst1_wuser),
    .slv1_bvalid     (mst1_bvalid),
    .slv1_bready     (mst1_bready),
    .slv1_bid        (mst1_bid),
    .slv1_bresp      (mst1_bresp),
    .slv1_buser      (mst1_buser),
    .slv1_arvalid    (mst1_arvalid),
    .slv1_arready    (mst1_arready),
    .slv1_araddr     (mst1_araddr),
    .slv1_arlen      (mst1_arlen),
    .slv1_arsize     (mst1_arsize),
    .slv1_arburst    (mst1_arburst),
    .slv1_arlock     (mst1_arlock),
    .slv1_arcache    (mst1_arcache),
    .slv1_arprot     (mst1_arprot),
    .slv1_arqos      (mst1_arqos),
    .slv1_arregion   (mst1_arregion),
    .slv1_arid       (mst1_arid),
    .slv1_aruser     (mst1_aruser),
    .slv1_rvalid     (mst1_rvalid),
    .slv1_rready     (mst1_rready),
    .slv1_rid        (mst1_rid),
    .slv1_rresp      (mst1_rresp),
    .slv1_rdata      (mst1_rdata),
    .slv1_rlast      (mst1_rlast),
    .slv1_ruser      (mst1_ruser),
    .slv2_aclk       (mst2_aclk),
    .slv2_aresetn    (mst2_aresetn),
    .slv2_srst       (mst2_srst),
    .slv2_awvalid    (mst2_awvalid),
    .slv2_awready    (mst2_awready),
    .slv2_awaddr     (mst2_awaddr),
    .slv2_awlen      (mst2_awlen),
    .slv2_awsize     (mst2_awsize),
    .slv2_awburst    (mst2_awburst),
    .slv2_awlock     (mst2_awlock),
    .slv2_awcache    (mst2_awcache),
    .slv2_awprot     (mst2_awprot),
    .slv2_awqos      (mst2_awqos),
    .slv2_awregion   (mst2_awregion),
    .slv2_awid       (mst2_awid),
    .slv2_awuser     (mst2_awuser),
    .slv2_wvalid     (mst2_wvalid),
    .slv2_wready     (mst2_wready),
    .slv2_wlast      (mst2_wlast),
    .slv2_wdata      (mst2_wdata),
    .slv2_wstrb      (mst2_wstrb),
    .slv2_wuser      (mst2_wuser),
    .slv2_bvalid     (mst2_bvalid),
    .slv2_bready     (mst2_bready),
    .slv2_bid        (mst2_bid),
    .slv2_bresp      (mst2_bresp),
    .slv2_buser      (mst2_buser),
    .slv2_arvalid    (mst2_arvalid),
    .slv2_arready    (mst2_arready),
    .slv2_araddr     (mst2_araddr),
    .slv2_arlen      (mst2_arlen),
    .slv2_arsize     (mst2_arsize),
    .slv2_arburst    (mst2_arburst),
    .slv2_arlock     (mst2_arlock),
    .slv2_arcache    (mst2_arcache),
    .slv2_arprot     (mst2_arprot),
    .slv2_arqos      (mst2_arqos),
    .slv2_arregion   (mst2_arregion),
    .slv2_arid       (mst2_arid),
    .slv2_aruser     (mst2_aruser),
    .slv2_rvalid     (mst2_rvalid),
    .slv2_rready     (mst2_rready),
    .slv2_rid        (mst2_rid),
    .slv2_rresp      (mst2_rresp),
    .slv2_rdata      (mst2_rdata),
    .slv2_rlast      (mst2_rlast),
    .slv2_ruser      (mst2_ruser),
    .slv3_aclk       (mst3_aclk),
    .slv3_aresetn    (mst3_aresetn),
    .slv3_srst       (mst3_srst),
    .slv3_awvalid    (mst3_awvalid),
    .slv3_awready    (mst3_awready),
    .slv3_awaddr     (mst3_awaddr),
    .slv3_awlen      (mst3_awlen),
    .slv3_awsize     (mst3_awsize),
    .slv3_awburst    (mst3_awburst),
    .slv3_awlock     (mst3_awlock),
    .slv3_awcache    (mst3_awcache),
    .slv3_awprot     (mst3_awprot),
    .slv3_awqos      (mst3_awqos),
    .slv3_awregion   (mst3_awregion),
    .slv3_awid       (mst3_awid),
    .slv3_awuser     (mst3_awuser),
    .slv3_wvalid     (mst3_wvalid),
    .slv3_wready     (mst3_wready),
    .slv3_wlast      (mst3_wlast),
    .slv3_wdata      (mst3_wdata),
    .slv3_wstrb      (mst3_wstrb),
    .slv3_wuser      (mst3_wuser),
    .slv3_bvalid     (mst3_bvalid),
    .slv3_bready     (mst3_bready),
    .slv3_bid        (mst3_bid),
    .slv3_bresp      (mst3_bresp),
    .slv3_buser      (mst3_buser),
    .slv3_arvalid    (mst3_arvalid),
    .slv3_arready    (mst3_arready),
    .slv3_araddr     (mst3_araddr),
    .slv3_arlen      (mst3_arlen),
    .slv3_arsize     (mst3_arsize),
    .slv3_arburst    (mst3_arburst),
    .slv3_arlock     (mst3_arlock),
    .slv3_arcache    (mst3_arcache),
    .slv3_arprot     (mst3_arprot),
    .slv3_arqos      (mst3_arqos),
    .slv3_arregion   (mst3_arregion),
    .slv3_arid       (mst3_arid),
    .slv3_aruser     (mst3_aruser),
    .slv3_rvalid     (mst3_rvalid),
    .slv3_rready     (mst3_rready),
    .slv3_rid        (mst3_rid),
    .slv3_rresp      (mst3_rresp),
    .slv3_rdata      (mst3_rdata),
    .slv3_rlast      (mst3_rlast),
    .slv3_ruser      (mst3_ruser),
    .mst0_aclk       (slv0_aclk),
    .mst0_aresetn    (slv0_aresetn),
    .mst0_srst       (slv0_srst),
    .mst0_awvalid    (slv0_awvalid),
    .mst0_awready    (slv0_awready),
    .mst0_awaddr     (slv0_awaddr),
    .mst0_awlen      (slv0_awlen),
    .mst0_awsize     (slv0_awsize),
    .mst0_awburst    (slv0_awburst),
    .mst0_awlock     (slv0_awlock),
    .mst0_awcache    (slv0_awcache),
    .mst0_awprot     (slv0_awprot),
    .mst0_awqos      (slv0_awqos),
    .mst0_awregion   (slv0_awregion),
    .mst0_awid       (slv0_awid),
    .mst0_awuser     (slv0_awuser),
    .mst0_wvalid     (slv0_wvalid),
    .mst0_wready     (slv0_wready),
    .mst0_wlast      (slv0_wlast),
    .mst0_wdata      (slv0_wdata),
    .mst0_wstrb      (slv0_wstrb),
    .mst0_wuser      (slv0_wuser),
    .mst0_bvalid     (slv0_bvalid),
    .mst0_bready     (slv0_bready),
    .mst0_bid        (slv0_bid),
    .mst0_bresp      (slv0_bresp),
    .mst0_buser      (slv0_buser),
    .mst0_arvalid    (slv0_arvalid),
    .mst0_arready    (slv0_arready),
    .mst0_araddr     (slv0_araddr),
    .mst0_arlen      (slv0_arlen),
    .mst0_arsize     (slv0_arsize),
    .mst0_arburst    (slv0_arburst),
    .mst0_arlock     (slv0_arlock),
    .mst0_arcache    (slv0_arcache),
    .mst0_arprot     (slv0_arprot),
    .mst0_arqos      (slv0_arqos),
    .mst0_arregion   (slv0_arregion),
    .mst0_arid       (slv0_arid),
    .mst0_aruser     (slv0_aruser),
    .mst0_rvalid     (slv0_rvalid),
    .mst0_rready     (slv0_rready),
    .mst0_rid        (slv0_rid),
    .mst0_rresp      (slv0_rresp),
    .mst0_rdata      (slv0_rdata),
    .mst0_rlast      (slv0_rlast),
    .mst0_ruser      (slv0_ruser),
    .mst1_aclk       (slv1_aclk),
    .mst1_aresetn    (slv1_aresetn),
    .mst1_srst       (slv1_srst),
    .mst1_awvalid    (slv1_awvalid),
    .mst1_awready    (slv1_awready),
    .mst1_awaddr     (slv1_awaddr),
    .mst1_awlen      (slv1_awlen),
    .mst1_awsize     (slv1_awsize),
    .mst1_awburst    (slv1_awburst),
    .mst1_awlock     (slv1_awlock),
    .mst1_awcache    (slv1_awcache),
    .mst1_awprot     (slv1_awprot),
    .mst1_awqos      (slv1_awqos),
    .mst1_awregion   (slv1_awregion),
    .mst1_awid       (slv1_awid),
    .mst1_awuser     (slv1_awuser),
    .mst1_wvalid     (slv1_wvalid),
    .mst1_wready     (slv1_wready),
    .mst1_wlast      (slv1_wlast),
    .mst1_wdata      (slv1_wdata),
    .mst1_wstrb      (slv1_wstrb),
    .mst1_wuser      (slv1_wuser),
    .mst1_bvalid     (slv1_bvalid),
    .mst1_bready     (slv1_bready),
    .mst1_bid        (slv1_bid),
    .mst1_buser      (slv1_buser),
    .mst1_bresp      (slv1_bresp),
    .mst1_arvalid    (slv1_arvalid),
    .mst1_arready    (slv1_arready),
    .mst1_araddr     (slv1_araddr),
    .mst1_arlen      (slv1_arlen),
    .mst1_arsize     (slv1_arsize),
    .mst1_arburst    (slv1_arburst),
    .mst1_arlock     (slv1_arlock),
    .mst1_arcache    (slv1_arcache),
    .mst1_arprot     (slv1_arprot),
    .mst1_arqos      (slv1_arqos),
    .mst1_arregion   (slv1_arregion),
    .mst1_arid       (slv1_arid),
    .mst1_aruser     (slv1_aruser),
    .mst1_rvalid     (slv1_rvalid),
    .mst1_rready     (slv1_rready),
    .mst1_rid        (slv1_rid),
    .mst1_rresp      (slv1_rresp),
    .mst1_rdata      (slv1_rdata),
    .mst1_rlast      (slv1_rlast),
    .mst1_ruser      (slv1_ruser),
    .mst2_aclk       (slv2_aclk),
    .mst2_aresetn    (slv2_aresetn),
    .mst2_srst       (slv2_srst),
    .mst2_awvalid    (slv2_awvalid),
    .mst2_awready    (slv2_awready),
    .mst2_awaddr     (slv2_awaddr),
    .mst2_awlen      (slv2_awlen),
    .mst2_awsize     (slv2_awsize),
    .mst2_awburst    (slv2_awburst),
    .mst2_awlock     (slv2_awlock),
    .mst2_awcache    (slv2_awcache),
    .mst2_awprot     (slv2_awprot),
    .mst2_awqos      (slv2_awqos),
    .mst2_awregion   (slv2_awregion),
    .mst2_awid       (slv2_awid),
    .mst2_awuser     (slv2_awuser),
    .mst2_wvalid     (slv2_wvalid),
    .mst2_wready     (slv2_wready),
    .mst2_wlast      (slv2_wlast),
    .mst2_wdata      (slv2_wdata),
    .mst2_wstrb      (slv2_wstrb),
    .mst2_wuser      (slv2_wuser),
    .mst2_bvalid     (slv2_bvalid),
    .mst2_bready     (slv2_bready),
    .mst2_bid        (slv2_bid),
    .mst2_bresp      (slv2_bresp),
    .mst2_buser      (slv2_buser),
    .mst2_arvalid    (slv2_arvalid),
    .mst2_arready    (slv2_arready),
    .mst2_araddr     (slv2_araddr),
    .mst2_arlen      (slv2_arlen),
    .mst2_arsize     (slv2_arsize),
    .mst2_arburst    (slv2_arburst),
    .mst2_arlock     (slv2_arlock),
    .mst2_arcache    (slv2_arcache),
    .mst2_arprot     (slv2_arprot),
    .mst2_arqos      (slv2_arqos),
    .mst2_arregion   (slv2_arregion),
    .mst2_arid       (slv2_arid),
    .mst2_aruser     (slv2_aruser),
    .mst2_rvalid     (slv2_rvalid),
    .mst2_rready     (slv2_rready),
    .mst2_rid        (slv2_rid),
    .mst2_rresp      (slv2_rresp),
    .mst2_rdata      (slv2_rdata),
    .mst2_rlast      (slv2_rlast),
    .mst2_ruser      (slv2_ruser),
    .mst3_aclk       (slv3_aclk),
    .mst3_aresetn    (slv3_aresetn),
    .mst3_srst       (slv3_srst),
    .mst3_awvalid    (slv3_awvalid),
    .mst3_awready    (slv3_awready),
    .mst3_awaddr     (slv3_awaddr),
    .mst3_awlen      (slv3_awlen),
    .mst3_awsize     (slv3_awsize),
    .mst3_awburst    (slv3_awburst),
    .mst3_awlock     (slv3_awlock),
    .mst3_awcache    (slv3_awcache),
    .mst3_awprot     (slv3_awprot),
    .mst3_awqos      (slv3_awqos),
    .mst3_awregion   (slv3_awregion),
    .mst3_awid       (slv3_awid),
    .mst3_awuser     (slv3_awuser),
    .mst3_wvalid     (slv3_wvalid),
    .mst3_wready     (slv3_wready),
    .mst3_wlast      (slv3_wlast),
    .mst3_wdata      (slv3_wdata),
    .mst3_wstrb      (slv3_wstrb),
    .mst3_wuser      (slv3_wuser),
    .mst3_bvalid     (slv3_bvalid),
    .mst3_bready     (slv3_bready),
    .mst3_bid        (slv3_bid),
    .mst3_bresp      (slv3_bresp),
    .mst3_buser      (slv3_buser),
    .mst3_arvalid    (slv3_arvalid),
    .mst3_arready    (slv3_arready),
    .mst3_araddr     (slv3_araddr),
    .mst3_arlen      (slv3_arlen),
    .mst3_arsize     (slv3_arsize),
    .mst3_arburst    (slv3_arburst),
    .mst3_arlock     (slv3_arlock),
    .mst3_arcache    (slv3_arcache),
    .mst3_arprot     (slv3_arprot),
    .mst3_arqos      (slv3_arqos),
    .mst3_arregion   (slv3_arregion),
    .mst3_arid       (slv3_arid),
    .mst3_aruser     (slv3_aruser),
    .mst3_rvalid     (slv3_rvalid),
    .mst3_rready     (slv3_rready),
    .mst3_rid        (slv3_rid),
    .mst3_rresp      (slv3_rresp),
    .mst3_rdata      (slv3_rdata),
    .mst3_rlast      (slv3_rlast),
    .mst3_ruser      (slv3_ruser)
    );


    mst_driver
    #(
    .AXI_ADDR_W      (AXI_ADDR_W),
    .AXI_ID_W        (AXI_ID_W),
    .AXI_DATA_W      (AXI_DATA_W),
    .MST_ID          (MST0_ID_MASK),
    .MST_OSTDREQ_NUM (16),
    .AXI_SIGNALING   (AXI_SIGNALING),
    .USER_SUPPORT    (USER_SUPPORT),
    .AXI_AUSER_W     (AXI_AUSER_W),
    .AXI_WUSER_W     (AXI_WUSER_W),
    .AXI_BUSER_W     (AXI_BUSER_W),
    .AXI_RUSER_W     (AXI_RUSER_W),
    .MST_ROUTES      (MST0_ROUTES),
    .SLV0_START_ADDR (SLV0_START_ADDR),
    .SLV0_END_ADDR   (SLV0_END_ADDR),
    .SLV1_START_ADDR (SLV1_START_ADDR),
    .SLV1_END_ADDR   (SLV1_END_ADDR),
    .SLV2_START_ADDR (SLV2_START_ADDR),
    .SLV2_END_ADDR   (SLV2_END_ADDR),
    .SLV3_START_ADDR (SLV3_START_ADDR),
    .SLV3_END_ADDR   (SLV3_END_ADDR),
    .CHECK_REPORT    (CHECK_REPORT),
    .TIMEOUT         (`OR_TIMEOUT),
    .KEY             ('hCCCCCCCC)
    )
    mst_driver0
    (
    .aclk     (mst0_aclk),
    .aresetn  (mst0_aresetn),
    .srst     (mst0_srst),
    .en       (mst_en[0]),
    .addr_min (addr_min),
    .addr_max (addr_max),
    .error    (error[0]),
    .awvalid  (mst0_awvalid),
    .awready  (mst0_awready),
    .awaddr   (mst0_awaddr),
    .awlen    (mst0_awlen),
    .awsize   (mst0_awsize),
    .awburst  (mst0_awburst),
    .awlock   (mst0_awlock),
    .awcache  (mst0_awcache),
    .awprot   (mst0_awprot),
    .awqos    (mst0_awqos),
    .awregion (mst0_awregion),
    .awid     (mst0_awid),
    .awuser   (mst0_awuser),
    .wvalid   (mst0_wvalid),
    .wready   (mst0_wready),
    .wlast    (mst0_wlast),
    .wdata    (mst0_wdata),
    .wstrb    (mst0_wstrb),
    .wuser    (mst0_wuser),
    .bvalid   (mst0_bvalid),
    .bready   (mst0_bready),
    .bid      (mst0_bid),
    .bresp    (mst0_bresp),
    .buser    (mst0_buser),
    .arvalid  (mst0_arvalid),
    .arready  (mst0_arready),
    .araddr   (mst0_araddr),
    .arlen    (mst0_arlen),
    .arsize   (mst0_arsize),
    .arburst  (mst0_arburst),
    .arlock   (mst0_arlock),
    .arcache  (mst0_arcache),
    .arprot   (mst0_arprot),
    .arqos    (mst0_arqos),
    .arregion (mst0_arregion),
    .arid     (mst0_arid),
    .aruser   (mst0_aruser),
    .rvalid   (mst0_rvalid),
    .rready   (mst0_rready),
    .rid      (mst0_rid),
    .rresp    (mst0_rresp),
    .rdata    (mst0_rdata),
    .rlast    (mst0_rlast),
    .ruser    (mst0_ruser)
    );

    mst_driver
    #(
    .AXI_ADDR_W      (AXI_ADDR_W),
    .AXI_ID_W        (AXI_ID_W),
    .AXI_DATA_W      (AXI_DATA_W),
    .MST_ID          (MST1_ID_MASK),
    .MST_OSTDREQ_NUM (16),
    .AXI_SIGNALING   (AXI_SIGNALING),
    .USER_SUPPORT    (USER_SUPPORT),
    .AXI_AUSER_W     (AXI_AUSER_W),
    .AXI_WUSER_W     (AXI_WUSER_W),
    .AXI_BUSER_W     (AXI_BUSER_W),
    .AXI_RUSER_W     (AXI_RUSER_W),
    .CHECK_REPORT    (CHECK_REPORT),
    .MST_ROUTES      (MST1_ROUTES),
    .SLV0_START_ADDR (SLV0_START_ADDR),
    .SLV0_END_ADDR   (SLV0_END_ADDR),
    .SLV1_START_ADDR (SLV1_START_ADDR),
    .SLV1_END_ADDR   (SLV1_END_ADDR),
    .SLV2_START_ADDR (SLV2_START_ADDR),
    .SLV2_END_ADDR   (SLV2_END_ADDR),
    .SLV3_START_ADDR (SLV3_START_ADDR),
    .SLV3_END_ADDR   (SLV3_END_ADDR),
    .TIMEOUT         (`OR_TIMEOUT),
    .KEY             ('hEEEEEEEE)
    )
    mst_driver1
    (
    .aclk     (mst1_aclk),
    .aresetn  (mst1_aresetn),
    .srst     (mst1_srst),
    .en       (mst_en[1]),
    .addr_min (addr_min),
    .addr_max (addr_max),
    .error    (error[1]),
    .awvalid  (mst1_awvalid),
    .awready  (mst1_awready),
    .awaddr   (mst1_awaddr),
    .awlen    (mst1_awlen),
    .awsize   (mst1_awsize),
    .awburst  (mst1_awburst),
    .awlock   (mst1_awlock),
    .awcache  (mst1_awcache),
    .awprot   (mst1_awprot),
    .awqos    (mst1_awqos),
    .awregion (mst1_awregion),
    .awid     (mst1_awid),
    .awuser   (mst1_awuser),
    .wvalid   (mst1_wvalid),
    .wready   (mst1_wready),
    .wlast    (mst1_wlast),
    .wdata    (mst1_wdata),
    .wstrb    (mst1_wstrb),
    .wuser    (mst1_wuser),
    .bvalid   (mst1_bvalid),
    .bready   (mst1_bready),
    .bid      (mst1_bid),
    .bresp    (mst1_bresp),
    .buser    (mst1_buser),
    .arvalid  (mst1_arvalid),
    .arready  (mst1_arready),
    .araddr   (mst1_araddr),
    .arlen    (mst1_arlen),
    .arsize   (mst1_arsize),
    .arburst  (mst1_arburst),
    .arlock   (mst1_arlock),
    .arcache  (mst1_arcache),
    .arprot   (mst1_arprot),
    .arqos    (mst1_arqos),
    .arregion (mst1_arregion),
    .arid     (mst1_arid),
    .aruser   (mst1_aruser),
    .rvalid   (mst1_rvalid),
    .rready   (mst1_rready),
    .rid      (mst1_rid),
    .rresp    (mst1_rresp),
    .rdata    (mst1_rdata),
    .rlast    (mst1_rlast),
    .ruser    (mst1_ruser)
    );

    mst_driver
    #(
    .AXI_ADDR_W      (AXI_ADDR_W),
    .AXI_ID_W        (AXI_ID_W),
    .AXI_DATA_W      (AXI_DATA_W),
    .MST_ID          (MST2_ID_MASK),
    .MST_OSTDREQ_NUM (16),
    .AXI_SIGNALING   (AXI_SIGNALING),
    .USER_SUPPORT    (USER_SUPPORT),
    .AXI_AUSER_W     (AXI_AUSER_W),
    .AXI_WUSER_W     (AXI_WUSER_W),
    .AXI_BUSER_W     (AXI_BUSER_W),
    .AXI_RUSER_W     (AXI_RUSER_W),
    .CHECK_REPORT    (CHECK_REPORT),
    .MST_ROUTES      (MST2_ROUTES),
    .SLV0_START_ADDR (SLV0_START_ADDR),
    .SLV0_END_ADDR   (SLV0_END_ADDR),
    .SLV1_START_ADDR (SLV1_START_ADDR),
    .SLV1_END_ADDR   (SLV1_END_ADDR),
    .SLV2_START_ADDR (SLV2_START_ADDR),
    .SLV2_END_ADDR   (SLV2_END_ADDR),
    .SLV3_START_ADDR (SLV3_START_ADDR),
    .SLV3_END_ADDR   (SLV3_END_ADDR),
    .TIMEOUT         (`OR_TIMEOUT),
    .KEY             ('hAAAAAAAA)
    )
    mst_driver2
    (
    .aclk     (mst2_aclk),
    .aresetn  (mst2_aresetn),
    .srst     (mst2_srst),
    .en       (mst_en[2]),
    .addr_min (addr_min),
    .addr_max (addr_max),
    .error    (error[2]),
    .awvalid  (mst2_awvalid),
    .awready  (mst2_awready),
    .awaddr   (mst2_awaddr),
    .awlen    (mst2_awlen),
    .awsize   (mst2_awsize),
    .awburst  (mst2_awburst),
    .awlock   (mst2_awlock),
    .awcache  (mst2_awcache),
    .awprot   (mst2_awprot),
    .awqos    (mst2_awqos),
    .awregion (mst2_awregion),
    .awid     (mst2_awid),
    .awuser   (mst2_awuser),
    .wvalid   (mst2_wvalid),
    .wready   (mst2_wready),
    .wlast    (mst2_wlast),
    .wdata    (mst2_wdata),
    .wstrb    (mst2_wstrb),
    .wuser    (mst2_wuser),
    .bvalid   (mst2_bvalid),
    .bready   (mst2_bready),
    .bid      (mst2_bid),
    .bresp    (mst2_bresp),
    .buser    (mst2_buser),
    .arvalid  (mst2_arvalid),
    .arready  (mst2_arready),
    .araddr   (mst2_araddr),
    .arlen    (mst2_arlen),
    .arsize   (mst2_arsize),
    .arburst  (mst2_arburst),
    .arlock   (mst2_arlock),
    .arcache  (mst2_arcache),
    .arprot   (mst2_arprot),
    .arqos    (mst2_arqos),
    .arregion (mst2_arregion),
    .arid     (mst2_arid),
    .aruser   (mst2_aruser),
    .rvalid   (mst2_rvalid),
    .rready   (mst2_rready),
    .rid      (mst2_rid),
    .rresp    (mst2_rresp),
    .rdata    (mst2_rdata),
    .rlast    (mst2_rlast),
    .ruser    (mst2_ruser)
    );

    mst_driver
    #(
    .AXI_ADDR_W      (AXI_ADDR_W),
    .AXI_ID_W        (AXI_ID_W),
    .AXI_DATA_W      (AXI_DATA_W),
    .MST_ID          (MST3_ID_MASK),
    .MST_OSTDREQ_NUM (16),
    .AXI_SIGNALING   (AXI_SIGNALING),
    .USER_SUPPORT    (USER_SUPPORT),
    .AXI_AUSER_W     (AXI_AUSER_W),
    .AXI_WUSER_W     (AXI_WUSER_W),
    .AXI_BUSER_W     (AXI_BUSER_W),
    .AXI_RUSER_W     (AXI_RUSER_W),
    .CHECK_REPORT    (CHECK_REPORT),
    .MST_ROUTES      (MST3_ROUTES),
    .SLV0_START_ADDR (SLV0_START_ADDR),
    .SLV0_END_ADDR   (SLV0_END_ADDR),
    .SLV1_START_ADDR (SLV1_START_ADDR),
    .SLV1_END_ADDR   (SLV1_END_ADDR),
    .SLV2_START_ADDR (SLV2_START_ADDR),
    .SLV2_END_ADDR   (SLV2_END_ADDR),
    .SLV3_START_ADDR (SLV3_START_ADDR),
    .SLV3_END_ADDR   (SLV3_END_ADDR),
    .TIMEOUT         (`OR_TIMEOUT),
    .KEY             ('h55555555)
    )
    mst_driver3
    (
    .aclk     (mst3_aclk),
    .aresetn  (mst3_aresetn),
    .srst     (mst3_srst),
    .en       (mst_en[3]),
    .addr_min (addr_min),
    .addr_max (addr_max),
    .error    (error[3]),
    .awvalid  (mst3_awvalid),
    .awready  (mst3_awready),
    .awaddr   (mst3_awaddr),
    .awlen    (mst3_awlen),
    .awsize   (mst3_awsize),
    .awburst  (mst3_awburst),
    .awlock   (mst3_awlock),
    .awcache  (mst3_awcache),
    .awprot   (mst3_awprot),
    .awqos    (mst3_awqos),
    .awregion (mst3_awregion),
    .awid     (mst3_awid),
    .awuser   (mst3_awuser),
    .wvalid   (mst3_wvalid),
    .wready   (mst3_wready),
    .wlast    (mst3_wlast),
    .wdata    (mst3_wdata),
    .wstrb    (mst3_wstrb),
    .wuser    (mst3_wuser),
    .bvalid   (mst3_bvalid),
    .bready   (mst3_bready),
    .bid      (mst3_bid),
    .bresp    (mst3_bresp),
    .buser    (mst3_buser),
    .arvalid  (mst3_arvalid),
    .arready  (mst3_arready),
    .araddr   (mst3_araddr),
    .arlen    (mst3_arlen),
    .arsize   (mst3_arsize),
    .arburst  (mst3_arburst),
    .arlock   (mst3_arlock),
    .arcache  (mst3_arcache),
    .arprot   (mst3_arprot),
    .arqos    (mst3_arqos),
    .arregion (mst3_arregion),
    .arid     (mst3_arid),
    .aruser   (mst3_aruser),
    .rvalid   (mst3_rvalid),
    .rready   (mst3_rready),
    .rid      (mst3_rid),
    .rresp    (mst3_rresp),
    .rdata    (mst3_rdata),
    .rlast    (mst3_rlast),
    .ruser    (mst3_ruser)
    );


    slv_monitor
    #(
    .SLV_ID         (0),
    .AXI_ADDR_W     (AXI_ADDR_W),
    .AXI_ID_W       (AXI_ID_W),
    .AXI_DATA_W     (AXI_DATA_W),
    .CHECK_REPORT   (CHECK_REPORT),
    .AXI_SIGNALING  (AXI_SIGNALING),
    .USER_SUPPORT   (USER_SUPPORT),
    .AXI_AUSER_W    (AXI_AUSER_W),
    .AXI_WUSER_W    (AXI_WUSER_W),
    .AXI_BUSER_W    (AXI_BUSER_W),
    .AXI_RUSER_W    (AXI_RUSER_W),
    .SLV_ADDR       (SLV0_START_ADDR),
    .TIMEOUT        (`OR_TIMEOUT),
    .KEY            ('hABCDEF0)
    )
    slv_monitor0
    (
    .aclk     (slv0_aclk),
    .aresetn  (slv0_aresetn),
    .srst     (slv0_srst),
    .error    (error[4]),
    .awvalid  (slv0_awvalid),
    .awready  (slv0_awready),
    .awaddr   (slv0_awaddr),
    .awlen    (slv0_awlen),
    .awsize   (slv0_awsize),
    .awburst  (slv0_awburst),
    .awlock   (slv0_awlock),
    .awcache  (slv0_awcache),
    .awprot   (slv0_awprot),
    .awqos    (slv0_awqos),
    .awregion (slv0_awregion),
    .awid     (slv0_awid),
    .awuser   (slv0_awuser),
    .wvalid   (slv0_wvalid),
    .wready   (slv0_wready),
    .wlast    (slv0_wlast),
    .wdata    (slv0_wdata),
    .wstrb    (slv0_wstrb),
    .wuser    (slv0_wuser),
    .bvalid   (slv0_bvalid),
    .bready   (slv0_bready),
    .bid      (slv0_bid),
    .bresp    (slv0_bresp),
    .buser    (slv0_buser),
    .arvalid  (slv0_arvalid),
    .arready  (slv0_arready),
    .araddr   (slv0_araddr),
    .arlen    (slv0_arlen),
    .arsize   (slv0_arsize),
    .arburst  (slv0_arburst),
    .arlock   (slv0_arlock),
    .arcache  (slv0_arcache),
    .arprot   (slv0_arprot),
    .arqos    (slv0_arqos),
    .arregion (slv0_arregion),
    .arid     (slv0_arid),
    .aruser   (slv0_aruser),
    .rvalid   (slv0_rvalid),
    .rready   (slv0_rready),
    .rid      (slv0_rid),
    .rresp    (slv0_rresp),
    .rdata    (slv0_rdata),
    .rlast    (slv0_rlast),
    .ruser    (slv0_ruser)
    );

    slv_monitor
    #(
    .SLV_ID         (1),
    .AXI_ADDR_W     (AXI_ADDR_W),
    .AXI_ID_W       (AXI_ID_W),
    .AXI_DATA_W     (AXI_DATA_W),
    .CHECK_REPORT   (CHECK_REPORT),
    .AXI_SIGNALING  (AXI_SIGNALING),
    .USER_SUPPORT   (USER_SUPPORT),
    .AXI_AUSER_W    (AXI_AUSER_W),
    .AXI_WUSER_W    (AXI_WUSER_W),
    .AXI_BUSER_W    (AXI_BUSER_W),
    .AXI_RUSER_W    (AXI_RUSER_W),
    .SLV_ADDR       (SLV1_START_ADDR),
    .TIMEOUT        (`OR_TIMEOUT),
    .KEY            ('hA1C5EF0)
    )
    slv_monitor1
    (
    .aclk     (slv1_aclk),
    .aresetn  (slv1_aresetn),
    .srst     (slv1_srst),
    .error    (error[5]),
    .awvalid  (slv1_awvalid),
    .awready  (slv1_awready),
    .awaddr   (slv1_awaddr),
    .awlen    (slv1_awlen),
    .awsize   (slv1_awsize),
    .awburst  (slv1_awburst),
    .awlock   (slv1_awlock),
    .awcache  (slv1_awcache),
    .awprot   (slv1_awprot),
    .awqos    (slv1_awqos),
    .awregion (slv1_awregion),
    .awid     (slv1_awid),
    .awuser   (slv1_awuser),
    .wvalid   (slv1_wvalid),
    .wready   (slv1_wready),
    .wlast    (slv1_wlast),
    .wdata    (slv1_wdata),
    .wstrb    (slv1_wstrb),
    .wuser    (slv1_wuser),
    .bvalid   (slv1_bvalid),
    .bready   (slv1_bready),
    .bid      (slv1_bid),
    .bresp    (slv1_bresp),
    .buser    (slv1_buser),
    .arvalid  (slv1_arvalid),
    .arready  (slv1_arready),
    .araddr   (slv1_araddr),
    .arlen    (slv1_arlen),
    .arsize   (slv1_arsize),
    .arburst  (slv1_arburst),
    .arlock   (slv1_arlock),
    .arcache  (slv1_arcache),
    .arprot   (slv1_arprot),
    .arqos    (slv1_arqos),
    .arregion (slv1_arregion),
    .arid     (slv1_arid),
    .aruser   (slv1_aruser),
    .rvalid   (slv1_rvalid),
    .rready   (slv1_rready),
    .rid      (slv1_rid),
    .rresp    (slv1_rresp),
    .rdata    (slv1_rdata),
    .rlast    (slv1_rlast),
    .ruser    (slv1_ruser)
    );

    slv_monitor
    #(
    .SLV_ID         (2),
    .AXI_ADDR_W     (AXI_ADDR_W),
    .AXI_ID_W       (AXI_ID_W),
    .AXI_DATA_W     (AXI_DATA_W),
    .CHECK_REPORT   (CHECK_REPORT),
    .AXI_SIGNALING  (AXI_SIGNALING),
    .USER_SUPPORT   (USER_SUPPORT),
    .AXI_AUSER_W    (AXI_AUSER_W),
    .AXI_WUSER_W    (AXI_WUSER_W),
    .AXI_BUSER_W    (AXI_BUSER_W),
    .AXI_RUSER_W    (AXI_RUSER_W),
    .SLV_ADDR       (SLV2_START_ADDR),
    .TIMEOUT        (`OR_TIMEOUT),
    .KEY            ('hABCDEF5)
    )
    slv_monitor2
    (
    .aclk     (slv2_aclk),
    .aresetn  (slv2_aresetn),
    .srst     (slv2_srst),
    .error    (error[6]),
    .awvalid  (slv2_awvalid),
    .awready  (slv2_awready),
    .awaddr   (slv2_awaddr),
    .awlen    (slv2_awlen),
    .awsize   (slv2_awsize),
    .awburst  (slv2_awburst),
    .awlock   (slv2_awlock),
    .awcache  (slv2_awcache),
    .awprot   (slv2_awprot),
    .awqos    (slv2_awqos),
    .awregion (slv2_awregion),
    .awid     (slv2_awid),
    .awuser   (slv2_awuser),
    .wvalid   (slv2_wvalid),
    .wready   (slv2_wready),
    .wlast    (slv2_wlast),
    .wdata    (slv2_wdata),
    .wstrb    (slv2_wstrb),
    .wuser    (slv2_wuser),
    .bvalid   (slv2_bvalid),
    .bready   (slv2_bready),
    .bid      (slv2_bid),
    .bresp    (slv2_bresp),
    .buser    (slv2_buser),
    .arvalid  (slv2_arvalid),
    .arready  (slv2_arready),
    .araddr   (slv2_araddr),
    .arlen    (slv2_arlen),
    .arsize   (slv2_arsize),
    .arburst  (slv2_arburst),
    .arlock   (slv2_arlock),
    .arcache  (slv2_arcache),
    .arprot   (slv2_arprot),
    .arqos    (slv2_arqos),
    .arregion (slv2_arregion),
    .arid     (slv2_arid),
    .aruser   (slv2_aruser),
    .rvalid   (slv2_rvalid),
    .rready   (slv2_rready),
    .rid      (slv2_rid),
    .rresp    (slv2_rresp),
    .rdata    (slv2_rdata),
    .rlast    (slv2_rlast),
    .ruser    (slv2_ruser)
);

    slv_monitor
    #(
    .SLV_ID         (3),
    .AXI_ADDR_W     (AXI_ADDR_W),
    .AXI_ID_W       (AXI_ID_W),
    .AXI_DATA_W     (AXI_DATA_W),
    .CHECK_REPORT   (CHECK_REPORT),
    .AXI_SIGNALING  (AXI_SIGNALING),
    .USER_SUPPORT   (USER_SUPPORT),
    .AXI_AUSER_W    (AXI_AUSER_W),
    .AXI_WUSER_W    (AXI_WUSER_W),
    .AXI_BUSER_W    (AXI_BUSER_W),
    .AXI_RUSER_W    (AXI_RUSER_W),
    .SLV_ADDR       (SLV3_START_ADDR),
    .TIMEOUT        (`OR_TIMEOUT),
    .KEY            ('hADCDEF0)
    )
    slv_monitor3
    (
    .aclk     (slv3_aclk),
    .aresetn  (slv3_aresetn),
    .srst     (slv3_srst),
    .error    (error[7]),
    .awvalid  (slv3_awvalid),
    .awready  (slv3_awready),
    .awaddr   (slv3_awaddr),
    .awlen    (slv3_awlen),
    .awsize   (slv3_awsize),
    .awburst  (slv3_awburst),
    .awlock   (slv3_awlock),
    .awcache  (slv3_awcache),
    .awprot   (slv3_awprot),
    .awqos    (slv3_awqos),
    .awregion (slv3_awregion),
    .awid     (slv3_awid),
    .awuser   (slv3_awuser),
    .wvalid   (slv3_wvalid),
    .wready   (slv3_wready),
    .wlast    (slv3_wlast),
    .wdata    (slv3_wdata),
    .wstrb    (slv3_wstrb),
    .wuser    (slv3_wuser),
    .bvalid   (slv3_bvalid),
    .bready   (slv3_bready),
    .bid      (slv3_bid),
    .bresp    (slv3_bresp),
    .buser    (slv3_buser),
    .arvalid  (slv3_arvalid),
    .arready  (slv3_arready),
    .araddr   (slv3_araddr),
    .arlen    (slv3_arlen),
    .arsize   (slv3_arsize),
    .arburst  (slv3_arburst),
    .arlock   (slv3_arlock),
    .arcache  (slv3_arcache),
    .arprot   (slv3_arprot),
    .arqos    (slv3_arqos),
    .arregion (slv3_arregion),
    .arid     (slv3_arid),
    .aruser   (slv3_aruser),
    .rvalid   (slv3_rvalid),
    .rready   (slv3_rready),
    .rid      (slv3_rid),
    .rresp    (slv3_rresp),
    .rdata    (slv3_rdata),
    .rlast    (slv3_rlast),
    .ruser    (slv3_ruser)
);


    //////////////////////////////////////////////////////////////////////////
    // Testbench setup
    //////////////////////////////////////////////////////////////////////////

    // To create a clock:
    initial aclk = 0;
    initial mst0_aclk = 0;
    initial mst1_aclk = 0;
    initial mst2_aclk = 0;
    initial mst3_aclk = 0;
    initial slv0_aclk = 0;
    initial slv1_aclk = 0;
    initial slv2_aclk = 0;
    initial slv3_aclk = 0;

    always #2 aclk = ~aclk;
    always #2 mst0_aclk = ~mst0_aclk;
    always #2 mst1_aclk = ~mst1_aclk;
    always #2 mst2_aclk = ~mst2_aclk;
    always #2 mst3_aclk = ~mst3_aclk;
    always #2 slv0_aclk = ~slv0_aclk;
    always #2 slv1_aclk = ~slv1_aclk;
    always #2 slv2_aclk = ~slv2_aclk;
    always #2 slv3_aclk = ~slv3_aclk;

    `ifndef NOVCD
    // To dump data for visualization:
    initial begin
         $dumpfile("axicb_crossbar_top_testbench.vcd");
         $dumpvars(0, axicb_crossbar_top_testbench);
     end
    `endif

    // Setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        timeout = 0;
        nb_reqs = 0;
        addr_min = 0;
        addr_max = 128;
        srst = 0;
        aresetn = 0;
        mst0_aresetn = 0;
        mst0_srst = 0;
        mst1_aresetn = 0;
        mst1_srst = 0;
        mst2_aresetn = 0;
        mst2_srst = 0;
        mst3_aresetn = 0;
        mst3_srst = 0;
        slv0_aresetn = 0;
        slv0_srst = 0;
        slv1_aresetn = 0;
        slv1_srst = 0;
        slv2_aresetn = 0;
        slv2_srst = 0;
        slv3_aresetn = 0;
        slv3_srst = 0;
        mst_en = 4'b0;
        #100;
        aresetn = 1;
        mst0_aresetn = 1;
        mst1_aresetn = 1;
        mst2_aresetn = 1;
        mst3_aresetn = 1;
        slv0_aresetn = 1;
        slv1_aresetn = 1;
        slv2_aresetn = 1;
        slv3_aresetn = 1;
        repeat (10) @(posedge aclk);
    end
    endtask

    task teardown(msg="");
    begin
        mst_en = 'b0;
        repeat (20) @(posedge aclk);
    end
    endtask

    //////////////////////////////////////////////////////////////////////////
    // Monitor the execution to state if the testcase is successfull or not
    //////////////////////////////////////////////////////////////////////////
    task wait_end_of_execution();

        fork
        begin
            while (timeout<`TIMEOUT) begin
                @(posedge aclk);
                timeout = timeout + 1;
            end
            `ASSERT((timeout<`TIMEOUT), "Testcase reached timeout");
        end
        begin
            while (nb_reqs<`MAX_TRAFFIC) begin
                @(posedge aclk);
                if (mst0_bvalid && mst0_bready)
                    nb_reqs = nb_reqs + 1;
            end
            `INFO("Full traffic has been injected by the drivers");
        end
        begin

            while (error===8'b0) begin
                @(posedge aclk);
            end
            `ASSERT((error===8'b0), "Error detected during execution");
            $display("Errors: %x", error);
        end
        join_any

        disable fork;

    endtask


    // Format testsuite name to string
    initial begin
        $sformat(tsname, "%s", ``TSNAME);
    end

    initial begin
        $display("");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("");
        $display("Testbench Configuration:");
        $display("------------------------");
        $display("");
        $display("  - Configuration: %s", tsname);
        $display("  - Testbench timeout: %0d cycles", `TIMEOUT);
        $display("  - Outstanding request timeout: %0d cycles", `OR_TIMEOUT);
        $display("  - Maximum traffic: %0d", `MAX_TRAFFIC);
        $display("  - AXI_ADDR_W: %0d", `AXI_ADDR_W);
        $display("  - AXI_DATA_W: %0d", `AXI_DATA_W);
        $display("  - AXI_ID_W: %0d", `AXI_ID_W);
        $display("");
        $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        $display("");
    end

    //////////////////////////////////////////////////////////////////////////
    // Testsuite
    //////////////////////////////////////////////////////////////////////////

    `TEST_SUITE(tsname)


    `UNIT_TEST("Single Master Driver vs a Single Slave Monitor")

        addr_min = 0;
        addr_max = 4095;

        @(posedge aclk);
        mst_en = 4'h1;
        wait_end_of_execution();

    `UNIT_TEST_END

    `UNIT_TEST("Single Master Driver vs Two Slave Monitors")

        addr_min = 0;
        addr_max = 8191;

        @(posedge aclk);
        mst_en = 4'h1;
        wait_end_of_execution();

    `UNIT_TEST_END

    `UNIT_TEST("Two Master Drivers vs a Single Slave Monitor")

        addr_min = 0;
        addr_max = 4095;

        @(posedge aclk);
        mst_en = 4'h3;
        wait_end_of_execution();

    `UNIT_TEST_END

    `UNIT_TEST("Three Master Drivers vs a Single Slave Monitor")

        addr_min = 0;
        addr_max = 4095;

        @(posedge aclk);
        mst_en = 4'h7;
        wait_end_of_execution();

    `UNIT_TEST_END


    `UNIT_TEST("Four Master Drivers vs a Single Slave Monitor")

        addr_min = 0;
        addr_max = 4095;

        @(posedge aclk);
        mst_en = 4'hF;
        wait_end_of_execution();

    `UNIT_TEST_END

    `UNIT_TEST("Two Master Drivers vs Two Slave Monitors")

        addr_min = 0;
        addr_max = 8191;

        @(posedge aclk);
        mst_en = 4'h3;
        wait_end_of_execution();

    `UNIT_TEST_END

    `UNIT_TEST("Three Master Drivers vs Two Slave Monitors")

        addr_min = 0;
        addr_max = 8191;

        @(posedge aclk);
        mst_en = 4'h7;
        wait_end_of_execution();

    `UNIT_TEST_END

    `UNIT_TEST("Four Master Drivers vs Two Slave Monitors")

        addr_min = 0;
        addr_max = 8191;

        @(posedge aclk);
        mst_en = 4'hF;
        wait_end_of_execution();

    `UNIT_TEST_END

    `UNIT_TEST("Four Master Drivers vs Four Slave Monitors")

        addr_min = 0;
        addr_max = 16383;

        @(posedge aclk);
        mst_en = 4'hF;
        wait_end_of_execution();

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
