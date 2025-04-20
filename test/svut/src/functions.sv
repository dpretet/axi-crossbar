// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`default_nettype none

`ifndef TB_FUNCTIONS
`define TB_FUNCTIONS



function automatic integer is_misroute(
    input integer mst_route,
    input integer slv0_start_addr,
    input integer slv0_end_addr,
    input integer slv1_start_addr,
    input integer slv1_end_addr,
    input integer slv2_start_addr,
    input integer slv2_end_addr,
    input integer slv3_start_addr,
    input integer slv3_end_addr,
    input integer value
);

    // Targeted address is not allowed for this master
    if (((value>=slv0_start_addr && value<=slv0_end_addr) && !mst_route[0]) ||
        ((value>=slv1_start_addr && value<=slv1_end_addr) && !mst_route[1]) ||
        ((value>=slv2_start_addr && value<=slv2_end_addr) && !mst_route[2]) ||
        ((value>=slv3_start_addr && value<=slv3_end_addr) && !mst_route[3])
     ) begin
         is_misroute = 1;
    // Try to target an unmapped address
    end else if (!(value>=slv0_start_addr && value<=slv0_end_addr) &&
                 !(value>=slv1_start_addr && value<=slv1_end_addr) &&
                 !(value>=slv2_start_addr && value<=slv2_end_addr) &&
                 !(value>=slv3_start_addr && value<=slv3_end_addr)
     ) begin
         is_misroute = 1;
     end else begin
         is_misroute = 0;
     end
endfunction


function automatic integer gen_resp_for_master(
    input integer mst_route,
    input integer slv0_start_addr,
    input integer slv0_end_addr,
    input integer slv1_start_addr,
    input integer slv1_end_addr,
    input integer slv2_start_addr,
    input integer slv2_end_addr,
    input integer slv3_start_addr,
    input integer slv3_end_addr,
    input integer value
);

    // Targeted address is not allowed for this master
    if (is_misroute(
        mst_route,
        slv0_start_addr,
        slv0_end_addr,
        slv1_start_addr,
        slv1_end_addr,
        slv2_start_addr,
        slv2_end_addr,
        slv3_start_addr,
        slv3_end_addr,
        value
        ) > 0
     ) begin
        gen_resp_for_master = 3;

    // Target is legal, generate the response
    end else begin
        gen_resp_for_master = gen_resp_for_slave(value);
    end

endfunction


function automatic integer gen_resp_for_slave(
    input integer value
);
    gen_resp_for_slave[31] = value[31];
    for (int i=31; i>0; i=i-1) begin
        gen_resp_for_slave[i-1] = value[i] ^ value[i-1];
    end
endfunction


function automatic integer gen_data(
    input integer value
);
    gen_data = {value[7:0],value[7:0],value[7:0],value[7:0]};
endfunction



function automatic integer next_data(
    input integer value
);
    next_data = value + {8'h1, 8'h1, 8'h1, 8'h1};
endfunction


function automatic integer gen_size(
    input integer value
);
    gen_size = value - 10 + value >> 1;
endfunction


function automatic integer gen_burst(
    input integer value
);
    gen_burst = value | value << 2;
endfunction


function automatic integer gen_lock(
    input integer value
);
    gen_lock = value / 2;
endfunction


function automatic integer gen_cache(
    input integer value
);
    gen_cache = value - 23;
endfunction


function automatic integer gen_prot(
    input integer value
);
    gen_prot = value + 1;
endfunction


function automatic integer gen_qos(
    input integer value
);
    gen_qos = 50 * value - 2;
endfunction


function automatic integer gen_region(
    input integer value
);
    gen_region = (7 + value) / 4;
endfunction


function automatic integer gen_auser(
    input integer value
);
    gen_auser = value ^ value << 3;
endfunction


function automatic integer gen_wuser(
    input integer value
);
    gen_wuser = 23 + value;
endfunction


function automatic integer gen_buser(
    input integer value
);
    gen_buser = value + value >> 3;
endfunction


function automatic integer gen_ruser(
    input integer value
);
    gen_ruser = value - value * 6;
endfunction

`endif
