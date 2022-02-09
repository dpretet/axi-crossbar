// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module axicb_scfifo_ram

    #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8,
        parameter FFD_EN = 0
    )(
        input  wire                   aclk,
        input  wire                   wr_en,
        input  wire  [ADDR_WIDTH-1:0] addr_in,
        input  wire  [DATA_WIDTH-1:0] data_in,
        input  wire  [ADDR_WIDTH-1:0] addr_out,
        output logic [DATA_WIDTH-1:0] data_out
    );

    logic [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];

    always @ (posedge aclk) begin
        if (wr_en) begin
            ram[addr_in] <= data_in;
        end
    end

    generate if (FFD_EN==1) begin: WITH_FFD
        always @ (posedge aclk) begin
            data_out <= ram[addr_out];
        end
    end else begin: NO_FFD
        assign data_out = ram[addr_out];
    end
    endgenerate

endmodule

`resetall
