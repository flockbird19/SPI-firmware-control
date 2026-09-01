module spi_fsm (
    input wire clk,
    input wire reset,

    // Signals from FIFO and Data Path
    input wire fifo_empty,
    input wire byte_done,

    // Control Signals Out
    output reg fifo_rd_en, // Tell FIFO to output next byte
    output reg load, // Tell PISO to load the byte
    output reg enable, // Start the clock divider and bit counter
    output reg fsm_cs // Flash Chip Select (active low)
);

    // State Encodings
    localparam IDLE        = 3'd0;
    localparam LOAD_BYTE   = 3'd1;
    localparam ASSERT_CS   = 3'd2;
    localparam SHIFT       = 3'd3;
    localparam CHECK       = 3'd4;
    localparam DEASSERT_CS = 3'd5;

    reg [2:0] state, next_state;

    // 1. Sequential block for state tracking
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 2. Combinational block for next-state logic and outputs (Moore Machine)
    always @(*) begin
        // Default Output Values (Prevents inferred latches)
        fifo_rd_en = 1'b0;
        load       = 1'b0;
        enable     = 1'b0;
        fsm_cs     = 1'b1; // CS is active low, default to high (deasserted)

        // Default Next State
        next_state = state;

        case (state)
            IDLE: begin
                // Wait for data in the FIFO
                if (!fifo_empty) begin
                    next_state = LOAD_BYTE;
                end
            end

            LOAD_BYTE: begin
                fifo_rd_en = 1'b1; // Trigger a read from the FIFO
                // It takes 1 cycle for sync_fifo to output data,
                // so the data will be ready when we enter ASSERT_CS
                next_state = ASSERT_CS;
            end

            ASSERT_CS: begin
                fsm_cs = 1'b0; // Pull CS low to wake up the flash
                load = 1'b1; // Pulse 'load' so PISO grabs the FIFO output
                next_state = SHIFT;
            end

            SHIFT: begin
                fsm_cs = 1'b0;
                enable = 1'b1; // Let the clock divider and counter run!

                // Wait until the bit_counter says all 8 bits are done
                if (byte_done) begin
                    next_state = CHECK;
                end
            end

            CHECK: begin
                fsm_cs = 1'b0; // Keep CS low while we check

                // If there's more data, continuously send it. Otherwise, end transaction.
                if (!fifo_empty) begin
                    next_state = LOAD_BYTE;
                end else begin
                    next_state = DEASSERT_CS;
                end
            end

            DEASSERT_CS: begin
                fsm_cs = 1'b1; // Pull CS high to end transaction
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule