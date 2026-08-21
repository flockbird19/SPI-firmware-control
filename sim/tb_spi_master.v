// Day 4: SPI Master Testbench
module tb_spi_master;
    // Master Inputs
    reg clk;
    reg reset;
    reg enable;
    reg load;
    reg [7:0] parl_in;
    reg fsm_cs;
    
    // Master Outputs / SPI Bus
    wire sclk;
    wire mosi;
    wire cs;
    wire [2:0] bit_count;
    wire byte_done;

    // Instantiate SPI Master Wrapper
    spi_master u_spi_master (
        .clk (clk),
        .reset (reset),
        .enable (enable),
        .load (load),
        .parl_in (parl_in),
        .fsm_cs (fsm_cs),
        .sclk (sclk),
        .mosi (mosi),
        .cs (cs),
        .bit_count (bit_count),
        .byte_done (byte_done)
    );

    // Instantiate Behavioral Flash Model Receiver
    flash_model_tb u_flash_model (
        .cs (cs),
        .sclk (sclk),
        .mosi (mosi)
    );

    // Generate main system clock (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 1'b0;
        reset = 1'b1;
        enable = 1'b0;
        load = 1'b0;
        parl_in = 8'h00;
        fsm_cs = 1'b1; // CS is active low, default high

        #30; 
        reset = 1'b0; // Release reset

        // Phase 1: Manually load a byte into the PISO
        @(negedge clk);
        parl_in = 8'hB6; // Test byte 
        load = 1'b1;
        @(negedge clk);
        load = 1'b0;

        // Phase 2: Start SPI transmission
        fsm_cs = 1'b0;   // Assert Chip Select
        enable = 1'b1;   // Start SPI clock and counter
        
        // Wait for bit_counter to signal the byte is finished
        wait (byte_done == 1'b1);
        
        // Phase 3: End SPI transmission
        @(negedge clk);
        enable = 1'b0;   // Stop SPI clock
        fsm_cs = 1'b1;   // Deassert Chip Select

        #50;
        $finish;
    end

    // Monitor Outputs
    always @(posedge sclk) begin
        if (!cs) begin
            $display("TIME=%0t SCLK=%b MOSI=%b bit_count=%0d byte_done=%b", 
                     $time, sclk, mosi, bit_count, byte_done);
        end
    end
endmodule