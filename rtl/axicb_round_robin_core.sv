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
//     (here, priority 2 for req 2, 0 for others)
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

module axicb_round_robin_core

    #(
        // Number of requesters
        parameter REQ_NB = 4
    )(
        input  wire                   aclk,
        input  wire                   aresetn,
        input  wire                   srst,
        input  wire                   en,
        input  wire  [REQ_NB    -1:0] req,
        output logic [REQ_NB    -1:0] grant
    );

    logic [REQ_NB    -1:0] mask;
    logic [REQ_NB    -1:0] masked;


    ///////////////////////////////////////////////////////////////////////////
    // Compute the requester granted based on mask state
    ///////////////////////////////////////////////////////////////////////////

    generate
    if (REQ_NB==4) begin : GRANT_4

    always @ (*) begin

        // 1. Applies the mask and init the granted output
        masked = mask & req;

        // 2. Zeroes the grants once found a first activated one

        // 2.1 handles first the reqs which fall into the mask
        if (|masked) begin
            if      (masked[0]) grant = 4'b0001;
            else if (masked[1]) grant = 4'b0010;
            else if (masked[2]) grant = 4'b0100;
            else if (masked[3]) grant = 4'b1000;
            else                grant = 4'b0000;

        // 2.2 if the mask doesn't match the reqs, uses the unmasked ones
        end else begin
            if      (req[0]) grant = 4'b0001;
            else if (req[1]) grant = 4'b0010;
            else if (req[2]) grant = 4'b0100;
            else if (req[3]) grant = 4'b1000;
            else             grant = 4'b0000;
        end
    end

    end else if (REQ_NB==8) begin : GRANT_8

    always @ (*) begin

        // 1. Applies the mask and init the granted output
        masked = mask & req;

        // 2. Zeroes the grants once found a first activated one

        // 2.1 handles first the reqs which fall into the mask
        if (|masked) begin
            if      (masked[0]) grant = 8'b00000001;
            else if (masked[1]) grant = 8'b00000010;
            else if (masked[2]) grant = 8'b00000100;
            else if (masked[3]) grant = 8'b00001000;
            else if (masked[4]) grant = 8'b00010000;
            else if (masked[5]) grant = 8'b00100000;
            else if (masked[6]) grant = 8'b01000000;
            else if (masked[7]) grant = 8'b10000000;
            else                grant = 8'b00000000;

        // 2.2 if the mask doesn't match the reqs, uses the unmasked ones
        end else begin
            if      (req[0]) grant = 8'b00000001;
            else if (req[1]) grant = 8'b00000010;
            else if (req[2]) grant = 8'b00000100;
            else if (req[3]) grant = 8'b00001000;
            else if (req[4]) grant = 8'b00010000;
            else if (req[5]) grant = 8'b00100000;
            else if (req[6]) grant = 8'b01000000;
            else if (req[7]) grant = 8'b10000000;
            else             grant = 8'b00000000;
        end
    end

    end

    endgenerate

    ///////////////////////////////////////////////////////////////////////////
    // Generate the next mask
    ///////////////////////////////////////////////////////////////////////////

    generate
    if (REQ_NB==4) begin : REQ_4

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            mask <= {REQ_NB{1'b1}};
        end else if (srst) begin
            mask <= {REQ_NB{1'b1}};
        end else begin
            if (en && |grant) begin
                if      (grant[0]) mask <= 4'b1110;
                else if (grant[1]) mask <= 4'b1100;
                else if (grant[2]) mask <= 4'b1000;
                else if (grant[3]) mask <= 4'b1111;
            end
        end
    end

    end else if (REQ_NB==8) begin : REQ_8

    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            mask <= {REQ_NB{1'b1}};
        end else if (srst) begin
            mask <= {REQ_NB{1'b1}};
        end else begin
            if (en && |grant) begin
                if      (grant[0]) mask <= 8'b11111110;
                else if (grant[1]) mask <= 8'b11111100;
                else if (grant[2]) mask <= 8'b11111000;
                else if (grant[3]) mask <= 8'b11110000;
                else if (grant[4]) mask <= 8'b11100000;
                else if (grant[5]) mask <= 8'b11000000;
                else if (grant[6]) mask <= 8'b10000000;
                else               mask <= 8'b11111111;

            end
        end
    end

    end
    endgenerate

endmodule

`resetall
