// ---------------------------------------------------------
// Module 1: Binary to Gray Code Converter
// ---------------------------------------------------------
module bin2gray #(
    parameter WIDTH = 5
)(
    input wire [WIDTH-1:0] bin,
    output wire [WIDTH-1:0] gray
);
    // Gray code is calculated by XORing the binary number with itself shifted right by 1
    assign gray = bin ^ (bin >> 1);
endmodule

// ---------------------------------------------------------
// Module 2: Gray to Binary Code Converter
// ---------------------------------------------------------
module gray2bin #(
    parameter WIDTH = 5
)(
    input wire [WIDTH-1:0] gray,
    output reg [WIDTH-1:0] bin
);
    integer i;
    always @(*) begin
        // The MSB is the same for both binary and gray
        bin[WIDTH-1] = gray[WIDTH-1];
        // The rest are XORed down the chain
        for (i = WIDTH-2; i >= 0; i = i - 1) begin
            bin[i] = bin[i+1] ^ gray[i];
        end
    end
endmodule

// ---------------------------------------------------------
// Module 3: 2-Stage Flip-Flop Synchronizer
// ---------------------------------------------------------
module sync_2ff #(
    parameter WIDTH = 5
)(
    input wire clk,
    input wire reset,
    input wire [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    reg [WIDTH-1:0] q1; // First stage flip-flop

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q1 <= {WIDTH{1'b0}};
            q  <= {WIDTH{1'b0}};
        end else begin
            q1 <= d; // Catch the incoming data (might be metastable)
            q  <= q1; // Safely sample it into the new clock domain
        end
    end
endmodule