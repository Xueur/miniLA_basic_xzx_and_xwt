`timescale 1ns / 1ps

module icache #(
    parameter LINES = 64
)(
    input  wire         clk,
    input  wire         rst,

    input  wire         cpu_req,
    input  wire [31:0]  cpu_addr,
    output reg          cpu_valid,
    output reg  [31:0]  cpu_data,

    input  wire         mem_rrdy,
    output wire         mem_ren,
    output wire [31:0]  mem_raddr,
    input  wire         mem_rvalid,
    input  wire [127:0] mem_rdata
);

    localparam INDEX_W = $clog2(LINES);
    localparam ST_IDLE = 2'd0;
    localparam ST_REQ  = 2'd1;
    localparam ST_WAIT = 2'd2;

    reg [1:0] state;
    reg [31:0] miss_addr;
    (* ram_style = "distributed" *)
    reg [31-INDEX_W-4:0] tags [0:LINES-1];
    (* ram_style = "distributed" *)
    reg [127:0] lines [0:LINES-1];
    reg valid [0:LINES-1];
    integer i;

    wire [INDEX_W-1:0] cpu_index = cpu_addr[INDEX_W+3:4];
    wire [31-INDEX_W-4:0] cpu_tag = cpu_addr[31:INDEX_W+4];
    wire cpu_hit = valid[cpu_index] && tags[cpu_index] == cpu_tag;

    wire [INDEX_W-1:0] miss_index = miss_addr[INDEX_W+3:4];
    wire [31-INDEX_W-4:0] miss_tag = miss_addr[31:INDEX_W+4];

    function [31:0] select_word;
        input [127:0] block;
        input [1:0] word;
        begin
            case (word)
                2'd0: select_word = block[31:0];
                2'd1: select_word = block[63:32];
                2'd2: select_word = block[95:64];
                default: select_word = block[127:96];
            endcase
        end
    endfunction

    assign mem_ren = state == ST_REQ;
    assign mem_raddr = {miss_addr[31:4], 4'h0};

    always @(posedge clk) begin
        if (!rst && state == ST_WAIT && mem_rvalid) begin
            lines[miss_index] <= mem_rdata;
            tags[miss_index] <= miss_tag;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= ST_IDLE;
            cpu_valid <= 1'b0;
            cpu_data <= 32'h0;
            miss_addr <= 32'h0;
            for (i = 0; i < LINES; i = i + 1)
                valid[i] <= 1'b0;
        end else begin
            cpu_valid <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (cpu_req) begin
                        if (cpu_hit) begin
                            cpu_data <= select_word(lines[cpu_index],
                                                    cpu_addr[3:2]);
                            cpu_valid <= 1'b1;
                        end else begin
                            miss_addr <= cpu_addr;
                            state <= ST_REQ;
                        end
                    end
                end
                ST_REQ: begin
                    if (mem_rrdy)
                        state <= ST_WAIT;
                end
                ST_WAIT: begin
                    if (mem_rvalid) begin
                        valid[miss_index] <= 1'b1;
                        cpu_data <= select_word(mem_rdata, miss_addr[3:2]);
                        cpu_valid <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
