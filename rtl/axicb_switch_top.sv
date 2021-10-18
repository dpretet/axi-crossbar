// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_switch_top

    #(
        // Address width in bits
        parameter AXI_ADDR_W = 8,
        // ID width in bits
        parameter AXI_ID_W = 8,
        // Data width in bits
        parameter AXI_DATA_W = 8,

        // Number of master(s)
        parameter MST_NB = 4,
        // Number of slave(s)
        parameter SLV_NB = 4,
        // Switching logic pipelining (0 deactivate, 1 enable)
        parameter MST_PIPELINE = 0,
        parameter SLV_PIPELINE = 0,

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

        // Slaves memory mapping
        parameter SLV0_START_ADDR = 0,
        parameter SLV0_END_ADDR = 4095,
        parameter SLV1_START_ADDR = 4096,
        parameter SLV1_END_ADDR = 8191,
        parameter SLV2_START_ADDR = 8192,
        parameter SLV2_END_ADDR = 12287,
        parameter SLV3_START_ADDR = 12288,
        parameter SLV3_END_ADDR = 16383,

        // Channels' width (concatenated)
        parameter AWCH_W = 8,
        parameter WCH_W = 8,
        parameter BCH_W = 8,
        parameter ARCH_W = 8,
        parameter RCH_W = 8
    )(
        // Global interface
        input  logic                          aclk,
        input  logic                          aresetn,
        input  logic                          srst,
        // Input interfaces from masters
        input  logic [MST_NB            -1:0] i_awvalid,
        output logic [MST_NB            -1:0] i_awready,
        input  logic [MST_NB*AWCH_W     -1:0] i_awch,
        input  logic [MST_NB            -1:0] i_wvalid,
        output logic [MST_NB            -1:0] i_wready,
        input  logic [MST_NB            -1:0] i_wlast,
        input  logic [MST_NB*WCH_W      -1:0] i_wch,
        output logic [MST_NB            -1:0] i_bvalid,
        input  logic [MST_NB            -1:0] i_bready,
        output logic [MST_NB*BCH_W      -1:0] i_bch,
        input  logic [MST_NB            -1:0] i_arvalid,
        output logic [MST_NB            -1:0] i_arready,
        input  logic [MST_NB*ARCH_W     -1:0] i_arch,
        output logic [MST_NB            -1:0] i_rvalid,
        input  logic [MST_NB            -1:0] i_rready,
        output logic [MST_NB            -1:0] i_rlast,
        output logic [MST_NB*RCH_W      -1:0] i_rch,
        // Output interfaces to slaves
        output logic [SLV_NB            -1:0] o_awvalid,
        input  logic [SLV_NB            -1:0] o_awready,
        output logic [SLV_NB*AWCH_W     -1:0] o_awch,
        output logic [SLV_NB            -1:0] o_wvalid,
        input  logic [SLV_NB            -1:0] o_wready,
        output logic [SLV_NB            -1:0] o_wlast,
        output logic [SLV_NB*WCH_W      -1:0] o_wch,
        input  logic [SLV_NB            -1:0] o_bvalid,
        output logic [SLV_NB            -1:0] o_bready,
        input  logic [SLV_NB*BCH_W      -1:0] o_bch,
        output logic [SLV_NB            -1:0] o_arvalid,
        input  logic [SLV_NB            -1:0] o_arready,
        output logic [SLV_NB*ARCH_W     -1:0] o_arch,
        input  logic [SLV_NB            -1:0] o_rvalid,
        output logic [SLV_NB            -1:0] o_rready,
        input  logic [SLV_NB            -1:0] o_rlast,
        input  logic [SLV_NB*RCH_W      -1:0] o_rch
    );

    // master logic routing
    logic [MST_NB*SLV_NB            -1:0] ml_awvalid;
    logic [MST_NB*SLV_NB            -1:0] ml_awready;
    logic [MST_NB*AWCH_W            -1:0] ml_awch;
    logic [MST_NB*SLV_NB            -1:0] ml_wvalid;
    logic [MST_NB*SLV_NB            -1:0] ml_wready;
    logic [MST_NB*SLV_NB            -1:0] ml_wlast;
    logic [MST_NB*WCH_W             -1:0] ml_wch;
    logic [MST_NB*SLV_NB            -1:0] ml_bvalid;
    logic [MST_NB*SLV_NB            -1:0] ml_bready;
    logic [MST_NB*SLV_NB            -1:0] ml_arvalid;
    logic [MST_NB*SLV_NB            -1:0] ml_arready;
    logic [MST_NB*ARCH_W            -1:0] ml_arch;
    logic [MST_NB*SLV_NB            -1:0] ml_rvalid;
    logic [MST_NB*SLV_NB            -1:0] ml_rready;
    logic [MST_NB*SLV_NB            -1:0] ml_rlast;

    // slave logic routing
    logic [MST_NB*SLV_NB            -1:0] sl_awvalid;
    logic [MST_NB*SLV_NB            -1:0] sl_awready;
    logic [MST_NB*SLV_NB            -1:0] sl_wvalid;
    logic [MST_NB*SLV_NB            -1:0] sl_wready;
    logic [MST_NB*SLV_NB            -1:0] sl_wlast;
    logic [MST_NB*SLV_NB            -1:0] sl_bvalid;
    logic [MST_NB*SLV_NB            -1:0] sl_bready;
    logic [SLV_NB*BCH_W             -1:0] sl_bch;
    logic [MST_NB*SLV_NB            -1:0] sl_arvalid;
    logic [MST_NB*SLV_NB            -1:0] sl_arready;
    logic [MST_NB*SLV_NB            -1:0] sl_rvalid;
    logic [MST_NB*SLV_NB            -1:0] sl_rready;
    logic [MST_NB*SLV_NB            -1:0] sl_rlast;
    logic [SLV_NB*RCH_W             -1:0] sl_rch;

    ///////////////////////////////////////////////////////////////////////////
    // Generate all master interfaces
    ///////////////////////////////////////////////////////////////////////////

    generate
    for (genvar i=0;i<MST_NB;i=i+1) begin: MST_GEN

        axicb_mst_switch 
        #(
        .AXI_ADDR_W      (AXI_ADDR_W),
        .SLV_NB          (SLV_NB),
        .TIMEOUT_ENABLE  (TIMEOUT_ENABLE),
        .SLV0_START_ADDR (SLV0_START_ADDR),
        .SLV0_END_ADDR   (SLV0_END_ADDR),
        .SLV1_START_ADDR (SLV1_START_ADDR),
        .SLV1_END_ADDR   (SLV1_END_ADDR),
        .SLV2_START_ADDR (SLV2_START_ADDR),
        .SLV2_END_ADDR   (SLV2_END_ADDR),
        .SLV3_START_ADDR (SLV3_START_ADDR),
        .SLV3_END_ADDR   (SLV3_END_ADDR),
        .AWCH_W          (AWCH_W),
        .WCH_W           (WCH_W),
        .BCH_W           (BCH_W),
        .ARCH_W          (ARCH_W),
        .RCH_W           (RCH_W)
        )
        mst_switch 
        (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .srst      (srst),
        .i_awvalid (i_awvalid[i]),
        .i_awready (i_awready[i]),
        .i_awch    (i_awch[i*AWCH_W+:AWCH_W]),
        .i_wvalid  (i_wvalid[i]),
        .i_wready  (i_wready[i]),
        .i_wlast   (i_wlast[i]),
        .i_wch     (i_wch[i*WCH_W+:WCH_W]),
        .i_bvalid  (i_bvalid[i]),
        .i_bready  (i_bready[i]),
        .i_bch     (i_bch[i*BCH_W+:BCH_W]),
        .i_arvalid (i_arvalid[i]),
        .i_arready (i_arready[i]),
        .i_arch    (i_arch[i*ARCH_W+:ARCH_W]),
        .i_rvalid  (i_rvalid[i]),
        .i_rready  (i_rready[i]),
        .i_rlast   (i_rlast[i]),
        .i_rch     (i_rch[i*RCH_W+:RCH_W]),
        .o_awvalid (ml_awvalid[i*SLV_NB+:SLV_NB]),
        .o_awready (ml_awready[i*SLV_NB+:SLV_NB]),
        .o_awch    (ml_awch[i*AWCH_W+:AWCH_W]),
        .o_wvalid  (ml_wvalid[i*SLV_NB+:SLV_NB]),
        .o_wready  (ml_wready[i*SLV_NB+:SLV_NB]),
        .o_wlast   (ml_wlast[i*SLV_NB+:SLV_NB]),
        .o_wch     (ml_wch[i*WCH_W+:WCH_W]),
        .o_bvalid  (ml_bvalid[i*SLV_NB+:SLV_NB]),
        .o_bready  (ml_bready[i*SLV_NB+:SLV_NB]),
        .o_bch     (sl_bch),
        .o_arvalid (ml_arvalid[i*SLV_NB+:SLV_NB]),
        .o_arready (ml_arready[i*SLV_NB+:SLV_NB]),
        .o_arch    (ml_arch[i*ARCH_W+:ARCH_W]),
        .o_rvalid  (ml_rvalid[i*SLV_NB+:SLV_NB]),
        .o_rready  (ml_rready[i*SLV_NB+:SLV_NB]),
        .o_rlast   (ml_rlast[i*SLV_NB+:SLV_NB]),
        .o_rch     (sl_rch)
        );
    end
    endgenerate


    ///////////////////////////////////////////////////////////////////////////
    // Reorder the valid/ready handshakes:
    //
    // mst0 uses awvalid[0,1,2,3,...] for slave 0,1,2,3 ... same for mst1 ...
    //
    // slv0 must receives awvalid[0] of mst0 + awvalid[0] of mst 1 ...
    //
    // Same for all channels driven from the masters: aw, w & ar channels
    //
    // Then apply the same process for completion channel coming from the
    // slave interfaces.
    //
    ///////////////////////////////////////////////////////////////////////////

    generate
    for (genvar i=0;i<SLV_NB;i=i+1) begin: REORDERING_TO_SLV
        for (genvar j=0;j<MST_NB;j=j+1) begin: MST_PARSING
            assign sl_awvalid[i*SLV_NB+j] = ml_awvalid[j*MST_NB+i];
            assign sl_wvalid[i*SLV_NB+j] = ml_wvalid[j*MST_NB+i];
            assign sl_wlast[i*SLV_NB+j] = ml_wlast[j*MST_NB+i];
            assign sl_bready[i*SLV_NB+j] = ml_bready[j*MST_NB+i];
            assign sl_arvalid[i*SLV_NB+j] = ml_arvalid[j*MST_NB+i];
            assign sl_rready[i*SLV_NB+j] = ml_rready[j*MST_NB+i];
        end
    end
    for (genvar i=0;i<MST_NB;i=i+1) begin: REORDERING_TO_MST
        for (genvar j=0;j<SLV_NB;j=j+1) begin: SLV_PARSING
            assign ml_awready[i*MST_NB+j] = sl_awready[j*SLV_NB+i];
            assign ml_wready[i*MST_NB+j] = sl_wready[j*SLV_NB+i];
            assign ml_bvalid[i*MST_NB+j] = sl_bvalid[j*SLV_NB+i];
            assign ml_arready[i*MST_NB+j] = sl_arready[j*SLV_NB+i];
            assign ml_rvalid[i*MST_NB+j] = sl_rvalid[j*SLV_NB+i];
            assign ml_rlast[i*MST_NB+j] = sl_rlast[j*SLV_NB+i];
        end
    end
    endgenerate


    ///////////////////////////////////////////////////////////////////////////
    // Generate all slave interfaces
    ///////////////////////////////////////////////////////////////////////////

    generate
    for (genvar i=0;i<SLV_NB;i=i+1) begin: SLV_GEN

        axicb_slv_switch 
        #(
        .AXI_ID_W       (AXI_ID_W),
        .AXI_DATA_W     (AXI_DATA_W),
        .MST_NB         (MST_NB),
        .TIMEOUT_ENABLE (TIMEOUT_ENABLE),
        .MST0_ID_MASK   (MST0_ID_MASK),
        .MST1_ID_MASK   (MST1_ID_MASK),
        .MST2_ID_MASK   (MST2_ID_MASK),
        .MST3_ID_MASK   (MST3_ID_MASK),
        .MST0_PRIORITY  (MST0_PRIORITY),
        .MST1_PRIORITY  (MST1_PRIORITY),
        .MST2_PRIORITY  (MST2_PRIORITY),
        .MST3_PRIORITY  (MST3_PRIORITY),
        .AWCH_W         (AWCH_W),
        .WCH_W          (WCH_W),
        .BCH_W          (BCH_W),
        .ARCH_W         (ARCH_W),
        .RCH_W          (RCH_W)
        )
        slv_switch
        (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .srst      (srst),
        .i_awvalid (sl_awvalid[i*MST_NB+:MST_NB]),
        .i_awready (sl_awready[i*MST_NB+:MST_NB]),
        .i_awch    (ml_awch),
        .i_wvalid  (sl_wvalid [i*MST_NB+:MST_NB]),
        .i_wready  (sl_wready[i*MST_NB+:MST_NB]),
        .i_wlast   (sl_wlast[i*MST_NB+:MST_NB]),
        .i_wch     (ml_wch),
        .i_bvalid  (sl_bvalid[i*MST_NB+:MST_NB]),
        .i_bready  (sl_bready[i*MST_NB+:MST_NB]),
        .i_bch     (sl_bch[i*BCH_W+:BCH_W]),
        .i_arvalid (sl_arvalid[i*MST_NB+:MST_NB]),
        .i_arready (sl_arready[i*MST_NB+:MST_NB]),
        .i_arch    (ml_arch),
        .i_rvalid  (sl_rvalid[i*MST_NB+:MST_NB]),
        .i_rready  (sl_rready[i*MST_NB+:MST_NB]),
        .i_rlast   (sl_rlast[i*MST_NB+:MST_NB]),
        .i_rch     (sl_rch[i*RCH_W+:RCH_W]),
        .o_awvalid (o_awvalid[i]),
        .o_awready (o_awready[i]),
        .o_awch    (o_awch[i*AWCH_W+:AWCH_W]),
        .o_wvalid  (o_wvalid[i]),
        .o_wready  (o_wready[i]),
        .o_wlast   (o_wlast[i]),
        .o_wch     (o_wch[i*WCH_W+:WCH_W]),
        .o_bvalid  (o_bvalid[i]),
        .o_bready  (o_bready[i]),
        .o_bch     (o_bch[i*BCH_W+:BCH_W]),
        .o_arvalid (o_arvalid[i]),
        .o_arready (o_arready[i]),
        .o_arch    (o_arch[i*ARCH_W+:ARCH_W]),
        .o_rvalid  (o_rvalid[i]),
        .o_rready  (o_rready[i]),
        .o_rlast   (o_rlast[i]),
        .o_rch     (o_rch[i*RCH_W+:RCH_W])
        );

    end
    endgenerate

endmodule

`resetall
