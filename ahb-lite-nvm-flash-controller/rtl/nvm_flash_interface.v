`timescale 1ns / 1ps

// NVM Flash Interface
//
// Responsibilities:
// 1. Connect the NVM datapath to the Flash IP.
// 2. Forward the local Flash address.
// 3. Forward the registered write data.
// 4. Forward Flash control signals from the Control FSM.
// 5. Return Flash status signals to the Control FSM.
// 6. Generate RD_CAPTURE_EN when valid read data is available.
//
// Flash interface assumptions:
// - FLASH_PROG_EN starts a program operation.
// - FLASH_ERASE_EN starts an erase operation.
// - FLASH_RD_EN starts a read operation.
// - FLASH_DONE indicates successful operation completion.
// - FLASH_ERROR indicates operation failure.
// - During a read, FLASH_DONE indicates FLASH_RDATA is valid.
// - RD_CAPTURE_EN is generated only for an active read operation.

module nvm_flash_interface #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
)(
    //============================================================
    // Controller-side inputs
    //============================================================

    // Local Flash address from Address Decoder
    input  wire [ADDR_WIDTH-1:0] local_addr,

    // Registered write data
    input  wire [DATA_WIDTH-1:0] write_data_reg,

    // Control signals from Control FSM
    input  wire flash_cs,
    input  wire flash_rd_en,
    input  wire flash_prog_en,
    input  wire flash_erase_en,

    // Indicates that a read operation is currently active
    input  wire read_active,


    //============================================================
    // Flash IP-side inputs
    //============================================================

    // Read data returned by Flash IP
    input  wire [DATA_WIDTH-1:0] flash_rdata,

    // Flash status signals
    input  wire FLASH_BUSY,
    input  wire FLASH_DONE,
    input  wire FLASH_ERROR,


    //============================================================
    // Outputs to Flash IP
    //============================================================

    // Flash address
    output wire [ADDR_WIDTH-1:0] flash_addr,

    // Flash program data
    output wire [DATA_WIDTH-1:0] flash_wdata,

    // Flash control signals
    output wire flash_cs_out,
    output wire flash_rd_en_out,
    output wire flash_prog_en_out,
    output wire flash_erase_en_out,


    //============================================================
    // Outputs to NVM Controller
    //============================================================

    // Enables Read Data Register to capture FLASH_RDATA
    output wire rd_capture_en,

    // Flash status returned to Control FSM
    output wire flash_busy,
    output wire flash_done,
    output wire flash_error

);


    //============================================================
    // Address Path
    //============================================================

    assign flash_addr = local_addr;


    //============================================================
    // Write Data Path
    //============================================================

    assign flash_wdata = write_data_reg;


    //============================================================
    // Flash Control Path
    //============================================================

    assign flash_cs_out       = flash_cs;
    assign flash_rd_en_out    = flash_rd_en;
    assign flash_prog_en_out  = flash_prog_en;
    assign flash_erase_en_out = flash_erase_en;


    //============================================================
    // Read Data Capture Control
    //============================================================
    //
    // RD_CAPTURE_EN is asserted when:
    //
    // 1. A read operation is currently active, and
    // 2. Flash reports operation completion.
    //
    // Under our Flash-IP assumption, FLASH_DONE also indicates
    // that FLASH_RDATA is valid.
    //
    // Therefore:
    //
    //     read_active + flash_done
    //              |
    //              v
    //       RD_CAPTURE_EN
    //
    //============================================================

    assign rd_capture_en = read_active && FLASH_DONE;


    //============================================================
    // Flash Status Path
    //============================================================

    assign flash_busy  = FLASH_BUSY;
    assign flash_done = FLASH_DONE;
    assign flash_error = FLASH_ERROR;


endmodule