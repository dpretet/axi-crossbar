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

        // Maximum number of priority in Round-Robin for Masters selections
        parameter NUM_PRIORITY_LVL = 4,

        // Masters ID mask
        parameter [AXI_ID_W*MST_NB-1:0] MST_ID_MASK = 'h30_20_10_00,

        // Masters priorities
        parameter PRIORITY_W = 2,
        parameter [PRIORITY_W*MST_NB-1:0] MST_PRIORITY = 0,

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

    logic [MST_NB    -1:0] mst_rch_targeted;

    ///////////////////////////////////////////////////////////////////////////
    // Read Address Channel
    ///////////////////////////////////////////////////////////////////////////

    assign arch_req = i_arvalid;

    axicb_round_robin
    #(
        .REQ_NB           (MST_NB),
        .PRIORITY_W       (PRIORITY_W),
        .NUM_PRIORITY_LVL (NUM_PRIORITY_LVL),
        .PRIORITY         (MST_PRIORITY)
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

    always_comb begin

        o_arvalid = '0;

        for (int i=0; i<MST_NB; i++)
            if (arch_grant[i])
                o_arvalid = i_arvalid[i];
    end

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

    always_comb begin

        o_arch = '0;

        if (arch_grant == '0)
            o_arch = '0;
        else
            for (int i=0;i<MST_NB;i++)
                if (arch_grant[i])
                    o_arch = i_arch[i*ARCH_W+:ARCH_W];
    end

    ///////////////////////////////////////////////////////////////////////////
    // Read Response Channel
    ///////////////////////////////////////////////////////////////////////////

    // RCH = {RESP, ID, DATA}
    generate
    genvar i;
        for (i = 0; i < MST_NB; i = i + 1) begin : MST_RCH_TARGET
            assign mst_rch_targeted[i] = ((MST_ID_MASK[i*AXI_ID_W+:AXI_ID_W] & o_rch[0+:AXI_ID_W]) == MST_ID_MASK[i*AXI_ID_W+:AXI_ID_W]);
            assign i_rvalid[i] = (mst_rch_targeted[i]) ? o_rvalid : 1'b0;
            assign i_rlast[i] = (mst_rch_targeted[i]) ? o_rlast : 1'b0;
        end
    endgenerate

    always_comb begin
        o_rready = '0;
        if (mst_rch_targeted == '0)
            o_rready = '0;
        else for (int i=0; i<MST_NB; i++)
            if (mst_rch_targeted[i])
                o_rready = i_rready[i];
    end


    assign i_rch = o_rch;

endmodule

`resetall
