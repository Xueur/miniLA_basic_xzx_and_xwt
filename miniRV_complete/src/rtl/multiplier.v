`timescale 1ns / 1ps

module multiplier #(
    parameter WIDTH = 32
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire [WIDTH-1:0]     x,
    input  wire [WIDTH-1:0]     y,
    input  wire                 start,
    output reg  [2*WIDTH-1:0]   z,
    output reg                  busy
);

    localparam COUNT_W = $clog2(WIDTH);

    reg [2*WIDTH-1:0] acc;
    reg [2*WIDTH-1:0] multiplicand;
    reg [WIDTH-1:0] multiplier_reg;
    reg [COUNT_W-1:0] count;
    reg negative;
    reg [2*WIDTH-1:0] acc_next;

    wire [WIDTH-1:0] x_abs = x[WIDTH-1] ? (~x + 1'b1) : x;
    wire [WIDTH-1:0] y_abs = y[WIDTH-1] ? (~y + 1'b1) : y;

    always @(*) begin
        acc_next = multiplier_reg[0] ? acc + multiplicand : acc;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            z <= {2*WIDTH{1'b0}};
            acc <= {2*WIDTH{1'b0}};
            multiplicand <= {2*WIDTH{1'b0}};
            multiplier_reg <= {WIDTH{1'b0}};
            count <= {COUNT_W{1'b0}};
            negative <= 1'b0;
            busy <= 1'b0;
        end else if (start && !busy) begin
            acc <= {2*WIDTH{1'b0}};
            multiplicand <= {{WIDTH{1'b0}}, x_abs};
            multiplier_reg <= y_abs;
            count <= {COUNT_W{1'b0}};
            negative <= x[WIDTH-1] ^ y[WIDTH-1];
            busy <= 1'b1;
        end else if (busy) begin
            if (count == WIDTH - 1) begin
                z <= negative ? (~acc_next + 1'b1) : acc_next;
                busy <= 1'b0;
            end else begin
                acc <= acc_next;
                multiplicand <= multiplicand << 1;
                multiplier_reg <= multiplier_reg >> 1;
                count <= count + 1'b1;
            end
        end
    end

endmodule
