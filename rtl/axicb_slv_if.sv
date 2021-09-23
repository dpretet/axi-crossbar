// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_slv_if

    #(
        // Address width in bits
        parameter AXI_ADDR_W = 8,
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // STRB support:
        //   - 0: contiguous wstrb (store only 1st/last dataphase)
        //   - 1: full wstrb transport
        parameter STRB_MODE = 1,

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: Restricted AXI4 (INCR mode, ADDR, ALEN)
        //   - 2: Complete
        parameter AXI_SIGNALING = 0,

        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,

        // Input channels' width (concatenated)
        parameter AWCH_W = 8,
        parameter WCH_W = 8,
        parameter BCH_W = 8,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // input interface from switching logic
        input  logic                      i_aclk,
        input  logic                      i_aresetn,
        input  logic                      i_srst,
        input  logic                      i_awvalid,
        output logic                      i_awready,
        input  logic [AWCH_W        -1:0] i_awch,
        input  logic                      i_wvalid,
        output logic                      i_wready,
        input  logic                      i_wlast,
        input  logic [WCH_W         -1:0] i_wch,
        output logic                      i_bvalid,
        input  logic                      i_bready,
        output logic [BCH_W         -1:0] i_bch,
        input  logic                      i_arvalid,
        output logic                      i_arready,
        input  logic [ARCH_W        -1:0] i_arch,
        output logic                      i_rvalid,
        input  logic                      i_rready,
        output logic                      i_rlast,
        output logic [RCH_W         -1:0] i_rch,
        // output interface to external slave
        input  logic                      o_aclk,
        input  logic                      o_aresetn,
        input  logic                      o_srst,
        output logic                      o_awvalid,
        input  logic                      o_awready,
        output logic [AXI_ADDR_W    -1:0] o_awaddr,
        output logic [8             -1:0] o_awlen,
        output logic [3             -1:0] o_awsize,
        output logic [2             -1:0] o_awburst,
        output logic [2             -1:0] o_awlock,
        output logic [4             -1:0] o_awcache,
        output logic [3             -1:0] o_awprot,
        output logic [4             -1:0] o_awqos,
        output logic [4             -1:0] o_awregion,
        output logic [AXI_ID_W      -1:0] o_awid,
        output logic                      o_wvalid,
        input  logic                      o_wready,
        output logic                      o_wlast,
        output logic [AXI_DATA_W    -1:0] o_wdata,
        output logic [AXI_DATA_W/8  -1:0] o_wstrb,
        input  logic                      o_bvalid,
        output logic                      o_bready,
        input  logic [AXI_ID_W      -1:0] o_bid,
        input  logic [2             -1:0] o_bresp,
        output logic                      o_arvalid,
        input  logic                      o_arready,
        output logic [AXI_ADDR_W    -1:0] o_araddr,
        output logic [8             -1:0] o_arlen,
        output logic [3             -1:0] o_arsize,
        output logic [2             -1:0] o_arburst,
        output logic [2             -1:0] o_arlock,
        output logic [4             -1:0] o_arcache,
        output logic [3             -1:0] o_arprot,
        output logic [4             -1:0] o_arqos,
        output logic [4             -1:0] o_arregion,
        output logic [AXI_ID_W      -1:0] o_arid,
        input  logic                      o_rvalid,
        output logic                      o_rready,
        input  logic [AXI_ID_W      -1:0] o_rid,
        input  logic [2             -1:0] o_rresp,
        input  logic [AXI_DATA_W    -1:0] o_rdata,
        input  logic                      o_rlast
    );


    generate 
    if (AXI_SIGNALING==0) begin : AXI4LITE_MODE

        assign {
            o_awid,
            o_awprot,
            o_awaddr
        } = i_awch;

        assign {
            o_arid,
            o_arprot,
            o_araddr
        }  = i_arch;

    end else if (AXI_SIGNALING==1) begin : AXI4LITE_BURST_MODE

        assign {
            o_awid,
            o_awprot,
            o_awlen,
            o_awaddr
        } = i_awch;

        assign {
            o_arid,
            o_arprot,
            o_arlen,
            o_araddr
        } = i_arch;

    end else begin : AXI4_MODE

        assign {
            o_awid,
            o_awregion,
            o_awqos,
            o_awprot,
            o_awcache,
            o_awlock,
            o_awburst,
            o_awsize,
            o_awlen,
            o_awaddr
        } = i_awch;

        assign {
            o_arid,
            o_arregion,
            o_arqos,
            o_arprot,
            o_arcache,
            o_arlock,
            o_arburst,
            o_arsize,
            o_arlen,
            o_araddr
        } = i_arch;

    end
    endgenerate

    assign o_awvalid = i_awvalid;
    assign i_awready = o_awready;

    assign o_wvalid = i_wvalid;
    assign i_wready = o_wready;
    assign o_wlast = i_wlast;

    assign {o_wstrb, o_wdata} = i_wch;

    assign i_bvalid = o_bvalid;
    assign o_bready = i_bready;
    assign i_bch = {o_bresp, o_bid};

    assign o_arvalid = i_arvalid;
    assign i_arready = o_arready;

    assign i_rvalid = o_rvalid;
    assign o_rready = i_rready;
    assign i_rlast = o_rlast;
    assign i_rch = {o_rresp, o_rid, o_rdata};

endmodule

`resetall

