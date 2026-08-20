///////
//!! this is a standalone testbench for SPI Flash behavioral model
module tb_flash_model;
    reg cs;
    reg sclk;
    reg mosi;

    flash_model_tb dut (
        .cs (cs),
        .sclk (sclk),
        .mosi (mosi)
    );

    always #5 sclk = ~sclk;

    task send_byte;
        input [7:0] data; // Byte to transmit
        integer i;
        begin
            cs=1'b0;
            // Bit counter
            for (i = 7; i >= 0; i = i-1) begin // Send bits from msb to lsb
                @(negedge sclk);
                // change mosi before rising edge
                mosi = data[i];
                @(posedge sclk);
                // flash samples mosi at rising edge
            end
            @(negedge sclk); // finish the SPI transaction
            cs=1'b1;
        end
    endtask

    initial begin
        cs = 1'b1; // Flash not selected
        sclk = 1'b0; // Clock starts LOW
        mosi = 1'b0; // MOSI starts LOW
        #30; //wait to strat communication
        send_byte(8'hB6); //1st byte
        #40; // wait after first byte
        send_byte(8'h3C); //2nd byte
        #40;
        $finish;
    end
endmodule