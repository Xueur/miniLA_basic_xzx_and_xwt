`timescale 1ns / 1ps

module divider #(
    parameter WIDTH = 32
)(
    input  wire               clk,
    input  wire               rst,
    input  wire [WIDTH-1:0]   x,
    input  wire [WIDTH-1:0]   y,
    input  wire               start,
    output reg  [WIDTH-1:0]   z,
    output reg  [WIDTH-1:0]   r,
    output reg                busy
);

    localparam COUNT_W = $clog2(WIDTH);

    reg [WIDTH-1:0] dividend;
    reg [WIDTH-1:0] divisor;
    reg [WIDTH-1:0] quotient;
    reg [WIDTH:0] remainder;
    reg [COUNT_W-1:0] count;

    reg [WIDTH:0] remainder_shift;
    reg [WIDTH:0] remainder_next;
    reg [WIDTH-1:0] quotient_next;

    always @(*) begin
        remainder_shift = {remainder[WIDTH-1:0], dividend[WIDTH-1]};
        if (remainder_shift >= {1'b0, divisor}) begin
            remainder_next = remainder_shift - {1'b0, divisor};
            quotient_next = {quotient[WIDTH-2:0], 1'b1};
        end else begin
            remainder_next = remainder_shift;
            quotient_next = {quotient[WIDTH-2:0], 1'b0};
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            z <= {WIDTH{1'b0}};
            r <= {WIDTH{1'b0}};
            dividend <= {WIDTH{1'b0}};
            divisor <= {WIDTH{1'b0}};
            quotient <= {WIDTH{1'b0}};
            remainder <= {(WIDTH+1){1'b0}};
            count <= {COUNT_W{1'b0}};
            busy <= 1'b0;
        end else if (start && !busy) begin
            dividend <= x;
            divisor <= y;
            quotient <= {WIDTH{1'b0}};
            remainder <= {(WIDTH+1){1'b0}};
            count <= {COUNT_W{1'b0}};
            busy <= 1'b1;
        end else if (busy) begin
            dividend <= dividend << 1;
            if (count == WIDTH - 1) begin
                z <= quotient_next;
                r <= remainder_next[WIDTH-1:0];
                busy <= 1'b0;
            end else begin
                quotient <= quotient_next;
                remainder <= remainder_next;
                count <= count + 1'b1;
            end
        end
    end

endmodule
