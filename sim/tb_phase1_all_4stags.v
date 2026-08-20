module tb_phase1_all_4stags;
    reg clk;
    reg reset;
    reg enable_clk; // Drives the clock divider
    reg enable_cnt; // Drives the bit counter
    reg load;
    reg [7:0] parl_in;
    wire sclk;
    wire mosi;
    wire [2:0] bit_count;
    wire byte_done;
    reg cs; // flash Chip Select

    // Clock Divider
    clk_div #(.divide(2)) u_clk_div (
        .clk (clk),
        .reset (reset),
        .enable (enable_clk), // Wired to clock enable
        .sclk (sclk)
    );

    // PISO register
    piso_reg u_piso (
        .sclk (sclk),
        .reset (reset),
        .load (load),
        .parl_in (parl_in),
        .serl_out (mosi)
    );

    // Bit Counter
    bit_counter u_bit_counter (
        .clk (sclk),
        .reset (reset),
        .enable (enable_cnt), // Wired to counter enable
        .count (bit_count),
        .done (byte_done)
    );

    // Flash Model
    flash_model_tb u_flash_model (
        .cs (cs),
        .sclk (sclk),
        .mosi (mosi)
    );

    always #5 clk = ~clk;

    // Main Test Sequence
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        enable_clk = 1'b0;
        enable_cnt = 1'b0;
        load = 1'b0;
        parl_in = 8'h00;
        cs = 1'b1; 
        #30; 
        reset = 1'b0; 

        // 1. Turn on the clock ONLY to allow data loading
        enable_clk = 1'b1; 
        
        // 2. Load the data while keeping the counter off and flash asleep
        @(negedge sclk); 
        parl_in = 8'hA5; 
        load = 1'b1;     
        @(negedge sclk); 
        load = 1'b0;     
        
        // 3. Start transmission! Wake up flash and start counting
        cs = 1'b0; 
        enable_cnt = 1'b1; 
        
        // wait until all 8 bits are transmitted
        wait (byte_done == 1'b1); 
        
        // End SPI transmission
        @(negedge clk);
        enable_clk = 1'b0;
        enable_cnt = 1'b0;
        cs = 1'b1; 
        #50;
        $finish;
    end

    // Display tracking
    always @(posedge sclk) begin
        if (!cs) begin
            $display("TIME=%0t SCLK=%b MOSI=%b bit_counter=%0d done =%b", $time, sclk, mosi, bit_count, byte_done);
        end
    end
endmodule