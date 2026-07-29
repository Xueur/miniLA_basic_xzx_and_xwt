`timescale 1ns / 1ps

module uart_simple #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD = 115200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        rx,
    output reg         tx,

    input  wire        tx_start,
    input  wire [7:0]  tx_data,
    output reg         tx_busy,
    input  wire        tx_reset,

    output reg  [7:0]  rx_data,
    output reg         rx_valid,
    input  wire        rx_pop,
    input  wire        rx_reset
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam COUNT_W = $clog2(CLKS_PER_BIT + 1);

    reg [9:0] tx_frame;
    reg [3:0] tx_bit;
    reg [COUNT_W-1:0] tx_count;

    reg rx_meta;
    reg rx_sync;
    reg rx_busy;
    reg [3:0] rx_bit;
    reg [COUNT_W-1:0] rx_count;
    reg [7:0] rx_shift;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_frame <= 10'h3FF;
            tx_bit <= 4'h0;
            tx_count <= {COUNT_W{1'b0}};
        end else if (tx_reset) begin
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_frame <= 10'h3FF;
            tx_bit <= 4'h0;
            tx_count <= {COUNT_W{1'b0}};
        end else if (tx_start && !tx_busy) begin
            tx_frame <= {1'b1, tx_data, 1'b0};
            tx <= 1'b0;
            tx_bit <= 4'h0;
            tx_count <= CLKS_PER_BIT - 1;
            tx_busy <= 1'b1;
        end else if (tx_busy) begin
            if (tx_count == 0) begin
                if (tx_bit == 4'd9) begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                end else begin
                    tx_bit <= tx_bit + 1'b1;
                    tx <= tx_frame[tx_bit + 1'b1];
                    tx_count <= CLKS_PER_BIT - 1;
                end
            end else begin
                tx_count <= tx_count - 1'b1;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_busy <= 1'b0;
            rx_bit <= 4'h0;
            rx_count <= {COUNT_W{1'b0}};
            rx_shift <= 8'h0;
            rx_data <= 8'h0;
            rx_valid <= 1'b0;
        end else if (rx_reset) begin
            rx_busy <= 1'b0;
            rx_bit <= 4'h0;
            rx_count <= {COUNT_W{1'b0}};
            rx_shift <= 8'h0;
            rx_data <= 8'h0;
            rx_valid <= 1'b0;
        end else begin
            if (rx_pop)
                rx_valid <= 1'b0;

            if (!rx_busy) begin
                if (!rx_sync) begin
                    rx_busy <= 1'b1;
                    rx_bit <= 4'h0;
                    rx_count <= CLKS_PER_BIT / 2;
                end
            end else if (rx_count != 0) begin
                rx_count <= rx_count - 1'b1;
            end else begin
                if (rx_bit == 4'd0) begin
                    if (!rx_sync) begin
                        rx_bit <= 4'd1;
                        rx_count <= CLKS_PER_BIT - 1;
                    end else begin
                        rx_busy <= 1'b0;
                    end
                end else if (rx_bit <= 4'd8) begin
                    rx_shift[rx_bit - 1'b1] <= rx_sync;
                    rx_bit <= rx_bit + 1'b1;
                    rx_count <= CLKS_PER_BIT - 1;
                end else begin
                    rx_busy <= 1'b0;
                    if (rx_sync) begin
                        rx_data <= rx_shift;
                        rx_valid <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
