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
        // Requesters priorities
        parameter PRIORITY_W = 2,
        parameter NUM_PRIORITY_LVL = 4,
        parameter [PRIORITY_W*REQ_NB-1:0] PRIORITY = 0
    )(
        input  wire                   aclk,
        input  wire                   aresetn,
        input  wire                   srst,
        input  wire                   en,
        input  wire  [REQ_NB    -1:0] req,
        output logic [REQ_NB    -1:0] grant
    );

    ////////////////////////////////////////
    // Local functions to mux granting
    ////////////////////////////////////////

    function [REQ_NB-1:0] grant_lvl4(
        input [REQ_NB-1:0] lvl,
        input [REQ_NB-1:0] grant_p3,
        input [REQ_NB-1:0] grant_p2,
        input [REQ_NB-1:0] grant_p1,
        input [REQ_NB-1:0] grant_p0
    );

        grant_lvl4 = (lvl[3]) ? grant_p3 :
                     (lvl[2]) ? grant_p2 :
                     (lvl[1]) ? grant_p1 :
                                grant_p0 ;
    endfunction


    function [REQ_NB-1:0] grant_lvl3(
        input [REQ_NB-1:0] lvl,
        input [REQ_NB-1:0] grant_p2,
        input [REQ_NB-1:0] grant_p1,
        input [REQ_NB-1:0] grant_p0
    );

        grant_lvl3 = (lvl[2]) ? grant_p2 :
                     (lvl[1]) ? grant_p1 :
                                grant_p0 ;
    endfunction


    function [REQ_NB-1:0] grant_lvl2(
        input [REQ_NB-1:0] lvl,
        input [REQ_NB-1:0] grant_p1,
        input [REQ_NB-1:0] grant_p0
    );

        grant_lvl2 = (lvl[1]) ? grant_p1 :
                                grant_p0 ;
    endfunction

    ////////////////////////////////////////
    // Local variables
    ////////////////////////////////////////

    logic [REQ_NB          -1:0] reqs[NUM_PRIORITY_LVL-1:0];
    logic [REQ_NB          -1:0] grants[NUM_PRIORITY_LVL-1:0];
    logic [NUM_PRIORITY_LVL-1:0] p_active;

    genvar i, j;

    // Sort the requesters by priority levels
    generate

        if (NUM_PRIORITY_LVL > 1) begin: LVL_REQS
            for (i=0; i<REQ_NB; i++) begin: GEN_REQS
                for (j=0; j<NUM_PRIORITY_LVL; j++) begin: GEN_PRIO
                    assign reqs[j][i] = (PRIORITY[i*PRIORITY_W+:PRIORITY_W] == j) ? req[i] : '0;
                end
            end
        end else begin: NO_LVL_REQS
            assign reqs[0] = req;
        end

    endgenerate

    // Enable a round robin layer
    generate

        // With priority level bigger than 1, a layer is active only if
        // the upper layers are not
        if (NUM_PRIORITY_LVL > 1) begin: LVL_GEN_ACTIVE
            for (i=NUM_PRIORITY_LVL-1; i>=0; i--) begin: GEN_P_ACTIVE
                if (i==NUM_PRIORITY_LVL-1) begin: LVL_ACTIVE_MAX
                    assign p_active[i] = |reqs[i];
                end else begin: LVL_ACTIVE_N
                    assign p_active[i] = |reqs[i] & !p_active[i+1];
                end
            end
        // One layer to always active
        end else begin: NO_LVL_GEN_ACTIVE
            assign p_active[0] = '1;
        end

    endgenerate

    axicb_round_robin_core
    #(
        .REQ_NB (REQ_NB)
    )
    rr_p0
    (
        .aclk    (aclk),
        .aresetn (aresetn),
        .srst    (srst),
        .en      (en & p_active[0]),
        .req     (reqs[0]),
        .grant   (grants[0])
    );

    generate

    if (NUM_PRIORITY_LVL > 1) begin: LVL_RR
        for (i=1; i<NUM_PRIORITY_LVL; i++) begin: GEN_RR
            axicb_round_robin_core
            #(
                .REQ_NB (REQ_NB)
            )
            rr_core
            (
                .aclk    (aclk),
                .aresetn (aresetn),
                .srst    (srst),
                .en      (en & p_active[i]),
                .req     (reqs[i]),
                .grant   (grants[i])
            );
        end
    end
    endgenerate

    generate

        if (NUM_PRIORITY_LVL == 4) begin: GRANT_L4
            assign grant = grant_lvl4(p_active, grants[3], grants[2], grants[1], grants[0]);
        end else if (NUM_PRIORITY_LVL == 3) begin: GRANT_L3
            assign grant = grant_lvl3(p_active, grants[2], grants[1], grants[0]);
        end else if (NUM_PRIORITY_LVL == 2) begin: GRANT_L2
            assign grant = grant_lvl2(p_active, grants[1], grants[0]);
        end else begin: GRANT_L1
            assign grant = grants[0];
        end

    endgenerate

endmodule

`resetall
