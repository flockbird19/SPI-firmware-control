// Single integrated testbench: a real spi_master and a real spi_slave wired
// together over SCLK/MOSI/CS/MISO, each side checked automatically instead
// of eyeballing waveforms. This is the "one top module, one testbench,
// master AND slave integrated" test the mentor asked for.
module tb_master_slave;
    reg clk, reset;
    reg enable, load, fsm_cs;
    reg [7:0] parl_in;
    wire sclk, mosi, cs;
    wire [7:0] master_rx_data;
    wire master_rx_valid;
    wire [2:0] bit_count;
    wire byte_done;

    wire [7:0] slave_rx_data;
    wire slave_rx_valid;
    wire slave_miso;
    reg [7:0] slave_tx_data;

    localparam [7:0] MASTER_TX = 8'hB6; // master -> slave, over MOSI
    localparam [7:0] SLAVE_TX  = 8'h3C; // slave  -> master, over MISO

    spi_master u_master (
        .clk       (clk),
        .reset     (reset),
        .enable    (enable),
        .load      (load),
        .parl_in   (parl_in),
        .fsm_cs    (fsm_cs),
        .miso      (slave_miso),
        .sclk      (sclk),
        .mosi      (mosi),
        .cs        (cs),
        .rx_data   (master_rx_data),
        .rx_valid  (master_rx_valid),
        .bit_count (bit_count),
        .byte_done (byte_done)
    );

    spi_slave u_slave (
        .clk      (clk),
        .reset    (reset),
        .cs       (cs),
        .sclk     (sclk),
        .mosi     (mosi),
        .tx_data  (slave_tx_data),
        .miso     (slave_miso),
        .rx_data  (slave_rx_data),
        .rx_valid (slave_rx_valid)
    );

    always #5 clk = ~clk; // 100 MHz reference clock

    initial begin
        clk = 1'b0; reset = 1'b1; enable = 1'b0; load = 1'b0;
        parl_in = 8'h00; fsm_cs = 1'b1; slave_tx_data = SLAVE_TX;

        #30 reset = 1'b0;

        // Load the byte the master will send, then start the transfer
        @(negedge clk);
        parl_in = MASTER_TX;
        load = 1'b1;
        @(negedge clk);
        load = 1'b0;

        fsm_cs = 1'b0;   // select the slave
        enable = 1'b1;   // run SCLK + bit counter

        wait (byte_done == 1'b1);

        @(negedge clk);
        enable = 1'b0;
        fsm_cs = 1'b1;   // deselect

        #20; // let rx_valid pulses settle both sides

        if (slave_rx_data === MASTER_TX)
            $display("PASS: slave received 0x%02h from master (MOSI path)", slave_rx_data);
        else
            $display("FAIL: slave received 0x%02h, expected 0x%02h (MOSI path)", slave_rx_data, MASTER_TX);

        if (master_rx_data === SLAVE_TX)
            $display("PASS: master received 0x%02h from slave (MISO path)", master_rx_data);
        else
            $display("FAIL: master received 0x%02h, expected 0x%02h (MISO path)", master_rx_data, SLAVE_TX);

        #20;
        $finish;
    end
endmodule
