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

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI
        parameter AXI_SIGNALING = {{ global.AXI_SIGNALING }},

        // USER fields transport enabling (0 deactivate, 1 activate)
        parameter USER_SUPPORT = {{ global.USER_SUPPORT }},
        // USER fields width in bits
        parameter AXI_AUSER_W = {{ global.AXI_AUSER_W }},
        parameter AXI_WUSER_W = {{ global.AXI_WUSER_W }},
        parameter AXI_BUSER_W = {{ global.AXI_BUSER_W }},
        parameter AXI_RUSER_W = {{ global.AXI_RUSER_W }},

        // Timeout configuration in clock cycles, applied to all channels (UNUSED)
        parameter TIMEOUT_VALUE = {{ global.TIMEOUT_VALUE }},
        // Activate the timer to avoid deadlock (UNUSED)
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
        parameter MST{{ loop.index0 }}_OSTDREQ_SIZE = {{ mst.OSTDREQ_SIZE }},
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

        {%- for slv in slaves %}

        ///////////////////////////////////////////////////////////////////////
        // Slave {{ loop.index0 }} configuration
        ///////////////////////////////////////////////////////////////////////

        parameter SLV{{ loop.index0 }}_CDC = {{ slv.CDC }},
        parameter SLV{{ loop.index0 }}_START_ADDR = {{ slv.START_ADDR }},
        parameter SLV{{ loop.index0 }}_END_ADDR = {{ slv.END_ADDR }},
        parameter SLV{{ loop.index0 }}_OSTDREQ_NUM = {{ slv.OSTDREQ_NUM }},
        parameter SLV{{ loop.index0 }}_OSTDREQ_SIZE = {{ slv.OSTDREQ_SIZE }},
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
        input  wire  [8             -1:0] slv{{ mst_idx }}_awlen,
        input  wire  [3             -1:0] slv{{ mst_idx }}_awsize,
        input  wire  [2             -1:0] slv{{ mst_idx }}_awburst,
        input  wire                       slv{{ mst_idx }}_awlock,
        input  wire  [4             -1:0] slv{{ mst_idx }}_awcache,
        input  wire  [3             -1:0] slv{{ mst_idx }}_awprot,
        input  wire  [4             -1:0] slv{{ mst_idx }}_awqos,
        input  wire  [4             -1:0] slv{{ mst_idx }}_awregion,
        input  wire  [AXI_ID_W      -1:0] slv{{ mst_idx }}_awid,
        input  wire  [AXI_AUSER_W   -1:0] slv{{ mst_idx }}_awuser,
        input  wire                       slv{{ mst_idx }}_wvalid,
        output logic                      slv{{ mst_idx }}_wready,
        input  wire                       slv{{ mst_idx }}_wlast,
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
        input  wire  [8             -1:0] slv{{ mst_idx }}_arlen,
        input  wire  [3             -1:0] slv{{ mst_idx }}_arsize,
        input  wire  [2             -1:0] slv{{ mst_idx }}_arburst,
        input  wire                       slv{{ mst_idx }}_arlock,
        input  wire  [4             -1:0] slv{{ mst_idx }}_arcache,
        input  wire  [3             -1:0] slv{{ mst_idx }}_arprot,
        input  wire  [4             -1:0] slv{{ mst_idx }}_awqos,
        input  wire  [4             -1:0] slv{{ mst_idx }}_arregion,
        input  wire  [AXI_ID_W      -1:0] slv{{ mst_idx }}_arid,
        input  wire  [AXI_AUSER_W   -1:0] slv{{ mst_idx }}_aruser,
        output logic                      slv{{ mst_idx }}_rvalid,
        input  wire                       slv{{ mst_idx }}_rready,
        output logic [AXI_ID_W      -1:0] slv{{ mst_idx }}_rid,
        output logic [2             -1:0] slv{{ mst_idx }}_rresp,
        output logic [AXI_DATA_W    -1:0] slv{{ mst_idx }}_rdata,
        output logic                      slv{{ mst_idx }}_rlast,
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
        output logic [8             -1:0] mst{{ slv_idx }}_awlen,
        output logic [3             -1:0] mst{{ slv_idx }}_awsize,
        output logic [2             -1:0] mst{{ slv_idx }}_awburst,
        output logic                      mst{{ slv_idx }}_awlock,
        output logic [4             -1:0] mst{{ slv_idx }}_awcache,
        output logic [3             -1:0] mst{{ slv_idx }}_awprot,
        output logic [4             -1:0] mst{{ slv_idx }}_awqos,
        output logic [4             -1:0] mst{{ slv_idx }}_awregion,
        output logic [AXI_ID_W      -1:0] mst{{ slv_idx }}_awid,
        output logic [AXI_AUSER_W   -1:0] mst{{ slv_idx }}_awuser,
        output logic                      mst{{ slv_idx }}_wvalid,
        input  wire                       mst{{ slv_idx }}_wready,
        output logic                      mst{{ slv_idx }}_wlast,
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
        output logic [8             -1:0] mst{{ slv_idx }}_arlen,
        output logic [3             -1:0] mst{{ slv_idx }}_arsize,
        output logic [2             -1:0] mst{{ slv_idx }}_arburst,
        output logic                      mst{{ slv_idx }}_arlock,
        output logic [4             -1:0] mst{{ slv_idx }}_arcache,
        output logic [3             -1:0] mst{{ slv_idx }}_arprot,
        output logic [4             -1:0] mst{{ slv_idx }}_arqos,
        output logic [4             -1:0] mst{{ slv_idx }}_arregion,
        output logic [AXI_ID_W      -1:0] mst{{ slv_idx }}_arid,
        output logic [AXI_AUSER_W   -1:0] mst{{ slv_idx }}_aruser,
        input  wire                       mst{{ slv_idx }}_rvalid,
        output logic                      mst{{ slv_idx }}_rready,
        input  wire  [AXI_ID_W      -1:0] mst{{ slv_idx }}_rid,
        input  wire  [2             -1:0] mst{{ slv_idx }}_rresp,
        input  wire  [AXI_DATA_W    -1:0] mst{{ slv_idx }}_rdata,
        input  wire                       mst{{ slv_idx }}_rlast,
        input  wire  [AXI_RUSER_W   -1:0] mst{{ slv_idx }}_ruser{% if not loop.last %},{% endif %}
        {%- endfor %}
    );


    ///////////////////////////////////////////////////////////////////////////
    // Parameters setup checks
    ///////////////////////////////////////////////////////////////////////////

    initial begin

        {%- for mst_idx in range(global.MST_NB) %}
        `CHECKER((MST{{ mst_idx }}_OSTDREQ_NUM>0 && MST{{ mst_idx }}_OSTDREQ_SIZE==0),
            "MST{{ mst_idx }} is setup with oustanding request but their size must be greater than 0");

        {%- endfor %}
        {%- for mst_idx in range(global.MST_NB) %}
        `CHECKER((MST{{ mst_idx }}_ID_MASK==0), "MST{{ mst_idx }} mask ID must be greater than 0");
        {%- endfor %}
        {%- for slv_idx in range(global.SLV_NB) %}
        `CHECKER((SLV{{ slv_idx }}_OSTDREQ_NUM>0 && SLV{{ slv_idx }}_OSTDREQ_SIZE==0),
            "SLV{{ slv_idx }} is setup with oustanding request but their size must be greater than 0");
        {%- endfor %}
        `CHECKER((NUM_PRIORITY_LVL>4), "Can't select more than 4 levels of priority");

        `CHECKER((SLV_NB> {{ global.SLV_NB }}), "Can't select more than {{ global.SLV_NB }} slaves");

        `CHECKER((MST_NB> {{ global.MST_NB }}), "Can't select more than {{ global.MST_NB }} masters");

        {%- for mst_idx in range(global.MST_NB) %}
        `CHECKER((MST{{ mst_idx }}_PRIORITY > (NUM_PRIORITY_LVL-1)), 
            "Master {{ mst_idx }} priority is bigger than number of priority level");
        {%- endfor %

        {%- for mst_idx in range(global.MST_NB) %}
        `CHECKER((MST{{ mst_idx }}_OSTDREQ_NUM > (2**OR_NUM_W)), 
            "Master {{ mst_idx }} oustanding request number is too big compared to OR_NUM_W parameter");
        {%- endfor %}

        {%- for slv_idx in range(global.SLV_NB) %}
        `CHECKER((SLV{{ slv_idx }}_OSTDREQ_NUM > (2**OR_NUM_W)), 
            "Slave {{ slv_idx }} oustanding request number is too big compared to OR_NUM_W parameter");
        {%- endfor %}
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
                                             AXI_ADDR_W + AXI_ID_W + 29 + AUSER_W;

    localparam WCH_W = AXI_DATA_W + AXI_DATA_W/8 + WUSER_W;

    localparam BCH_W = AXI_ID_W + 2 + BUSER_W;

    localparam ARCH_W = AWCH_W;

    localparam RCH_W = AXI_DATA_W + AXI_ID_W + 2 + RUSER_W;

    localparam [MST_NB*SLV_NB -1:0] MST_ROUTES = {
        {%- for mst_idx in range(global.MST_NB - 1, -1, -1) %}
        MST{{ mst_idx }}_ROUTES[0+:SLV_NB],
        {%- endfor %}
    };

    localparam _NUM_PRIORITY_LVL = (NUM_PRIORITY_LVL <= 1) ? 1 : NUM_PRIORITY_LVL;
    localparam PRIORITY_W = (NUM_PRIORITY_LVL <= 1) ? 1 : $clog2(NUM_PRIORITY_LVL);

    localparam [PRIORITY_W*MST_NB-1:0] MST_PRIORITY = {
        {%- for mst_idx in range(global.MST_NB - 1, -1, -1) %}
        MST{{ mst_idx }}_PRIORITY[0+:PRIORITY_W],
        {%- endfor %}
    };

    localparam [AXI_ID_W*MST_NB-1:0] MST_ID_MASK = {
        {%- for mst_idx in range(global.MST_NB - 1, -1, -1) %}
        MST{{ mst_idx }}_ID_MASK[AXI_ID_W-1:0],
        {%- endfor %}
    };

    localparam [MST_NB*OR_NUM_W-1:0] MST_OSTDREQ_NUM = {
        {%- for mst_idx in range(global.MST_NB - 1, -1, -1) %}
        MST{{ mst_idx }}_OSTDREQ_NUM[OR_NUM_W-1:0],
        {%- endfor %}
    };

    parameter [AXI_ADDR_W * SLV_NB - 1:0] SLV_START_ADDR = {
        {%- for slv_idx in range(global.SLV_NB - 1, -1, -1) %}
        SLV{{ slv_idx }}_START_ADDR[0+:AXI_ADDR_W],
        {%- endfor %}
    };

    parameter [AXI_ADDR_W * SLV_NB - 1:0] SLV_END_ADDR = {
        {%- for slv_idx in range(global.SLV_NB - 1, -1, -1) %}
        SLV{{ slv_idx }}_END_ADDR[0+:AXI_ADDR_W],
        {%- endfor %}
    };

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


    {%- for mst_idx in range(global.MST_NB) %}
    ///////////////////////////////////////////////////////////////////////////
    // Slave interface {{ mst_idx }}
    ///////////////////////////////////////////////////////////////////////////

    axicb_slv_if
    #(
        .AXI_ADDR_W        (AXI_ADDR_W),
        .AXI_ID_W          (AXI_ID_W),
        .AXI_DATA_W        (AXI_DATA_W),
        .SLV_NB            (SLV_NB),
        .AXI_SIGNALING     (AXI_SIGNALING),
        .MST_CDC           (MST{{ mst_idx }}_CDC),
        .MST_OSTDREQ_NUM   (MST{{ mst_idx }}_OSTDREQ_NUM),
        .MST_OSTDREQ_SIZE  (MST{{ mst_idx }}_OSTDREQ_SIZE),
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
    slv{{ mst_idx }}_if
    (
        .i_aclk       (slv{{ mst_idx }}_aclk),
        .i_aresetn    (slv{{ mst_idx }}_aresetn),
        .i_srst       (slv{{ mst_idx }}_srst),
        .i_awvalid    (slv{{ mst_idx }}_awvalid),
        .i_awready    (slv{{ mst_idx }}_awready),
        .i_awaddr     (slv{{ mst_idx }}_awaddr),
        .i_awlen      (slv{{ mst_idx }}_awlen),
        .i_awsize     (slv{{ mst_idx }}_awsize),
        .i_awburst    (slv{{ mst_idx }}_awburst),
        .i_awlock     (slv{{ mst_idx }}_awlock),
        .i_awcache    (slv{{ mst_idx }}_awcache),
        .i_awprot     (slv{{ mst_idx }}_awprot),
        .i_awqos      (slv{{ mst_idx }}_awqos),
        .i_awregion   (slv{{ mst_idx }}_awregion),
        .i_awid       (slv{{ mst_idx }}_awid),
        .i_awuser     (slv{{ mst_idx }}_awuser),
        .i_wvalid     (slv{{ mst_idx }}_wvalid),
        .i_wready     (slv{{ mst_idx }}_wready),
        .i_wlast      (slv{{ mst_idx }}_wlast),
        .i_wdata      (slv{{ mst_idx }}_wdata),
        .i_wstrb      (slv{{ mst_idx }}_wstrb),
        .i_wuser      (slv{{ mst_idx }}_wuser),
        .i_bvalid     (slv{{ mst_idx }}_bvalid),
        .i_bready     (slv{{ mst_idx }}_bready),
        .i_bid        (slv{{ mst_idx }}_bid),
        .i_bresp      (slv{{ mst_idx }}_bresp),
        .i_buser      (slv{{ mst_idx }}_buser),
        .i_arvalid    (slv{{ mst_idx }}_arvalid),
        .i_arready    (slv{{ mst_idx }}_arready),
        .i_araddr     (slv{{ mst_idx }}_araddr),
        .i_arlen      (slv{{ mst_idx }}_arlen),
        .i_arsize     (slv{{ mst_idx }}_arsize),
        .i_arburst    (slv{{ mst_idx }}_arburst),
        .i_arlock     (slv{{ mst_idx }}_arlock),
        .i_arcache    (slv{{ mst_idx }}_arcache),
        .i_arprot     (slv{{ mst_idx }}_arprot),
        .i_arqos      (slv{{ mst_idx }}_arqos),
        .i_arregion   (slv{{ mst_idx }}_arregion),
        .i_arid       (slv{{ mst_idx }}_arid),
        .i_aruser     (slv{{ mst_idx }}_aruser),
        .i_rvalid     (slv{{ mst_idx }}_rvalid),
        .i_rready     (slv{{ mst_idx }}_rready),
        .i_rid        (slv{{ mst_idx }}_rid),
        .i_rresp      (slv{{ mst_idx }}_rresp),
        .i_rdata      (slv{{ mst_idx }}_rdata),
        .i_rlast      (slv{{ mst_idx }}_rlast),
        .i_ruser      (slv{{ mst_idx }}_ruser),
        .o_aclk       (aclk),
        .o_aresetn    (aresetn),
        .o_srst       (srst),
        .o_awvalid    (i_awvalid[{{ mst_idx }}]),
        .o_awready    (i_awready[{{ mst_idx }}]),
        .o_awch       (i_awch[{{ mst_idx }}*AWCH_W+:AWCH_W]),
        .o_wvalid     (i_wvalid[{{ mst_idx }}]),
        .o_wready     (i_wready[{{ mst_idx }}]),
        .o_wlast      (i_wlast[{{ mst_idx }}]),
        .o_wch        (i_wch[{{ mst_idx }}*WCH_W+:WCH_W]),
        .o_bvalid     (i_bvalid[{{ mst_idx }}]),
        .o_bready     (i_bready[{{ mst_idx }}]),
        .o_bch        (i_bch[{{ mst_idx }}*BCH_W+:BCH_W]),
        .o_arvalid    (i_arvalid[{{ mst_idx }}]),
        .o_arready    (i_arready[{{ mst_idx }}]),
        .o_arch       (i_arch[{{ mst_idx }}*ARCH_W+:ARCH_W]),
        .o_rvalid     (i_rvalid[{{ mst_idx }}]),
        .o_rready     (i_rready[{{ mst_idx }}]),
        .o_rlast      (i_rlast[{{ mst_idx }}]),
        .o_rch        (i_rch[{{ mst_idx }}*RCH_W+:RCH_W])
    );
{% endfor %}

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
        .MST_ID_MASK        (MST_ID_MASK),
        .OR_NUM_W           (OR_NUM_W),
        .MST_OSTDREQ_NUM    (MST_OSTDREQ_NUM),
        .MST_ROUTES         (MST_ROUTES),
        .PRIORITY_W         (PRIORITY_W),
        .NUM_PRIORITY_LVL   (_NUM_PRIORITY_LVL),
        .MST_PRIORITY       (MST_PRIORITY),
        .SLV_START_ADDR     (SLV_START_ADDR),
        .SLV_END_ADDR       (SLV_END_ADDR),
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


    {%- for slv_idx in range(global.SLV_NB) %}
    ///////////////////////////////////////////////////////////////////////////
    // Master {{ slv_idx }} Interface
    ///////////////////////////////////////////////////////////////////////////

    axicb_mst_if
    #(
        .AXI_ADDR_W       (AXI_ADDR_W),
        .AXI_ID_W         (AXI_ID_W),
        .AXI_DATA_W       (AXI_DATA_W),
        .AXI_SIGNALING    (AXI_SIGNALING),
        .SLV_CDC          (SLV{{ slv_idx }}_CDC),
        .SLV_OSTDREQ_NUM  (SLV{{ slv_idx }}_OSTDREQ_NUM),
        .SLV_OSTDREQ_SIZE (SLV{{ slv_idx }}_OSTDREQ_SIZE),
        .USER_SUPPORT     (USER_SUPPORT),
        .KEEP_BASE_ADDR   (SLV{{ slv_idx }}_KEEP_BASE_ADDR),
        .BASE_ADDR        (SLV{{ slv_idx }}_START_ADDR),
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
    mst{{ slv_idx }}_if
    (
        .i_aclk       (aclk),
        .i_aresetn    (aresetn),
        .i_srst       (srst),
        .i_awvalid    (o_awvalid[{{ slv_idx }}]),
        .i_awready    (o_awready[{{ slv_idx }}]),
        .i_awch       (o_awch[{{ slv_idx }}*AWCH_W+:AWCH_W]),
        .i_wvalid     (o_wvalid[{{ slv_idx }}]),
        .i_wready     (o_wready[{{ slv_idx }}]),
        .i_wlast      (o_wlast[{{ slv_idx }}]),
        .i_wch        (o_wch[{{ slv_idx }}*WCH_W+:WCH_W]),
        .i_bvalid     (o_bvalid[{{ slv_idx }}]),
        .i_bready     (o_bready[{{ slv_idx }}]),
        .i_bch        (o_bch[{{ slv_idx }}*BCH_W+:BCH_W]),
        .i_arvalid    (o_arvalid[{{ slv_idx }}]),
        .i_arready    (o_arready[{{ slv_idx }}]),
        .i_arch       (o_arch[{{ slv_idx }}*ARCH_W+:ARCH_W]),
        .i_rvalid     (o_rvalid[{{ slv_idx }}]),
        .i_rready     (o_rready[{{ slv_idx }}]),
        .i_rlast      (o_rlast[{{ slv_idx }}]),
        .i_rch        (o_rch[{{ slv_idx }}*RCH_W+:RCH_W]),
        .o_aclk       (mst{{ slv_idx }}_aclk),
        .o_aresetn    (mst{{ slv_idx }}_aresetn),
        .o_srst       (mst{{ slv_idx }}_srst),
        .o_awvalid    (mst{{ slv_idx }}_awvalid),
        .o_awready    (mst{{ slv_idx }}_awready),
        .o_awaddr     (mst{{ slv_idx }}_awaddr),
        .o_awlen      (mst{{ slv_idx }}_awlen),
        .o_awsize     (mst{{ slv_idx }}_awsize),
        .o_awburst    (mst{{ slv_idx }}_awburst),
        .o_awlock     (mst{{ slv_idx }}_awlock),
        .o_awcache    (mst{{ slv_idx }}_awcache),
        .o_awprot     (mst{{ slv_idx }}_awprot),
        .o_awqos      (mst{{ slv_idx }}_awqos),
        .o_awregion   (mst{{ slv_idx }}_awregion),
        .o_awid       (mst{{ slv_idx }}_awid),
        .o_awuser     (mst{{ slv_idx }}_awuser),
        .o_wvalid     (mst{{ slv_idx }}_wvalid),
        .o_wready     (mst{{ slv_idx }}_wready),
        .o_wlast      (mst{{ slv_idx }}_wlast),
        .o_wdata      (mst{{ slv_idx }}_wdata),
        .o_wstrb      (mst{{ slv_idx }}_wstrb),
        .o_wuser      (mst{{ slv_idx }}_wuser),
        .o_bvalid     (mst{{ slv_idx }}_bvalid),
        .o_bready     (mst{{ slv_idx }}_bready),
        .o_bid        (mst{{ slv_idx }}_bid),
        .o_bresp      (mst{{ slv_idx }}_bresp),
        .o_buser      (mst{{ slv_idx }}_buser),
        .o_arvalid    (mst{{ slv_idx }}_arvalid),
        .o_arready    (mst{{ slv_idx }}_arready),
        .o_araddr     (mst{{ slv_idx }}_araddr),
        .o_arlen      (mst{{ slv_idx }}_arlen),
        .o_arsize     (mst{{ slv_idx }}_arsize),
        .o_arburst    (mst{{ slv_idx }}_arburst),
        .o_arlock     (mst{{ slv_idx }}_awlock),
        .o_arcache    (mst{{ slv_idx }}_arcache),
        .o_arprot     (mst{{ slv_idx }}_arprot),
        .o_arqos      (mst{{ slv_idx }}_arqos),
        .o_arregion   (mst{{ slv_idx }}_arregion),
        .o_arid       (mst{{ slv_idx }}_arid),
        .o_aruser     (mst{{ slv_idx }}_aruser),
        .o_rvalid     (mst{{ slv_idx }}_rvalid),
        .o_rready     (mst{{ slv_idx }}_rready),
        .o_rid        (mst{{ slv_idx }}_rid),
        .o_rresp      (mst{{ slv_idx }}_rresp),
        .o_rdata      (mst{{ slv_idx }}_rdata),
        .o_rlast      (mst{{ slv_idx }}_rlast),
        .o_ruser      (mst{{ slv_idx }}_ruser)
    );
{% endfor %}

endmodule
`resetall
