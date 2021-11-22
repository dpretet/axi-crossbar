// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

`include "functions.sv"
`include "svlogger.sv"

module mst_driver

    #(
        // Address width in bits
        parameter AXI_ADDR_W = 8,
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // ID assigned to the master
        parameter MST_ID = 'h10,
        parameter MST_ROUTES = 4'b1_1_1_1,

        // Maximum number of OR that can be issued
        parameter MST_OSTDREQ_NUM = 4,

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI4
        parameter AXI_SIGNALING = 0,

        // Enable completion check and log
        parameter CHECK_REPORT = 1,

        // USER sideband support ans setup
        parameter USER_SUPPORT = 0,
        parameter AXI_AUSER_W = 4,
        parameter AXI_WUSER_W = 4,
        parameter AXI_BUSER_W = 4,
        parameter AXI_RUSER_W = 4,

        // Timeout value used outstanding request monitoring
        // and channels handshakes
        parameter TIMEOUT = 100,

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
        input  logic                      en,
        input  logic [AXI_ADDR_W    -1:0] addr_min,
        input  logic [AXI_ADDR_W    -1:0] addr_max,
        output logic                      error,
        output logic                      awvalid,
        input  logic                      awready,
        output logic [AXI_ADDR_W    -1:0] awaddr,
        output logic [8             -1:0] awlen,
        output logic [3             -1:0] awsize,
        output logic [2             -1:0] awburst,
        output logic [2             -1:0] awlock,
        output logic [4             -1:0] awcache,
        output logic [3             -1:0] awprot,
        output logic [4             -1:0] awqos,
        output logic [4             -1:0] awregion,
        output logic [AXI_ID_W      -1:0] awid,
        output logic [AXI_AUSER_W   -1:0] awuser,
        output logic                      wvalid,
        input  logic                      wready,
        output logic                      wlast,
        output logic [AXI_DATA_W    -1:0] wdata,
        output logic [AXI_DATA_W/8  -1:0] wstrb,
        output logic [AXI_WUSER_W   -1:0] wuser,
        input  logic                      bvalid,
        output logic                      bready,
        input  logic [AXI_ID_W      -1:0] bid,
        input  logic [2             -1:0] bresp,
        input  logic [AXI_BUSER_W   -1:0] buser,
        output logic                      arvalid,
        input  logic                      arready,
        output logic [AXI_ADDR_W    -1:0] araddr,
        output logic [8             -1:0] arlen,
        output logic [3             -1:0] arsize,
        output logic [2             -1:0] arburst,
        output logic [2             -1:0] arlock,
        output logic [4             -1:0] arcache,
        output logic [3             -1:0] arprot,
        output logic [4             -1:0] arqos,
        output logic [4             -1:0] arregion,
        output logic [AXI_ID_W      -1:0] arid,
        output logic [AXI_AUSER_W   -1:0] aruser,
        input  logic                      rvalid,
        output logic                      rready,
        input  logic [AXI_ID_W      -1:0] rid,
        input  logic [2             -1:0] rresp,
        input  logic [AXI_DATA_W    -1:0] rdata,
        input  logic                      rlast,
        input  logic [AXI_RUSER_W   -1:0] ruser
    );

    logic [32                          -1:0] awaddr_ramp;
    logic [32                          -1:0] araddr_ramp;
    logic [AXI_ID_W                    -1:0] awid_cnt;
    logic [AXI_ID_W                    -1:0] arid_cnt;
    logic [32                          -1:0] aw_lfsr;
    logic [32                          -1:0] ar_lfsr;
    logic [32                          -1:0] r_lfsr;
    logic [32                          -1:0] b_lfsr;
    logic [32                          -1:0] awvalid_lfsr;
    logic [32                          -1:0] wvalid_lfsr;
    logic [8                           -1:0] awlen_w;
    logic [8                           -1:0] wlen;
    logic [AXI_DATA_W                  -1:0] wdata_w;
    logic [AXI_DATA_W                  -1:0] next_wdata;
    logic [32                          -1:0] arvalid_lfsr;
    logic [32                          -1:0] bready_lfsr;
    logic [32                          -1:0] rready_lfsr;
    logic [MST_OSTDREQ_NUM             -1:0] wr_orreq;
    logic [MST_OSTDREQ_NUM*AXI_ID_W    -1:0] wr_orreq_id;
    logic [MST_OSTDREQ_NUM*2           -1:0] wr_orreq_bresp;
    logic [MST_OSTDREQ_NUM*AXI_BUSER_W -1:0] wr_orreq_buser;
    logic [MST_OSTDREQ_NUM             -1:0] rd_orreq;
    logic [MST_OSTDREQ_NUM*AXI_ID_W    -1:0] rd_orreq_id;
    logic [MST_OSTDREQ_NUM*AXI_DATA_W  -1:0] rd_orreq_rdata;
    logic [MST_OSTDREQ_NUM*2           -1:0] rd_orreq_rresp;
    logic [MST_OSTDREQ_NUM*AXI_RUSER_W -1:0] rd_orreq_ruser;
    logic [MST_OSTDREQ_NUM*8           -1:0] rd_orreq_rlen;
    logic [MST_OSTDREQ_NUM*8           -1:0] rlen;
    logic [MST_OSTDREQ_NUM             -1:0] bresp_error;
    logic [MST_OSTDREQ_NUM             -1:0] buser_error;
    logic [MST_OSTDREQ_NUM             -1:0] rresp_error;
    logic [MST_OSTDREQ_NUM             -1:0] ruser_error;
    logic [MST_OSTDREQ_NUM             -1:0] wor_error;
    logic [MST_OSTDREQ_NUM             -1:0] ror_error;
    logic [MST_OSTDREQ_NUM             -1:0] rlen_error;
    logic [MST_OSTDREQ_NUM             -1:0] rid_error;
    logic [MST_OSTDREQ_NUM             -1:0] bid_error;
    logic [MST_OSTDREQ_NUM             -1:0] wr_orreq_mr;
    logic [MST_OSTDREQ_NUM             -1:0] rd_orreq_mr;
    integer                                  wr_orreq_timeout[MST_OSTDREQ_NUM-1:0];
    integer                                  rd_orreq_timeout[MST_OSTDREQ_NUM-1:0];
    integer                                  awtimer;
    integer                                  wtimer;
    integer                                  artimer;
    logic                                    awtimeout;
    logic                                    wtimeout;
    logic                                    artimeout;
    logic                                    w_full;
    logic                                    w_empty;
    logic                                    w_empty_r;
    logic                                    wlast_r;

    // Logger setup

    svlogger log;
    string svlogger_name;
    string msg;

    initial begin
        $sformat(svlogger_name, "MstDriver%x", MST_ID);
        log = new(svlogger_name,
                  `SVL_VERBOSE_DEBUG,
                  `SVL_ROUTE_ALL);
    end

    function automatic integer gen_resp(input integer value);
        gen_resp = gen_resp_for_master(
            MST_ROUTES,
            SLV0_START_ADDR,
            SLV0_END_ADDR,
            SLV1_START_ADDR,
            SLV1_END_ADDR,
            SLV2_START_ADDR,
            SLV2_END_ADDR,
            SLV3_START_ADDR,
            SLV3_END_ADDR,
            value
        );
    endfunction

    function automatic integer req_is_misroute(input integer value);
        req_is_misroute = is_misroute(
            MST_ROUTES,
            SLV0_START_ADDR,
            SLV0_END_ADDR,
            SLV1_START_ADDR,
            SLV1_END_ADDR,
            SLV2_START_ADDR,
            SLV2_END_ADDR,
            SLV3_START_ADDR,
            SLV3_END_ADDR,
            value
        );
    endfunction

    ///////////////////////////////////////////////////////////////////////////
    // Write Address & Data Channels
    ///////////////////////////////////////////////////////////////////////////

    assign awsize = gen_size(awaddr);
    assign awburst = gen_burst(awaddr);
    assign awlock = gen_lock(awaddr);
    assign awcache = gen_cache(awaddr);
    assign awprot = gen_prot(awaddr);
    assign awqos = gen_qos(awaddr);
    assign awregion = gen_region(awaddr);
    assign awuser = gen_auser(awaddr);
    assign awid = MST_ID + awid_cnt;


    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            awvalid_lfsr <= 32'b0;
            wvalid_lfsr <= 32'b0;
            awid_cnt <= {AXI_ID_W{1'b0}};
        end else if (srst) begin
            awvalid_lfsr <= 32'b0;
            wvalid_lfsr <= 32'b0;
            awid_cnt <= {AXI_ID_W{1'b0}};
        end else if (en) begin

            // At startup init with LFSR default value
            if (awvalid_lfsr==32'b0) begin
                awvalid_lfsr <= aw_lfsr;
            // Use to randomly assert awvalid/wvalid
            end else if (~awvalid) begin
                awvalid_lfsr <= awvalid_lfsr >> 1;
            end else if (awready) begin
                awvalid_lfsr <= aw_lfsr;
            end

            // At startup init with LFSR default value
            if (wvalid_lfsr==32'b0) begin
                wvalid_lfsr <= {aw_lfsr[15:0],aw_lfsr[31:16]};
            // Use to randomly assert awvalid/wvalid
            end else if (~wvalid) begin
                wvalid_lfsr <= wvalid_lfsr >> 1;
            end else if (wready) begin
                wvalid_lfsr <= aw_lfsr;
            end

            // ID counter
            if (awvalid && awready) begin
                if (awid_cnt==(MST_OSTDREQ_NUM-1)) awid_cnt <= 'h0;
                else awid_cnt <= awid_cnt + 1;
            end
        end
    end

    // LFSR to generate valid of AW / W channels
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

    // A ramp used in address field when the generated one is out of
    // min/max bound
    always @ (posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            awaddr_ramp <= 32'b0;
        end else if (srst) begin
            awaddr_ramp <= 32'b0;
        end else begin
            if (awvalid & awready) begin
                if (awaddr_ramp >= (addr_max-16))
                    awaddr_ramp <= 32'b0;
                else
                    awaddr_ramp <= awaddr_ramp + 4;
            end
        end
    end

    assign awvalid = awvalid_lfsr[0] & en & ~wr_orreq[awid_cnt] & ~w_full;
    // Limit the address range to target possibly a particular slave
    // Always use aligned address
    assign awaddr = (aw_lfsr[AXI_ADDR_W-1:0]>addr_max) ? {awaddr_ramp[AXI_ADDR_W-1:2], 2'h0} :
                    (aw_lfsr[AXI_ADDR_W-1:0]<addr_min) ? {awaddr_ramp[AXI_ADDR_W-1:2], 2'h0} :
                                                         {aw_lfsr[AXI_ADDR_W-1:2], 2'h0} ;

    generate
    if (AXI_SIGNALING>0) assign awlen = {3'h0, awaddr[4:0]};
    else assign awlen = 8'b0;
    endgenerate

    axicb_scfifo
    #(
        .PASS_THRU  (0),
        .ADDR_WIDTH (8),
        .DATA_WIDTH (AXI_DATA_W+8)
    )
    wfifo
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (1'b0),
        .data_in  ({awlen, gen_data(awaddr)}),
        .push     (awvalid & awready),
        .full     (w_full),
        .data_out ({awlen_w, wdata_w}),
        .pull     (wvalid & wready & wlast),
        .empty    (w_empty)
    );

    generate
    if (AXI_SIGNALING > 0) begin

        assign wvalid = wvalid_lfsr[0] & en & ~w_empty_r;
        assign wdata = (wlen==8'h0) ? wdata_w : next_wdata;
        assign wstrb = {AXI_DATA_W/8{1'b1}};
        assign wlast = (wlen==awlen_w) ? 1'b1 : 1'b0;
        assign wuser = gen_auser(wdata_w);

        always @ (posedge aclk or negedge aresetn) begin
            if (~aresetn) begin
                wlen <= 8'h0;
                next_wdata <= {AXI_DATA_W{1'b0}};
                w_empty_r <= 1'b0;
                wlast_r <= 1'b0;
            end else if (srst) begin
                wlen <= 8'h0;
                next_wdata <= {AXI_DATA_W{1'b0}};
                w_empty_r <= 1'b0;
                wlast_r <= 1'b0;
            end else if (en) begin

                w_empty_r <= w_empty;
                wlast_r <= wlast;

                // Was empty, but now it's filled with new request
                if (!w_empty && w_empty_r) begin
                    next_wdata <= wdata_w;
                // FIFO is filled and last request has been fully transmitted
                end else if (!w_empty && wlen==8'h0 && wlast_r==1'b1) begin
                    next_wdata <= next_data(wdata_w);
                // Under a request processing
                end else if (wvalid && wready) begin
                    next_wdata <= next_data(wdata);
                end

                if (!w_empty) begin
                    if (wvalid && wready && wlen==awlen_w) wlen <= 8'h0;
                    else if (wvalid && wready) wlen <= wlen + 1;
                end else begin
                    wlen <= 8'h0;
                end
            end
        end

    end else begin

        assign wvalid = wvalid_lfsr[0] & en & ~w_empty;
        assign wdata = wdata_w;
        assign wstrb = {AXI_DATA_W/8{1'b1}};
        assign wlast = 1'b1;
        assign wuser = gen_auser(wdata_w);

    end
    endgenerate

    ///////////////////////////////////////////////////////////////////////////////
    // Monitor AW/W channel to detect timeout
    ///////////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            awtimer <= 0;
            awtimeout <= 1'b0;
            wtimer <= 0;
            wtimeout <= 1'b0;
        end else if (srst) begin
            awtimer <= 0;
            awtimeout <= 1'b0;
            wtimer <= 0;
            wtimeout <= 1'b0;
        end else if (en) begin
            if (awvalid && ~awready) begin
                awtimer <= awtimer + 1;
            end else begin
                awtimer <= 0;
            end
            if (awtimer >= TIMEOUT) begin
                log.error("AW Channel reached timeout");
                awtimeout <= 1'b1;
            end else begin
                awtimeout <= 1'b0;
            end
            if (wvalid && ~wready) begin
                wtimer <= wtimer + 1;
            end else begin
                wtimer <= 0;
            end
            if (wtimer >= TIMEOUT) begin
                wtimeout <= 1'b1;
                log.error("W Channel reached timeout");
            end else begin
                wtimeout <= 1'b0;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////////
    // Write Oustanding Requests Management
    ///////////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin

            wr_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            wr_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            wr_orreq_bresp <= {MST_OSTDREQ_NUM*2{1'b0}};
            wr_orreq_buser <= {MST_OSTDREQ_NUM*AXI_BUSER_W{1'b0}};
            wr_orreq_mr <= {MST_OSTDREQ_NUM{1'b0}};
            bresp_error <= {MST_OSTDREQ_NUM{1'b0}};
            buser_error <= {MST_OSTDREQ_NUM{1'b0}};
            bid_error <= {MST_OSTDREQ_NUM{1'b0}};
            wor_error <= {MST_OSTDREQ_NUM{1'b0}};

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                wr_orreq_timeout[i] <= 0;
            end

        end else if (srst) begin

            wr_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            wr_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            wr_orreq_bresp <= {MST_OSTDREQ_NUM*2{1'b0}};
            wr_orreq_buser <= {MST_OSTDREQ_NUM*AXI_BUSER_W{1'b0}};
            wr_orreq_mr <= {MST_OSTDREQ_NUM{1'b0}};
            bresp_error <= {MST_OSTDREQ_NUM{1'b0}};
            buser_error <= {MST_OSTDREQ_NUM{1'b0}};
            wor_error <= {MST_OSTDREQ_NUM{1'b0}};

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                wr_orreq_timeout[i] <= 0;
            end

        end else if (en) begin

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin

                if (bvalid && bready) begin
                    if ((bid&MST_ID) != MST_ID) begin
                        $sformat(msg, "Received a completion not addressed to the right master (BID=%0x)", bid);
                        log.error(msg);
                        bid_error[i] <= 1'b1;
                    end else begin
                        bid_error[i] <= 1'b0;
                    end
                end

                // Store the OR request on address channel handshake
                if (awvalid && awready && i==awid_cnt) begin
                    wr_orreq[i] <= 1'b1;
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= awid;
                    wr_orreq_bresp[i*2+:2] <= gen_resp(awaddr);
                    wr_orreq_buser[i*AXI_BUSER_W+:AXI_BUSER_W] <= gen_buser(awaddr);
                    wr_orreq_mr[i] <= req_is_misroute(awaddr);
                end

                // Release the OR on response handshake
                if (bvalid && bready && wr_orreq[i] &&
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W]==bid)
                begin

                    wr_orreq[i] <= 1'b0;
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= {AXI_ID_W{1'b0}};
                    wr_orreq_bresp[i*2+:2] <= 2'b0;
                    wr_orreq_buser[i*AXI_BUSER_W+:AXI_BUSER_W] <= {AXI_BUSER_W{1'b0}};

                    if (wr_orreq_bresp[i*2+:2] !== bresp && CHECK_REPORT) begin
                        log.error("BRESP doesn't match expected value");
                        $sformat(msg, "  - BID: %x", bid); log.error(msg);
                        $sformat(msg, "  - BRESP: %x", bresp); log.error(msg);
                        $sformat(msg, "  - Expected BRESP: %x", wr_orreq_bresp[i*2+:2]); log.error(msg);
                        bresp_error[i] <= 1'b1;
                    end else begin

                        if (wr_orreq_buser[i*AXI_BUSER_W+:AXI_BUSER_W] !== buser &&
                            !wr_orreq_mr[i] && USER_SUPPORT && CHECK_REPORT
                        ) begin
                            log.error("BUSER doesn't match expected value");
                            $sformat(msg, "  - BID: %x", bid); log.error(msg);
                            $sformat(msg, "  - BUSER: %x", buser); log.error(msg);
                            $sformat(msg, "  - Expected BUSER: %x", wr_orreq_buser[i*AXI_BUSER_W+:AXI_BUSER_W]); log.error(msg);
                            buser_error[i] <= 1'b1;
                        end

                    end

                end else begin
                    bresp_error[i] <= 1'b0;
                    buser_error[i] <= 1'b0;
                end

                // Manage OR timeout
                if (wr_orreq[i]) begin
                    if (wr_orreq_timeout[i]==TIMEOUT) begin
                        $sformat(msg, "Write OR %0x reached timeout (MST_ID: %0x)", i, MST_ID);
                        log.error(msg);
                        wor_error[i] <= 1'b1;
                    end
                    if (wr_orreq_timeout[i]<=TIMEOUT) begin
                        wr_orreq_timeout[i] <= wr_orreq_timeout[i] + 1;
                    end
                end else begin
                    wr_orreq_timeout[i] <= 0;
                    wor_error[i] <= 1'b0;
                end
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            bready_lfsr <= 32'b0;
        end else if (srst) begin
            bready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (bready_lfsr==32'b0) begin
                bready_lfsr <= b_lfsr;
            // Use to randomly assert arready
            end else if (~bready) begin
                bready_lfsr <= bready_lfsr >> 1;
            end else if (bvalid) begin
                bready_lfsr <= b_lfsr;
            end
        end
    end

    assign bready = bready_lfsr[0];

    // LFSR to generate valid of B channels
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


    ///////////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////////

    assign arsize = gen_size(araddr);
    assign arburst = gen_burst(araddr);
    assign arlock = gen_lock(araddr);
    assign arcache = gen_cache(araddr);
    assign arprot = gen_prot(araddr);
    assign arqos = gen_qos(araddr);
    assign arregion = gen_region(araddr);
    assign aruser = gen_auser(araddr);
    assign arid = MST_ID + arid_cnt;

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            arvalid_lfsr <= 32'b0;
            arid_cnt <= {AXI_ID_W{1'b0}};
        end else if (srst) begin
            arvalid_lfsr <= 32'b0;
            arid_cnt <= {AXI_ID_W{1'b0}};
        end else if (en) begin

            // At startup init with LFSR default value
            if (arvalid_lfsr==32'b0) begin
                arvalid_lfsr <= ar_lfsr;
            // Use to randomly assert arvalid/wvalid
            end else if (~arvalid) begin
                arvalid_lfsr <= arvalid_lfsr >> 1;
            end else if (arready) begin
                arvalid_lfsr <= ar_lfsr;
            end

            // ID counter
            if (arvalid && arready) begin
                if (arid_cnt==(MST_OSTDREQ_NUM-1)) arid_cnt <= 'h0;
                else arid_cnt <= arid_cnt + 1;
            end
        end
    end

    // LFSR to generate valid of AR channel
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

    // A ramp used in address field when generated one is out of
    // min/max bound
    always @ (posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            araddr_ramp <= 32'b0;
        end else if (srst) begin
            araddr_ramp <= 32'b0;
        end else begin
            if (arvalid & arready) begin
                if (araddr_ramp >= (addr_max-16))
                    araddr_ramp <= 32'b0;
                else
                    araddr_ramp <= araddr_ramp + 4;
            end
        end
    end

    // Limit the address range to target possibly a particular slave
    // Always use aligned address
    assign araddr = (ar_lfsr[AXI_ADDR_W-1:0]>addr_max) ? {araddr_ramp} :
                    (ar_lfsr[AXI_ADDR_W-1:0]<addr_min) ? {araddr_ramp} :
                                                         {ar_lfsr[AXI_ADDR_W-1:2], 2'h0} ;

    assign arvalid = arvalid_lfsr[0] & en & ~rd_orreq[arid_cnt];

    generate
    if (AXI_SIGNALING>0) assign arlen = {3'h0, araddr[4:0]};
    else assign arlen = 8'b0;
    endgenerate

    ///////////////////////////////////////////////////////////////////////////
    // Monitor AR channel to detect timeout
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            artimer <= 0;
            artimeout <= 1'b0;
        end else if (srst) begin
            artimer <= 0;
            artimeout <= 1'b0;
        end else if (en) begin
            if (arvalid && ~arready) begin
                artimer <= artimer + 1;
            end else begin
                artimer <= 0;
            end
            if (artimer >= TIMEOUT) begin
                artimeout <= 1'b1;
                log.error("AR Channel reached timeout");
            end else begin
                artimeout <= 1'b0;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Read Response channel
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            rready_lfsr <= 32'b0;
        end else if (srst) begin
            rready_lfsr <= 32'b0;
        end else begin
            // At startup init with LFSR default value
            if (rready_lfsr==32'b0) begin
                rready_lfsr <= r_lfsr;
            // Use to randomly assert arready
            end else if (~rready) begin
                rready_lfsr <= rready_lfsr >> 1;
            end else if (rvalid) begin
                rready_lfsr <= r_lfsr;
            end
        end
    end

    assign rready = rready_lfsr[0];

    // LFSR to generate valid of R channel
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


    ///////////////////////////////////////////////////////////////////////////////
    // Read Oustanding Requests Management
    ///////////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin

            rd_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            rd_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            rd_orreq_rdata <= {MST_OSTDREQ_NUM*AXI_DATA_W{1'b0}};
            rd_orreq_rresp <= {MST_OSTDREQ_NUM*2{1'b0}};
            rd_orreq_ruser <= {MST_OSTDREQ_NUM*AXI_RUSER_W{1'b0}};
            rd_orreq_rlen <= {MST_OSTDREQ_NUM*8{1'b0}};
            rresp_error <= {MST_OSTDREQ_NUM{1'b0}};
            ruser_error <= {MST_OSTDREQ_NUM{1'b0}};
            ror_error <= {MST_OSTDREQ_NUM{1'b0}};
            rlen_error <= {MST_OSTDREQ_NUM{1'b0}};
            rid_error <= {MST_OSTDREQ_NUM{1'b0}};
            rd_orreq_mr <= {MST_OSTDREQ_NUM{1'b0}};
            rlen <= {MST_OSTDREQ_NUM*8{1'b0}};

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                rd_orreq_timeout[i] <= 0;
            end

        end else if (srst) begin

            rd_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            rd_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            rd_orreq_rdata <= {MST_OSTDREQ_NUM*AXI_DATA_W{1'b0}};
            rd_orreq_rresp <= {MST_OSTDREQ_NUM*2{1'b0}};
            rd_orreq_ruser <= {MST_OSTDREQ_NUM*AXI_RUSER_W{1'b0}};
            rd_orreq_rlen <= {MST_OSTDREQ_NUM*8{1'b0}};
            rresp_error <= {MST_OSTDREQ_NUM{1'b0}};
            ruser_error <= {MST_OSTDREQ_NUM{1'b0}};
            ror_error <= {MST_OSTDREQ_NUM{1'b0}};
            rlen_error <= {MST_OSTDREQ_NUM{1'b0}};
            rid_error <= {MST_OSTDREQ_NUM{1'b0}};
            rd_orreq_mr <= {MST_OSTDREQ_NUM{1'b0}};
            rlen <= {MST_OSTDREQ_NUM*8{1'b0}};

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                rd_orreq_timeout[i] <= 0;
            end

        end else if (en) begin

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin

                // Store the OR request on address channel handshake
                if (arvalid && arready && i==arid_cnt) begin
                    rd_orreq[i] <= 1'b1;
                    rd_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= arid;
                    rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W] <= gen_data(araddr);
                    rd_orreq_rresp[i*2+:2] <= gen_resp(araddr);
                    rd_orreq_rlen[i*8+:8] <= arlen;
                    rd_orreq_ruser[i*AXI_RUSER_W+:AXI_RUSER_W] <= gen_ruser(araddr);
                    rd_orreq_mr[i] <= req_is_misroute(araddr);
                // And release the OR when handshaking with RLAST
                end else if (rvalid && rready && rlast && 
                             rd_orreq_id[i*AXI_ID_W+:AXI_ID_W]==rid) 
                begin
                    rd_orreq[i] <= 1'b0;
                end

                // Check the completion is supposed to reach this master
                if (rvalid && rready) begin
                    if ((rid&MST_ID) != MST_ID) begin
                        $sformat(msg, "Received a completion not addressed to the right master (RID=%0x)", rid);
                        log.error(msg);
                        rid_error[i] <= 1'b1;
                    end else begin
                        rid_error[i] <= 1'b0;
                    end
                end

                // Release the OR once read data channel hanshakes
                if (rvalid && rready && rd_orreq[i] &&
                    rd_orreq_id[i*AXI_ID_W+:AXI_ID_W]==rid)
                begin

                    if (rlast) begin
                        rlen[i*8+:8] <= 0;
                    end else begin
                        rlen[i*8+:8] <= rlen[i*8+:8] + 1;
                    end

                    rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W] <= next_data(rdata);

                    if (rd_orreq_ruser[i*AXI_RUSER_W+:AXI_RUSER_W] != ruser &&
                        !rd_orreq_mr[i] && USER_SUPPORT && CHECK_REPORT)
                    begin
                        log.error("RUSER doesn't match expected value");
                        ruser_error[i] <= 1'b1;
                    end

                    if (rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W] != rdata &&
                        !rd_orreq_mr[i] && CHECK_REPORT)
                    begin
                        log.error("RDATA doesn't match the expected value:");
                        $sformat(msg, "  - RID: %x", rid); log.error(msg);
                        $sformat(msg, "  - RDATA: %x", rdata); log.error(msg);
                        $sformat(msg, "  - Expected RDATA: %x", rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W]); log.error(msg);
                        rresp_error[i] <= 1'b1;
                    end

                    if (rd_orreq_rresp[i*2+:2] != rresp &&
                        CHECK_REPORT)
                    begin
                        log.error("RRESP doesn't match the expected value:");
                        $sformat(msg, "  - RID: %x", rid); log.error(msg);
                        $sformat(msg, "  - RRESP: %x", rresp); log.error(msg);
                        $sformat(msg, "  - Expected RRESP: %x", rd_orreq_rresp[i*2+:2]); log.error(msg);
                        rresp_error[i] <= 1'b1;
                    end

                    if (rlast && rd_orreq_rlen[i*8+:8] != rlen[i*8+:8] &&
                        CHECK_REPORT)
                    begin
                        log.error("ARLEN doesn't match the expected beats:");
                        $sformat(msg, "  - RID: %x", rid); log.error(msg);
                        $sformat(msg, "  - ARLEN: %x", rlen[i*8+:8]); log.error(msg);
                        $sformat(msg, "  - Expected ARLEN: %x", rd_orreq_rlen[i*8+:8]); log.error(msg);
                        rlen_error[i] <= 1'b1;
                    end

                end else begin
                    rresp_error[i] <= 1'b0;
                    ruser_error[i] <= 1'b0;
                    rlen_error[i] <= 1'b0;
                end

                // Manage OR timeout
                if (rd_orreq[i]) begin
                    if (rd_orreq_timeout[i]==TIMEOUT) begin
                        $sformat(msg, "ERROR: Read OR %0x reached timeout (@ %g ns) (MST_ID: %0x)", i, $realtime, MST_ID);
                        log.error(msg);
                        ror_error[i] <= 1'b1;
                    end
                    if (rd_orreq_timeout[i]<=TIMEOUT) begin
                        rd_orreq_timeout[i] <= rd_orreq_timeout[i] + 1;
                    end
                end else begin
                    rd_orreq_timeout[i] <= 0;
                    ror_error[i] <= 1'b0;
                end
            end
        end
    end

    // Error report to the testbench
    assign error = (en) ?

                    (|bresp_error | |buser_error | |rresp_error | |ruser_error |
                    |wor_error | |ror_error | |bid_error | |rid_error | |rlen_error |
                    awtimeout | wtimeout | artimeout) : 1'b0;

endmodule

`resetall
