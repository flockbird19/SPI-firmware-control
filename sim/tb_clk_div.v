///
// !! This is only a stand alone Testbench for SPI clock divider
module tb_clk_div;
    reg clk;
    reg reset;
    reg enable;
    wire sclk;

    clk_div #(.divide(4)) dut (
        .clk (clk),
        .reset (reset),
        .enable (enable),
        .sclk (sclk)
    );

    always #5 clk = ~clk;

    initial begin
        // Initial states
        clk = 1'b0;
        reset = 1'b1;
        enable = 1'b0;
        //reset state for 20
        #10;
        // reset end
        reset = 1'b0;
        // SPI clock disabled for 20
        #20;
        // SPI clock enabled
        enable = 1'b1;
        //SCLK to run for 240 ns; like 40 ns -> SCLK HIGH,80 ns -> SCLK LOW, 120 ns -> SCLK HIGH, 160 ns -> SCLK LOW
        #240;
        // Disable SPI clock; sclk becomes low
        enable = 1'b0;
        #40;
        $finish;
    end

    always @(posedge sclk or negedge sclk) begin
        $display("TIME =%0t enable =%b SCLK=%b", $time, enable, sclk);
    end
endmodule