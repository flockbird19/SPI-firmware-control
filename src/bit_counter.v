// stage 1 - Building a 3-bit bit-position counter, with enalbe to start count and done if 0-7 bits are loaded.
module bit_counter (
    input wire clk,
    input wire reset,
    input wire enable,
    output reg [2:0] count, // position: 0 to 7
    output reg done // High(1)- bit 7 is completed
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 3'd0; // Reset to 0
            done <= 1'b0;
        end else begin
            done <= 1'b0; // Default: done - LOW
            if (enable) begin
                if (count == 3'd7) begin
                    count <= 3'd0; // Start next byte from 0
                    done <= 1'b1; // Byte transmission completed
                end else begin
                    count <= count + 3'd1; // Move to next bit
                end
            end
        end
    end
endmodule