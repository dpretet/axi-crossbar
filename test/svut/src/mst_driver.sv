// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

`include "functions.sv"
`include "svut_h.sv"

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

        // Maximum number of OR that can be issued
        parameter MST_OSTDREQ_NUM = 4,

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: Restricted AXI4 (INCR mode, ADDR, ALEN)
        //   - 2: Complete
        parameter AXI_SIGNALING = 0,

        // Enable completion check and log
        parameter CHECK_REPORT = 1,

        // Timeout value used outstanding request monitoring
        // and channels handshakes
        parameter TIMEOUT = 100,

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
        output logic                      wvalid,
        input  logic                      wready,
        output logic                      wlast,
        output logic [AXI_DATA_W    -1:0] wdata,
        output logic [AXI_DATA_W/8  -1:0] wstrb,
        input  logic                      bvalid,
        output logic                      bready,
        input  logic [AXI_ID_W      -1:0] bid,
        input  logic [2             -1:0] bresp,
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
        input  logic                      rvalid,
        output logic                      rready,
        input  logic [AXI_ID_W      -1:0] rid,
        input  logic [2             -1:0] rresp,
        input  logic [AXI_DATA_W    -1:0] rdata,
        input  logic                      rlast
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
    logic [32                          -1:0] arvalid_lfsr;
    logic [32                          -1:0] bready_lfsr;
    logic [32                          -1:0] rready_lfsr;
    logic [MST_OSTDREQ_NUM             -1:0] wr_orreq;
    logic [MST_OSTDREQ_NUM*AXI_ID_W    -1:0] wr_orreq_id;
    logic [MST_OSTDREQ_NUM*2           -1:0] wr_orreq_resp;
    logic [MST_OSTDREQ_NUM             -1:0] rd_orreq;
    logic [MST_OSTDREQ_NUM*AXI_ID_W    -1:0] rd_orreq_id;
    logic [MST_OSTDREQ_NUM*AXI_DATA_W  -1:0] rd_orreq_rdata;
    logic [MST_OSTDREQ_NUM*2           -1:0] rd_orreq_rresp;
    logic                                    bresp_error;
    logic                                    rresp_error;
    logic                                    wor_error;
    logic                                    ror_error;
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

    `SVUT_SETUP

    ///////////////////////////////////////////////////////////////////////////
    // Write Address & Data Channels
    ///////////////////////////////////////////////////////////////////////////

    assign awlen = 0;
    assign awsize = 0 ;
    assign awburst = 1;
    assign awlock = 0;
    assign awcache = 0;
    assign awprot = 0;
    assign awqos = 0;
    assign awregion = 0;
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
                wvalid_lfsr <= aw_lfsr;
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

    // A ramp used in address field when generated one is out of 
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

    axicb_scfifo 
    #(
        .PASS_THRU  (0),
        .ADDR_WIDTH (8),
        .DATA_WIDTH (AXI_DATA_W)
    )
    wfifo 
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (1'b0),
        .data_in  (gen_data(awaddr)),
        .push     (awvalid & awready),
        .full     (w_full),
        .data_out (wdata),
        .pull     (wvalid & wready & wlast),
        .empty    (w_empty)
    );

    assign wvalid = wvalid_lfsr[0] & en & ~w_empty;
    assign wstrb = {AXI_DATA_W/8{1'b1}};
    assign wlast = 1'b1;

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
                `ERROR("AW Channel reached timeout");
                $display("  - MST_ID=%0x", MST_ID);
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
                `ERROR("W Channel reached timeout");
                $display("  - MST_ID=%0x", MST_ID);
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
            wr_orreq_resp <= {MST_OSTDREQ_NUM*2{1'b0}};
            bresp_error <= 1'b0;
            wor_error <= 1'b0;

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                wr_orreq_timeout[i] <= 0;
            end

        end else if (srst) begin

            wr_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            wr_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            wr_orreq_resp <= {MST_OSTDREQ_NUM*2{1'b0}};
            bresp_error <= 1'b0;
            wor_error <= 1'b0;

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                wr_orreq_timeout[i] <= 0;
            end

        end else begin

            if (bvalid && bready) begin
                if ((bid&MST_ID) != MST_ID) begin
                    `ERROR("Received a completion not addressed to the right master");
                    $display("  - MST_ID=%0x", MST_ID);
                    $display("  - BID=%0x", bid);
                    $display("  - EN=%0x", en);
                    @(posedge aclk);
                    $finish();
                end
            end

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin

                // Store the OR request on address channel handshake
                if (awvalid && awready && i==awid_cnt) begin
                    wr_orreq[i] <= 1'b1;
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= awid;
                    wr_orreq_resp[i*2+:2] <= gen_resp(awaddr);
                end

                // Release the OR on response handshake
                if (bvalid && bready && wr_orreq[i] &&
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W]==bid)
                begin

                    wr_orreq[i] <= 1'b0;
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= {AXI_ID_W{1'b0}};
                    wr_orreq_resp[i*2+:2] <= 2'b0;

                    if (wr_orreq_resp[i*2+:2] !== bresp && CHECK_REPORT) begin
                        `ERROR("BRESP doesn't match expected value");
                        $display("  - BID: %x", bid);
                        $display("  - BRESP: %x", bresp);
                        $display("  - Expected BRESP: %x", wr_orreq_resp[i*2+:2]);
                        bresp_error <= 1'b1;
                    end

                end else begin
                    bresp_error <= 1'b0;
                end

                // Manage OR timeout
                if (wr_orreq[i]) begin
                    if (wr_orreq_timeout[i]==TIMEOUT) begin
                        $display("Write OR %x reached timeout (@ %g ns) (MST_ID: %0x)", i, $realtime, MST_ID);
                        wor_error <= 1'b1;
                    end
                    if (wr_orreq_timeout[i]<=TIMEOUT) begin
                        wr_orreq_timeout[i] <= wr_orreq_timeout[i] + 1;
                    end
                end else begin
                    wr_orreq_timeout[i] <= 0;
                    wor_error <= 1'b0;
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

    assign arlen = 0;
    assign arsize = 0;
    assign arburst = 1;
    assign arlock = 0;
    assign arcache = 0;
    assign arprot = 0;
    assign arqos = 0;
    assign arregion = 0;
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

    // Limit the address ragne to target possibly a particular slave
    // Always use aligned address
    assign araddr = (ar_lfsr[AXI_ADDR_W-1:0]>addr_max) ? {araddr_ramp} :
                    (ar_lfsr[AXI_ADDR_W-1:0]<addr_min) ? {araddr_ramp} :
                                                         {ar_lfsr[AXI_ADDR_W-1:2], 2'h0} ;

    assign arvalid = arvalid_lfsr[0] & en & ~rd_orreq[arid_cnt];

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
                `ERROR("AR Channel reached timeout");
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
            rresp_error <= 1'b0;
            ror_error <= 1'b0;
            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                rd_orreq_timeout[i] <= 0;
            end

        end else if (srst) begin

            rd_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            rd_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            rd_orreq_rdata <= {MST_OSTDREQ_NUM*AXI_DATA_W{1'b0}};
            rd_orreq_rresp <= {MST_OSTDREQ_NUM*2{1'b0}};
            rresp_error <= 1'b0;
            ror_error <= 1'b0;
            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin
                rd_orreq_timeout[i] <= 0;
            end

        end else begin

            if (rvalid && rready) begin
                if ((rid&MST_ID) != MST_ID) begin
                    `ERROR("Received a completion not addressed to the right master");
                    $display("  - MST_ID: %0x", MST_ID);
                    $display("  - RID: %0x", rid);
                    $display("  - EN=%0x", en);
                    @(posedge aclk);
                    $finish();
                end
            end

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin

                // Store the OR request on address channel handshake
                if (arvalid && arready && i==arid_cnt) begin
                    rd_orreq[i] <= 1'b1;
                    rd_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= arid;
                    rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W] <= gen_resp(araddr);
                    rd_orreq_rresp[i*2+:2] <= gen_resp(araddr);
                end

                // Release the OR once read data channel hanshakes
                if (rvalid && rready && rlast && rd_orreq[i] &&
                    rd_orreq_id[i*AXI_ID_W+:AXI_ID_W]==rid)
                begin

                    rd_orreq[i] <= 1'b0;
                    rd_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= {AXI_ID_W{1'b0}};
                    rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W] <= {AXI_DATA_W{1'b0}};
                    rd_orreq_rresp[i*2+:2] <= 2'b0;

                    if (rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W] != rdata &&
                        rd_orreq_rresp[i*2+:2] != rresp &&
                        CHECK_REPORT)
                    begin
                        `ERROR("RRESP/RDATA don't match expected values");
                        $display("  - RID: %x", rid);
                        $display("  - RRESP: %x", rresp);
                        $display("  - Expected RRESP: %x", rd_orreq_rresp[i*2+:2]);
                        $display("  - RDATA: %x", rdata);
                        $display("  - Expected RDATA: %x", rd_orreq_rdata[i*AXI_DATA_W+:AXI_DATA_W]);
                        rresp_error <= 1'b1;
                    end
                end else begin
                    rresp_error <= 1'b0;
                end

                // Manage OR timeout
                if (rd_orreq[i]) begin
                    if (rd_orreq_timeout[i]==TIMEOUT) begin
                        $display("ERROR: Read OR %x reached timeout (@ %g ns) (MST_ID: %0x)", i, $realtime, MST_ID);
                        ror_error <= 1'b1;
                    end
                    if (rd_orreq_timeout[i]<=TIMEOUT) begin
                        rd_orreq_timeout[i] <= rd_orreq_timeout[i] + 1;
                    end
                end else begin
                    rd_orreq_timeout[i] <= 0;
                    ror_error <= 1'b0;
                end
            end
        end
    end

    // Error report to the testbench
    assign error = (en) ?

                    bresp_error | rresp_error | wor_error | ror_error |
                    awtimeout | wtimeout | artimeout :

                    1'b0;

endmodule

`resetall
