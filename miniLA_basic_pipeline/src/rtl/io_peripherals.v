`timescale 1ns / 1ps

`include "defines.vh"

module io_peripherals #(
    parameter CLK_FREQ = 50000000,
    parameter UART_BAUD = 115200
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         io_ren,
    input  wire [ 3:0]  io_wen,
    input  wire [31:0]  io_addr,
    input  wire [31:0]  io_wdata,
    output reg          io_rvalid,
    output reg  [31:0]  io_rdata,
    output reg          io_wresp,

    input  wire [15:0]  sw,
    output reg  [15:0]  led,
    output reg  [31:0]  dig_value,
    input  wire         rx,
    output wire         tx
);

    reg [63:0] timer;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    reg tx_reset;
    wire [7:0] rx_data;
    wire rx_valid;
    reg rx_pop;
    reg rx_reset;

    function [31:0] merge_bytes;
        input [31:0] old_data;
        input [31:0] new_data;
        input [3:0] byte_en;
        begin
            merge_bytes = old_data;
            if (byte_en[0]) merge_bytes[7:0] = new_data[7:0];
            if (byte_en[1]) merge_bytes[15:8] = new_data[15:8];
            if (byte_en[2]) merge_bytes[23:16] = new_data[23:16];
            if (byte_en[3]) merge_bytes[31:24] = new_data[31:24];
        end
    endfunction

    uart_simple #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD     (UART_BAUD)
    ) U_UART (
        .clk      (clk),
        .rst      (rst),
        .rx       (rx),
        .tx       (tx),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx_busy  (tx_busy),
        .tx_reset (tx_reset),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .rx_pop   (rx_pop),
        .rx_reset (rx_reset)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            timer <= 64'h0;
            led <= 16'h0;
            dig_value <= 32'h0;
            io_rvalid <= 1'b0;
            io_rdata <= 32'h0;
            io_wresp <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 8'h0;
            tx_reset <= 1'b0;
            rx_pop <= 1'b0;
            rx_reset <= 1'b0;
        end else begin
            timer <= timer + 1'b1;
            io_rvalid <= 1'b0;
            io_wresp <= 1'b0;
            tx_start <= 1'b0;
            tx_reset <= 1'b0;
            rx_pop <= 1'b0;
            rx_reset <= 1'b0;

            if (io_ren) begin
                io_rvalid <= 1'b1;
                case (io_addr)
                    `PERI_ADDR_SWITCH:
                        io_rdata <= {16'h0, sw};
                    `PERI_ADDR_UART + 32'h0: begin
                        io_rdata <= {24'h0, rx_data};
                        if (rx_valid)
                            rx_pop <= 1'b1;
                    end
                    `PERI_ADDR_UART + 32'h8:
                        io_rdata <= {28'h0, !tx_busy, 2'b00,
                                     rx_valid};
                    `PERI_ADDR_TIMER + 32'h0:
                        io_rdata <= timer[31:0];
                    `PERI_ADDR_TIMER + 32'h8:
                        io_rdata <= timer[63:32];
                    default:
                        io_rdata <= 32'h0;
                endcase
            end

            if (|io_wen) begin
                io_wresp <= 1'b1;
                case (io_addr)
                    `PERI_ADDR_LED:
                        led <= merge_bytes({16'h0, led}, io_wdata,
                                           io_wen);
                    `PERI_ADDR_DIGLED:
                        dig_value <= merge_bytes(dig_value, io_wdata,
                                                 io_wen);
                    `PERI_ADDR_UART + 32'h4: begin
                        if (!tx_busy) begin
                            tx_data <= io_wdata[7:0];
                            tx_start <= 1'b1;
                        end
                    end
                    `PERI_ADDR_UART + 32'hC: begin
                        rx_reset <= io_wdata[1];
                        tx_reset <= io_wdata[0];
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
