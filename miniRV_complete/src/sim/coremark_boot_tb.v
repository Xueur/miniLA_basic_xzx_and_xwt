`timescale 1ns / 1ps

module coremark_boot_tb;

    localparam CLK_PERIOD = 20;
    localparam MAX_CYCLES = 7000000;

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
    integer chars = 0;
    reg [8*12-1:0] received = 0;

    always #(CLK_PERIOD / 2) fpga_clk = ~fpga_clk;

    miniRV_SoC #(
        .MEM_BANK0_FILE ("coremark_bank0.hex"),
        .MEM_BANK1_FILE ("coremark_bank1.hex"),
        .MEM_BANK2_FILE ("coremark_bank2.hex"),
        .MEM_BANK3_FILE ("coremark_bank3.hex"),
        .MEM_BANK4_FILE ("coremark_bank4.hex")
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

            if (DUT.U_cpu.U_IO.tx_start) begin
                $write("%c", DUT.U_cpu.U_IO.tx_data);
                received <= {
                    received[8*11-1:0],
                    DUT.U_cpu.U_IO.tx_data
                };
                chars <= chars + 1;
                if ({
                    received[8*11-1:0],
                    DUT.U_cpu.U_IO.tx_data
                } == "CoreMark 1.0") begin
                    $display(
                        "COREMARK BOOT/UART TEST PASSED in %0d cycles",
                        cycles
                    );
                    $finish;
                end
            end

            if (cycles >= MAX_CYCLES) begin
                $fatal(
                    1,
                    "COREMARK BOOT/UART TEST TIMEOUT after %0d chars",
                    chars
                );
            end
        end
    end

    initial begin
        repeat (10) @(posedge fpga_clk);
        fpga_rst = 1'b1;
    end

endmodule
