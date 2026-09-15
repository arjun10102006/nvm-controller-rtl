`timescale 1ns / 1ps

//==============================================================
// AHB-Lite to NVM/Flash Controller - Top Module
//
// Notes:
// 1. HRESP is one bit according to AHB-Lite:
//      1'b0 -> OKAY
//      1'b1 -> ERROR
//
// 2. size_valid has been removed from the transaction decoder.
//
// 3. Only word-sized transfers are currently accepted:
//      HSIZE = 3'b010
//
// 4. HBURST is included for AHB compatibility but is currently
//    unused because the controller supports single transfers.
//
// 5. The Flash IP is treated as a black box.
//==============================================================

module nvm_controller_top #(
    parameter integer AHB_ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH     = 32,
    parameter integer LOCAL_ADDR_WIDTH = 12,

    parameter [AHB_ADDR_WIDTH-1:0] FLASH_REGION_BASE = {
        AHB_ADDR_WIDTH{1'b0}
    },

    parameter integer FLASH_REGION_SIZE_BYTES = 4096,

    parameter [AHB_ADDR_WIDTH-1:0] ERASE_REGION_BASE = {
        AHB_ADDR_WIDTH{1'b0}
    },

    parameter integer ERASE_REGION_SIZE_BYTES = 4096
)(
    //==========================================================
    // Clock and Reset
    //==========================================================
    input wire clk,
    input wire reset_n,

    //==========================================================
    // AHB-Lite Slave Interface
    //==========================================================
    input wire [AHB_ADDR_WIDTH-1:0] HADDR,
    input wire                     HWRITE,
    input wire [1:0]               HTRANS,
    input wire [2:0]               HSIZE,
    input wire [2:0]               HBURST,
    input wire [DATA_WIDTH-1:0]    HWDATA,
    input wire                     HSEL_FLASH,
    input wire                     HREADY,

    output wire [DATA_WIDTH-1:0]   HRDATA,
    output wire                    HREADYOUT,
    output wire                    HRESP,

    //==========================================================
    // Flash/NVM IP Interface
    //==========================================================
    input wire [DATA_WIDTH-1:0]    FLASH_RDATA,
    input wire                     FLASH_BUSY,
    input wire                     FLASH_DONE,
    input wire                     FLASH_ERROR,

    output wire [LOCAL_ADDR_WIDTH-1:0] FLASH_ADDR,
    output wire [DATA_WIDTH-1:0]       FLASH_WDATA,
    output wire                        FLASH_CS,
    output wire                        FLASH_RD_EN,
    output wire                        FLASH_PROG_EN,
    output wire                        FLASH_ERASE_EN
);

    // HBURST is currently unused.
    wire [2:0] unused_hburst;
    assign unused_hburst = HBURST;

    //==========================================================
    // Transaction Decoder Signals
    //==========================================================
    wire valid_transfer;
    wire capture_en;
    wire read_req;
    wire write_req;

    //==========================================================
    // Address/Control Register Signals
    //==========================================================
    wire [AHB_ADDR_WIDTH-1:0] addr_reg;
    wire                      write_reg;

    //==========================================================
    // Address Decoder Signals
    //==========================================================
    wire [LOCAL_ADDR_WIDTH-1:0] local_addr;
    wire                        addr_valid;
    wire                        flash_region;
    wire                        erase_region_select;

    //==========================================================
    // Write and Read Data Register Signals
    //==========================================================
    wire [DATA_WIDTH-1:0] write_data_reg;
    wire [DATA_WIDTH-1:0] read_data_reg;

    wire wd_capture_en;
    wire rd_capture_en;

    //==========================================================
    // FSM Control Signals
    //==========================================================
    wire flash_cs_int;
    wire flash_rd_en_int;
    wire flash_prog_en_int;
    wire flash_erase_en_int;
    wire read_active;

    wire fsm_hreadyout;
    wire fsm_hresp;

    //==========================================================
    // Flash Interface Internal Signals
    //==========================================================
    wire [LOCAL_ADDR_WIDTH-1:0] flash_addr_int;
    wire [DATA_WIDTH-1:0]       flash_wdata_int;

    wire flash_cs_out_int;
    wire flash_rd_en_out_int;
    wire flash_prog_en_out_int;
    wire flash_erase_en_out_int;

    wire flash_busy_int;
    wire flash_done_int;
    wire flash_error_int;

    //==========================================================
    // 1. AHB Transaction Decoder
    //==========================================================
    nvm_transaction_decoder u_transaction_decoder (
        .HSEL_FLASH     (HSEL_FLASH),
        .HREADY         (HREADY),
        .HTRANS        (HTRANS),
        .HSIZE         (HSIZE),
        .HWRITE        (HWRITE),

        .valid_transfer(valid_transfer),
        .capture_en    (capture_en),
        .read_req      (read_req),
        .write_req     (write_req)
    );

    //==========================================================
    // 2. Address/Control Register
    //==========================================================
    nvm_address_control_reg #(
        .ADDR_WIDTH(AHB_ADDR_WIDTH)
    ) u_address_control_reg (
        .clk       (clk),
        .reset_n   (reset_n),
        .HADDR     (HADDR),
        .HWRITE    (HWRITE),
        .capture_en(capture_en),

        .addr_reg  (addr_reg),
        .write_reg (write_reg)
    );

    //==========================================================
    // 3. Address Decoder
    //==========================================================
    nvm_address_decoder #(
        .AHB_ADDR_WIDTH        (AHB_ADDR_WIDTH),
        .LOCAL_ADDR_WIDTH      (LOCAL_ADDR_WIDTH),
        .FLASH_REGION_BASE     (FLASH_REGION_BASE),
        .FLASH_REGION_SIZE_BYTES(FLASH_REGION_SIZE_BYTES),
        .ERASE_REGION_BASE     (ERASE_REGION_BASE),
        .ERASE_REGION_SIZE_BYTES(ERASE_REGION_SIZE_BYTES)
    ) u_address_decoder (
        .addr_reg          (addr_reg),

        .addr_valid        (addr_valid),
        .local_addr        (local_addr),
        .flash_region      (flash_region),
        .erase_region_select(erase_region_select)
    );

    //==========================================================
    // 4. Control FSM
    //==========================================================
    nvm_control_fsm u_control_fsm (
        .clk                 (clk),
        .reset_n             (reset_n),

        .valid_transfer      (valid_transfer),
        .addr_valid          (addr_valid),
        .flash_region        (flash_region),
        .erase_region_select (erase_region_select),
        .hwrite_reg          (write_reg),

        .flash_busy          (flash_busy_int),
        .flash_done          (flash_done_int),
        .flash_error         (flash_error_int),

        .flash_cs            (flash_cs_int),
        .flash_rd_en         (flash_rd_en_int),
        .flash_prog_en       (flash_prog_en_int),
        .flash_erase_en      (flash_erase_en_int),

        .read_active         (read_active),
        .wd_capture_en       (wd_capture_en),

        .hreadyout           (fsm_hreadyout),
        .hresp               (fsm_hresp)
    );

    //==========================================================
    // 5. Write Data Register
    //==========================================================
    nvm_write_data_reg #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_write_data_reg (
        .clk          (clk),
        .reset_n      (reset_n),
        .hwdata       (HWDATA),
        .wd_capture_en(wd_capture_en),

        .write_data_reg(write_data_reg)
    );

    //==========================================================
    // 6. Flash Interface
    //==========================================================
    nvm_flash_interface #(
        .ADDR_WIDTH(LOCAL_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_flash_interface (
        .local_addr    (local_addr),
        .write_data_reg(write_data_reg),

        .flash_cs      (flash_cs_int),
        .flash_rd_en   (flash_rd_en_int),
        .flash_prog_en (flash_prog_en_int),
        .flash_erase_en(flash_erase_en_int),
        .read_active   (read_active),

        .flash_rdata   (FLASH_RDATA),
        .FLASH_BUSY    (FLASH_BUSY),
        .FLASH_DONE    (FLASH_DONE),
        .FLASH_ERROR   (FLASH_ERROR),

        .flash_addr    (flash_addr_int),
        .flash_wdata   (flash_wdata_int),

        .flash_cs_out       (flash_cs_out_int),
        .flash_rd_en_out    (flash_rd_en_out_int),
        .flash_prog_en_out  (flash_prog_en_out_int),
        .flash_erase_en_out (flash_erase_en_out_int),

        .rd_capture_en (rd_capture_en),

        .flash_busy    (flash_busy_int),
        .flash_done    (flash_done_int),
        .flash_error   (flash_error_int)
    );

    //==========================================================
    // 7. Read Data Register
    //==========================================================
    nvm_read_data_reg #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_read_data_reg (
        .clk         (clk),
        .reset_n     (reset_n),
        .flash_rdata  (FLASH_RDATA),
        .rd_capture_en(rd_capture_en),

        .read_data_reg(read_data_reg)
    );

    //==========================================================
    // Top-Level AHB Outputs
    //==========================================================
    assign HRDATA    = read_data_reg;
    assign HREADYOUT = fsm_hreadyout;
    assign HRESP     = fsm_hresp;

    //==========================================================
    // Top-Level Flash Outputs
    //==========================================================
    assign FLASH_ADDR     = flash_addr_int;
    assign FLASH_WDATA    = flash_wdata_int;

    assign FLASH_CS       = flash_cs_out_int;
    assign FLASH_RD_EN    = flash_rd_en_out_int;
    assign FLASH_PROG_EN  = flash_prog_en_out_int;
    assign FLASH_ERASE_EN = flash_erase_en_out_int;

endmodule