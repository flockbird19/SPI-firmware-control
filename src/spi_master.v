module spi_master(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire load,
    input wire [7:0] parl_in,

    output wire mosi,
    output wire sclk,
    output wire cs,
    output wire byte_done
);

    // SPI Clock Divider
    clk_div #(.divide(2)) u_clk_div (
        .clk    (clk),
        .reset  (reset),
        .enable (enable),
        .sclk   (sclk)
    );

    // PISO Register
    piso_reg u_piso (
        .sclk     (sclk),
        .reset    (reset),
        .load     (load),
        .parl_in  (parl_in),
        .serl_out (mosi)
    );

    // Bit Counter
    bit_counter u_bit_counter (
        .clk    (sclk),
        .reset  (reset),
        .enable (enable),
        .count  (),
        .done   (byte_done)
    );

    // Chip Select
    // SPI flash is active LOW
    assign cs = ~enable;

endmodule