module tb_dual_clock_top;
    // Host Domain Signals
    reg host_clk;
    reg host_reset;
    reg host_wr_en;
    reg [7:0] host_din;
    wire fifo_full;

    // Host Read Domain Signals (NEW)
    reg host_rd_en;
    wire [7:0] host_dout;
    wire rx_fifo_empty;

    // SPI Domain Signals
    reg spi_clk;
    reg spi_reset;
    wire fifo_empty;

    // SPI Physical Pins
    wire sclk;
    wire mosi;
    reg  miso; // (NEW) Mock data coming back from flash
    wire cs;

    // Instantiate Final Dual-Clock Top Module
    dual_clock_top u_top (
        .host_clk(host_clk),
        .host_reset(host_reset),
        .host_wr_en(host_wr_en),
        .host_din(host_din),
        .fifo_full(fifo_full),

        .host_rd_en(host_rd_en),
        .host_dout(host_dout),
        .rx_fifo_empty(rx_fifo_empty),

        .spi_clk(spi_clk),
        .spi_reset(spi_reset),
        .fifo_empty(fifo_empty),

        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs(cs)
    );

    // Instantiate Flash Behavioral Model
    flash_model_tb u_flash (
        .cs(cs),
        .sclk(sclk),
        .mosi(mosi)
    );

    // CLOCK 1: 200 MHz Host Clock (Fast)
    always #2.5 host_clk = ~host_clk;

    // CLOCK 2: 100 MHz SPI Controller Clock (Slower)
    always #5.0 spi_clk = ~spi_clk;

    // Mock MISO behavior: We will just toggle MISO so it generates fake incoming data (0x55 / 0xAA)
    always @(negedge sclk) begin
        if (!cs) miso = ~miso;
    end

    initial begin
        // Initialization
        host_clk = 0;
        spi_clk = 0;
        host_reset = 1;
        spi_reset = 1;
        host_wr_en = 0;
        host_rd_en = 0;
        host_din = 8'h00;
        miso = 0;

        // Wait and release resets
        #40;
        host_reset = 0;
        spi_reset = 0;
        #20;

        // The Host writes a rapid burst of 3 bytes at 200 MHz
        @(negedge host_clk);
        host_wr_en = 1;
        host_din = 8'hAA;

        @(negedge host_clk);
        host_din = 8'h55;

        @(negedge host_clk);
        host_din = 8'h99;

        @(negedge host_clk);
        host_wr_en = 0; // Stop writing

        // THE FIX: Clock Domain Crossing takes time! 
        // We have to wait for the FSM to WAKE UP (cs goes low) before we wait for it to finish!
        wait(cs == 1'b0);

        // NOW we wait for the transmission to completely finish
        wait(fifo_empty == 1'b1);
        wait(cs == 1'b1);

        // Phase 2 Verification: Let's read the 3 bytes that came BACK from the MISO pin!
        #50;
        $display("--- SPI Transmission Finished. Reading back from RX FIFO ---");
        
        repeat (3) begin
            wait(rx_fifo_empty == 1'b0); // Wait for data to sync to host domain
            @(negedge host_clk);
            host_rd_en = 1;
            @(negedge host_clk);
            host_rd_en = 0;
            $display("Host read data from RX FIFO: 0x%02h", host_dout);
        end

        #200; // Let final bits flush out completely before killing simulation
        $display("Dual-Clock system simulation completed successfully.");
        $finish;
    end
endmodule