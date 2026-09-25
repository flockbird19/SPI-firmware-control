module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4 // Depth = 16 locations (requires 5-bit pointers)
)(
    // Write Domain (Host Side)
    input wire wr_clk,
    input wire wr_reset,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] din,
    output wire full,

    // Read Domain (SPI FSM Side)
    input wire rd_clk,
    input wire rd_reset,
    input wire rd_en,
    output reg [DATA_WIDTH-1:0] dout,
    output wire empty
);

    // Memory Array
    reg [DATA_WIDTH-1:0] fifo_ram [0:(1<<ADDR_WIDTH)-1];

    // Native Binary Pointers (5 bits to track wrap-arounds)
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_bin;

    // Gray Pointers
    wire [ADDR_WIDTH:0] wr_ptr_gray;
    wire [ADDR_WIDTH:0] rd_ptr_gray;

    // Safely Synchronized Gray Pointers
    wire [ADDR_WIDTH:0] sync_wr_ptr_gray;
    wire [ADDR_WIDTH:0] sync_rd_ptr_gray;

    // Synchronized Pointers converted back to Binary for easy comparison
    wire [ADDR_WIDTH:0] sync_wr_ptr_bin;
    wire [ADDR_WIDTH:0] sync_rd_ptr_bin;

    // =========================================================
    // 1. WRITE DOMAIN
    // =========================================================
    always @(posedge wr_clk or posedge wr_reset) begin
        if (wr_reset) begin
            wr_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        end else if (wr_en && !full) begin
            fifo_ram[wr_ptr_bin[ADDR_WIDTH-1:0]] <= din;
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
        end
    end

    // Convert Write Pointer to Gray Code
    bin2gray #(.WIDTH(ADDR_WIDTH+1)) u_wr_b2g (
        .bin(wr_ptr_bin),
        .gray(wr_ptr_gray)
    );

    // Synchronize the Read Pointer (Gray) into the Write Clock Domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_rd2wr (
        .clk(wr_clk),
        .reset(wr_reset),
        .d(rd_ptr_gray),
        .q(sync_rd_ptr_gray)
    );

    // Convert synced Read Pointer back to Binary to check FULL status
    gray2bin #(.WIDTH(ADDR_WIDTH+1)) u_wr_g2b (
        .gray(sync_rd_ptr_gray),
        .bin(sync_rd_ptr_bin)
    );

    // Full: MSB differs, but lower address bits perfectly match
    assign full = (wr_ptr_bin[ADDR_WIDTH] != sync_rd_ptr_bin[ADDR_WIDTH]) &&
    (wr_ptr_bin[ADDR_WIDTH-1:0] == sync_rd_ptr_bin[ADDR_WIDTH-1:0]);

    // =========================================================
    // 2. READ DOMAIN
    // =========================================================
    always @(posedge rd_clk or posedge rd_reset) begin
        if (rd_reset) begin
            rd_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
            dout <= {DATA_WIDTH{1'b0}};
        end else if (rd_en && !empty) begin
            dout <= fifo_ram[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
        end
    end

    // Convert Read Pointer to Gray Code
    bin2gray #(.WIDTH(ADDR_WIDTH+1)) u_rd_b2g (
        .bin(rd_ptr_bin),
        .gray(rd_ptr_gray)
    );

    // Synchronize the Write Pointer (Gray) into the Read Clock Domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_wr2rd (
        .clk(rd_clk),
        .reset(rd_reset),
        .d(wr_ptr_gray),
        .q(sync_wr_ptr_gray)
    );

    // Convert synced Write Pointer back to Binary to check EMPTY status
    gray2bin #(.WIDTH(ADDR_WIDTH+1)) u_rd_g2b (
        .gray(sync_wr_ptr_gray),
        .bin(sync_wr_ptr_bin)
    );

    // Empty: All bits of Write and Read pointers match completely
    assign empty = (rd_ptr_bin == sync_wr_ptr_bin);

endmodule