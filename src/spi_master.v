// Day 3: SPI Master Integration
module spi_master (
    input wire clk, // System clock
    input wire reset, // Active high reset
    input wire enable, // Enable for clock divider and counter
    input wire load, // Load signal for PISO
    input wire [7:0] parl_in, // Parallel byte from FIFO/Host
    input wire fsm_cs, // Chip select controlled by FSM

    // Exposed Physical SPI Pins
    output wire sclk,
    output wire mosi,
    output wire cs,

    // Status signals back to FSM
    output wire [2:0] bit_count,
    output wire byte_done
);

    // Route FSM Chip Select directly to physical CS pin
    assign cs = fsm_cs;

    // Instantiate Clock Divider
    clk_div #(.divide(2)) u_clk_div (
        .clk (clk),
        .reset (reset),
        .enable (enable),
        .sclk (sclk)
    );

    // Instantiate PISO Register
    piso_reg u_piso (
        .sclk (sclk),
        .reset (reset),
        .load (load),
        .parl_in (parl_in),
        .serl_out (mosi)
    );

    // Instantiate Bit Counter
    bit_counter u_bit_counter (
        .clk (sclk), // Counter runs on the divided SPI clock
        .reset (reset),
        .enable (enable),
        .count (bit_count),
        .done (byte_done)
    );

endmodule