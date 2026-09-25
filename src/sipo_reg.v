// Phase 2: Serial-In, Parallel-Out Shift Register
// Listens to the MISO pin and reconstructs 8-bit bytes coming from the Flash.
module sipo_reg (
    input wire clk, // System clock
    input wire sclk, // SPI clock
    input wire reset,
    input wire enable, // Only shift when SPI is active
    input wire miso, // Serial data in from Flash

    output reg [7:0] rx_data, // Parallel data out
    output reg rx_valid // Pulses high for 1 cycle when 8 bits are collected
);
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;

    // Rising edge detector for sclk (SPI Mode 0 samples MISO on rising edge)
    reg sclk_d;
    always @(posedge clk or posedge reset) begin
        if (reset) sclk_d <= 1'b0;
        else sclk_d <= sclk;
    end
    wire sclk_rise = sclk & ~sclk_d;

    // sclk_rise lags the real SCLK edge by up to one 'clk' cycle (it can
    // only fire after sclk_d has caught up). 'enable' can already have
    // dropped by then (the FSM turns it off the instant bit_counter's
    // independent, zero-lag byte_done fires on that same real edge), which
    // would silently drop the 8th bit forever. Remembering enable for one
    // extra cycle closes that race.
    reg enable_d;
    always @(posedge clk or posedge reset) begin
        if (reset) enable_d <= 1'b0;
        else enable_d <= enable;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            shift_reg <= 8'h00;
            rx_data   <= 8'h00;
            bit_cnt   <= 3'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // Default low (only pulses high once per byte)

            if ((enable || enable_d) && sclk_rise) begin
                shift_reg <= {shift_reg[6:0], miso}; // Shift MSB first

                if (bit_cnt == 3'd7) begin
                    rx_data <= {shift_reg[6:0], miso}; // Latch the fully reconstructed byte
                    rx_valid <= 1'b1; // Tell the system the byte is ready
                    bit_cnt <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end else if (!enable) begin
                bit_cnt <= 3'd0; // Reset counter between bytes
            end
        end
    end
endmodule