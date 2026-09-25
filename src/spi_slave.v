// Minimal SPI slave (Mode 0): mirrors spi_master's PISO/SIPO pair so the
// project has a real two-sided SPI link, not just a passive receiver.
module spi_slave (
    input  wire clk,        // local reference clock, faster than sclk
    input  wire reset,
    input  wire cs,         // from master, active low
    input  wire sclk,       // from master
    input  wire mosi,       // from master

    input  wire [7:0] tx_data,  // byte to shift out on miso once selected
    output wire miso,           // to master

    output wire [7:0] rx_data,  // byte captured from mosi
    output wire rx_valid
);
    // Pulse 'load' for one clk cycle right after CS falls, so the PISO
    // grabs tx_data before the master's first SCLK edge arrives.
    reg cs_d, load;
    always @(posedge clk or posedge reset) begin
        if (reset) cs_d <= 1'b1;
        else       cs_d <= cs;
    end
    always @(posedge clk or posedge reset) begin
        if (reset) load <= 1'b0;
        else       load <= cs_d & ~cs; // falling edge of cs
    end

    piso_reg u_piso (
        .clk      (clk),
        .sclk     (sclk),
        .reset    (reset),
        .load     (load),
        .parl_in  (tx_data),
        .serl_out (miso)
    );

    sipo_reg u_sipo (
        .clk      (clk),
        .sclk     (sclk),
        .reset    (reset),
        .enable   (~cs),
        .miso     (mosi),      // sipo_reg's serial-in pin, fed by MOSI here
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    // ponytail: tx_data loads once per CS assertion, so a multi-byte burst
    // (CS held low across several bytes) only sends the first byte
    // correctly on MISO. Fine for the one-byte-per-select test in
    // tb_master_slave.v; reload-per-byte if a multi-byte slave-TX test is
    // ever needed.
endmodule
