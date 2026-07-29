`timescale 1ns / 1ps

module coremark_crc_tb;
    localparam MAX_CYCLES = 30000000;

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
    reg timer_sped_up = 1'b0;
    reg iterations_patched = 1'b0;
    reg list_crc_seen = 1'b0;
    reg matrix_crc_seen = 1'b0;
    reg state_crc_seen = 1'b0;
    reg [8*6-1:0] tail = 0;

    always #10 fpga_clk = ~fpga_clk;

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

            if (!timer_sped_up && cycles == 10000) begin
                force DUT.U_cpu.U_IO.timer = 64'd6000000;
                timer_sped_up <= 1'b1;
            end
            if (timer_sped_up && cycles == 10010)
                release DUT.U_cpu.U_IO.timer;

            if (DUT.U_cpu.U_IO.tx_start) begin
                $write("%c", DUT.U_cpu.U_IO.tx_data);
                tail <= {tail[8*5-1:0], DUT.U_cpu.U_IO.tx_data};
                chars <= chars + 1;

                if (!iterations_patched) begin
                    DUT.U_MAIN_MEMORY.mem1[5629] = 32'd1;
                    DUT.U_cpu.U_DCACHE.valid[63] = 1'b0;
                    iterations_patched <= 1'b1;
                end

                if ({tail[8*5-1:0], DUT.U_cpu.U_IO.tx_data} ==
                    "0xe714")
                    list_crc_seen <= 1'b1;
                if ({tail[8*5-1:0], DUT.U_cpu.U_IO.tx_data} ==
                    "0x1fd7")
                    matrix_crc_seen <= 1'b1;
                if ({tail[8*5-1:0], DUT.U_cpu.U_IO.tx_data} ==
                    "0x8e3a")
                    state_crc_seen <= 1'b1;

                if ({tail[8*5-1:0], DUT.U_cpu.U_IO.tx_data} ==
                    "FINISH") begin
                    if (!list_crc_seen)
                        $fatal(1, "CoreMark list CRC e714 was not seen");
                    if (!matrix_crc_seen)
                        $fatal(1, "CoreMark matrix CRC 1fd7 was not seen");
                    if (!state_crc_seen)
                        $fatal(1, "CoreMark state CRC 8e3a was not seen");
                    $display(
                        "\nCOREMARK CRC TEST PASSED: e714 / 1fd7 / 8e3a"
                    );
                    $finish;
                end
            end

            if (cycles >= MAX_CYCLES)
                $fatal(1, "CoreMark CRC timeout cycles=%0d chars=%0d",
                       cycles, chars);
        end
    end

    initial begin
        repeat (10) @(posedge fpga_clk);
        fpga_rst = 1'b1;
    end
endmodule
