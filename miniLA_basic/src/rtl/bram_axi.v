`timescale 1ns / 1ps

/* verilator lint_off MODDUP */

module bram_axi #(
    parameter DATA_WIDTH = 32,
    parameter DATA_DEPTH = 32768,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = 4,
    parameter ID_WIDTH = 4,
    parameter PIPELINE_OUTPUT = 0
)(
    input  wire                     s_aclk,
    input  wire                     s_aresetn,
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,
    output reg  [ID_WIDTH-1:0]      s_axi_bid,
    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,
    output reg  [ID_WIDTH-1:0]      s_axi_rid,
    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg                      s_axi_rvalid,
    output reg                      s_axi_rlast,
    output reg  [1:0]               s_axi_rresp,
    input  wire                     s_axi_rready
);

    localparam ADDR_BITS = $clog2(DATA_DEPTH);
    reg [DATA_WIDTH-1:0] mem [0:DATA_DEPTH-1];

    // Load test program on startup
    initial begin
        $readmemb("meminit.bin", mem);
    end

    reg [ADDR_BITS-1:0] w_ptr;
    reg [7:0] w_count, w_length;
    reg [ADDR_BITS-1:0] r_ptr;
    reg [7:0] r_count, r_length;

    localparam W_IDLE=0, W_DATA=1, W_RESP=2;
    reg [1:0] w_state;
    localparam R_IDLE=0, R_DATA=1;
    reg [1:0] r_state;

    always @(posedge s_aclk or negedge s_aresetn) begin
        if (!s_aresetn) begin
            w_state <= W_IDLE; w_ptr <= 0; w_count <= 0;
            s_axi_awready <= 1; s_axi_wready <= 0;
            s_axi_bvalid <= 0; s_axi_bresp <= 0; s_axi_bid <= 0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    s_axi_awready <= 1;
                    if (s_axi_awvalid && s_axi_awready) begin
                        w_ptr <= s_axi_awaddr[ADDR_BITS+1:2];
                        w_length <= s_axi_awlen;
                        w_count <= 0;
                        s_axi_awready <= 0;
                        s_axi_wready <= 1;
                        w_state <= W_DATA;
                    end
                end
                W_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        for (integer i = 0; i < STRB_WIDTH; i=i+1)
                            if (s_axi_wstrb[i]) mem[w_ptr][i*8+:8] <= s_axi_wdata[i*8+:8];
                        w_ptr <= w_ptr + 1;
                        w_count <= w_count + 1;
                        if (s_axi_wlast) begin
                            s_axi_wready <= 0;
                            s_axi_bvalid <= 1;
                            w_state <= W_RESP;
                        end
                    end
                end
                W_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 0;
                        s_axi_awready <= 1;
                        w_state <= W_IDLE;
                    end
                end
            endcase
        end
    end

    always @(posedge s_aclk or negedge s_aresetn) begin
        if (!s_aresetn) begin
            r_state <= R_IDLE; r_ptr <= 0; r_count <= 0;
            s_axi_arready <= 1; s_axi_rvalid <= 0;
            s_axi_rdata <= 0; s_axi_rlast <= 0; s_axi_rresp <= 0; s_axi_rid <= 0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    s_axi_arready <= 1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        r_ptr <= s_axi_araddr[ADDR_BITS+1:2];
                        r_length <= s_axi_arlen;
                        r_count <= 0;
                        s_axi_arready <= 0;
                        s_axi_rvalid <= 1;
                        s_axi_rdata <= mem[s_axi_araddr[ADDR_BITS+1:2]];
                        s_axi_rlast <= (s_axi_arlen == 0);
                        r_state <= R_DATA;
                    end
                end
                R_DATA: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        if (r_count >= r_length) begin
                            s_axi_rvalid <= 0;
                            s_axi_arready <= 1;
                            r_state <= R_IDLE;
                        end else begin
                            r_ptr <= r_ptr + 1;
                            r_count <= r_count + 1;
                            s_axi_rdata <= mem[r_ptr + 1];
                            s_axi_rlast <= (r_count + 1 >= r_length);
                        end
                    end
                end
            endcase
        end
    end

endmodule
