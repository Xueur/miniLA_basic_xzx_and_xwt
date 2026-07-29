`timescale 1ns / 1ps

module seven_seg_board_tb;

    reg clk = 1'b0;
    reg rst = 1'b0;
    reg [31:0] value = 32'h25000025;
    wire [7:0] dig_en;
    wire [7:0] dig_seg;
    wire [7:0] dig_seg1;
    integer i;

    seven_seg DUT (
        .clk      (clk),
        .rst      (rst),
        .value    (value),
        .dig_en   (dig_en),
        .dig_seg  (dig_seg),
        .dig_seg1 (dig_seg1)
    );

    always #10 clk = ~clk;

    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            force DUT.refresh = i << 13;
            #1;
            if (dig_en !== (8'b00000001 << i))
                $fatal(1, "digit enable mismatch at scan %0d", i);
            if (i < 4) begin
                if (dig_seg !== 8'h00 || dig_seg1 === 8'h00)
                    $fatal(1, "right group routing mismatch at scan %0d", i);
            end else begin
                if (dig_seg === 8'h00 || dig_seg1 !== 8'h00)
                    $fatal(1, "left group routing mismatch at scan %0d", i);
            end
            release DUT.refresh;
        end
        $display("EGO1 SEVEN-SEGMENT GROUP ROUTING PASSED");
        $finish;
    end

endmodule
