// Combined testbench of all 4 Stages. 
// I hve made this extra module to check things working fine or not
// !!! all leaf i have included in this...
// stags:
// 1 clock divider
// 2 PISO register
// 3. bit counter
// 4. flash behavioral model
module tb_phase1_all_4stags;
    reg clk;
    reg reset;
    reg enable;
    reg load;
    reg [7:0] parl_in;
    wire sclk;
    wire mosi;
    wire [2:0] bit_count;
    wire byte_done;
    reg cs; // flash Chip Select

    // Clock Divider
    // divide is 2
    // Main clock = 100 MHz
    // SCLK = 100/(2*2) = 25 MHz
    clk_div #(.divide(2)) u_clk_div (
        .clk (clk),
        .reset (reset),
        .enable (enable),
        .sclk (sclk)
    );

    // PISO register
    // converts the 8bit parallel data into serial Mosi data.
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
        .enable (enable),
        .count (bit_count),
        .done (byte_done)
    );

    // Flash Model
    // receives mosi data just like an SPI flash device. // it acts Ike a virtual flash device.
    flash_model_tb u_flash_model (
        .cs (cs),
        .sclk (sclk),
        .mosi (mosi)
    );

    // Generate main clock
    // #5 means clock changes every 5ns
    // So, clock period = 10ns = 100MHz.
    always #5 clk = ~clk;

    // Main Test Sequence
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        enable = 1'b0;
        load = 1'b0;
        parl_in = 8'h00;
        cs = 1'b1; // flash not selected
        #30; // reset active for 30ns
        reset = 1'b0; // release reset

        // ========== BUG FIX SECTION ==========
        // Turn on the clock divider first so 'sclk' actually ticks
        enable = 1'b1;

        // Load data into PISO using the SLOW clock (sclk) instead of the fast clk
        @(negedge sclk);
        parl_in = 8'hA5; // loading data 8'hA5
        load = 1'b1; // tell PISO to load the byte
        @(negedge sclk);
        load = 1'b0; // stop loading
        // =====================================

        //==========
        // Starting SPI transmission
        cs = 1'b0; // Pull CS low to tell the flash model to start listening

        // wait until all 8 bits are transmitted
        wait (byte_done == 1'b1);

        //=================
        // End SPI transmission
        @(negedge clk);
        enable = 1'b0; // stoping SPI clock and counter
        cs = 1'b1; // deselect Flash
        #50;
        $finish;
    end

    //displaying the nessasary data
    always @(posedge sclk) begin
        if (!cs) begin
            $display("TIME=%0t SCLK=%b MOSI=%b bit_counter=%0d done =%b", $time, sclk, mosi, bit_count, byte_done);
        end
    end
endmodule