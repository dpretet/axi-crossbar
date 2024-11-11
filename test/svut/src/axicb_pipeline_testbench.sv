/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_pipeline_testbench();

    ///////////////////////////////////////////////////////////////////////////
    // Logic and defines declaration
    ///////////////////////////////////////////////////////////////////////////

    `SVUT_SETUP

    `ifndef MAX_TRAFFIC
    `define MAX_TRAFFIC 100000
    `endif
    
    `ifndef TIMEOUT
    `define TIMEOUT 10000
    `endif
    
    parameter DATA_BUS_W = 32;
    parameter NB_PIPELINE = 1;

    logic                      aclk;
    logic                      aresetn;
    logic                      srst;

    logic                      i_valid;
    logic                      i_ready;
    logic [DATA_BUS_W    -1:0] i_data;
    logic                      o_valid;
    logic                      o_ready;
    logic [DATA_BUS_W    -1:0] o_data;

    integer                    traffic_count;
    integer                    timeout;
    logic                      error;

    ///////////////////////////////////////////////////////////////////////////
    // DUT
    ///////////////////////////////////////////////////////////////////////////

    axicb_pipeline
    #(
    .DATA_BUS_W  (DATA_BUS_W),
    .NB_PIPELINE (NB_PIPELINE)
    )
    dut
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (i_valid),
    .i_ready (i_ready),
    .i_data  (i_data),
    .o_valid (o_valid),
    .o_ready (o_ready),
    .o_data  (o_data)
    );

    ///////////////////////////////////////////////////////////////////////////
    // valid/ready/data generation and data checking for both DUT sides
    ///////////////////////////////////////////////////////////////////////////

    pipeline_checker 
    #(
    .DATA_BUS_W  (DATA_BUS_W),
    .KEY         (32'h4A5B3C86)
    )
    traffic_gen 
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (i_valid),
    .i_ready (i_ready),
    .i_data  (i_data),
    .o_valid (o_valid),
    .o_ready (o_ready),
    .o_data  (o_data),
    .error   (error)
    );

    ///////////////////////////////////////////////////////////////////////////
    // Clock generation, setup/teardown functions & waveform storage
    ///////////////////////////////////////////////////////////////////////////

    // clock creation
    initial aclk = 0;
    always #2 aclk = ~aclk;

    // dump data for visualization:
    initial begin
        $dumpfile("axicb_pipeline_testbench.fst");
        $dumpvars(0, axicb_pipeline_testbench);
    end

    // setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        aresetn = 1'b0;
        srst = 1'b0;
        traffic_count = 0;
        timeout = 0;
        #10;
        aresetn = 1'b1;
    end
    endtask

    task teardown(msg="");
    begin
        /// teardown() runs when a test ends
    end
    endtask

    ///////////////////////////////////////////////////////////////////////////
    // Testsuite description
    ///////////////////////////////////////////////////////////////////////////

    `TEST_SUITE("PIPELINE STAGE TESTSUITE")

    `UNIT_TEST("RANDOM TESTCASE")

        fork 
        begin
            while (traffic_count<`MAX_TRAFFIC) begin
                @(posedge aclk);
                if (o_valid && o_ready) begin
                    traffic_count = traffic_count + 1;
                end
            end
            `INFO("Full traffic has been injected by the driver");
        end
        begin
            while (timeout<`TIMEOUT) begin
                @(posedge aclk);
                if (o_valid && o_ready) begin
                    timeout = 0;
                end else begin
                    timeout = timeout + 1;
                end
            end
            `ASSERT((timeout<`TIMEOUT), "Testcase reached timeout");
        end
        begin
            while (error==1'b0) begin
                @(posedge aclk);
            end
            `ASSERT((error==0), "Error detected during execution");
        end
        join_any

        disable fork;

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
