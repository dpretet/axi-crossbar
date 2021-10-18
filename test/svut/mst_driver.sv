// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

`include "functions.sv"

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

    logic [AXI_ID_W                    -1:0] awid_cnt;
    logic [AXI_ID_W                    -1:0] arid_cnt;
    logic [32                          -1:0] aw_lfsr;
    logic [32                          -1:0] ar_lfsr;
    logic [32                          -1:0] awvalid_lfsr;
    logic [32                          -1:0] arvalid_lfsr;
    logic [MST_OSTDREQ_NUM             -1:0] wr_orreq;
    logic [MST_OSTDREQ_NUM*AXI_ID_W    -1:0] wr_orreq_id;
    logic [MST_OSTDREQ_NUM*2           -1:0] wr_orreq_resp;
    logic [MST_OSTDREQ_NUM             -1:0] rd_orreq;
    logic [MST_OSTDREQ_NUM*AXI_ID_W    -1:0] rd_orreq_id;
    logic [MST_OSTDREQ_NUM*AXI_DATA_W  -1:0] rd_orreq_resp;
    logic                                    bresp_error;
    logic                                    rresp_error;


    ///////////////////////////////////////////////////////////////////////////////
    // Write channels
    ///////////////////////////////////////////////////////////////////////////////

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
            awid_cnt <= {AXI_ID_W{1'b0}};
        end else if (srst) begin
            awvalid_lfsr <= 32'b0;
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

            // ID counter
            if (awvalid && awready && wready) begin
                if (awid_cnt==(MST_OSTDREQ_NUM-1)) awid_cnt <= 'h0;
                else awid_cnt <= awid_cnt + 1;
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
    .en      (awvalid & awready & wready),
    .lfsr    (aw_lfsr)
    );

    // Limit the address ragne to target possibly a particular slave
    // Always use aligned address
    assign awaddr = (aw_lfsr[AXI_ADDR_W-1:0]>addr_max) ? {addr_max[AXI_ADDR_W-1:2],2'b0} :
                    (aw_lfsr[AXI_ADDR_W-1:0]<addr_min) ? {addr_min[AXI_ADDR_W-1:2],2'b0} :
                    {aw_lfsr[AXI_ADDR_W-1:2], 2'h0};

    assign awvalid = awvalid_lfsr[0] & en;
    assign wvalid = awvalid_lfsr[0] & en;
    assign wdata = aw_lfsr[0+:AXI_DATA_W];
    assign wstrb = aw_lfsr[0+:AXI_DATA_W/8];
    assign wlast = 1'b1;

    assign bready = 1'b1;

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin

            wr_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            wr_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            wr_orreq_resp <= {MST_OSTDREQ_NUM*2{1'b0}};
            bresp_error <= 1'b0;

        end else if (srst) begin

            wr_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            wr_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            wr_orreq_resp <= {MST_OSTDREQ_NUM*2{1'b0}};
            bresp_error <= 1'b0;

        end else begin

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin

                if (awvalid && awready && i==awid_cnt) begin
                    wr_orreq[i] <= 1'b1;
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= awid;
                    wr_orreq_resp[i*2+:2] <= gen_resp(awaddr);
                end

                if (bvalid && bready && wr_orreq[i] &&
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W]==bid)
                begin

                    wr_orreq[i] <= 1'b0;
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= {AXI_ID_W{1'b0}};
                    wr_orreq_resp[i*2+:2] <= 2'b0;

                    if (wr_orreq_resp[i*2+:2] !== bresp && CHECK_REPORT) begin
                        $display("ERROR: BRESP doesn't match expected value");
                        $display("  - BID: %x", bid);
                        $display("  - BRESP: %x", bresp);
                        $display("  - Expected: %x", wr_orreq_resp[i*2+:2]);
                        bresp_error <= 1'b1;
                    end

                end else begin
                    bresp_error <= 1'b0;
                end
            end
        end
    end

    // TODO: impplement timeout for each outstanding request
    // TODO: implement timeout during a write request


    ///////////////////////////////////////////////////////////////////////////////
    // Read channels
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
            end else begin
                arvalid_lfsr <= ar_lfsr;
            end

            // ID counter
            if (arvalid && arready) begin
                if (arid_cnt==(MST_OSTDREQ_NUM-1)) arid_cnt <= 'h0;
                else arid_cnt <= arid_cnt + 1;
            end
        end
    end

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

    // Limit the address ragne to target possibly a particular slave
    // Always use aligned address
    assign araddr = (ar_lfsr[AXI_ADDR_W-1:0]>addr_max) ? {addr_max[AXI_ADDR_W-1:2],2'b0} :
                    (ar_lfsr[AXI_ADDR_W-1:0]<addr_min) ? {addr_min[AXI_ADDR_W-1:2],2'b0} :
                                                         {ar_lfsr[AXI_ADDR_W-1:2], 2'h0};

    assign arvalid = arvalid_lfsr[0] & en;

    assign rready = 1'b1;

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin

            rd_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            rd_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            rd_orreq_resp <= {MST_OSTDREQ_NUM*AXI_DATA_W{1'b0}};
            rresp_error <= 1'b0;

        end else if (srst) begin

            rd_orreq <= {MST_OSTDREQ_NUM{1'b0}};
            rd_orreq_id <= {MST_OSTDREQ_NUM*AXI_ID_W{1'b0}};
            rd_orreq_resp <= {MST_OSTDREQ_NUM*AXI_DATA_W{1'b0}};
            rresp_error <= 1'b0;

        end else begin

            for (int i=0;i<MST_OSTDREQ_NUM;i++) begin

                if (arvalid && arready && i==arid_cnt) begin
                    rd_orreq[i] <= 1'b1;
                    rd_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= arid;
                    rd_orreq_resp[i*AXI_DATA_W+:AXI_DATA_W] <= gen_resp(araddr);
                end

                if (rvalid && rready && rlast && rd_orreq[i] &&
                    rd_orreq_id[i*AXI_ID_W+:AXI_ID_W]==rid)
                begin

                    rd_orreq[i] <= 1'b0;
                    wr_orreq_id[i*AXI_ID_W+:AXI_ID_W] <= {AXI_ID_W{1'b0}};
                    wr_orreq_resp[i*AXI_DATA_W+:AXI_DATA_W] <= {AXI_DATA_W{1'b0}};

                    if (rd_orreq_resp[i*AXI_DATA_W+:AXI_DATA_W] != rresp && CHECK_REPORT) begin
                        $display("ERROR: RRESP doesn't match expected value");
                        $display("  - RID: %x", rid);
                        $display("  - RRESP: %x", rresp);
                        $display("  - Expected: %x", rd_orreq_resp[i*AXI_DATA_W+:AXI_DATA_W]);
                        rresp_error <= 1'b1;
                    end
                end else begin
                    rresp_error <= 1'b0;
                end
            end
        end
    end

    assign error = bresp_error | rresp_error;

endmodule

`resetall
