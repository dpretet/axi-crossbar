`default_nettype none

`ifndef TB_FUNCTIONS
`define TB_FUNCTIONS

function automatic integer gen_resp(integer value);

    gen_resp[31] = value[31];
    for (int i=31; i>0; i=i-1) begin
        gen_resp[i-1] = value[i] ^ value[i-1];
    end

endfunction

`endif
