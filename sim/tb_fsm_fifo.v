`timescale 1ns / 1ps

module tb_fsm_fifo;

    // System Signals
    reg clk;
    reg reset;

    // Host -> FIFO Signals
    reg wr_en;
    reg [7:0] din;
    wire full;

    // FIFO -> FSM Signals
    wire empty;
    wire [7:0] dout; // Not actively used by FSM, but part of FIFO interface

    // FSM Control Signals (Outputs)
    wire fifo_rd_en;
    wire load;
    wire enable;
    wire fsm_cs;

    // Datapath -> FSM Signals (Inputs)
    reg byte_done;

    // 1. Instantiate the FIFO
    sync_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4) // 16 bytes deep
    ) u_fifo (
        .clk(clk),
        .reset(reset),
        .wr_en(wr_en),
        .rd_en(fifo_rd_en), // Driven by FSM
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    // 2. Instantiate the FSM (The Brain)
    spi_fsm u_fsm (
        .clk(clk),
        .reset(reset),
        .fifo_empty(empty),
        .byte_done(byte_done),
        .fifo_rd_en(fifo_rd_en),
        .load(load),
        .enable(enable),
        .fsm_cs(fsm_cs)
    );

    // Generate System Clock (100 MHz)
    always #5 clk = ~clk;

    // 3. Mock the Datapath (Simulate the SPI Master sending a byte)
    // When the FSM asserts 'enable', we wait a few clock cycles and then pulse 'byte_done'
    reg [4:0] mock_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            byte_done <= 1'b0;
            mock_counter <= 5'd0;
        end else if (enable) begin
            // Simulate time taken to shift 8 bits (shortened for simulation speed)
            if (mock_counter == 5'd15) begin
                byte_done <= 1'b1;
                mock_counter <= 5'd0;
            end else begin
                byte_done <= 1'b0;
                mock_counter <= mock_counter + 1;
            end
        end else begin
            byte_done <= 1'b0;
            mock_counter <= 5'd0;
        end
    end

    // 4. State string logic for easy reading in the console
    reg [8*11:1] state_name;
    always @(*) begin
        case(u_fsm.state)
            3'd0: state_name = "IDLE";
            3'd1: state_name = "LOAD_BYTE";
            3'd2: state_name = "ASSERT_CS";
            3'd3: state_name = "SHIFT";
            3'd4: state_name = "CHECK";
            3'd5: state_name = "DEASSERT_CS";
            default: state_name = "UNKNOWN";
        endcase
    end

    // 5. Main Test Sequence
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        wr_en = 0;
        din = 8'h00;

        #20;
        reset = 0;

        $display("--- SYSTEM RESET: Waiting in IDLE ---");
        #20;

        // Write Byte 1 into FIFO
        @(negedge clk);
        wr_en = 1;
        din = 8'hAA;
        @(negedge clk);
        wr_en = 0;
        $display("--- HOST: Wrote 0xAA to FIFO ---");

        // Write Byte 2 into FIFO immediately after
        @(negedge clk);
        wr_en = 1;
        din = 8'h55;
        @(negedge clk);
        wr_en = 0;
        $display("--- HOST: Wrote 0x55 to FIFO ---");

        // Now just wait and let the FSM process both bytes automatically!
        // We will wait until we see CS go back high (deasserted)
        wait(fsm_cs == 1'b1);
        #50;

        $display("--- TEST COMPLETE: FSM returned to IDLE ---");
        $finish;
    end

    // 6. Monitor FSM Behavior
    always @(posedge clk) begin
        // Print whenever the state changes
        if (u_fsm.state != u_fsm.next_state) begin
            $display("TIME=%0t | State Transition: %0s -> %0s | FIFO Empty=%b | byte_done=%b",
                $time, state_name,
                (u_fsm.next_state==3'd0) ? "IDLE" :
                (u_fsm.next_state==3'd1) ? "LOAD_BYTE" :
                (u_fsm.next_state==3'd2) ? "ASSERT_CS" :
                (u_fsm.next_state==3'd3) ? "SHIFT" :
                (u_fsm.next_state==3'd4) ? "CHECK" : "DEASSERT_CS",
                empty, byte_done);
        end
    end

endmodule