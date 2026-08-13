`timescale 1ns / 1ps

module seven_seg (
    input  wire         clk,
    input  wire         rst,
    input  wire [31:0]  value,
    output reg  [ 7:0]  dig_en,
    output reg  [ 7:0]  dig_seg,
    output reg  [ 7:0]  dig_seg1
);

    reg [15:0] refresh;
    wire [2:0] scan = refresh[15:13];
    reg [3:0] nibble;
    reg [7:0] segment;

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh <= 16'h0;
        else
            refresh <= refresh + 1'b1;
    end

    always @(*) begin
        case (scan)
            3'd0: nibble = value[3:0];
            3'd1: nibble = value[7:4];
            3'd2: nibble = value[11:8];
            3'd3: nibble = value[15:12];
            3'd4: nibble = value[19:16];
            3'd5: nibble = value[23:20];
            3'd6: nibble = value[27:24];
            default: nibble = value[31:28];
        endcase

        case (nibble)
            4'h0: segment = 8'b11111100;
            4'h1: segment = 8'b01100000;
            4'h2: segment = 8'b11011010;
            4'h3: segment = 8'b11110010;
            4'h4: segment = 8'b01100110;
            4'h5: segment = 8'b10110110;
            4'h6: segment = 8'b10111110;
            4'h7: segment = 8'b11100000;
            4'h8: segment = 8'b11111110;
            4'h9: segment = 8'b11110110;
            4'hA: segment = 8'b11101110;
            4'hB: segment = 8'b00111110;
            4'hC: segment = 8'b10011100;
            4'hD: segment = 8'b01111010;
            4'hE: segment = 8'b10011110;
            default: segment = 8'b10001110;
        endcase

        dig_en = 8'b00000001 << scan;
        dig_seg = scan < 4 ? segment : 8'h0;
        dig_seg1 = scan < 4 ? 8'h0 : segment;
    end

endmodule
