//stage 2: SPI Clock Divider
module clk_div #(
    //#: beccause we use a parameter divide in the module
    parameter integer divide = 4 // 4 input clocks before SCLK toggles
    // i have taken divide as 4
    // because the input clock i 100 MHz we want 12.5 MHz
    // SPI clock: 100/(2*4) = 12.5MHz
)(
    input wire clk, // (100 MHz)
    input wire reset,
    input wire enable,
    output reg sclk //which will going to be 12.5 MHz
);
    integer div_count; // Counts input clock cycles
    always @(posedge clk or posedge reset) begin
        //reset sclk to low first.
        if (reset) begin
            div_count <= 0;
            sclk <= 1'b0;
            // If SPI is disabled, keep SCLK LOW
        end else if (!enable) begin
            div_count <= 0;
            sclk <= 1'b0;
        end else begin
            if (div_count == divide-1) begin // after 4 input clock cycles, toggle SCLK
                div_count <= 0;
                sclk <= ~sclk; // inverts the cycle hight to low or vise versa
            end else begin
                div_count <= div_count + 1;
            end
        end
    end
endmodule