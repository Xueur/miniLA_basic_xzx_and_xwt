`timescale 1ns / 1ps

module axi_bram_slave #(
    parameter RAM_WORDS = 40960,
    parameter BANK0_INIT_FILE = "",
    parameter BANK1_INIT_FILE = "",
    parameter BANK2_INIT_FILE = "",
    parameter BANK3_INIT_FILE = "",
    parameter BANK4_INIT_FILE = ""
)(
    input  wire         clk,
    input  wire         rst,

    input  wire [31:0]  s_axi_awaddr,
    input  wire [ 7:0]  s_axi_awlen,
    input  wire [ 2:0]  s_axi_awsize,
    input  wire [ 1:0]  s_axi_awburst,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,

    input  wire [31:0]  s_axi_wdata,
    input  wire [ 3:0]  s_axi_wstrb,
    input  wire         s_axi_wlast,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,

    output wire [ 1:0]  s_axi_bresp,
    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,

    input  wire [31:0]  s_axi_araddr,
    input  wire [ 7:0]  s_axi_arlen,
    input  wire [ 2:0]  s_axi_arsize,
    input  wire [ 1:0]  s_axi_arburst,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,

    output reg  [31:0]  s_axi_rdata,
    output wire [ 1:0]  s_axi_rresp,
    output wire         s_axi_rlast,
    output reg          s_axi_rvalid,
    input  wire         s_axi_rready
);

    localparam BANK_WORDS = 8192;
    localparam BANK_ADDR_W = 13;
    localparam WORD_ADDR_W = 16;

    (* ram_style = "block" *) reg [31:0] mem0 [0:BANK_WORDS-1];
    (* ram_style = "block" *) reg [31:0] mem1 [0:BANK_WORDS-1];
    (* ram_style = "block" *) reg [31:0] mem2 [0:BANK_WORDS-1];
    (* ram_style = "block" *) reg [31:0] mem3 [0:BANK_WORDS-1];
    (* ram_style = "block" *) reg [31:0] mem4 [0:BANK_WORDS-1];

    reg aw_hold;
    reg [31:0] awaddr_hold;
    reg w_hold;
    reg [31:0] wdata_hold;
    reg [3:0] wstrb_hold;

    reg r_active;
    reg [31:0] r_addr;
    reg [7:0] r_len;
    reg [7:0] r_beat;
    reg [2:0] read_bank_q;
    reg read_in_range_q;
    reg [31:0] bank0_rdata;
    reg [31:0] bank1_rdata;
    reg [31:0] bank2_rdata;
    reg [31:0] bank3_rdata;
    reg [31:0] bank4_rdata;
    wire [31:0] next_r_addr = r_addr + 32'd4;
    wire [WORD_ADDR_W-1:0] next_r_index =
        next_r_addr[WORD_ADDR_W+1:2];
    wire [WORD_ADDR_W-1:0] write_index =
        awaddr_hold[WORD_ADDR_W+1:2];
    wire write_fire = aw_hold && w_hold && !s_axi_bvalid;
    wire read_start = s_axi_arvalid && s_axi_arready;
    wire read_advance = s_axi_rvalid && s_axi_rready &&
                        r_beat != r_len;
    wire read_fire = read_start || read_advance;
    wire [WORD_ADDR_W-1:0] read_index =
        read_start ? s_axi_araddr[WORD_ADDR_W+1:2] : next_r_index;
    wire [2:0] write_bank = write_index[15:13];
    wire [2:0] read_bank = read_index[15:13];
    wire [BANK_ADDR_W-1:0] write_offset =
        write_index[BANK_ADDR_W-1:0];
    wire [BANK_ADDR_W-1:0] read_offset =
        read_index[BANK_ADDR_W-1:0];
    wire write_in_range = write_index < RAM_WORDS;
    wire read_in_range = read_index < RAM_WORDS;

    initial begin
        if (BANK0_INIT_FILE != "")
            $readmemh(BANK0_INIT_FILE, mem0);
        if (BANK1_INIT_FILE != "")
            $readmemh(BANK1_INIT_FILE, mem1);
        if (BANK2_INIT_FILE != "")
            $readmemh(BANK2_INIT_FILE, mem2);
        if (BANK3_INIT_FILE != "")
            $readmemh(BANK3_INIT_FILE, mem3);
        if (BANK4_INIT_FILE != "")
            $readmemh(BANK4_INIT_FILE, mem4);
    end

    assign s_axi_awready = !aw_hold && !s_axi_bvalid;
    assign s_axi_wready  = !w_hold && !s_axi_bvalid;
    assign s_axi_bresp   = 2'b00;

    assign s_axi_arready = !r_active && !s_axi_rvalid;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rlast   = s_axi_rvalid && r_beat == r_len;

    always @(posedge clk) begin
        if (write_fire && write_in_range) begin
            case (write_bank)
                3'd0: begin
                    if (wstrb_hold[0])
                        mem0[write_offset][7:0] <= wdata_hold[7:0];
                    if (wstrb_hold[1])
                        mem0[write_offset][15:8] <= wdata_hold[15:8];
                    if (wstrb_hold[2])
                        mem0[write_offset][23:16] <= wdata_hold[23:16];
                    if (wstrb_hold[3])
                        mem0[write_offset][31:24] <= wdata_hold[31:24];
                end
                3'd1: begin
                    if (wstrb_hold[0])
                        mem1[write_offset][7:0] <= wdata_hold[7:0];
                    if (wstrb_hold[1])
                        mem1[write_offset][15:8] <= wdata_hold[15:8];
                    if (wstrb_hold[2])
                        mem1[write_offset][23:16] <= wdata_hold[23:16];
                    if (wstrb_hold[3])
                        mem1[write_offset][31:24] <= wdata_hold[31:24];
                end
                3'd2: begin
                    if (wstrb_hold[0])
                        mem2[write_offset][7:0] <= wdata_hold[7:0];
                    if (wstrb_hold[1])
                        mem2[write_offset][15:8] <= wdata_hold[15:8];
                    if (wstrb_hold[2])
                        mem2[write_offset][23:16] <= wdata_hold[23:16];
                    if (wstrb_hold[3])
                        mem2[write_offset][31:24] <= wdata_hold[31:24];
                end
                3'd3: begin
                    if (wstrb_hold[0])
                        mem3[write_offset][7:0] <= wdata_hold[7:0];
                    if (wstrb_hold[1])
                        mem3[write_offset][15:8] <= wdata_hold[15:8];
                    if (wstrb_hold[2])
                        mem3[write_offset][23:16] <= wdata_hold[23:16];
                    if (wstrb_hold[3])
                        mem3[write_offset][31:24] <= wdata_hold[31:24];
                end
                3'd4: begin
                    if (wstrb_hold[0])
                        mem4[write_offset][7:0] <= wdata_hold[7:0];
                    if (wstrb_hold[1])
                        mem4[write_offset][15:8] <= wdata_hold[15:8];
                    if (wstrb_hold[2])
                        mem4[write_offset][23:16] <= wdata_hold[23:16];
                    if (wstrb_hold[3])
                        mem4[write_offset][31:24] <= wdata_hold[31:24];
                end
                default: begin
                end
            endcase
        end

        if (read_fire && read_in_range) begin
            case (read_bank)
                3'd0: bank0_rdata <= mem0[read_offset];
                3'd1: bank1_rdata <= mem1[read_offset];
                3'd2: bank2_rdata <= mem2[read_offset];
                3'd3: bank3_rdata <= mem3[read_offset];
                3'd4: bank4_rdata <= mem4[read_offset];
                default: begin
                end
            endcase
        end
    end

    always @(*) begin
        if (!read_in_range_q)
            s_axi_rdata = 32'h00000000;
        else begin
            case (read_bank_q)
                3'd0: s_axi_rdata = bank0_rdata;
                3'd1: s_axi_rdata = bank1_rdata;
                3'd2: s_axi_rdata = bank2_rdata;
                3'd3: s_axi_rdata = bank3_rdata;
                3'd4: s_axi_rdata = bank4_rdata;
                default: s_axi_rdata = 32'h00000000;
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            aw_hold <= 1'b0;
            awaddr_hold <= 32'h0;
            w_hold <= 1'b0;
            wdata_hold <= 32'h0;
            wstrb_hold <= 4'h0;
            s_axi_bvalid <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_hold <= 1'b1;
                awaddr_hold <= s_axi_awaddr;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_hold <= 1'b1;
                wdata_hold <= s_axi_wdata;
                wstrb_hold <= s_axi_wstrb;
            end

            if (write_fire) begin
                aw_hold <= 1'b0;
                w_hold <= 1'b0;
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_active <= 1'b0;
            r_addr <= 32'h0;
            r_len <= 8'h0;
            r_beat <= 8'h0;
            read_bank_q <= 3'h0;
            read_in_range_q <= 1'b0;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (read_fire) begin
                read_bank_q <= read_bank;
                read_in_range_q <= read_in_range;
            end
            if (read_start) begin
                r_active <= 1'b1;
                r_addr <= s_axi_araddr;
                r_len <= s_axi_arlen;
                r_beat <= 8'h0;
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                if (r_beat == r_len) begin
                    r_active <= 1'b0;
                    s_axi_rvalid <= 1'b0;
                end else begin
                    r_addr <= r_addr + 32'h4;
                    r_beat <= r_beat + 1'b1;
                end
            end
        end
    end

endmodule
