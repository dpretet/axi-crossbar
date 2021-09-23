// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

///////////////////////////////////////////////////////////////////////////////
//
// Non-blocking round robin arbiter:
//
//   - if all requesters are enabled, will grant the access from LSB to MSB,
//     thus from req 0 to req 3 and then restart from 0
//
//         req    mask  grant  next-mask
//                             
//         1111   1111   0001    1110
//         1111   1110   0010    1100
//         1111   1100   0100    1000 
//         1111   1000   1000    1111
//         1111   1111   0001    1110
//         ...
//
//   - if the next allowed is not active, pass to the next+2
//
//         req    mask   grant   next-mask
//                     
//         1101   1111    0001     1110
//         1101   1110    0100     1000
//         1101   1000    1000     1111
//         1101   1111    0001     1110
//         1111   1110    0010     1100
//         1111   1100    0100     1000
//         ...
//
//   - if a lonely request doesn't match a mask, pass anyway and reboot the
//     mask if no next req index is active
//
//         req    mask  grant   next-mask
//                      
//         0011   1111   0001     1110
//         0011   1110   0010     1100
//         0011   1100   0001     1110 
//         0111   1110   0010     1100
//         0111   1100   0100     1000
//         ...
//
//   - to balance granting, masters can be prioritzed (from 0 to 3); an 
//     activated highest priority layer prevent computation of lowest
//     priority layers.
//     
//     (here, priority 1 for req 2, 0 for others)
//
//         req    mask   grant   next-mask (p2) next-mask (p0)
//                      
//         1111   1111    0100      1000          1111    
//         1011   1111    0001      1100          1110
//         1011   1110    0010      1100          1100
//         1111   1000    0100      1111          1100
//         1011   1100    1000      1111          1111
//         ...
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
        input  logic                  aclk,
        input  logic                  aresetn,
        input  logic                  srst,
        input  logic                  en,
        input  logic [REQ_NB    -1:0] req,
        output logic [REQ_NB    -1:0] grant
    );

    logic [REQ_NB    -1:0] mask;
    logic [REQ_NB    -1:0] masked;


    ///////////////////////////////////////////////////////////////////////////
    // Compute the requester granted based on mask state
    ///////////////////////////////////////////////////////////////////////////
    always @ (*) begin

        int i;
        logic selected;

        // 1. Applies the mask and init the granted output
        masked = mask & req;

        // 2. Zeroes the grants once found a first activated one

        // 2.1 handles first the reqs which fall into the mask
        if (|masked) begin
            grant[0] = masked[0];
            selected = masked[0];
            for (i=1;i<REQ_NB;i=i+1) begin
                if (selected) begin
                    grant[i] = 0;
                end else begin
                    grant[i] = masked[i];
                    selected = masked[i];
                end
            end

        // 2.2 if the mask doesn't match the reqs, uses the unmasked ones
        end else begin
            grant[0] = req[0];
            selected = 0;
            for (i=1;i<REQ_NB;i=i+1) begin
                if (grant[i-1]) grant[i] = 0;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Generate the next mask
    ///////////////////////////////////////////////////////////////////////////

    generate
    if (REQ_NB==4) begin : REQ_4

    function automatic [REQ_NB-1:0] next_mask_4req(
        input [REQ_NB-1:0] grant
    );

        if      (grant[0]) next_mask_4req = 4'b1110;
        else if (grant[1]) next_mask_4req = 4'b1100;
        else if (grant[2]) next_mask_4req = 4'b1000;
        else if (grant[3]) next_mask_4req = 4'b1111;

    endfunction

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            mask <= {REQ_NB{1'b1}};
        end else if (srst) begin
            mask <= {REQ_NB{1'b1}};
        end else begin
            if (en && |grant) begin
                if (REQ_NB==4) mask <= next_mask_4req(grant);
            end
        end
    end

    end else if (REQ_NB==8) begin : REQ_8

    function automatic [REQ_NB-1:0] next_mask_8req(
        input [REQ_NB-1:0] grant
    );

        if      (grant[0]) next_mask_8req = 8'b11111110;
        else if (grant[1]) next_mask_8req = 8'b11111100;
        else if (grant[2]) next_mask_8req = 8'b11111000;
        else if (grant[3]) next_mask_8req = 8'b11110000;
        else if (grant[4]) next_mask_8req = 8'b11100000;
        else if (grant[5]) next_mask_8req = 8'b11000000;
        else if (grant[6]) next_mask_8req = 8'b10000000;
        else               next_mask_8req = 8'b11111111;

    endfunction

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            mask <= {REQ_NB{1'b1}};
        end else if (srst) begin
            mask <= {REQ_NB{1'b1}};
        end else begin
            if (en && |grant) begin
                if (REQ_NB==4) mask <= next_mask_8req(grant);
            end
        end
    end

    end
    endgenerate

endmodule

`resetall
