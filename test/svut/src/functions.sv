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

function automatic integer gen_size(integer value);
    gen_size = value - 10 + value >> 1;
endfunction

function automatic integer gen_burst(integer value);
    gen_burst = value | value << 2;
endfunction

function automatic integer gen_lock(integer value);
    gen_lock = value / 2;
endfunction

function automatic integer gen_cache(integer value);
    gen_cache = value - 23; 
endfunction

function automatic integer gen_prot(integer value);
    gen_prot = value + 1;
endfunction

function automatic integer gen_qos(integer value);
    gen_qos = 50 * value - 2;
endfunction

function automatic integer gen_region(integer value);
    gen_region = (7 + value) / 4;
endfunction

function automatic integer gen_auser(integer value);
    gen_auser = value ^ value << 3;
endfunction

function automatic integer gen_wuser(integer value);
    gen_wuser = 23 + value;
endfunction

function automatic integer gen_buser(integer value);
    gen_buser = value + value >> 3;
endfunction

function automatic integer gen_ruser(integer value);
    gen_ruser = value - value * 6;
endfunction

`endif
