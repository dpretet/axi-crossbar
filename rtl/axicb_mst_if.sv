// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_mst_if

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

        // Implement CDC output stage
        parameter SLV_CDC = 0,
        // Maximum number of requests a slave can store
        parameter SLV_OSTDREQ_NUM = 4,
        // Size of an outstanding request in dataphase
        parameter SLV_OSTDREQ_SIZE = 1,

        // USER fields transport enabling (0 deactivate, 1 activate)
        parameter USER_SUPPORT = 0,
        // USER fields width in bits
        parameter AXI_AUSER_W = 0,
        parameter AXI_WUSER_W = 0,
        parameter AXI_BUSER_W = 0,
        parameter AXI_RUSER_W = 0,

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
        output logic [AXI_AUSER_W   -1:0] o_awuser,
        output logic                      o_wvalid,
        input  logic                      o_wready,
        output logic                      o_wlast,
        output logic [AXI_DATA_W    -1:0] o_wdata,
        output logic [AXI_DATA_W/8  -1:0] o_wstrb,
        output logic [AXI_WUSER_W   -1:0] o_wuser,
        input  logic                      o_bvalid,
        output logic                      o_bready,
        input  logic [AXI_ID_W      -1:0] o_bid,
        input  logic [2             -1:0] o_bresp,
        input  logic [AXI_BUSER_W   -1:0] o_buser,
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
        output logic [AXI_AUSER_W   -1:0] o_aruser,
        input  logic                      o_rvalid,
        output logic                      o_rready,
        input  logic [AXI_ID_W      -1:0] o_rid,
        input  logic [2             -1:0] o_rresp,
        input  logic [AXI_DATA_W    -1:0] o_rdata,
        input  logic                      o_rlast,
        input  logic [AXI_RUSER_W   -1:0] o_ruser
    );

    ///////////////////////////////////////////////////////////////////////////////
    // Logic declarations
    ///////////////////////////////////////////////////////////////////////////////

    logic [AWCH_W        -1:0] awch;
    logic [WCH_W         -1:0] wch;
    logic [BCH_W         -1:0] bch;
    logic [ARCH_W        -1:0] arch;
    logic [RCH_W         -1:0] rch;
    logic                      rlast;

    generate

    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////
    if (SLV_CDC) begin: CDC_STAGE
    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    localparam AW_ASIZE = (SLV_OSTDREQ_NUM==0) ? 2 :
                          (SLV_OSTDREQ_NUM<2)  ? 2 :
                          $clog2(SLV_OSTDREQ_NUM);

    localparam W_ASIZE = (SLV_OSTDREQ_NUM==0) ? 2 :
                         (SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE<2) ? 2 :
                         $clog2(SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE);

    localparam B_ASIZE = (SLV_OSTDREQ_NUM==0) ? 2 :
                         (SLV_OSTDREQ_NUM<2)  ? 2 :
                         $clog2(SLV_OSTDREQ_NUM);

    localparam AR_ASIZE = (SLV_OSTDREQ_NUM==0) ? 2 :
                          (SLV_OSTDREQ_NUM<2)  ? 2 :
                          $clog2(SLV_OSTDREQ_NUM);

    localparam R_ASIZE = (SLV_OSTDREQ_NUM==0) ? 2 :
                         (SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE<2) ? 2 :
                         $clog2(SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE);

    logic             aw_winc;
    logic             aw_full;
    logic             aw_rinc;
    logic             aw_empty;
    logic             w_winc;
    logic             w_full;
    logic             w_rinc;
    logic             w_empty;
    logic             b_winc;
    logic             b_full;
    logic             b_rinc;
    logic             b_empty;
    logic             ar_winc;
    logic             ar_full;
    logic             ar_rinc;
    logic             ar_empty;
    logic             r_winc;
    logic             r_full;
    logic             r_rinc;
    logic             r_empty;

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
    .wdata   (i_awch),
    .wfull   (aw_full),
    .awfull  (),
    .rclk    (o_aclk),
    .rrst_n  (o_aresetn),
    .rinc    (aw_rinc),
    .rdata   (awch),
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
    .wdata   ({i_wlast, i_wch}),
    .wfull   (w_full),
    .awfull  (),
    .rclk    (o_aclk),
    .rrst_n  (o_aresetn),
    .rinc    (w_rinc),
    .rdata   ({o_wlast, wch}),
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
    .wdata   (bch),
    .wfull   (b_full),
    .awfull  (),
    .rclk    (i_aclk),
    .rrst_n  (i_aresetn),
    .rinc    (b_rinc),
    .rdata   (i_bch),
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
    .wdata   (i_arch),
    .wfull   (ar_full),
    .awfull  (),
    .rclk    (o_aclk),
    .rrst_n  (o_aresetn),
    .rinc    (ar_rinc),
    .rdata   (arch),
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
    .wdata   ({rlast, rch}),
    .wfull   (r_full),
    .awfull  (),
    .rclk    (i_aclk),
    .rrst_n  (i_aresetn),
    .rinc    (r_rinc),
    .rdata   ({i_rlast, i_rch}),
    .rempty  (r_empty),
    .arempty ()
    );

    assign o_rready = ~r_full;
    assign r_winc = o_rvalid & ~r_full;

    assign i_rvalid = ~r_empty;
    assign r_rinc = ~r_empty & i_rready;


    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////
    end else if (SLV_OSTDREQ_NUM>0) begin: BUFF_STAGE
    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    localparam PASS_THRU = 0;
    localparam AW_ASIZE = (SLV_OSTDREQ_NUM<2) ? 1 : $clog2(SLV_OSTDREQ_NUM);
    localparam W_ASIZE = (SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE<2) ? 1 : $clog2(SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE);
    localparam B_ASIZE = (SLV_OSTDREQ_NUM<2) ? 1 : $clog2(SLV_OSTDREQ_NUM);
    localparam AR_ASIZE = (SLV_OSTDREQ_NUM<2) ? 1 : $clog2(SLV_OSTDREQ_NUM);
    localparam R_ASIZE = (SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE<2) ? 1 : $clog2(SLV_OSTDREQ_NUM*SLV_OSTDREQ_SIZE);

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
    .data_in  (i_awch),
    .push     (i_awvalid),
    .full     (aw_full),
    .data_out (awch),
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
    .data_in  ({i_wlast, i_wch}),
    .push     (i_wvalid),
    .full     (w_full),
    .data_out ({o_wlast, wch}),
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
    .data_in  (bch),
    .push     (o_bvalid),
    .full     (b_full),
    .data_out (i_bch),
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
    .data_in  (i_arch),
    .push     (i_arvalid),
    .full     (ar_full),
    .data_out (arch),
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
    .data_in  ({rlast, rch}),
    .push     (o_rvalid),
    .full     (r_full),
    .data_out ({i_rlast,i_rch}),
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
    assign awch = i_awch;

    assign o_wvalid = i_wvalid;
    assign i_wready = o_wready;
    assign o_wlast = i_wlast;

    assign wch = i_wch;

    assign i_bvalid = o_bvalid;
    assign o_bready = i_bready;
    assign i_bch = bch;

    assign o_arvalid = i_arvalid;
    assign i_arready = o_arready;
    assign arch = i_arch;

    assign i_rvalid = o_rvalid;
    assign o_rready = i_rready;
    assign i_rlast = rlast;
    assign i_rch = rch;

    end
    endgenerate

    generate

    if (AXI_SIGNALING==0) begin : AXI4LITE_MODE

        if (USER_SUPPORT>0 && AXI_AUSER_W>0) begin: AUSER_ON

            assign {
                o_awuser,
                o_awid,
                o_awprot,
                o_awaddr
            } = awch;

            assign {
                o_aruser,
                o_arid,
                o_arprot,
                o_araddr
            }  = arch;

            end else begin: AUSER_OFF

            assign {
                o_awid,
                o_awprot,
                o_awaddr
            } = awch;

            assign {
                o_arid,
                o_arprot,
                o_araddr
            }  = arch;

            end

        end else begin : AXI4_MODE

            if (USER_SUPPORT>0 && AXI_AUSER_W>0) begin: AUSER_ON

            assign {
                o_awuser,
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
            } = awch;

            assign {
                o_aruser,
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
            } = arch;

            end else begin: AUSER_OFF

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
            } = awch;

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
            } = arch;
        end

    end

    endgenerate

    generate

        if (USER_SUPPORT>0 && AXI_WUSER_W>0) begin: WUSER_ON
            assign{o_wuser, o_wstrb, o_wdata} = wch;
        end else begin: WUSER_OFF
            assign {o_wstrb, o_wdata} = wch;
        end

    endgenerate

    generate
        if (USER_SUPPORT>0 && AXI_BUSER_W>0) begin: BUSER_ON
            assign bch = {o_buser, o_bresp, o_bid};
        end else begin: BUSER_OFF
            assign bch = {o_bresp, o_bid};
        end
    endgenerate

    generate
        if (USER_SUPPORT>0 && AXI_RUSER_W>0) begin: RUSER_ON
            assign rch = {o_ruser, o_rresp, o_rdata, o_rid};
        end else begin: RUSER_OFF
            assign rch = {o_rresp, o_rdata, o_rid};
        end
    endgenerate

    generate
        if (AXI_SIGNALING==0) begin: AXI4_LITE_RLAST
            assign rlast = 1'b1;
        end else begin: AXI4_RLAST
            assign rlast = o_rlast;
        end
    endgenerate

endmodule

`resetall
