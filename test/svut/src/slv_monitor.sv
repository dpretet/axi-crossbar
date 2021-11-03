// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

`include "functions.sv"
`include "svlogger.sv"

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

        // TIMEOUT value used for response channels
        parameter TIMEOUT = 100,

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
        input  logic                      wvalid,
        output logic                      wready,
        input  logic                      wlast,
        input  logic [AXI_DATA_W    -1:0] wdata,
        input  logic [AXI_DATA_W/8  -1:0] wstrb,
        output logic                      bvalid,
        input  logic                      bready,
        output logic [AXI_ID_W      -1:0] bid,
        output logic [2             -1:0] bresp,
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
        output logic                      rvalid,
        input  logic                      rready,
        output logic [AXI_ID_W      -1:0] rid,
        output logic [2             -1:0] rresp,
        output logic [AXI_DATA_W    -1:0] rdata,
        output logic                      rlast
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
    logic [AXI_DATA_W                  -1:0] w_fifo_i;
    logic [AXI_DATA_W                  -1:0] w_fifo_o;
    logic                                    b_full;
    logic                                    b_empty;
    logic [2+AXI_ID_W                  -1:0] b_fifo_i;
    logic [2+AXI_ID_W                  -1:0] b_fifo_o;
    logic [32                          -1:0] bresp_exp;
    logic                                    r_full;
    logic                                    r_empty;
    logic [2+AXI_ID_W+AXI_DATA_W       -1:0] r_fifo_i;
    logic [2+AXI_ID_W+AXI_DATA_W       -1:0] r_fifo_o;
    logic [32                          -1:0] rdata_exp;
    logic [32                          -1:0] rresp_exp;

    integer                                  btimer;
    integer                                  rtimer;
    logic                                    btimeout;
    logic                                    rtimeout;
    logic                                    wdata_error;

    // Logger setup
    svlogger log;
    string svlogger_name;

    initial begin
        $sformat(svlogger_name, "SlvMonitor%0x", SLV_ID);
        log = new(svlogger_name,
                  `SVL_VERBOSE_DEBUG,
                  `SVL_ROUTE_ALL);
    end

    assign error = btimeout | rtimeout | wdata_error;


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

    assign wready = wready_lfsr[0] & ~w_empty;

    assign w_fifo_i = gen_data(awaddr);

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
        .data_in  (w_fifo_i),
        .push     (awvalid & awready),
        .full     (w_full),
        .data_out (w_fifo_o),
        .pull     (wvalid & wready & wlast),
        .empty    (w_empty)
    );


    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            wdata_error <= 1'b0;
        end else if (srst) begin
            wdata_error <= 1'b0;
        end else begin
            if (wvalid & wready & wlast) begin
                if (w_fifo_o != wdata) begin
                    log.error("ERROR: WDATA received doesn't match the expected");
                    wdata_error <= 1'b1;
                    $finish();
                end begin
                    wdata_error <= 1'b0;
                end
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////
    // Write Response channel
    ///////////////////////////////////////////////////////////////////////////

    assign bresp_exp = gen_resp(awaddr);
    assign b_fifo_i = {awid, bresp_exp[1:0]};

    axicb_scfifo 
    #(
        .PASS_THRU  (0),
        .ADDR_WIDTH (8),
        .DATA_WIDTH (AXI_ID_W+2)
    )
    bfifo 
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (1'b0),
        .data_in  (b_fifo_i),
        .push     (awvalid & awready),
        .full     (b_full),
        .data_out (b_fifo_o),
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
    assign bresp = b_fifo_o[1:0];
    assign bid = (bvalid) ? b_fifo_o[2+:AXI_ID_W] : {AXI_ID_W{1'b0}};

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
            end else begin
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


    ///////////////////////////////////////////////////////////////////////////
    // Read Response channel
    ///////////////////////////////////////////////////////////////////////////

    assign rresp_exp = gen_resp(araddr);
    assign rdata_exp = gen_resp(araddr);
    assign r_fifo_i = {arid, rresp_exp[1:0], rdata_exp};

    axicb_scfifo 
    #(
        .PASS_THRU  (0),
        .ADDR_WIDTH (2),
        .DATA_WIDTH (AXI_ID_W+2+AXI_DATA_W)
    )
    rfifo 
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .flush    (1'b0),
        .data_in  (r_fifo_i),
        .push     (arvalid & arready),
        .full     (r_full),
        .data_out (r_fifo_o),
        .pull     (rvalid & rready),
        .empty    (r_empty)
    );

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

    assign rvalid = ~r_empty & rvalid_lfsr[0];
    assign rdata = r_fifo_o[0+:AXI_DATA_W];
    assign rresp = r_fifo_o[AXI_DATA_W+:2];
    assign rid = r_fifo_o[AXI_DATA_W+2+:AXI_ID_W];
    assign rlast = 1'b1;

    // Monitor RRESP channel to detect timeout
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
                rtimeout <= 1'b1;
            end else begin
                rtimeout <= 1'b0;
            end
        end
    end
endmodule

`resetall

