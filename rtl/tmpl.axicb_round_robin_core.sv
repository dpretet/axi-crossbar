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
// This template is derived from the original code only handling
// 4 or 8 requesters: orig.axicb_round_robin_core.sv
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
    logic [REQ_NB    -1:0] grant_r;
    logic [REQ_NB    -1:0] grant_c;


    generate
    {% for ix in range(2, num+1) %}
    if (REQ_NB=={{ix}}) begin : GRANT_{{ix}}

    // Compute the requester granted based on mask state
    always @ (*) begin

        // 1. Applies the mask and init the granted output
        masked = mask & req;

        // 2. Zeroes the grants once found a first activated one

        // 2.1 handles first the reqs which fall into the mask
        if (|masked) begin
            if      (masked[0]) grant_c = $bits(grant_c)'(1);
            {%- for gix in range(1, ix) %}
            else if (masked[{{gix}}]) grant_c = $bits(grant_c)'({{2**gix}});
            {%- endfor %}
            else                grant_c = '0;

        // 2.2 if the mask doesn't match the reqs, uses the unmasked ones
        end else begin
            if      (req[0]) grant_c = $bits(grant_c)'(1);
            {%- for gix in range(1, ix) %}
            else if (req[{{gix}}]) grant_c = $bits(grant_c)'({{2**gix}});
            {%- endfor %}
            else             grant_c = '0;
        end
    end

    // Generate the next mask
    always @ (posedge aclk or negedge aresetn) begin : MASK_{{ix}}

        if (!aresetn) begin
            mask <= '0;
        end else if (srst) begin
            mask <= '0;
        end else begin
            if (en && |grant) begin
                if      (grant[0]) mask <= $bits(mask)'({{(2**ix-1)-1}});
                {%- for mix in range(1, ix-1) %}
                else if (grant[{{mix}}]) mask <= $bits(mask)'({{((2**ix-1-1)*2*mix)%(2**ix)}});
                {%- endfor %}
                else if (grant[{{ix-1}}]) mask <= '1;
            end
        end
    end

    end
    {% endfor %}
    endgenerate

    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            grant_r <= '0;
        end else if (srst) begin
            grant_r <= '0;
        end else begin
            if (en) begin
                grant_r <= grant_c;
            end
        end
    end

    always @ (*) begin
        if (en)
            grant = grant_c;
        else
            grant = grant_r;
    end

endmodule

`resetall
