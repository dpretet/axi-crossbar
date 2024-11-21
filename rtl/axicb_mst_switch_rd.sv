// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_mst_switch_rd

    #(
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // Number of master(s)
        parameter MST_NB = 4,

        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,

        // Masters ID mask
        parameter [AXI_ID_W-1:0] MST0_ID_MASK = 'h00,
        parameter [AXI_ID_W-1:0] MST1_ID_MASK = 'h10,
        parameter [AXI_ID_W-1:0] MST2_ID_MASK = 'h20,
        parameter [AXI_ID_W-1:0] MST3_ID_MASK = 'h30,

        // Masters priorities
        parameter MST0_PRIORITY = 0,
        parameter MST1_PRIORITY = 0,
        parameter MST2_PRIORITY = 0,
        parameter MST3_PRIORITY = 0,

        // Channels' width (concatenated)
        parameter AWCH_W = 8,
        parameter WCH_W = 8,
        parameter BCH_W = 8,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // Global interface
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interfaces from masters
        input  wire  [MST_NB            -1:0] i_arvalid,
        output logic [MST_NB            -1:0] i_arready,
        input  wire  [MST_NB*ARCH_W     -1:0] i_arch,
        output logic [MST_NB            -1:0] i_rvalid,
        input  wire  [MST_NB            -1:0] i_rready,
        output logic [MST_NB            -1:0] i_rlast,
        output logic [RCH_W             -1:0] i_rch,
        // Output interfaces to slaves
        output logic                          o_arvalid,
        input  wire                           o_arready,
        output logic [ARCH_W            -1:0] o_arch,
        input  wire                           o_rvalid,
        output logic                          o_rready,
        input  wire                           o_rlast,
        input  wire  [RCH_W             -1:0] o_rch
    );


    ///////////////////////////////////////////////////////////////////////////
    // Local declarations
    ///////////////////////////////////////////////////////////////////////////

    logic                  arch_en;
    logic                  arch_en_c;
    logic                  arch_en_r;
    logic [MST_NB    -1:0] arch_req;
    logic [MST_NB    -1:0] arch_grant;

    logic                  mst0_rch_targeted;
    logic                  mst1_rch_targeted;
    logic                  mst2_rch_targeted;
    logic                  mst3_rch_targeted;


    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    assign arch_req = i_arvalid;

    axicb_round_robin
    #(
        .REQ_NB        (MST_NB),
        .REQ0_PRIORITY (MST0_PRIORITY),
        .REQ1_PRIORITY (MST1_PRIORITY),
        .REQ2_PRIORITY (MST2_PRIORITY),
        .REQ3_PRIORITY (MST3_PRIORITY)
    )
    arch_round_robin
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (arch_en),
        .req     (arch_req),
        .grant   (arch_grant)
    );

    assign o_arvalid = (arch_grant[0]) ? i_arvalid[0] :
                       (arch_grant[1]) ? i_arvalid[1] :
                       (arch_grant[2]) ? i_arvalid[2] :
                       (arch_grant[3]) ? i_arvalid[3] :
                                         1'b0;

    assign i_arready = arch_grant & {MST_NB{o_arready}};

    assign arch_en_c = |i_arvalid & o_arready;

    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            arch_en_r <= '0;
        end else if (srst) begin
            arch_en_r <= '0;
        end else begin
            if (arch_grant=='0) arch_en_r <= 1'b1;
            else                arch_en_r <= 1'b0;
        end
    end

    assign arch_en = arch_en_c | arch_en_r;

    assign o_arch = (arch_grant[0]) ? i_arch[0*ARCH_W+:ARCH_W] :
                    (arch_grant[1]) ? i_arch[1*ARCH_W+:ARCH_W] :
                    (arch_grant[2]) ? i_arch[2*ARCH_W+:ARCH_W] :
                    (arch_grant[3]) ? i_arch[3*ARCH_W+:ARCH_W] :
                                      {ARCH_W{1'b0}};

    ///////////////////////////////////////////////////////////////////////////
    // Read Response Channel
    ///////////////////////////////////////////////////////////////////////////

    // RCH = {RESP, ID, DATA}

    assign mst0_rch_targeted = ((MST0_ID_MASK & o_rch[0+:AXI_ID_W]) == MST0_ID_MASK);
    assign mst1_rch_targeted = ((MST1_ID_MASK & o_rch[0+:AXI_ID_W]) == MST1_ID_MASK);
    assign mst2_rch_targeted = ((MST2_ID_MASK & o_rch[0+:AXI_ID_W]) == MST2_ID_MASK);
    assign mst3_rch_targeted = ((MST3_ID_MASK & o_rch[0+:AXI_ID_W]) == MST3_ID_MASK);

    assign i_rvalid[0] = (mst0_rch_targeted) ? o_rvalid : 1'b0;
    assign i_rvalid[1] = (mst1_rch_targeted) ? o_rvalid : 1'b0;
    assign i_rvalid[2] = (mst2_rch_targeted) ? o_rvalid : 1'b0;
    assign i_rvalid[3] = (mst3_rch_targeted) ? o_rvalid : 1'b0;

    assign i_rlast[0] = (mst0_rch_targeted) ? o_rlast : 1'b0;
    assign i_rlast[1] = (mst1_rch_targeted) ? o_rlast : 1'b0;
    assign i_rlast[2] = (mst2_rch_targeted) ? o_rlast : 1'b0;
    assign i_rlast[3] = (mst3_rch_targeted) ? o_rlast : 1'b0;

    assign o_rready = (mst0_rch_targeted) ? i_rready[0] :
                      (mst1_rch_targeted) ? i_rready[1] :
                      (mst2_rch_targeted) ? i_rready[2] :
                      (mst3_rch_targeted) ? i_rready[3] :
                                            1'b0;

    assign i_rch = o_rch;

endmodule

`resetall
