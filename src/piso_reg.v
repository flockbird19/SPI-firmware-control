// Stage 3: PISO, load the 8bit data at once and send it one by one serialy
module piso_reg (
    input wire clk,       // System clock
    input wire sclk,      // SPI clock
    input wire reset,
    input wire load,
    input wire [7:0] parl_in, // parallel in
    output wire serl_out //serial out
);
    reg [7:0] shift_reg; // where the 8 bit data stores
    assign serl_out = shift_reg[7]; // Send the MSB to serl_out

    // Edge detector for sclk to trigger shift
    reg sclk_d;
    always @(posedge clk or posedge reset) begin
        if (reset) sclk_d <= 1'b0;
        else sclk_d <= sclk;
    end
    wire sclk_fall = ~sclk & sclk_d;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            shift_reg <= 8'h00;
        end else if (load) begin
            shift_reg <= parl_in; // Load 8 bit at once
        end else if (sclk_fall) begin
            shift_reg <= {shift_reg[6:0], 1'b0}; // Shift left by one bit
        end
    end
endmodule