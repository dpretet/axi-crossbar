// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

///////////////////////////////////////////////////////////////////////////////
//
// Single clock FIFO (first-in / first-out) to buffer an incoming stream
// before consuming it.
//
// Address width: define the depth of the FIFO, only a power of 2
//
// Pass-thru mode: if enabled, when pull and empty are asserted, waiting
// for a data stream, the incoming write stream is moved directly
// to the output stream without buffering it into the RAM. This mode reduces
// the latency to transmit data if both producer and consumer are ready.
//
// CAUTION: this pass-thru mode implements a full combinatorial circuit, be
// sure to connect synchronous logic to avoid combinatorial loop around the
// control flow.
//
///////////////////////////////////////////////////////////////////////////////

module axicb_scfifo

    #(
        // When pull & empty, move data directly to the output
        parameter PASS_THRU = 0,
        // Address bus width, depth=2**ADDR_WIDTH
        parameter ADDR_WIDTH = 8,
        // Data stream width
        parameter DATA_WIDTH = 8
    )(
        input  wire                   aclk,
        input  wire                   aresetn,
        input  wire                   srst,
        input  wire                   flush,
        input  wire  [DATA_WIDTH-1:0] data_in,
        input  wire                   push,
        output logic                  full,
        output logic [DATA_WIDTH-1:0] data_out,
        input  wire                   pull,
        output logic                  empty
    );

    ///////////////////////////////////////////////////////////////////////////
    // Parameters and signals declarations
    ///////////////////////////////////////////////////////////////////////////

    logic                  wr_en;
    logic [ADDR_WIDTH  :0] wrptr;
    logic [ADDR_WIDTH  :0] rdptr;
    logic                  empty_flag;
    logic                  full_flag;
    logic                  pass_thru;
    logic [DATA_WIDTH-1:0] data_fifo;


    ///////////////////////////////////////////////////////////////////////////
    // Write Pointer Management
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin
        if (aresetn == 1'b0) begin
            wrptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if (srst || flush) begin
            wrptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            if (push == 1'b1 && full_flag == 1'b0 && pass_thru==1'b0) begin
                wrptr <= wrptr + 1'b1;
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////
    // Read Pointer Management
    ///////////////////////////////////////////////////////////////////////////

    always @ (posedge aclk or negedge aresetn) begin
        if (aresetn == 1'b0) begin
            rdptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else if (srst || flush) begin
            rdptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            if (pull == 1'b1 && empty_flag == 1'b0) begin
                rdptr <= rdptr + 1'b1;
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////
    // Full and empty flags
    ///////////////////////////////////////////////////////////////////////////

    assign empty_flag = (wrptr == rdptr) ? 1'b1 : 1'b0;
    assign full_flag = ((wrptr - rdptr) == {1'b1,{ADDR_WIDTH{1'b0}}}) ? 1'b1 : 1'b0;


    ///////////////////////////////////////////////////////////////////////////
    // Internal RAM
    ///////////////////////////////////////////////////////////////////////////

    assign wr_en = push & ~full & ~pass_thru;

    axicb_scfifo_ram
    #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .FFD_EN     (0)
    )
        fifo_ram
    (
        .aclk     (aclk                 ),
        .wr_en    (wr_en                ),
        .addr_in  (wrptr[ADDR_WIDTH-1:0]),
        .data_in  (data_in              ),
        .addr_out (rdptr[ADDR_WIDTH-1:0]),
        .data_out (data_fifo            )
    );

    ///////////////////////////////////////////////////////////////////////////
    // Pass-thru mode management
    ///////////////////////////////////////////////////////////////////////////

    generate
    if (PASS_THRU) begin :  PASS_THRU_MODE

        assign pass_thru = pull & empty_flag;
        assign data_out = (pass_thru) ? data_in : data_fifo;
        assign empty = (pass_thru) ? ~push : empty_flag;
        assign full = full_flag;

    end else begin : STORE_MODE

        assign pass_thru = 1'b0;
        assign data_out = data_fifo;
        assign empty = empty_flag;
        assign full = full_flag;

    end
    endgenerate

endmodule

`resetall
