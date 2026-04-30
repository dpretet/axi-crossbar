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
        parameter AXI_ADDR_W = {{ global.AXI_ADDR_W }},
        // ID width in bits
        parameter AXI_ID_W = {{ global.AXI_ID_W }},
        // Data width in bits
        parameter AXI_DATA_W = {{ global.AXI_DATA_W }},

        // Number of master(s)
        parameter MST_NB = {{ global.MST_NB }},
        // Number of slave(s)
        parameter SLV_NB = {{ global.SLV_NB }},

        // Maximum number of Outstanding Request bit width
        parameter OR_NUM_W = {{ global.OR_NUM_W }},

        // Switching logic pipelining (0 deactivate, 1 enable)
        parameter MST_PIPELINE = {{ global.MST_PIPELINE }},
        parameter SLV_PIPELINE = {{ global.SLV_PIPELINE }},

        // USER fields transport enabling (0 deactivate, 1 activate)
        parameter USER_SUPPORT = {{ global.USER_SUPPORT }},
        // USER fields width in bits
        parameter AXI_AUSER_W = {{ global.AXI_AUSER_W }},
        parameter AXI_WUSER_W = {{ global.AXI_WUSER_W }},
        parameter AXI_BUSER_W = {{ global.AXI_BUSER_W }},
        parameter AXI_RUSER_W = {{ global.AXI_RUSER_W }},

        // Timeout configuration in clock cycles, applied to all channels
        parameter TIMEOUT_VALUE = {{ global.TIMEOUT_VALUE }},
        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = {{ global.TIMEOUT_ENABLE }},

        // Maximum number of priority in Round-Robin for Masters selections
        parameter NUM_PRIORITY_LVL = {{ global.NUM_PRIORITY_LVL }},

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
        //   - MSTx_RW: Select if the interface is
        //         - Read/Write (=0)
        //         - Read-only (=1)
        //         - Write-only (=2)
        //
        // The size of a master's internal buffer is equal to:
        //
        // SIZE = AXI_DATA_W * MSTx_OSTDREQ_NUM * MSTx_OSTDREQ_SIZE (in bits)
        //
        ///////////////////////////////////////////////////////////////////////

        {%- for mst in masters %}

        ///////////////////////////////////////////////////////////////////////
        // Master {{ loop.index0 }} configuration
        ///////////////////////////////////////////////////////////////////////

        parameter MST{{ loop.index0 }}_CDC = {{ mst.CDC }},
        parameter MST{{ loop.index0 }}_OSTDREQ_NUM = {{ mst.OSTDREQ_NUM }},
        parameter MST{{ loop.index0 }}_PRIORITY = {{ mst.PRIORITY }},
        parameter [SLV_NB-1:0] MST{{ loop.index0 }}_ROUTES = {{ mst.ROUTES }},
        parameter [AXI_ID_W-1:0] MST{{ loop.index0 }}_ID_MASK = 'h{{ "%0x"|format(mst.ID_MASK) }},
        parameter MST{{ loop.index0 }}_RW = {{ mst.RW }},
        {%- endfor %}

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

        {%- for slv in slaves %}

        ///////////////////////////////////////////////////////////////////////
        // Slave {{ loop.index0 }} configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV{{ loop.index0 }}_CDC = {{ slv.CDC }},
        parameter SLV{{ loop.index0 }}_START_ADDR = {{ slv.START_ADDR }},
        parameter SLV{{ loop.index0 }}_END_ADDR = {{ slv.END_ADDR }},
        parameter SLV{{ loop.index0 }}_OSTDREQ_NUM = {{ slv.OSTDREQ_NUM }},
        parameter SLV{{ loop.index0 }}_KEEP_BASE_ADDR = {{ slv.KEEP_BASE_ADDR }}{% if not loop.last %},{% endif %}
        {%- endfor %}
    )(
        ///////////////////////////////////////////////////////////////////////
        // Interconnect global interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       aclk,
        input  wire                       aresetn,
        input  wire                       srst,

        {%- for mst_idx in range(global.MST_NB) %}

        ///////////////////////////////////////////////////////////////////////
        // Master Agent {{ mst_idx }} interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       slv{{ mst_idx }}_aclk,
        input  wire                       slv{{ mst_idx }}_aresetn,
        input  wire                       slv{{ mst_idx }}_srst,
        input  wire                       slv{{ mst_idx }}_awvalid,
        output logic                      slv{{ mst_idx }}_awready,
        input  wire  [AXI_ADDR_W    -1:0] slv{{ mst_idx }}_awaddr,
        input  wire  [3             -1:0] slv{{ mst_idx }}_awprot,
        input  wire  [AXI_ID_W      -1:0] slv{{ mst_idx }}_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv{{ mst_idx }}_awuser,
        input  wire                       slv{{ mst_idx }}_wvalid,
        output logic                      slv{{ mst_idx }}_wready,
        input  wire  [AXI_DATA_W    -1:0] slv{{ mst_idx }}_wdata,
        input  wire  [AXI_DATA_W/8  -1:0] slv{{ mst_idx }}_wstrb,
        input  wire  [AXI_WUSER_W   -1:0] slv{{ mst_idx }}_wuser,
        output logic                      slv{{ mst_idx }}_bvalid,
        input  wire                       slv{{ mst_idx }}_bready,
        output logic [AXI_ID_W      -1:0] slv{{ mst_idx }}_bid,
        output logic [2             -1:0] slv{{ mst_idx }}_bresp,
        output logic [AXI_BUSER_W   -1:0] slv{{ mst_idx }}_buser,
        input  wire                       slv{{ mst_idx }}_arvalid,
        output logic                      slv{{ mst_idx }}_arready,
        input  wire  [AXI_ADDR_W    -1:0] slv{{ mst_idx }}_araddr,
        input  wire  [3             -1:0] slv{{ mst_idx }}_arprot,
        input  wire  [AXI_ID_W      -1:0] slv{{ mst_idx }}_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv{{ mst_idx }}_aruser,
        output logic                      slv{{ mst_idx }}_rvalid,
        input  wire                       slv{{ mst_idx }}_rready,
        output logic [AXI_ID_W      -1:0] slv{{ mst_idx }}_rid,
        output logic [2             -1:0] slv{{ mst_idx }}_rresp,
        output logic [AXI_DATA_W    -1:0] slv{{ mst_idx }}_rdata,
        output logic [AXI_RUSER_W   -1:0] slv{{ mst_idx }}_ruser,
        {%- endfor %}

        {%- for slv_idx in range(global.SLV_NB) %}

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent {{ slv_idx }} interface
        ///////////////////////////////////////////////////////////////////////

        input  wire                       mst{{ slv_idx }}_aclk,
        input  wire                       mst{{ slv_idx }}_aresetn,
        input  wire                       mst{{ slv_idx }}_srst,
        output logic                      mst{{ slv_idx }}_awvalid,
        input  wire                       mst{{ slv_idx }}_awready,
        output logic [AXI_ADDR_W    -1:0] mst{{ slv_idx }}_awaddr,
        output logic [3             -1:0] mst{{ slv_idx }}_awprot,
        output logic [AXI_ID_W      -1:0] mst{{ slv_idx }}_awid,
        output logic [AXI_AUSER_W   -1:0] mst{{ slv_idx }}_awuser,
        output logic                      mst{{ slv_idx }}_wvalid,
        input  wire                       mst{{ slv_idx }}_wready,
        output logic [AXI_DATA_W    -1:0] mst{{ slv_idx }}_wdata,
        output logic [AXI_DATA_W/8  -1:0] mst{{ slv_idx }}_wstrb,
        output logic [AXI_WUSER_W   -1:0] mst{{ slv_idx }}_wuser,
        input  wire                       mst{{ slv_idx }}_bvalid,
        output logic                      mst{{ slv_idx }}_bready,
        input  wire  [AXI_ID_W      -1:0] mst{{ slv_idx }}_bid,
        input  wire  [2             -1:0] mst{{ slv_idx }}_bresp,
        input  wire  [AXI_BUSER_W   -1:0] mst{{ slv_idx }}_buser,
        output logic                      mst{{ slv_idx }}_arvalid,
        input  wire                       mst{{ slv_idx }}_arready,
        output logic [AXI_ADDR_W    -1:0] mst{{ slv_idx }}_araddr,
        output logic [3             -1:0] mst{{ slv_idx }}_arprot,
        output logic [AXI_ID_W      -1:0] mst{{ slv_idx }}_arid,
        output logic [AXI_AUSER_W   -1:0] mst{{ slv_idx }}_aruser,
        input  wire                       mst{{ slv_idx }}_rvalid,
        output logic                      mst{{ slv_idx }}_rready,
        input  wire  [AXI_ID_W      -1:0] mst{{ slv_idx }}_rid,
        input  wire  [2             -1:0] mst{{ slv_idx }}_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst{{ slv_idx }}_rdata,
        input  wire  [AXI_RUSER_W   -1:0] mst{{ slv_idx }}_ruser{% if not loop.last %},{% endif %}
        {%- endfor %}
    );


    axicb_crossbar_top
    #(
        .AXI_ADDR_W          (AXI_ADDR_W),
        .AXI_ID_W            (AXI_ID_W),
        .AXI_DATA_W          (AXI_DATA_W),
        .MST_NB              (MST_NB),
        .SLV_NB              (SLV_NB),
        .OR_NUM_W            (OR_NUM_W),
        .MST_PIPELINE        (MST_PIPELINE),
        .SLV_PIPELINE        (SLV_PIPELINE),
        .AXI_SIGNALING       (0),
        .USER_SUPPORT        (USER_SUPPORT),
        .AXI_AUSER_W         (AXI_AUSER_W),
        .AXI_WUSER_W         (AXI_WUSER_W),
        .AXI_BUSER_W         (AXI_BUSER_W),
        .AXI_RUSER_W         (AXI_RUSER_W),
        .TIMEOUT_VALUE       (TIMEOUT_VALUE),
        .TIMEOUT_ENABLE      (TIMEOUT_ENABLE),
        .NUM_PRIORITY_LVL    (NUM_PRIORITY_LVL),
        {%- for mst_idx in range(global.MST_NB) %}
        .MST{{ mst_idx }}_CDC            (MST{{ mst_idx }}_CDC),
        .MST{{ mst_idx }}_OSTDREQ_NUM    (MST{{ mst_idx }}_OSTDREQ_NUM),
        .MST{{ mst_idx }}_OSTDREQ_SIZE   (1),
        .MST{{ mst_idx }}_PRIORITY       (MST{{ mst_idx }}_PRIORITY),
        .MST{{ mst_idx }}_ROUTES         (MST{{ mst_idx }}_ROUTES),
        .MST{{ mst_idx }}_ID_MASK        (MST{{ mst_idx }}_ID_MASK),
        .MST{{ mst_idx }}_RW             (MST{{ mst_idx }}_RW),
        {%- endfor %}
        {%- for slv_idx in range(global.SLV_NB) %}
        .SLV{{ slv_idx }}_CDC            (SLV{{ slv_idx }}_CDC),
        .SLV{{ slv_idx }}_START_ADDR     (SLV{{ slv_idx }}_START_ADDR),
        .SLV{{ slv_idx }}_END_ADDR       (SLV{{ slv_idx }}_END_ADDR),
        .SLV{{ slv_idx }}_OSTDREQ_NUM    (SLV{{ slv_idx }}_OSTDREQ_NUM),
        .SLV{{ slv_idx }}_OSTDREQ_SIZE   (1),
        .SLV{{ slv_idx }}_KEEP_BASE_ADDR (SLV{{ slv_idx }}_KEEP_BASE_ADDR){% if not loop.last %},{% endif %}
        {%- endfor %}
    )
    axi4lite_crossbar_inst
    (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .srst          (srst),
        {%- for mst_idx in range(global.MST_NB) %}
        .slv{{ mst_idx }}_aclk     (slv{{ mst_idx }}_aclk),
        .slv{{ mst_idx }}_aresetn  (slv{{ mst_idx }}_aresetn),
        .slv{{ mst_idx }}_srst     (slv{{ mst_idx }}_srst),
        .slv{{ mst_idx }}_awvalid  (slv{{ mst_idx }}_awvalid),
        .slv{{ mst_idx }}_awready  (slv{{ mst_idx }}_awready),
        .slv{{ mst_idx }}_awaddr   (slv{{ mst_idx }}_awaddr),
        .slv{{ mst_idx }}_awlen    (8'h0),
        .slv{{ mst_idx }}_awsize   (3'b0),
        .slv{{ mst_idx }}_awburst  (2'b0),
        .slv{{ mst_idx }}_awlock   (1'b0),
        .slv{{ mst_idx }}_awcache  (4'b0),
        .slv{{ mst_idx }}_awprot   (slv{{ mst_idx }}_awprot),
        .slv{{ mst_idx }}_awqos    (4'b0),
        .slv{{ mst_idx }}_awregion (4'b0),
        .slv{{ mst_idx }}_awid     (slv{{ mst_idx }}_awid),
        .slv{{ mst_idx }}_awuser   (slv{{ mst_idx }}_awuser),
        .slv{{ mst_idx }}_wvalid   (slv{{ mst_idx }}_wvalid),
        .slv{{ mst_idx }}_wready   (slv{{ mst_idx }}_wready),
        .slv{{ mst_idx }}_wlast    (1'b1),
        .slv{{ mst_idx }}_wdata    (slv{{ mst_idx }}_wdata),
        .slv{{ mst_idx }}_wstrb    (slv{{ mst_idx }}_wstrb),
        .slv{{ mst_idx }}_wuser    (slv{{ mst_idx }}_wuser),
        .slv{{ mst_idx }}_bvalid   (slv{{ mst_idx }}_bvalid),
        .slv{{ mst_idx }}_bready   (slv{{ mst_idx }}_bready),
        .slv{{ mst_idx }}_bid      (slv{{ mst_idx }}_bid),
        .slv{{ mst_idx }}_bresp    (slv{{ mst_idx }}_bresp),
        .slv{{ mst_idx }}_buser    (slv{{ mst_idx }}_buser),
        .slv{{ mst_idx }}_arvalid  (slv{{ mst_idx }}_arvalid),
        .slv{{ mst_idx }}_arready  (slv{{ mst_idx }}_arready),
        .slv{{ mst_idx }}_araddr   (slv{{ mst_idx }}_araddr),
        .slv{{ mst_idx }}_arlen    (8'h0),
        .slv{{ mst_idx }}_arsize   (3'h0),
        .slv{{ mst_idx }}_arburst  (2'b0),
        .slv{{ mst_idx }}_arlock   (1'b0),
        .slv{{ mst_idx }}_arcache  (4'h0),
        .slv{{ mst_idx }}_arprot   (slv{{ mst_idx }}_arprot),
        .slv{{ mst_idx }}_arqos    (4'h0),
        .slv{{ mst_idx }}_arregion (4'h0),
        .slv{{ mst_idx }}_arid     (slv{{ mst_idx }}_arid),
        .slv{{ mst_idx }}_aruser   (slv{{ mst_idx }}_aruser),
        .slv{{ mst_idx }}_rvalid   (slv{{ mst_idx }}_rvalid),
        .slv{{ mst_idx }}_rready   (slv{{ mst_idx }}_rready),
        .slv{{ mst_idx }}_rid      (slv{{ mst_idx }}_rid),
        .slv{{ mst_idx }}_rresp    (slv{{ mst_idx }}_rresp),
        .slv{{ mst_idx }}_rdata    (slv{{ mst_idx }}_rdata),
        .slv{{ mst_idx }}_rlast    (),
        .slv{{ mst_idx }}_ruser    (slv{{ mst_idx }}_ruser),
        {%- endfor %}
        {%- for slv_idx in range(global.SLV_NB) %}
        .mst{{ slv_idx }}_aclk     (mst{{ slv_idx }}_aclk),
        .mst{{ slv_idx }}_aresetn  (mst{{ slv_idx }}_aresetn),
        .mst{{ slv_idx }}_srst     (mst{{ slv_idx }}_srst),
        .mst{{ slv_idx }}_awvalid  (mst{{ slv_idx }}_awvalid),
        .mst{{ slv_idx }}_awready  (mst{{ slv_idx }}_awready),
        .mst{{ slv_idx }}_awaddr   (mst{{ slv_idx }}_awaddr),
        .mst{{ slv_idx }}_awlen    (),
        .mst{{ slv_idx }}_awsize   (),
        .mst{{ slv_idx }}_awburst  (),
        .mst{{ slv_idx }}_awlock   (),
        .mst{{ slv_idx }}_awcache  (),
        .mst{{ slv_idx }}_awprot   (mst{{ slv_idx }}_awprot),
        .mst{{ slv_idx }}_awqos    (),
        .mst{{ slv_idx }}_awregion (),
        .mst{{ slv_idx }}_awid     (mst{{ slv_idx }}_awid),
        .mst{{ slv_idx }}_awuser   (mst{{ slv_idx }}_awuser),
        .mst{{ slv_idx }}_wvalid   (mst{{ slv_idx }}_wvalid),
        .mst{{ slv_idx }}_wready   (mst{{ slv_idx }}_wready),
        .mst{{ slv_idx }}_wlast    (),
        .mst{{ slv_idx }}_wdata    (mst{{ slv_idx }}_wdata),
        .mst{{ slv_idx }}_wstrb    (mst{{ slv_idx }}_wstrb),
        .mst{{ slv_idx }}_wuser    (mst{{ slv_idx }}_wuser),
        .mst{{ slv_idx }}_bvalid   (mst{{ slv_idx }}_bvalid),
        .mst{{ slv_idx }}_bready   (mst{{ slv_idx }}_bready),
        .mst{{ slv_idx }}_bid      (mst{{ slv_idx }}_bid),
        .mst{{ slv_idx }}_bresp    (mst{{ slv_idx }}_bresp),
        .mst{{ slv_idx }}_buser    (mst{{ slv_idx }}_buser),
        .mst{{ slv_idx }}_arvalid  (mst{{ slv_idx }}_arvalid),
        .mst{{ slv_idx }}_arready  (mst{{ slv_idx }}_arready),
        .mst{{ slv_idx }}_araddr   (mst{{ slv_idx }}_araddr),
        .mst{{ slv_idx }}_arlen    (),
        .mst{{ slv_idx }}_arsize   (),
        .mst{{ slv_idx }}_arburst  (),
        .mst{{ slv_idx }}_arlock   (),
        .mst{{ slv_idx }}_arcache  (),
        .mst{{ slv_idx }}_arprot   (mst{{ slv_idx }}_arprot),
        .mst{{ slv_idx }}_arqos    (),
        .mst{{ slv_idx }}_arregion (),
        .mst{{ slv_idx }}_arid     (mst{{ slv_idx }}_arid),
        .mst{{ slv_idx }}_aruser   (mst{{ slv_idx }}_aruser),
        .mst{{ slv_idx }}_rvalid   (mst{{ slv_idx }}_rvalid),
        .mst{{ slv_idx }}_rready   (mst{{ slv_idx }}_rready),
        .mst{{ slv_idx }}_rid      (mst{{ slv_idx }}_rid),
        .mst{{ slv_idx }}_rresp    (mst{{ slv_idx }}_rresp),
        .mst{{ slv_idx }}_rdata    (mst{{ slv_idx }}_rdata),
        .mst{{ slv_idx }}_rlast    (1'b1),
        .mst{{ slv_idx }}_ruser    (mst{{ slv_idx }}_ruser){% if not loop.last %},{% endif %}
        {%- endfor %}
    );

endmodule

`resetall
