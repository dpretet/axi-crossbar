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

        // Number of slave
        parameter SLV_NB = 4,

        // STRB support:
        //   - 0: contiguous wstrb (store only 1st/last dataphase)
        //   - 1: full wstrb transport
        parameter STRB_MODE = 1,

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI4
        parameter AXI_SIGNALING = 0,

        // Implement CDC input stage
        parameter MST_CDC = 0,
        // Maximum number of requests a master can store
        parameter MST_OSTDREQ_NUM = 4,
        // Size of an outstanding request in dataphase
        parameter MST_OSTDREQ_SIZE = 1,

        // USER fields transport enabling (0 deactivate, 1 activate)
        parameter USER_SUPPORT = 0,
        // USER fields width in bits
        parameter AXI_AUSER_W = 0,
        parameter AXI_WUSER_W = 0,
        parameter AXI_BUSER_W = 0,
        parameter AXI_RUSER_W = 0,

        // Output channels' width (concatenated)
        parameter AWCH_W = 8,
        parameter WCH_W = 8,
        parameter BCH_W = 8,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // input interface from external master
        input  wire                       i_aclk,
        input  wire                       i_aresetn,
        input  wire                       i_srst,
        input  wire                       i_awvalid,
        output logic                      i_awready,
        input  wire  [AXI_ADDR_W    -1:0] i_awaddr,
        input  wire  [8             -1:0] i_awlen,
        input  wire  [3             -1:0] i_awsize,
        input  wire  [2             -1:0] i_awburst,
        input  wire  [2             -1:0] i_awlock,
        input  wire  [4             -1:0] i_awcache,
        input  wire  [3             -1:0] i_awprot,
        input  wire  [4             -1:0] i_awqos,
        input  wire  [4             -1:0] i_awregion,
        input  wire  [AXI_ID_W      -1:0] i_awid,
        input  wire  [AXI_AUSER_W   -1:0] i_awuser,
        input  wire                       i_wvalid,
        output logic                      i_wready,
        input  wire                       i_wlast,
        input  wire  [AXI_DATA_W    -1:0] i_wdata,
        input  wire  [AXI_DATA_W/8  -1:0] i_wstrb,
        input  wire  [AXI_WUSER_W   -1:0] i_wuser,
        output logic                      i_bvalid,
        input  wire                       i_bready,
        output logic [AXI_ID_W      -1:0] i_bid,
        output logic [2             -1:0] i_bresp,
        output logic [AXI_BUSER_W   -1:0] i_buser,
        input  wire                       i_arvalid,
        output logic                      i_arready,
        input  wire  [AXI_ADDR_W    -1:0] i_araddr,
        input  wire  [8             -1:0] i_arlen,
        input  wire  [3             -1:0] i_arsize,
        input  wire  [2             -1:0] i_arburst,
        input  wire  [2             -1:0] i_arlock,
        input  wire  [4             -1:0] i_arcache,
        input  wire  [3             -1:0] i_arprot,
        input  wire  [4             -1:0] i_arqos,
        input  wire  [4             -1:0] i_arregion,
        input  wire  [AXI_ID_W      -1:0] i_arid,
        input  wire  [AXI_AUSER_W   -1:0] i_aruser,
        output logic                      i_rvalid,
        input  wire                       i_rready,
        output logic [AXI_ID_W      -1:0] i_rid,
        output logic [2             -1:0] i_rresp,
        output logic [AXI_DATA_W    -1:0] i_rdata,
        output logic                      i_rlast,
        output logic [AXI_RUSER_W   -1:0] i_ruser,
        // output interface to switching logic
        input  wire                       o_aclk,
        input  wire                       o_aresetn,
        input  wire                       o_srst,
        output logic                      o_awvalid,
        input  wire                       o_awready,
        output logic [AWCH_W        -1:0] o_awch,
        output logic                      o_wvalid,
        input  wire                       o_wready,
        output logic                      o_wlast,
        output logic [WCH_W         -1:0] o_wch,
        input  wire                       o_bvalid,
        output logic                      o_bready,
        input  wire  [BCH_W         -1:0] o_bch,
        output logic                      o_arvalid,
        input  wire                       o_arready,
        output logic [ARCH_W        -1:0] o_arch,
        input  wire                       o_rvalid,
        output logic                      o_rready,
        input  wire                       o_rlast,
        input  wire  [RCH_W         -1:0] o_rch
    );


    ///////////////////////////////////////////////////////////////////////////////
    // Logic declarations
    ///////////////////////////////////////////////////////////////////////////////

    logic [AWCH_W        -1:0] awch;
    logic [WCH_W         -1:0] wch;
    logic [BCH_W         -1:0] bch;
    logic [ARCH_W        -1:0] arch;
    logic [RCH_W         -1:0] rch;
    logic                      wlast;


    ///////////////////////////////////////////////////////////////////////////////
    // Write/Read Address Channel preparation
    ///////////////////////////////////////////////////////////////////////////////

    generate

    if (AXI_SIGNALING==0) begin : AXI4LITE_MODE

        if (USER_SUPPORT>0 && AXI_AUSER_W>0) begin: AUSER_ON

        assign awch = {
            i_awuser,
            i_awprot,
            i_awid,
            i_awaddr
        };

        assign arch = {
            i_aruser,
            i_arprot,
            i_arid,
            i_araddr
        };

        end else begin: AUSER_OFF

        assign awch = {
            i_awprot,
            i_awid,
            i_awaddr
        };

        assign arch = {
            i_arprot,
            i_arid,
            i_araddr
        };

        end

    end else begin : AXI4_MODE

        if (USER_SUPPORT>0 && AXI_AUSER_W>0) begin: AUSER_ON

        assign awch = {
            i_awuser,
            i_awregion,
            i_awqos,
            i_awprot,
            i_awcache,
            i_awlock,
            i_awburst,
            i_awsize,
            i_awlen,
            i_awid,
            i_awaddr
        };

        assign arch = {
            i_aruser,
            i_arregion,
            i_arqos,
            i_arprot,
            i_arcache,
            i_arlock,
            i_arburst,
            i_arsize,
            i_arlen,
            i_arid,
            i_araddr
        };

        end else begin: AUSER_OFF

        assign awch = {
            i_awregion,
            i_awqos,
            i_awprot,
            i_awcache,
            i_awlock,
            i_awburst,
            i_awsize,
            i_awlen,
            i_awid,
            i_awaddr
        };

        assign arch = {
            i_arregion,
            i_arqos,
            i_arprot,
            i_arcache,
            i_arlock,
            i_arburst,
            i_arsize,
            i_arlen,
            i_arid,
            i_araddr
        };

        end
    end
    endgenerate

    generate
        if (USER_SUPPORT>0 && AXI_WUSER_W>0) begin: WUSER_ON
            assign wch = {i_wuser, i_wstrb, i_wdata};
        end else begin: WUSER_OFF
            assign wch = {i_wstrb, i_wdata};
        end
    endgenerate

    generate
        if (USER_SUPPORT>0 && AXI_BUSER_W>0) begin: BUSER_ON
            assign {i_buser, i_bresp, i_bid} = bch;
        end else begin: BUSER_OFF
            assign {i_bresp, i_bid} = bch;
        end
    endgenerate

    generate
        if (USER_SUPPORT>0 && AXI_RUSER_W>0) begin: RUSER_ON
            assign {i_ruser, i_rdata, i_rresp, i_rid} = rch;
        end else begin: RUSER_OFF
            assign {i_rdata, i_rresp, i_rid} = rch;
        end
    endgenerate

    generate
        if (AXI_SIGNALING==0) begin: AXI4_LITE_WLAST
            assign wlast = 1'b1;
        end else begin: AXI4_WLAST
            assign wlast = i_wlast;
        end
    endgenerate

    generate

    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////
    if (MST_CDC > 0) begin: CDC_STAGE
    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    localparam AW_ASIZE = (MST_OSTDREQ_NUM==0) ? 2 :
                          (MST_OSTDREQ_NUM<2)  ? 2 :
                          $clog2(MST_OSTDREQ_NUM);

    localparam W_ASIZE = (MST_OSTDREQ_NUM==0) ? 2 :
                         (MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE<2) ? 2 :
                         $clog2(MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE);

    localparam B_ASIZE = (MST_OSTDREQ_NUM==0) ? 2 :
                         (MST_OSTDREQ_NUM<2)  ? 2 :
                         $clog2(MST_OSTDREQ_NUM);

    localparam AR_ASIZE = (MST_OSTDREQ_NUM==0) ? 2 :
                          (MST_OSTDREQ_NUM<2)  ? 2 :
                          $clog2(MST_OSTDREQ_NUM);

    localparam R_ASIZE = (MST_OSTDREQ_NUM==0) ? 2 :
                         (MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE<2) ? 2 :
                         $clog2(MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE);

    logic aw_winc;
    logic aw_full;
    logic aw_rinc;
    logic aw_empty;
    logic w_winc;
    logic w_full;
    logic w_rinc;
    logic w_empty;
    logic b_winc;
    logic b_full;
    logic b_rinc;
    logic b_empty;
    logic ar_winc;
    logic ar_full;
    logic ar_rinc;
    logic ar_empty;
    logic r_winc;
    logic r_full;
    logic r_rinc;
    logic r_empty;

    ///////////////////////////////////////////////////////////////////////////
    // Write Address Channel
    ///////////////////////////////////////////////////////////////////////////

    async_fifo
    #(
    .DSIZE       (AWCH_W),
    .ASIZE       (AW_ASIZE),
    .FALLTHROUGH ("TRUE")
    )
    aw_dcfifo
    (
    .wclk    (i_aclk),
    .wrst_n  (i_aresetn),
    .winc    (aw_winc),
    .wdata   (awch),
    .wfull   (aw_full),
    .awfull  (),
    .rclk    (o_aclk),
    .rrst_n  (o_aresetn),
    .rinc    (aw_rinc),
    .rdata   (o_awch),
    .rempty  (aw_empty),
    .arempty ()
    );

    assign i_awready = ~aw_full;
    assign aw_winc = i_awvalid & ~aw_full;

    assign o_awvalid = ~aw_empty;
    assign aw_rinc = ~aw_empty & o_awready;

    ///////////////////////////////////////////////////////////////////////////
    // Write Data Channel
    ///////////////////////////////////////////////////////////////////////////

    async_fifo
    #(
    .DSIZE       (WCH_W+1),
    .ASIZE       (W_ASIZE),
    .FALLTHROUGH ("TRUE")
    )
    w_dcfifo
    (
    .wclk    (i_aclk),
    .wrst_n  (i_aresetn),
    .winc    (w_winc),
    .wdata   ({wlast, wch}),
    .wfull   (w_full),
    .awfull  (),
    .rclk    (o_aclk),
    .rrst_n  (o_aresetn),
    .rinc    (w_rinc),
    .rdata   ({o_wlast, o_wch}),
    .rempty  (w_empty),
    .arempty ()
    );

    assign i_wready = ~w_full;
    assign w_winc = i_wvalid & ~w_full;

    assign o_wvalid = ~w_empty;
    assign w_rinc = ~w_empty & o_wready;

    ///////////////////////////////////////////////////////////////////////////
    // Write Response Channel
    ///////////////////////////////////////////////////////////////////////////

    async_fifo
    #(
    .DSIZE       (BCH_W),
    .ASIZE       (B_ASIZE),
    .FALLTHROUGH ("TRUE")
    )
    b_dcfifo
    (
    .wclk    (o_aclk),
    .wrst_n  (o_aresetn),
    .winc    (b_winc),
    .wdata   (o_bch),
    .wfull   (b_full),
    .awfull  (),
    .rclk    (i_aclk),
    .rrst_n  (i_aresetn),
    .rinc    (b_rinc),
    .rdata   (bch),
    .rempty  (b_empty),
    .arempty ()
    );

    assign o_bready = ~b_full;
    assign b_winc = o_bvalid & ~b_full;

    assign i_bvalid = ~b_empty;
    assign b_rinc = ~b_empty & i_bready;

    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    async_fifo
    #(
    .DSIZE       (ARCH_W),
    .ASIZE       (AR_ASIZE),
    .FALLTHROUGH ("TRUE")
    )
    ar_dcfifo
    (
    .wclk    (i_aclk),
    .wrst_n  (i_aresetn),
    .winc    (ar_winc),
    .wdata   (arch),
    .wfull   (ar_full),
    .awfull  (),
    .rclk    (o_aclk),
    .rrst_n  (o_aresetn),
    .rinc    (ar_rinc),
    .rdata   (o_arch),
    .rempty  (ar_empty),
    .arempty ()
    );

    assign i_arready = ~ar_full;
    assign ar_winc = i_arvalid & ~ar_full;

    assign o_arvalid = ~ar_empty;
    assign ar_rinc = ~ar_empty & o_arready;

    ///////////////////////////////////////////////////////////////////////////
    // Read Data Channel
    ///////////////////////////////////////////////////////////////////////////

    async_fifo
    #(
    .DSIZE       (RCH_W+1),
    .ASIZE       (R_ASIZE),
    .FALLTHROUGH ("TRUE")
    )
    r_dcfifo
    (
    .wclk    (o_aclk),
    .wrst_n  (o_aresetn),
    .winc    (r_winc),
    .wdata   ({o_rlast, o_rch}),
    .wfull   (r_full),
    .awfull  (),
    .rclk    (i_aclk),
    .rrst_n  (i_aresetn),
    .rinc    (r_rinc),
    .rdata   ({i_rlast, rch}),
    .rempty  (r_empty),
    .arempty ()
    );

    assign o_rready = ~r_full;
    assign r_winc = o_rvalid & ~r_full;

    assign i_rvalid = ~r_empty;
    assign r_rinc = ~r_empty & i_rready;


    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////
    end else if (MST_OSTDREQ_NUM > 0) begin: BUFF_STAGE
    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    localparam PASS_THRU = 0;
    localparam AW_ASIZE = (MST_OSTDREQ_NUM<2) ? 1 : $clog2(MST_OSTDREQ_NUM);
    localparam W_ASIZE = (MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE<2) ? 1 : $clog2(MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE);
    localparam B_ASIZE = (MST_OSTDREQ_NUM<2) ? 1 : $clog2(MST_OSTDREQ_NUM);
    localparam AR_ASIZE = (MST_OSTDREQ_NUM<2) ? 1 : $clog2(MST_OSTDREQ_NUM);
    localparam R_ASIZE = (MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE<2) ? 1 : $clog2(MST_OSTDREQ_NUM*MST_OSTDREQ_SIZE);

    logic aw_full;
    logic aw_empty;
    logic w_full;
    logic w_empty;
    logic ar_full;
    logic ar_empty;
    logic r_full;
    logic r_empty;
    logic b_full;
    logic b_empty;

    ///////////////////////////////////////////////////////////////////////////
    // Write Address Channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_scfifo
    #(
    .PASS_THRU  (PASS_THRU),
    .ADDR_WIDTH (AW_ASIZE),
    .DATA_WIDTH (AWCH_W)
    )
    aw_scfifo
    (
    .aclk     (i_aclk),
    .aresetn  (i_aresetn),
    .srst     (i_srst),
    .flush    (1'b0),
    .data_in  (awch),
    .push     (i_awvalid),
    .full     (aw_full),
    .data_out (o_awch),
    .pull     (o_awready),
    .empty    (aw_empty)
    );
    assign i_awready = ~aw_full;
    assign o_awvalid = ~aw_empty;

    ///////////////////////////////////////////////////////////////////////////
    // Write Data Channel
    ///////////////////////////////////////////////////////////////////////////


    axicb_scfifo
    #(
    .PASS_THRU  (PASS_THRU),
    .ADDR_WIDTH (W_ASIZE),
    .DATA_WIDTH (WCH_W+1)
    )
    w_scfifo
    (
    .aclk     (i_aclk),
    .aresetn  (i_aresetn),
    .srst     (i_srst),
    .flush    (1'b0),
    .data_in  ({wlast, wch}),
    .push     (i_wvalid),
    .full     (w_full),
    .data_out ({o_wlast, o_wch}),
    .pull     (o_wready),
    .empty    (w_empty)
    );
    assign i_wready = ~w_full;
    assign o_wvalid = ~w_empty;

    ///////////////////////////////////////////////////////////////////////////
    // Write Response Channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_scfifo
    #(
    .PASS_THRU  (PASS_THRU),
    .ADDR_WIDTH (B_ASIZE),
    .DATA_WIDTH (BCH_W)
    )
    b_scfifo
    (
    .aclk     (o_aclk),
    .aresetn  (o_aresetn),
    .srst     (o_srst),
    .flush    (1'b0),
    .data_in  (o_bch),
    .push     (o_bvalid),
    .full     (b_full),
    .data_out (bch),
    .pull     (i_bready),
    .empty    (b_empty)
    );

    assign i_bvalid = ~b_empty;
    assign o_bready = ~b_full;

    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_scfifo
    #(
    .PASS_THRU  (PASS_THRU),
    .ADDR_WIDTH (AR_ASIZE),
    .DATA_WIDTH (ARCH_W)
    )
    ar_scfifo
    (
    .aclk     (i_aclk),
    .aresetn  (i_aresetn),
    .srst     (i_srst),
    .flush    (1'b0),
    .data_in  (arch),
    .push     (i_arvalid),
    .full     (ar_full),
    .data_out (o_arch),
    .pull     (o_arready),
    .empty    (ar_empty)
    );

    assign i_arready = ~ar_full;
    assign o_arvalid = ~ar_empty;

    ///////////////////////////////////////////////////////////////////////////
    // Read Data Channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_scfifo
    #(
    .PASS_THRU  (PASS_THRU),
    .ADDR_WIDTH (R_ASIZE),
    .DATA_WIDTH (RCH_W+1)
    )
    r_scfifo
    (
    .aclk     (o_aclk),
    .aresetn  (o_aresetn),
    .srst     (o_srst),
    .flush    (1'b0),
    .data_in  ({o_rlast,o_rch}),
    .push     (o_rvalid),
    .full     (r_full),
    .data_out ({i_rlast, rch}),
    .pull     (i_rready),
    .empty    (r_empty)
    );

    assign i_rvalid = ~r_empty;
    assign o_rready = ~r_full;


    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////
    end else begin: NO_CDC_NO_BUFFERING
    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    assign o_awvalid = i_awvalid;
    assign i_awready = o_awready;

    assign o_awch = awch;

    assign o_wvalid = i_wvalid;
    assign i_wready = o_wready;
    assign o_wlast = wlast;

    assign o_wch = wch;

    assign i_bvalid = o_bvalid;
    assign o_bready = i_bready;

    assign bch = o_bch;

    assign o_arvalid = i_arvalid;
    assign i_arready = o_arready;

    assign o_arch = arch;

    assign i_rvalid = o_rvalid;
    assign o_rready = i_rready;
    assign i_rlast = o_rlast;

    assign rch = o_rch;

    end

    endgenerate

endmodule

`resetall
