module single_clock_top (
    input wire clk,
    input wire reset,

    // Host Interface
    input wire host_wr_en,
    input wire [7:0] host_din,
    output wire fifo_full,
    output wire fifo_empty,

    // SPI Physical Interface
    output wire sclk,
    output wire mosi,
    output wire cs
);

    // Interconnect wires
    wire [7:0] fifo_dout;
    wire fifo_rd_en;
    wire load;
    wire enable;
    wire fsm_cs;
    wire byte_done;
    wire [2:0] bit_count; // Exposed by master, but unused at top level

    // 1. The Buffer
    sync_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) u_fifo (
        .clk(clk),
        .reset(reset),
        .wr_en(host_wr_en),
        .rd_en(fifo_rd_en),
        .din(host_din),
        .dout(fifo_dout),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    // 2. The Brain
    spi_fsm u_fsm (
        .clk(clk),
        .reset(reset),
        .fifo_empty(fifo_empty),
        .byte_done(byte_done),
        .fifo_rd_en(fifo_rd_en),
        .load(load),
        .enable(enable),
        .fsm_cs(fsm_cs)
    );

    // 3. The SPI Datapath
    spi_master u_spi_master (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .load(load),
        .parl_in(fifo_dout),
        .fsm_cs(fsm_cs),
        .sclk(sclk),
        .mosi(mosi),
        .cs(cs),
        .bit_count(bit_count),
        .byte_done(byte_done)
    );

endmodule