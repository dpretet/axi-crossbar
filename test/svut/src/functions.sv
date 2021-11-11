`default_nettype none

`ifndef TB_FUNCTIONS
`define TB_FUNCTIONS

function automatic integer gen_resp(integer value);

    gen_resp[31] = value[31];
    for (int i=31; i>0; i=i-1) begin
        gen_resp[i-1] = value[i] ^ value[i-1];
    end

endfunction

function automatic integer gen_data(integer value);

    gen_data = {value[7:0],value[7:0],value[7:0],value[7:0]};

endfunction

function automatic integer next_data(integer value);

    next_data = value + {8'h1, 8'h1, 8'h1, 8'h1};

endfunction

`endif
