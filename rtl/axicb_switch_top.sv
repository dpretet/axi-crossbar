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

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI4
        parameter AXI_SIGNALING = 0,

        // Number of master(s)
        parameter MST_NB = 4,
        // Number of slave(s)
        parameter SLV_NB = 4,
        // Switching logic pipelining (0 deactivate, 1 or more enable)
        parameter MST_PIPELINE = 0,
        parameter SLV_PIPELINE = 0,

        // Activate the timer to avoid deadlock
        parameter TIMEOUT_ENABLE = 1,

        // Routes to the slaves allowed per master
        parameter [MST_NB*SLV_NB -1:0] MST_ROUTES = 16'hFFFF,

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
        input  wire                           aclk,
        input  wire                           aresetn,
        input  wire                           srst,
        // Input interfaces from masters
        input  wire  [MST_NB            -1:0] i_awvalid,
        output logic [MST_NB            -1:0] i_awready,
        input  wire  [MST_NB*AWCH_W     -1:0] i_awch,
        input  wire  [MST_NB            -1:0] i_wvalid,
        output logic [MST_NB            -1:0] i_wready,
        input  wire  [MST_NB            -1:0] i_wlast,
        input  wire  [MST_NB*WCH_W      -1:0] i_wch,
        output logic [MST_NB            -1:0] i_bvalid,
        input  wire  [MST_NB            -1:0] i_bready,
        output logic [MST_NB*BCH_W      -1:0] i_bch,
        input  wire  [MST_NB            -1:0] i_arvalid,
        output logic [MST_NB            -1:0] i_arready,
        input  wire  [MST_NB*ARCH_W     -1:0] i_arch,
        output logic [MST_NB            -1:0] i_rvalid,
        input  wire  [MST_NB            -1:0] i_rready,
        output logic [MST_NB            -1:0] i_rlast,
        output logic [MST_NB*RCH_W      -1:0] i_rch,
        // Output interfaces to slaves
        output logic [SLV_NB            -1:0] o_awvalid,
        input  wire  [SLV_NB            -1:0] o_awready,
        output logic [SLV_NB*AWCH_W     -1:0] o_awch,
        output logic [SLV_NB            -1:0] o_wvalid,
        input  wire  [SLV_NB            -1:0] o_wready,
        output logic [SLV_NB            -1:0] o_wlast,
        output logic [SLV_NB*WCH_W      -1:0] o_wch,
        input  wire  [SLV_NB            -1:0] o_bvalid,
        output logic [SLV_NB            -1:0] o_bready,
        input  wire  [SLV_NB*BCH_W      -1:0] o_bch,
        output logic [SLV_NB            -1:0] o_arvalid,
        input  wire  [SLV_NB            -1:0] o_arready,
        output logic [SLV_NB*ARCH_W     -1:0] o_arch,
        input  wire  [SLV_NB            -1:0] o_rvalid,
        output logic [SLV_NB            -1:0] o_rready,
        input  wire  [SLV_NB            -1:0] o_rlast,
        input  wire  [SLV_NB*RCH_W      -1:0] o_rch
    );

    genvar i, j;

    // master <> slave logic routing
    logic [MST_NB*SLV_NB            -1:0] slv_awvalid;
    logic [MST_NB*SLV_NB            -1:0] slv_awready;
    logic [MST_NB*AWCH_W            -1:0] awch;
    logic [MST_NB*SLV_NB            -1:0] slv_wvalid;
    logic [MST_NB*SLV_NB            -1:0] slv_wready;
    logic [MST_NB*SLV_NB            -1:0] slv_wlast;
    logic [MST_NB*WCH_W             -1:0] wch;
    logic [MST_NB*SLV_NB            -1:0] slv_bvalid;
    logic [MST_NB*SLV_NB            -1:0] slv_bready;
    logic [MST_NB*SLV_NB            -1:0] slv_arvalid;
    logic [MST_NB*SLV_NB            -1:0] slv_arready;
    logic [MST_NB*ARCH_W            -1:0] arch;
    logic [MST_NB*SLV_NB            -1:0] slv_rvalid;
    logic [MST_NB*SLV_NB            -1:0] slv_rready;
    logic [MST_NB*SLV_NB            -1:0] slv_rlast;
    logic [MST_NB*SLV_NB            -1:0] mst_awvalid;
    logic [MST_NB*SLV_NB            -1:0] mst_awready;
    logic [MST_NB*SLV_NB            -1:0] mst_wvalid;
    logic [MST_NB*SLV_NB            -1:0] mst_wready;
    logic [MST_NB*SLV_NB            -1:0] mst_wlast;
    logic [MST_NB*SLV_NB            -1:0] mst_bvalid;
    logic [MST_NB*SLV_NB            -1:0] mst_bready;
    logic [SLV_NB*BCH_W             -1:0] bch;
    logic [MST_NB*SLV_NB            -1:0] mst_arvalid;
    logic [MST_NB*SLV_NB            -1:0] mst_arready;
    logic [MST_NB*SLV_NB            -1:0] mst_rvalid;
    logic [MST_NB*SLV_NB            -1:0] mst_rready;
    logic [MST_NB*SLV_NB            -1:0] mst_rlast;
    logic [SLV_NB*RCH_W             -1:0] rch;


    ///////////////////////////////////////////////////////////////////////////
    // Generate all master interfaces
    ///////////////////////////////////////////////////////////////////////////

    generate

    for (i=0;i<MST_NB;i=i+1) begin: SLV_SWITCHS_GEN

        logic                          pipe_awvalid;
        logic                          pipe_awready;
        logic [AWCH_W            -1:0] pipe_awch;
        logic                          pipe_wvalid;
        logic                          pipe_wready;
        logic                          pipe_wlast;
        logic [WCH_W             -1:0] pipe_wch;
        logic                          pipe_bvalid;
        logic                          pipe_bready;
        logic [BCH_W             -1:0] pipe_bch;
        logic                          pipe_arvalid;
        logic                          pipe_arready;
        logic [ARCH_W            -1:0] pipe_arch;
        logic                          pipe_rvalid;
        logic                          pipe_rready;
        logic                          pipe_rlast;
        logic [RCH_W             -1:0] pipe_rch;

        axicb_pipeline
        #(
            .DATA_BUS_W  (AWCH_W),
            .NB_PIPELINE (SLV_PIPELINE)
        )
        awch_slv_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (i_awvalid[i]),
            .i_ready (i_awready[i]),
            .i_data  (i_awch[i*AWCH_W+:AWCH_W]),
            .o_valid (pipe_awvalid),
            .o_ready (pipe_awready),
            .o_data  (pipe_awch)
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (WCH_W+1),
            .NB_PIPELINE (SLV_PIPELINE)
        )
        wch_slv_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (i_wvalid[i]),
            .i_ready (i_wready[i]),
            .i_data  ({i_wlast[i], i_wch[i*WCH_W+:WCH_W]}),
            .o_valid (pipe_wvalid),
            .o_ready (pipe_wready),
            .o_data  ({pipe_wlast, pipe_wch})
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (BCH_W),
            .NB_PIPELINE (SLV_PIPELINE)
        )
        bch_slv_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (pipe_bvalid),
            .i_ready (pipe_bready),
            .i_data  (pipe_bch),
            .o_valid (i_bvalid[i]),
            .o_ready (i_bready[i]),
            .o_data  (i_bch[i*BCH_W+:BCH_W])
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (ARCH_W),
            .NB_PIPELINE (SLV_PIPELINE)
        )
        arch_slv_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (i_arvalid[i]),
            .i_ready (i_arready[i]),
            .i_data  (i_arch[i*ARCH_W+:ARCH_W]),
            .o_valid (pipe_arvalid),
            .o_ready (pipe_arready),
            .o_data  (pipe_arch)
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (RCH_W+1),
            .NB_PIPELINE (SLV_PIPELINE)
        )
        rch_slv_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (pipe_rvalid),
            .i_ready (pipe_rready),
            .i_data  ({pipe_rlast, pipe_rch}),
            .o_valid (i_rvalid[i]),
            .o_ready (i_rready[i]),
            .o_data  ({i_rlast[i],i_rch[i*RCH_W+:RCH_W]})
        );

        axicb_slv_switch
        #(
            .AXI_ADDR_W      (AXI_ADDR_W),
            .AXI_ID_W        (AXI_ID_W),
            .AXI_SIGNALING   (AXI_SIGNALING),
            .SLV_NB          (SLV_NB),
            .MST_ROUTES      (MST_ROUTES[i*SLV_NB+:SLV_NB]),
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
        slv_switch
        (
            .aclk      (aclk),
            .aresetn   (aresetn),
            .srst      (srst),
            .i_awvalid (pipe_awvalid),
            .i_awready (pipe_awready),
            .i_awch    (pipe_awch),
            .i_wvalid  (pipe_wvalid),
            .i_wready  (pipe_wready),
            .i_wlast   (pipe_wlast),
            .i_wch     (pipe_wch),
            .i_bvalid  (pipe_bvalid),
            .i_bready  (pipe_bready),
            .i_bch     (pipe_bch),
            .i_arvalid (pipe_arvalid),
            .i_arready (pipe_arready),
            .i_arch    (pipe_arch),
            .i_rvalid  (pipe_rvalid),
            .i_rready  (pipe_rready),
            .i_rlast   (pipe_rlast),
            .i_rch     (pipe_rch),
            .o_awvalid (slv_awvalid[i*SLV_NB+:SLV_NB]),
            .o_awready (slv_awready[i*SLV_NB+:SLV_NB]),
            .o_awch    (awch[i*AWCH_W+:AWCH_W]),
            .o_wvalid  (slv_wvalid[i*SLV_NB+:SLV_NB]),
            .o_wready  (slv_wready[i*SLV_NB+:SLV_NB]),
            .o_wlast   (slv_wlast[i*SLV_NB+:SLV_NB]),
            .o_wch     (wch[i*WCH_W+:WCH_W]),
            .o_bvalid  (slv_bvalid[i*SLV_NB+:SLV_NB]),
            .o_bready  (slv_bready[i*SLV_NB+:SLV_NB]),
            .o_bch     (bch),
            .o_arvalid (slv_arvalid[i*SLV_NB+:SLV_NB]),
            .o_arready (slv_arready[i*SLV_NB+:SLV_NB]),
            .o_arch    (arch[i*ARCH_W+:ARCH_W]),
            .o_rvalid  (slv_rvalid[i*SLV_NB+:SLV_NB]),
            .o_rready  (slv_rready[i*SLV_NB+:SLV_NB]),
            .o_rlast   (slv_rlast[i*SLV_NB+:SLV_NB]),
            .o_rch     (rch)
        );
    end
    endgenerate


    ///////////////////////////////////////////////////////////////////////////
    // Reorder the valid/ready handshakes:
    //
    // slave interface uses awvalid[0,1,2,3,...] to target master interface 0,
    // master interface 1, master interface 2, master interface 3 ...
    //
    // master interfaces must receive awvalid[0] of slv_if0 + awvalid[0] of
    // slv_if1 ...
    //
    // The same principle is applied for all channels targeted from slave
    // interfaces: AW, W & AR channels.
    //
    // Then apply the same process for completion channel coming from the
    // slave interfaces: B channel & R chennel.
    //
    ///////////////////////////////////////////////////////////////////////////

    generate

    // Parse all slave agents, thus output master interfaces
    for (i=0;i<SLV_NB;i=i+1) begin: REORDERING_TO_MST
        // Parse all master agents, thus input slave interfaces
        for (j=0;j<MST_NB;j=j+1) begin: SLV_IF_PARSING
            assign mst_awvalid[i*SLV_NB+j] = slv_awvalid[j*MST_NB+i];
            assign mst_wvalid[i*SLV_NB+j] = slv_wvalid[j*MST_NB+i];
            assign mst_wlast[i*SLV_NB+j] = slv_wlast[j*MST_NB+i];
            assign mst_bready[i*SLV_NB+j] = slv_bready[j*MST_NB+i];
            assign mst_arvalid[i*SLV_NB+j] = slv_arvalid[j*MST_NB+i];
            assign mst_rready[i*SLV_NB+j] = slv_rready[j*MST_NB+i];
        end
    end

    // Parse all master agents, thus input slave interfaces
    for (i=0;i<MST_NB;i=i+1) begin: REORDERING_TO_SLV
        // Parse all slave agents, thus output master interfaces
        for (j=0;j<SLV_NB;j=j+1) begin: MST_IF_PARSING
            assign slv_awready[i*MST_NB+j] = mst_awready[j*SLV_NB+i];
            assign slv_wready[i*MST_NB+j] = mst_wready[j*SLV_NB+i];
            assign slv_bvalid[i*MST_NB+j] = mst_bvalid[j*SLV_NB+i];
            assign slv_arready[i*MST_NB+j] = mst_arready[j*SLV_NB+i];
            assign slv_rvalid[i*MST_NB+j] = mst_rvalid[j*SLV_NB+i];
            assign slv_rlast[i*MST_NB+j] = mst_rlast[j*SLV_NB+i];
        end
    end

    endgenerate


    ///////////////////////////////////////////////////////////////////////////
    // Generate all slave interfaces
    ///////////////////////////////////////////////////////////////////////////

    generate

    for (i=0;i<SLV_NB;i=i+1) begin: MST_SWITCHS_GEN

        logic                          pipe_awvalid;
        logic                          pipe_awready;
        logic [AWCH_W            -1:0] pipe_awch;
        logic                          pipe_wvalid;
        logic                          pipe_wready;
        logic                          pipe_wlast;
        logic [WCH_W             -1:0] pipe_wch;
        logic                          pipe_bvalid;
        logic                          pipe_bready;
        logic [BCH_W             -1:0] pipe_bch;
        logic                          pipe_arvalid;
        logic                          pipe_arready;
        logic [ARCH_W            -1:0] pipe_arch;
        logic                          pipe_rvalid;
        logic                          pipe_rready;
        logic                          pipe_rlast;
        logic [RCH_W             -1:0] pipe_rch;

        axicb_mst_switch
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
        mst_switch
        (
            .aclk      (aclk),
            .aresetn   (aresetn),
            .srst      (srst),
            .i_awvalid (mst_awvalid[i*MST_NB+:MST_NB]),
            .i_awready (mst_awready[i*MST_NB+:MST_NB]),
            .i_awch    (awch),
            .i_wvalid  (mst_wvalid [i*MST_NB+:MST_NB]),
            .i_wready  (mst_wready[i*MST_NB+:MST_NB]),
            .i_wlast   (mst_wlast[i*MST_NB+:MST_NB]),
            .i_wch     (wch),
            .i_bvalid  (mst_bvalid[i*MST_NB+:MST_NB]),
            .i_bready  (mst_bready[i*MST_NB+:MST_NB]),
            .i_bch     (bch[i*BCH_W+:BCH_W]),
            .i_arvalid (mst_arvalid[i*MST_NB+:MST_NB]),
            .i_arready (mst_arready[i*MST_NB+:MST_NB]),
            .i_arch    (arch),
            .i_rvalid  (mst_rvalid[i*MST_NB+:MST_NB]),
            .i_rready  (mst_rready[i*MST_NB+:MST_NB]),
            .i_rlast   (mst_rlast[i*MST_NB+:MST_NB]),
            .i_rch     (rch[i*RCH_W+:RCH_W]),
            .o_awvalid (pipe_awvalid),
            .o_awready (pipe_awready),
            .o_awch    (pipe_awch),
            .o_wvalid  (pipe_wvalid),
            .o_wready  (pipe_wready),
            .o_wlast   (pipe_wlast),
            .o_wch     (pipe_wch),
            .o_bvalid  (pipe_bvalid),
            .o_bready  (pipe_bready),
            .o_bch     (pipe_bch),
            .o_arvalid (pipe_arvalid),
            .o_arready (pipe_arready),
            .o_arch    (pipe_arch),
            .o_rvalid  (pipe_rvalid),
            .o_rready  (pipe_rready),
            .o_rlast   (pipe_rlast),
            .o_rch     (pipe_rch)
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (AWCH_W),
            .NB_PIPELINE (MST_PIPELINE)
        )
        awch_mst_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (pipe_awvalid),
            .i_ready (pipe_awready),
            .i_data  (pipe_awch),
            .o_valid (o_awvalid[i]),
            .o_ready (o_awready[i]),
            .o_data  (o_awch[i*AWCH_W+:AWCH_W])
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (WCH_W+1),
            .NB_PIPELINE (MST_PIPELINE)
        )
        wch_mst_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (pipe_wvalid),
            .i_ready (pipe_wready),
            .i_data  ({pipe_wlast, pipe_wch}),
            .o_valid (o_wvalid[i]),
            .o_ready (o_wready[i]),
            .o_data  ({o_wlast[i], o_wch[i*WCH_W+:WCH_W]})
        );


        axicb_pipeline
        #(
            .DATA_BUS_W  (BCH_W),
            .NB_PIPELINE (MST_PIPELINE)
        )
        bch_mst_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (o_bvalid[i]),
            .i_ready (o_bready[i]),
            .i_data  (o_bch[i*BCH_W+:BCH_W]),
            .o_valid (pipe_bvalid),
            .o_ready (pipe_bready),
            .o_data  (pipe_bch)
        );


        axicb_pipeline
        #(
            .DATA_BUS_W  (ARCH_W),
            .NB_PIPELINE (MST_PIPELINE)
        )
        arch_mst_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (pipe_arvalid),
            .i_ready (pipe_arready),
            .i_data  (pipe_arch),
            .o_valid (o_arvalid[i]),
            .o_ready (o_arready[i]),
            .o_data  (o_arch[i*ARCH_W+:ARCH_W])
        );

        axicb_pipeline
        #(
            .DATA_BUS_W  (RCH_W+1),
            .NB_PIPELINE (MST_PIPELINE)
        )
        rch_mst_pipe
        (
            .aclk    (aclk),
            .aresetn (aresetn),
            .srst    (srst),
            .i_valid (o_rvalid[i]),
            .i_ready (o_rready[i]),
            .i_data  ({o_rlast[i], o_rch[i*RCH_W+:RCH_W]}),
            .o_valid (pipe_rvalid),
            .o_ready (pipe_rready),
            .o_data  ({pipe_rlast, pipe_rch})
        );

    end
    endgenerate

    endmodule

    `resetall
