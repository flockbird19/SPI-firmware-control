///////
// !! THIS is a Standalone test bech for the bit_counter module
module tb_bit_counter;
    reg clk;
    reg reset;
    reg enable;
    wire [2:0] count;
    wire done;

    bit_counter dut (
        .clk (clk),
        .reset (reset),
        .enable (enable),
        .count (count),
        .done (done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        enable = 1'b0;
        // reset active 20 ns
        #10;
        reset = 1'b0;
        // Enable counting
        enable = 1'b1;
        // counting exactly 1 byte; that's 8bit.
        repeat (9)
            @(posedge clk);
            // Stop counting
        enable = 1'b0;
        #20;
        $finish;
    end

    // Display at every positive edge of counter
    always @(posedge clk) begin
        $display("TIME=%0t enable =%b count =%0d done =%b", $time, enable, count, done);
    end
endmodule