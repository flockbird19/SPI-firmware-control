module dual_clock_top (
    // Host Clock Domain (e.g., Fast PCIe/AXI bus)
    input wire host_clk,
    input wire host_reset,
    input wire host_wr_en,
    input wire [7:0] host_din,
    output wire fifo_full,

    // Host Read Interface (RX)
    input wire host_rd_en,
    output wire [7:0] host_dout,
    output wire rx_fifo_empty,

    // SPI Clock Domain (e.g., Standard 100 MHz System Clock)
    input wire spi_clk,
    input wire spi_reset,
    output wire fifo_empty,

    // SPI Physical Interface
    output wire sclk,
    output wire mosi,
    input  wire miso,
    output wire cs
);

    // Interconnect wires (All located in the SPI clock domain)
    wire [7:0] fifo_dout;
    wire fifo_rd_en;
    wire load;
    wire enable;
    wire fsm_cs;
    wire byte_done;
    wire [2:0] bit_count; // Exposed by master, but unused at top level
    
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_fifo_wr_en;

    // 1. Asynchronous FIFO (The Bridge)
    async_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) u_async_fifo (
        // Write Side (Host Domain)
        .wr_clk(host_clk),
        .wr_reset(host_reset),
        .wr_en(host_wr_en),
        .din(host_din),
        .full(fifo_full),

        // Read Side (SPI Domain)
        .rd_clk(spi_clk),
        .rd_reset(spi_reset),
        .rd_en(fifo_rd_en),
        .dout(fifo_dout),
        .empty(fifo_empty)
    );

    // 1b. Asynchronous RX FIFO (SPI back to Host)
    async_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) u_rx_fifo (
        // Write Side (SPI Domain)
        .wr_clk(spi_clk),
        .wr_reset(spi_reset),
        .wr_en(rx_fifo_wr_en),
        .din(rx_data),
        .full(), // Ignored at top level for basic design

        // Read Side (Host Domain)
        .rd_clk(host_clk),
        .rd_reset(host_reset),
        .rd_en(host_rd_en),
        .dout(host_dout),
        .empty(rx_fifo_empty)
    );

    // 2. SPI FSM (SPI Domain Brain)
    spi_fsm u_fsm (
        .clk(spi_clk),
        .reset(spi_reset),
        .fifo_empty(fifo_empty),
        .byte_done(byte_done),
        .fifo_rd_en(fifo_rd_en),
        .load(load),
        .enable(enable),
        .fsm_cs(fsm_cs),
        .rx_fifo_wr_en(rx_fifo_wr_en)
    );

    // 3. SPI Master Datapath (SPI Domain)
    spi_master u_spi_master (
        .clk(spi_clk),
        .reset(spi_reset),
        .enable(enable),
        .load(load),
        .parl_in(fifo_dout),
        .fsm_cs(fsm_cs),
        .sclk(sclk),
        .mosi(mosi),
        .cs(cs),
        .miso(miso),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .bit_count(bit_count),
        .byte_done(byte_done)
    );

endmodule