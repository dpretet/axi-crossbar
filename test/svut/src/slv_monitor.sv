// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

`include "functions.sv"
`ifndef NODEBUG
`include "svlogger.sv"
`endif

module slv_monitor

    #(
        parameter SLV_ID = 0,

        // Address width in bits
        parameter AXI_ADDR_W = 8,
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // Enable completion check and log
        parameter CHECK_REPORT = 1,

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI4
        parameter AXI_SIGNALING = 0,

        // USER fields transport enabling (0 deactivate, 1 activate)
        parameter USER_SUPPORT = 0,
        // USER fields width in bits
        parameter AXI_AUSER_W = 0,
        parameter AXI_WUSER_W = 0,
        parameter AXI_BUSER_W = 0,
        parameter AXI_RUSER_W = 0,

        // TIMEOUT value used for response channels
        parameter TIMEOUT = 100,

        // Offset of the emulated slave
        parameter SLV_ADDR = 0,

        // Slaves mapping in the memory space
        parameter SLV0_START_ADDR = 0,
        parameter SLV0_END_ADDR = 4095,
        parameter SLV1_START_ADDR = 0,
        parameter SLV1_END_ADDR = 4095,
        parameter SLV2_START_ADDR = 0,
        parameter SLV2_END_ADDR = 4095,
        parameter SLV3_START_ADDR = 0,
        parameter SLV3_END_ADDR = 4095,

        // LFSR key init
        parameter KEY = 'hFFFFFFFF
    )(
        input  logic                      aclk,
        input  logic                      aresetn,
        input  logic                      srst,
        output logic                      error,
        input  logic                      awvalid,
        output logic                      awready,
        input  logic [AXI_ADDR_W    -1:0] awaddr,
        input  logic [8             -1:0] awlen,
        input  logic [3             -1:0] awsize,
        input  logic [2             -1:0] awburst,
        input  logic [2             -1:0] awlock,
        input  logic [4             -1:0] awcache,
        input  logic [3             -1:0] awprot,
        input  logic [4             -1:0] awqos,
        input  logic [4             -1:0] awregion,
        input  logic [AXI_ID_W      -1:0] awid,
        input  logic [AXI_AUSER_W   -1:0] awuser,
        input  logic                      wvalid,
        output logic                      wready,
        input  logic                      wlast,
        input  logic [AXI_DATA_W    -1:0] wdata,
        input  logic [AXI_DATA_W/8  -1:0] wstrb,
        input  logic [AXI_WUSER_W   -1:0] wuser,
        output logic                      bvalid,
        input  logic                      bready,
        output logic [AXI_ID_W      -1:0] bid,
        output logic [2             -1:0] bresp,
        output logic [AXI_BUSER_W   -1:0] buser,
        input  logic                      arvalid,
        output logic                      arready,
        input  logic [AXI_ADDR_W    -1:0] araddr,
        input  logic [8             -1:0] arlen,
        input  logic [3             -1:0] arsize,
        input  logic [2             -1:0] arburst,
        input  logic [2             -1:0] arlock,
        input  logic [4             -1:0] arcache,
        input  logic [3             -1:0] arprot,
        input  logic [4             -1:0] arqos,
        input  logic [4             -1:0] arregion,
        input  logic [AXI_ID_W      -1:0] arid,
        input  logic [AXI_AUSER_W   -1:0] aruser,
        output logic                      rvalid,
        input  logic                      rready,
        output logic [AXI_ID_W      -1:0] rid,
        output logic [2             -1:0] rresp,
        output logic [AXI_DATA_W    -1:0] rdata,
        output logic                      rlast,
        output logic [AXI_RUSER_W   -1:0] ruser
    );

    logic [32                          -1:0] aw_lfsr;
    logic [32                          -1:0] w_lfsr;
    logic [32                          -1:0] ar_lfsr;
    logic [32                          -1:0] b_lfsr;
    logic [32                          -1:0] r_lfsr;
    logic [32                          -1:0] awready_lfsr;
    logic [32                          -1:0] wready_lfsr;
    logic [32                          -1:0] bvalid_lfsr;
    logic [32                          -1:0] arready_lfsr;
    logic [32                          -1:0] rvalid_lfsr;
    logic                                    w_full;
    logic                                    w_empty;
    logic                                    b_full;
    logic                                    b_empty;
    logic [32                          -1:0] bresp_exp;
    logic [32                          -1:0] buser_exp;
    logic                                    r_full;
    logic                                    r_empty;
    logic                                    r_empty_r;
    logic                                    rlast_r;
    logic [32                          -1:0] rdata_exp;
    logic [32                          -1:0] rresp_exp;
    logic [32                          -1:0] ruser_exp;

    integer                                  btimer;
    integer                                  rtimer;
    logic                                    btimeout;
    logic                                    rtimeout;
    logic                                    wdata_error;
    logic [AXI_ADDR_W                  -1:0] awaddr_w;
    logic [AXI_ID_W                    -1:0] awid_w;
    logic [8                           -1:0] awlen_w;
    logic [AXI_ADDR_W                  -1:0] awaddr_b;
    logic [AXI_ID_W                    -1:0] awid_b;
    logic [AXI_DATA_W                  -1:0] next_wdata;
    logic [8                           -1:0] wbeat;
    logic                                    wlen_error;
    logic [AXI_ADDR_W                  -1:0] araddr_r;
    logic [AXI_ID_W                    -1:0] arid_r;
    logic [8                           -1:0] arlen_r;
    logic [8                           -1:0] rlen;
    logic [AXI_DATA_W                  -1:0] next_rdata;
    logic [AXI_DATA_W                  -1:0] rdata_r;


    logic                                    awsideband_error;
    logic                                    wsideband_error;
    logic                                    arsideband_error;

    logic [8                           -1:0] exp_awlen;
    logic [3                           -1:0] exp_awsize;
    logic [2                           -1:0] exp_awburst;
    logic [2                           -1:0] exp_awlock;
    logic [4                           -1:0] exp_awcache;
    logic [3                           -1:0] exp_awprot;
    logic [4                           -1:0] exp_awqos;
    logic [4                           -1:0] exp_awregion;
    logic [AXI_AUSER_W                 -1:0] exp_awuser;
    logic [AXI_AUSER_W                 -1:0] exp_wuser;

    logic [8                           -1:0] exp_arlen;
    logic [3                           -1:0] exp_arsize;
    logic [2                           -1:0] exp_arburst;
    logic [2                           -1:0] exp_arlock;
    logic [4                           -1:0] exp_arcache;
    logic [3                           -1:0] exp_arprot;
    logic [4                           -1:0] exp_arqos;
    logic [4                           -1:0] exp_arregion;
    logic [AXI_AUSER_W                 -1:0] exp_aruser;


    `ifndef NODEBUG
    // Logger setup

    svlogger log;
    string svlogger_name;

    initial begin
        $sformat(svlogger_name, "SlvMonitor%0x", SLV_ID);
        log = new(svlogger_name,
                  `SVL_VERBOSE_DEBUG,
                  `SVL_ROUTE_ALL);
    end
    `endif

    assign error = btimeout | rtimeout | wdata_error | wlen_error |
                   awsideband_error | wsideband_error | arsideband_error;

    function automatic integer gen_resp(input integer value);
        gen_resp = gen_resp_for_slave(value);
    endfunction

    ///////////////////////////////////////////////////////////////////////////
    // Write Address channel
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            awready_lfsr <= 32'b0;
        end else if (srst) begin
            awready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (awready_lfsr==32'b0) begin
                awready_lfsr <= aw_lfsr;
            // Use to randomly assert awready/wready
            end else if (~awready) begin
                awready_lfsr <= awready_lfsr >> 1;
            end else if (awvalid) begin
                awready_lfsr <= aw_lfsr;
            end
        end
    end

    lfsr32
    #(
        .KEY (KEY)
    )
    awch_lfsr
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (awvalid & awready),
        .lfsr    (aw_lfsr)
    );

    assign awready = awready_lfsr[0] & ~b_full & ~w_full;

    assign exp_awsize = gen_size(awaddr);
    assign exp_awburst = gen_burst(awaddr);
    assign exp_awlock = gen_lock(awaddr);
    assign exp_awcache = gen_cache(awaddr);
    assign exp_awprot = gen_prot(awaddr);
    assign exp_awqos = gen_qos(awaddr);
    assign exp_awregion = gen_region(awaddr);
    assign exp_awuser = gen_auser(awaddr);

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            awsideband_error <= 1'b0;
        end else if (srst) begin
            awsideband_error <= 1'b0;
        end else begin
            
            if (awvalid && awready) begin
                if (awsize != exp_awsize[2:0])
                    awsideband_error <= 1'b1;

                if (awburst != exp_awburst[1:0])
                    awsideband_error <= 1'b1;

                if (awlock != exp_awlock[1:0])
                    awsideband_error <= 1'b1;

                if (awcache != exp_awcache[3:0])
                    awsideband_error <= 1'b1;

                if (awprot != exp_awprot[2:0])
                    awsideband_error <= 1'b1;

                if (awqos != exp_awqos[3:0])
                    awsideband_error <= 1'b1;

                if (awregion != exp_awregion[3:0])
                    awsideband_error <= 1'b1;

                if (USER_SUPPORT>0 && awuser != exp_awuser[AXI_AUSER_W-1:0])
                    awsideband_error <= 1'b1;

            end else begin
                awsideband_error <= 1'b0;
            end
        end

    end

    ///////////////////////////////////////////////////////////////////////////
    // Write Data channel
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            wready_lfsr <= 32'b0;
        end else if (srst) begin
            wready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (wready_lfsr==32'b0) begin
                wready_lfsr <= w_lfsr;
            // Use to randomly assert awready/wready
            end else if (~wready) begin
                wready_lfsr <= wready_lfsr >> 1;
            end else if (wvalid) begin
                wready_lfsr <= w_lfsr;
            end
        end
    end

    lfsr32
    #(
        .KEY ({KEY[15:0],KEY[31:16]})
    )
    wch_lfsr
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (wvalid & wready & wlast),
        .lfsr    (w_lfsr)
    );


    axicb_scfifo
    #(
        .PASS_THRU  (0),
        .ADDR_WIDTH (8),
        .DATA_WIDTH (AXI_ADDR_W+AXI_ID_W+8)
    )
    wfifo
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (1'b0),
        .data_in  ({awlen,awid,awaddr}),
        .push     (awvalid & awready),
        .full     (w_full),
        .data_out ({awlen_w,awid_w,awaddr_w}),
        .pull     (wvalid & wready & wlast),
        .empty    (w_empty)
    );


    assign exp_wuser = gen_auser(awaddr_w);

    generate

    // AXI4 Support
    if (AXI_SIGNALING > 0) begin

        assign wready = wready_lfsr[0] & ~w_empty;

        always @ (posedge aclk or negedge aresetn) begin

            if (~aresetn) begin
                wbeat <= 8'h0;
                next_wdata <= {AXI_DATA_W{1'b0}};
                wdata_error <= 1'b0;
                wlen_error <= 1'b0;
                wsideband_error <= 1'b0;
            end else if (srst) begin
                wbeat <= 8'h0;
                next_wdata <= {AXI_DATA_W{1'b0}};
                wdata_error <= 1'b0;
                wlen_error <= 1'b0;
                wsideband_error <= 1'b0;
            end else begin

                if (wvalid & wready) begin
                    if (wlast) wbeat <= 8'h0;
                    else wbeat <= wbeat + 1;
                    next_wdata <= next_data(wdata);
                end

                if (wvalid & wready) begin

                    if (USER_SUPPORT>0 && wuser!=exp_wuser[AXI_WUSER_W-1:0]) begin
                        `ifndef NODEBUG
                        log.error("ERROR: WUSER received doesn't match the expected");
                        `endif
                        wsideband_error <= 1'b1;
                    end

                    if (wlast && awlen_w!=wbeat) begin
                        `ifndef NODEBUG
                        log.error("AWLEN received doesn't match AW channel setup");
                        `endif
                        wlen_error <= 1'b1;
                        $finish();
                    end else begin
                        wlen_error <= 1'b0;
                    end

                    if (wbeat!=0 && next_wdata!=wdata ||
                        wbeat==0 && gen_data(awaddr_w)!=wdata
                    ) begin
                        `ifndef NODEBUG
                        log.error("ERROR: WDATA received doesn't match the expected");
                        `endif
                        wdata_error <= 1'b1;
                        $finish();
                    end begin
                        wdata_error <= 1'b0;
                    end
                end else begin
                    wsideband_error <= 1'b0;
                end
            end
        end

    // AXI4-lite Support
    end else begin

        assign wlen_error = 1'b0;
        assign wbeat = 8'h0;
        assign wready = wready_lfsr[0] & ~w_empty;

        always @ (posedge aclk or negedge aresetn) begin

            if (~aresetn) begin
                wdata_error <= 1'b0;
                wsideband_error <= 1'b0;
            end else if (srst) begin
                wdata_error <= 1'b0;
                wsideband_error <= 1'b0;
            end else begin
                if (wvalid & wready & wlast) begin

                    if (USER_SUPPORT>0 && wuser!=exp_wuser[AXI_WUSER_W-1:0]) begin
                        `ifndef NODEBUG
                        log.error("ERROR: WUSER received doesn't match the expected");
                        `endif
                        wsideband_error <= 1'b1;
                    end

                    if (gen_data(awaddr_w) != wdata) begin
                        `ifndef NODEBUG
                        log.error("ERROR: WDATA received doesn't match the expected");
                        `endif
                        wdata_error <= 1'b1;
                        $finish();
                    end begin
                        wdata_error <= 1'b0;
                    end
                end else begin
                    wsideband_error <= 1'b0;
                end
            end
        end

    end
    endgenerate


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    axicb_scfifo
    #(
        .PASS_THRU  (0),
        .ADDR_WIDTH (8),
        .DATA_WIDTH (AXI_ID_W+AXI_ADDR_W)
    )
    bfifo
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (1'b0),
        .data_in  ({awid_w,awaddr_w}),
        .push     (wvalid & wready & wlast),
        .full     (b_full),
        .data_out ({awid_b,awaddr_b}),
        .pull     (bvalid & bready),
        .empty    (b_empty)
    );

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            bvalid_lfsr <= 32'b0;
        end else if (srst) begin
            bvalid_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (bvalid_lfsr==32'b0) begin
                bvalid_lfsr <= b_lfsr;
            // Use to randomly assert bvalid/wready
            end else if (~bvalid) begin
                bvalid_lfsr <= bvalid_lfsr >> 1;
            end else if (bready) begin
                bvalid_lfsr <= b_lfsr;
            end
        end
    end

    lfsr32
    #(
        .KEY (KEY)
    )
    bch_lfsr
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (bvalid & bready),
        .lfsr    (b_lfsr)
    );

    assign bvalid = ~b_empty & bvalid_lfsr[0];
    assign bresp_exp = gen_resp(awaddr_b/*+SLV_ADDR*/);
    assign buser_exp = gen_buser(awaddr_b/*+SLV_ADDR*/);
    assign bresp = bresp_exp[1:0];
    assign bid = (bvalid) ?  awid_b : {AXI_ID_W{1'b0}};
    assign buser = buser_exp[0+:AXI_BUSER_W];

    // Monitor BRESP channel to detect timeout
    always @ (posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            btimer <= 0;
            btimeout <= 1'b0;
        end else if (srst) begin
            btimer <= 0;
            btimeout <= 1'b0;
        end else begin
            if (bvalid && ~bready) begin
                btimer <= btimer + 1;
            end else begin
                btimer <= 0;
            end
            if (btimer >= TIMEOUT) begin
                btimeout <= 1'b1;
            end else begin
                btimeout <= 1'b0;
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////////
    // Read Address channel
    ///////////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            arready_lfsr <= 32'b0;
        end else if (srst) begin
            arready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (arready_lfsr==32'b0) begin
                arready_lfsr <= ar_lfsr;
            // Use to randomly assert arready
            end else if (~arready) begin
                arready_lfsr <= arready_lfsr >> 1;
            end else if (arvalid) begin
                arready_lfsr <= ar_lfsr;
            end
        end
    end

    assign arready = arready_lfsr[0] & ~r_full;

    lfsr32
    #(
        .KEY (KEY)
    )
    arch_lfsr
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (arvalid & arready),
        .lfsr    (ar_lfsr)
    );

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            arsideband_error <= 1'b0;
        end else if (srst) begin
            arsideband_error <= 1'b0;
        end else begin
            
            if (arvalid && arready) begin
                if (arsize != exp_arsize[2:0])
                    arsideband_error <= 1'b1;

                if (arburst != exp_arburst[1:0])
                    arsideband_error <= 1'b1;

                if (arlock != exp_arlock[1:0])
                    arsideband_error <= 1'b1;

                if (arcache != exp_arcache[3:0])
                    arsideband_error <= 1'b1;

                if (arprot != exp_arprot[2:0])
                    arsideband_error <= 1'b1;

                if (arqos != exp_arqos[3:0])
                    arsideband_error <= 1'b1;

                if (arregion != exp_arregion[3:0])
                    arsideband_error <= 1'b1;

                if (USER_SUPPORT>0 && aruser != exp_aruser[AXI_AUSER_W-1:0])
                    arsideband_error <= 1'b1;

            end else begin
                arsideband_error <= 1'b0;
            end
        end

    end

    ///////////////////////////////////////////////////////////////////////////
    // Read Response channel
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            rvalid_lfsr <= 32'b0;
        end else if (srst) begin
            rvalid_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (rvalid_lfsr==32'b0) begin
                rvalid_lfsr <= b_lfsr;
            // Use to randomly assert bvalid/wready
            end else if (~rvalid) begin
                rvalid_lfsr <= rvalid_lfsr >> 1;
            end else if (rready) begin
                rvalid_lfsr <= r_lfsr;
            end
        end
    end

    lfsr32
    #(
    .KEY (KEY)
    )
    rch_lfsr
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (rvalid & rready),
    .lfsr    (r_lfsr)
    );

    axicb_scfifo
    #(
        .PASS_THRU  (0),
        .ADDR_WIDTH (2),
        .DATA_WIDTH (AXI_ID_W+AXI_ADDR_W+8+AXI_DATA_W)
    )
    rfifo
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (1'b0),
        .data_in  ({gen_data(araddr),arlen,arid,araddr}),
        .push     (arvalid & arready),
        .full     (r_full),
        .data_out ({rdata_r,arlen_r,arid_r,araddr_r}),
        .pull     (rvalid & rready & rlast),
        .empty    (r_empty)
    );

    assign rid = arid_r;
    assign rresp_exp = gen_resp(araddr_r/*+SLV_ADDR*/);
    assign rresp = rresp_exp[0+:2];
    assign ruser_exp = gen_ruser(araddr_r/*+SLV_ADDR*/);
    assign ruser = ruser_exp[0+:AXI_RUSER_W];

    generate
    if (AXI_SIGNALING > 0) begin

        assign rvalid = rvalid_lfsr[0] & (~r_empty_r & ~r_empty);
        assign rdata = (rlen==8'h0) ? rdata_r : next_rdata;
        assign rlast = (rlen==arlen_r) ? 1'b1 : 1'b0;

        always @ (posedge aclk or negedge aresetn) begin
            if (~aresetn) begin
                rlen <= 8'h0;
                next_rdata <= {AXI_DATA_W{1'b0}};
                r_empty_r <= 1'b0;
                rlast_r <= 1'b0;
            end else if (srst) begin
                rlen <= 8'h0;
                next_rdata <= {AXI_DATA_W{1'b0}};
                r_empty_r <= 1'b0;
                rlast_r <= 1'b0;
            end else begin

                r_empty_r <= r_empty;
                rlast_r <= rlast;

                // Was empty, but now it's filled with new request
                if (!r_empty && r_empty_r) begin
                    next_rdata <= rdata_r;
                // FIFO is filled and last request has been fully transmitted
                end else if (!r_empty && rlen==8'h0 && rlast_r==1'b1) begin
                    next_rdata <= next_data(rdata_r);
                // Under a request processing
                end else if (rvalid && rready) begin
                    next_rdata <= next_data(rdata);
                end

                if (!r_empty) begin
                    if (rvalid && rready && rlen==arlen_r) rlen <= 8'h0;
                    else if (rvalid && rready) rlen <= rlen + 1;
                end else begin
                    rlen <= 8'h0;
                end
            end
        end

    end else begin

        assign rvalid = rvalid_lfsr[0] & ~r_empty;
        assign rdata = rdata_r;
        assign rlast = 1'b1;

    end
    endgenerate

    // Monitor RDATA channel to detect timeout
    always @ (posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            rtimer <= 0;
            rtimeout <= 1'b0;
        end else if (srst) begin
            rtimer <= 0;
            rtimeout <= 1'b0;
        end else begin
            if (rvalid && ~rready) begin
                rtimer <= rtimer + 1;
            end else begin
                rtimer <= 0;
            end
            if (rtimer >= TIMEOUT) begin
                `ifndef NODEBUG
                log.error("R Channel reached timeout");
                `endif
                rtimeout <= 1'b1;
            end else begin
                rtimeout <= 1'b0;
            end
        end
    end
endmodule

`resetall

