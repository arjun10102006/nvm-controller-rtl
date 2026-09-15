`timescale 1ns / 1ps

// Captures the accepted AHB address/control context for an NVM transaction.
module nvm_address_control_reg #(
    parameter ADDR_WIDTH = 32
) (
    input  wire                  clk,
    input  wire                  reset_n,
    input  wire [ADDR_WIDTH-1:0] HADDR,
    input  wire                  HWRITE,
    input  wire                  capture_en,
    output reg  [ADDR_WIDTH-1:0] addr_reg,
    output reg                   write_reg
);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            addr_reg  <= 1'b0;
            write_reg <= 1'b0;
        end
        else if (capture_en) begin
            addr_reg  <= HADDR;
            write_reg <= HWRITE;
        end
    end

endmodule
