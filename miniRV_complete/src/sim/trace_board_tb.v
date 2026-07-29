`timescale 1ns / 1ps

module trace_board_tb;

    localparam CLK_PERIOD = 20;
    localparam EXPECTED_RESULT = 32'h25000025;
    localparam MAX_CYCLES = 2000000;

    reg fpga_clk = 1'b0;
    reg fpga_rst = 1'b0;
    reg [15:0] sw = 16'h0;
    reg rx = 1'b1;
    wire [15:0] led;
    wire [7:0] dig_en;
    wire [7:0] dig_seg;
    wire [7:0] dig_seg1;
    wire tx;
    integer cycles = 0;

    always #(CLK_PERIOD / 2) fpga_clk = ~fpga_clk;

    miniRV_SoC #(
        .MEM_BANK0_FILE ("start_bank0.hex"),
        .MEM_BANK1_FILE ("start_bank1.hex"),
        .MEM_BANK2_FILE ("start_bank2.hex"),
        .MEM_BANK3_FILE ("start_bank3.hex"),
        .MEM_BANK4_FILE ("start_bank4.hex")
    ) DUT (
        .fpga_clk (fpga_clk),
        .fpga_rst (fpga_rst),
        .sw       (sw),
        .led      (led),
        .dig_en   (dig_en),
        .dig_seg  (dig_seg),
        .dig_seg1 (dig_seg1),
        .rx       (rx),
        .tx       (tx)
    );

    always @(posedge fpga_clk) begin
        if (fpga_rst) begin
            cycles <= cycles + 1;

            if (DUT.U_cpu.U_IO.dig_value == EXPECTED_RESULT) begin
                $display(
                    "TRACE BOARD TEST PASSED: display = 0x%08x",
                    DUT.U_cpu.U_IO.dig_value
                );
                $finish;
            end

            if (cycles >= MAX_CYCLES) begin
                $fatal(
                    1,
                    "TRACE BOARD TEST TIMEOUT: display = 0x%08x",
                    DUT.U_cpu.U_IO.dig_value
                );
            end
        end
    end

    initial begin
        repeat (10) @(posedge fpga_clk);
        fpga_rst = 1'b1;
    end

endmodule
