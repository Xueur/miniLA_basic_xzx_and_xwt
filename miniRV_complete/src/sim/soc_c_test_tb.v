`timescale 1ns / 1ps

module soc_c_test_tb;

    localparam CLK_PERIOD = 20;
    localparam UART_BIT_TIME = 8680;

    reg fpga_clk = 1'b0;
    reg fpga_rst = 1'b0;
    reg [15:0] sw = 16'hA55A;
    reg rx = 1'b1;
    wire [15:0] led;
    wire [7:0] dig_en;
    wire [7:0] dig_seg;
    wire [7:0] dig_seg1;
    wire tx;

    integer uart_writes = 0;
    reg led_write = 1'b0;
    reg dig_write = 1'b0;
    reg switch_read = 1'b0;
    reg timer_read = 1'b0;
    reg uart_rx_read = 1'b0;
    reg tx_low_seen = 1'b0;
    reg [31:0] last_dig_value = 32'h0;

    always #(CLK_PERIOD / 2) fpga_clk = ~fpga_clk;

    miniRV_SoC #(
        .MEM_BANK0_FILE ("c_test_bank0.hex"),
        .MEM_BANK1_FILE ("c_test_bank1.hex"),
        .MEM_BANK2_FILE ("c_test_bank2.hex"),
        .MEM_BANK3_FILE ("c_test_bank3.hex"),
        .MEM_BANK4_FILE ("c_test_bank4.hex")
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

    task uart_send;
        input [7:0] value;
        integer bit_index;
        begin
            rx = 1'b0;
            #(UART_BIT_TIME);
            for (bit_index = 0; bit_index < 8;
                 bit_index = bit_index + 1) begin
                rx = value[bit_index];
                #(UART_BIT_TIME);
            end
            rx = 1'b1;
            #(UART_BIT_TIME);
        end
    endtask

    always @(negedge tx)
        tx_low_seen = 1'b1;

    always @(posedge fpga_clk) begin
        if (DUT.U_cpu.debug_mem_waddr == 32'hFFFF0000)
            switch_read <= 1'b1;
        if (DUT.U_cpu.debug_mem_waddr == 32'hFFFF4000)
            timer_read <= 1'b1;
        if (DUT.U_cpu.debug_mem_waddr == 32'hFFFF3000)
            uart_rx_read <= 1'b1;

        if (|DUT.U_cpu.debug_mem_we) begin
            case (DUT.U_cpu.debug_mem_waddr)
                32'hFFFF1000:
                    led_write <= 1'b1;
                32'hFFFF2000: begin
                    dig_write <= 1'b1;
                    last_dig_value <= DUT.U_cpu.debug_mem_wdata;
                end
                32'hFFFF3004:
                    uart_writes <= uart_writes + 1;
                default: begin
                end
            endcase
        end

        if (uart_writes >= 5 && led_write && dig_write &&
            switch_read && timer_read && uart_rx_read &&
            tx_low_seen && led == 16'hA55A &&
            last_dig_value != 32'h0) begin
            $display(
                "C_TEST: SWITCH + LED + DIG + UART TX/RX + TIMER PASSED"
            );
            $finish;
        end
    end

    initial begin
        repeat (10) @(posedge fpga_clk);
        fpga_rst = 1'b1;

        wait (uart_writes >= 4);
        repeat (100) @(posedge fpga_clk);
        uart_send(8'h41);
    end

    initial begin
        #1000000;
        $fatal(1, "C_TEST timeout");
    end

endmodule
