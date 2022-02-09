// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

///////////////////////////////////////////////////////////////////////////////
//
// Round robin arbitrer top level instanciating the cores per priority
//
///////////////////////////////////////////////////////////////////////////////

module axicb_round_robin

    #(
        // Number of requesters
        parameter REQ_NB = 4,
        // Masters priorities
        parameter REQ0_PRIORITY = 0,
        parameter REQ1_PRIORITY = 0,
        parameter REQ2_PRIORITY = 0,
        parameter REQ3_PRIORITY = 0
    )(
        input  wire                   aclk,
        input  wire                   aresetn,
        input  wire                   srst,
        input  wire                   en,
        input  wire  [REQ_NB    -1:0] req,
        output logic [REQ_NB    -1:0] grant
    );

    logic                  p0_active;
    logic                  p1_active;
    logic                  p2_active;
    logic                  p3_active;

    logic [REQ_NB    -1:0] req_p0;
    logic [REQ_NB    -1:0] req_p1;
    logic [REQ_NB    -1:0] req_p2;
    logic [REQ_NB    -1:0] req_p3;

    logic [REQ_NB    -1:0] grant_p0;
    logic [REQ_NB    -1:0] grant_p1;
    logic [REQ_NB    -1:0] grant_p2;
    logic [REQ_NB    -1:0] grant_p3;

    logic p0 = REQ0_PRIORITY;
    logic p1 = REQ1_PRIORITY;
    logic p2 = REQ2_PRIORITY;
    logic p3 = REQ3_PRIORITY;

    assign req_p0[0] = (REQ0_PRIORITY==0) ? req[0] : 1'b0;
    assign req_p0[1] = (REQ1_PRIORITY==0) ? req[1] : 1'b0;
    assign req_p0[2] = (REQ2_PRIORITY==0) ? req[2] : 1'b0;
    assign req_p0[3] = (REQ3_PRIORITY==0) ? req[3] : 1'b0;

    assign req_p1[0] = (REQ0_PRIORITY==1) ? req[0] : 1'b0;
    assign req_p1[1] = (REQ1_PRIORITY==1) ? req[1] : 1'b0;
    assign req_p1[2] = (REQ2_PRIORITY==1) ? req[2] : 1'b0;
    assign req_p1[3] = (REQ3_PRIORITY==1) ? req[3] : 1'b0;

    assign req_p2[0] = (REQ0_PRIORITY==2) ? req[0] : 1'b0;
    assign req_p2[1] = (REQ1_PRIORITY==2) ? req[1] : 1'b0;
    assign req_p2[2] = (REQ2_PRIORITY==2) ? req[2] : 1'b0;
    assign req_p2[3] = (REQ3_PRIORITY==2) ? req[3] : 1'b0;

    assign req_p3[0] = (REQ0_PRIORITY==3) ? req[0] : 1'b0;
    assign req_p3[1] = (REQ1_PRIORITY==3) ? req[1] : 1'b0;
    assign req_p3[2] = (REQ2_PRIORITY==3) ? req[2] : 1'b0;
    assign req_p3[3] = (REQ3_PRIORITY==3) ? req[3] : 1'b0;

    assign p3_active = |req_p3;
    assign p2_active = |req_p2 & ~p3_active;
    assign p1_active = |req_p1 & ~p2_active;
    assign p0_active = |req_p0 & ~p1_active;


    generate

    if (REQ0_PRIORITY==0 || REQ1_PRIORITY==0 || REQ2_PRIORITY==0 || REQ3_PRIORITY==0) begin : P0_ON

    axicb_round_robin_core
    #(
    .REQ_NB (REQ_NB)
    )
    rr_p0
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (en & p0_active),
    .req     (req_p0),
    .grant   (grant_p0)
    );

    end else begin : P0_OFF
        assign grant_p0 = {REQ_NB{1'b0}};
    end
    endgenerate

    generate
    if (REQ0_PRIORITY==1 || REQ1_PRIORITY==1 || REQ2_PRIORITY==1 || REQ3_PRIORITY==1) begin : P1_ON

    axicb_round_robin_core
    #(
    .REQ_NB (REQ_NB)
    )
    rr_p1
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (en & p1_active),
    .req     (req_p1),
    .grant   (grant_p1)
    );

    end else begin : P1_OFF
        assign grant_p1 = {REQ_NB{1'b0}};
    end
    endgenerate

    generate
    if (REQ0_PRIORITY==2 || REQ1_PRIORITY==2 || REQ2_PRIORITY==2 || REQ3_PRIORITY==2) begin : P2_ON

    axicb_round_robin_core
    #(
    .REQ_NB (REQ_NB)
    )
    rr_p2
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (en & p2_active),
    .req     (req_p2),
    .grant   (grant_p2)
    );

    end else begin : P2_OFF
        assign grant_p2 = {REQ_NB{1'b0}};
    end
    endgenerate

    generate
    if (REQ0_PRIORITY==3 || REQ1_PRIORITY==3 || REQ2_PRIORITY==3 || REQ3_PRIORITY==3) begin : P3_ON

    axicb_round_robin_core
    #(
    .REQ_NB (REQ_NB)
    )
    rr_p3
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .en      (en & p3_active),
    .req     (req_p3),
    .grant   (grant_p3)
    );

    end else begin : P3_OFF
        assign grant_p3 = {REQ_NB{1'b0}};
    end
    endgenerate

    assign grant = (|grant_p3) ? grant_p3 :
                   (|grant_p2) ? grant_p2 :
                   (|grant_p1) ? grant_p1 :
                                 grant_p0 ;

endmodule

`resetall
