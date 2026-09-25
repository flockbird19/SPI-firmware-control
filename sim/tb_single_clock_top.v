module tb_single_clock_top;
    reg clk;
    reg reset;

    // Host Inputs
    reg host_wr_en;
    reg [7:0] host_din;

    // Status and SPI Outputs
    wire fifo_full;
    wire fifo_empty;
    wire sclk;
    wire mosi;
    wire cs;

    // Instantiate the Top-Level System
    single_clock_top u_top (
        .clk(clk),
        .reset(reset),
        .host_wr_en(host_wr_en),
        .host_din(host_din),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .sclk(sclk),
        .mosi(mosi),
        .cs(cs)
    );

    // Instantiate the Flash Model Receiver
    flash_model_tb u_flash (
        .cs(cs),
        .sclk(sclk),
        .mosi(mosi)
    );

    // Generate 100 MHz System Clock
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        reset = 1;
        host_wr_en = 0;
        host_din = 8'h00;

        #30;
        reset = 0;
        #20;

        // 1. Host writes the first byte (0xAB) to the system
        @(negedge clk);
        host_wr_en = 1;
        host_din = 8'hAB;

        // 2. Host writes the second byte (0x3C) to the system immediately after
        @(negedge clk);
        host_wr_en = 1;
        host_din = 8'h3C;

        @(negedge clk);
        host_wr_en = 0; // Stop writing

        // The FSM should now automatically detect data in the FIFO,
        // pull CS low, and transmit both bytes sequentially.

        // Wait until FIFO empties and CS goes back high (transaction complete)
        wait(fifo_empty == 1'b1);
        wait(cs == 1'b1);

        #100;
        $display("System simulation completed successfully.");
        $finish;
    end
endmodule