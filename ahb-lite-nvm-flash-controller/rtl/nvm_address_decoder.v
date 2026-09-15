`timescale 1ns / 1ps

// NVM Controller Address Decoder
//
// Decodes the stored transaction address from the Address/Control Register.
//
// FLASH REGION:
//   HWRITE = 0 -> READ
//   HWRITE = 1 -> PROGRAM
//
// ERASE REGION:
//   HWRITE = 1 -> ERASE
//   HWRITE = 0 -> Invalid transaction (handled by Control FSM)
//
// The same local offset maps to the same logical Flash address
// regardless of whether the access is READ, PROGRAM, or ERASE.

module nvm_address_decoder #(
    parameter AHB_ADDR_WIDTH = 32,
    parameter LOCAL_ADDR_WIDTH = 12,

    // Normal Flash/NVM operation region.
    parameter [AHB_ADDR_WIDTH-1:0] FLASH_REGION_BASE = {AHB_ADDR_WIDTH{1'b0}},
    parameter integer FLASH_REGION_SIZE_BYTES = 4096,

    // Erase command region.
    parameter [AHB_ADDR_WIDTH-1:0] ERASE_REGION_BASE = {AHB_ADDR_WIDTH{1'b0}},
    parameter integer ERASE_REGION_SIZE_BYTES = 4096
) (
    // Stored address of the accepted AHB transaction.
    input wire [AHB_ADDR_WIDTH-1:0] addr_reg,

    // Address belongs to either the Flash region or Erase region.
    output wire addr_valid,

    // Offset within the selected operation region.
    output wire [LOCAL_ADDR_WIDTH-1:0] local_addr,

    // Normal Flash/NVM operation region.
    output wire flash_region,

    // Erase command region.
    output wire erase_region_select
);

    assign flash_region = (addr_reg >= FLASH_REGION_BASE)
                       && (addr_reg < (FLASH_REGION_BASE
                                      + FLASH_REGION_SIZE_BYTES));

    assign erase_region_select = (addr_reg >= ERASE_REGION_BASE)
                               && (addr_reg < (ERASE_REGION_BASE
                                              + ERASE_REGION_SIZE_BYTES));

    assign addr_valid = flash_region || erase_region_select;

    assign local_addr = flash_region
                      ? (addr_reg - FLASH_REGION_BASE)
                      : erase_region_select
                        ? (addr_reg - ERASE_REGION_BASE)
                        : {LOCAL_ADDR_WIDTH{1'b0}};

endmodule