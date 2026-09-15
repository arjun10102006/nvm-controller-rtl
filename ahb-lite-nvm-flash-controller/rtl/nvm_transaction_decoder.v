`timescale 1ns / 1ps

// Combinational AHB-Lite transaction qualifier for the NVM controller.
module nvm_transaction_decoder (
    input  wire       HSEL_FLASH,
    input  wire       HREADY,
    input  wire [1:0] HTRANS,
    input  wire [2:0] HSIZE,
    input  wire       HWRITE,
    output wire       valid_transfer,
    output wire       capture_en,
    output wire       read_req,
    output wire       write_req
);

    assign valid_transfer = HSEL_FLASH
                     && HREADY
                     && ((HTRANS == 2'b10) || (HTRANS == 2'b11))
                     && (HSIZE == 3'b010);

    assign capture_en = valid_transfer;
    assign read_req  = valid_transfer && !HWRITE;
    assign write_req = valid_transfer && HWRITE;

endmodule
