// Stage 3: PISO, load the 8bit data at once and send it one by one serialy
module piso_reg (
    input wire sclk,
    input wire reset,
    input wire load,
    input wire [7:0] parl_in, // parallel in
    output wire serl_out //serial out
);
    reg [7:0] shift_reg; // where the 8 bit data stores
    assign serl_out = shift_reg[7]; // Send the MSB to serl_out

    always @(posedge sclk or posedge reset) begin
        if (reset) begin
            shift_reg <= 8'h00;
        end else if (load) begin
            shift_reg <= parl_in; // Load8 bit at once
        end else begin
            shift_reg <= {shift_reg[6:0], 1'b0}; // Shift left by one bit by one
        end
    end
endmodule