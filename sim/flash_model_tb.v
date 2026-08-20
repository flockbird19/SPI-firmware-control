//////
// Stage 4: SPI Flash behavioral model (!! as we not uploading the controller to a physical hardware i am created this module).
// SPI Mode 0 - samples MOSI on rising edge of SCLK
// cs is active low
module flash_model_tb (
    input wire cs,
    input wire sclk,
    input wire mosi
);
    // SPI data from master to Flash
    reg [7:0] rx_shift; // recived data stored here
    integer bit_count;
    integer byte_count;

    initial begin
        rx_shift = 8'h00;
        bit_count = 0;
        byte_count = 0;
    end

    always @(negedge cs) begin
        rx_shift = 8'h00;
        bit_count = 0;
    end

    // When CS goes LOW, start new SPI transaction
    // SPI Mode 0: sample MOSI on rising edge of SCLK
    always @(posedge sclk) begin
        if (!cs) begin
            rx_shift = {rx_shift[6:0], mosi}; // Shift previous bits left and add new MOSI bit
            if (bit_count == 7) begin // Check if 8 bit have received or not.
                $display("Flash Model: received byte %0d = 0x%02h", byte_count, rx_shift);
                byte_count = byte_count + 1; // Move to the next byte
                bit_count = 0; // Prepare for the next byte
                rx_shift = 8'h00;
            end else begin
                bit_count = bit_count + 1;
            end
        end
    end
endmodule