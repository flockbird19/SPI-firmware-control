///
// !! this is a standalone Testbench for PISO register
module tb_piso_reg;
    reg sclk;
    reg reset;
    reg load;
    reg [7:0] parl_in;
    wire serl_out;

    piso_reg dut (
        .sclk (sclk),
        .reset (reset),
        .load (load),
        .parl_in (parl_in),
        .serl_out (serl_out)
    );

    always #5 sclk = ~sclk;

    // Test sequence
    initial begin
        // Initial values
        sclk = 1'b0;
        reset = 1'b1;
        load = 1'b0;
        parl_in = 8'h00;
        #20;
        reset = 1'b0; //reset
        // Prepare data before the rising edge
        #5;
        parl_in = 8'b10110010; //
        load = 1'b1;
        // waiting for raising edge to load data
        @(posedge sclk);
        // using 1 ns after edge to avoid race condition
        #1;
        load = 1'b0;
        repeat (8)
            //waiting still all data are serial out
            @(posedge sclk);
        #10;
        $finish;
    end

    always @(posedge sclk) begin
        $display("TIME=%0t load=%b parallel_in=%b MOSI=%b", $time, load, parl_in, serl_out);
    end
endmodule