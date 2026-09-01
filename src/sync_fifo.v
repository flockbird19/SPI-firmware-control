module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4 //depth = 16 locations
)(
    input wire clk,
    input wire reset,
    input wire wr_en, //write enable
    input wire rd_en, //read enable
    input wire [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout,
    output wire full,
    output wire empty
);
    //memory array
    reg [DATA_WIDTH-1:0] fifo_ram [0:(1<<ADDR_WIDTH)-1];

    //pointer with extra bits for full and empty 
    reg [ADDR_WIDTH:0] wr_ptr, rd_ptr;

    //empty : all bits of write and read pointers match completely
    // full :  msb differs, but lower addr bits match

    assign empty = (wr_ptr ==rd_ptr);
    assign full = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    //write logic
    always@(posedge clk)begin
        if(reset) begin
            wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end else if (wr_en && !full)begin
            fifo_ram[wr_ptr[ADDR_WIDTH-1:0]] <= din;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    //read logic
    always@(posedge clk) begin
        if(reset) begin
            rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
            dout <= {DATA_WIDTH{1'b0}};
        end else if  (rd_en && !empty)begin
            dout <= fifo_ram[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1'b1;
        end
    end


endmodule