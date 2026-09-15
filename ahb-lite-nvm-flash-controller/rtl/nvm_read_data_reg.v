module nvm_read_data_reg #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  reset_n,

    input  wire [DATA_WIDTH-1:0] flash_rdata,
    input  wire                  rd_capture_en,

    output reg  [DATA_WIDTH-1:0] read_data_reg
);

    always @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin
            read_data_reg <= {DATA_WIDTH{1'b0}};
        end
        else if (rd_capture_en) begin
            read_data_reg <= flash_rdata;
        end

    end

endmodule