`ifndef AXICB_CHECKERS
`define AXICB_CHECKERS

`define CHECKER(condition, msg)\
    if (condition) begin \
        $display("\033[1;31mERROR: %s\033[0m", msg); \
        $finish(1); \
    end

`endif
