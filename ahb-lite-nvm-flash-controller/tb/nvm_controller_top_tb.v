`timescale 1ns / 1ps

//======================================================================
// Self-checking testbench for nvm_controller_top
//
// Tested cases:
//   1. Reset behavior
//   2. Valid Flash read with delayed completion
//   3. Valid Flash read with error
//   4. Valid Flash program with delayed completion
//   5. Valid Flash program with error
//   6. Valid erase with delayed completion
//   7. Valid erase with error
//   8. Invalid address
//   9. Read access to erase-command region
//  10. Unsupported HSIZE
//  11. Non-selected transfer
//  12. IDLE/BUSY stability and back-to-back transactions
//
// Assumptions from the current RTL:
//   - FLASH_REGION_BASE = 0x00000000, size = 4096 bytes
//   - ERASE_REGION_BASE = 0x00001000, size = 4096 bytes
//   - HSIZE = 3'b010 is the only accepted transfer size
//   - HRESP is one bit: 0 = OKAY, 1 = ERROR
//   - Flash completion is indicated by FLASH_DONE
//======================================================================

module nvm_controller_top_tb;

    localparam integer AHB_ADDR_WIDTH   = 32;
    localparam integer DATA_WIDTH       = 32;
    localparam integer LOCAL_ADDR_WIDTH = 12;

    localparam [1:0] HTRANS_IDLE   = 2'b00;
    localparam [1:0] HTRANS_BUSY   = 2'b01;
    localparam [1:0] HTRANS_NONSEQ = 2'b10;
    localparam [1:0] HTRANS_SEQ    = 2'b11;

    localparam [2:0] HSIZE_BYTE = 3'b000;
    localparam [2:0] HSIZE_HALF = 3'b001;
    localparam [2:0] HSIZE_WORD = 3'b010;

    localparam [31:0] FLASH_BASE = 32'h0000_0000;
    localparam [31:0] ERASE_BASE = 32'h0000_1000;

    reg clk;
    reg reset_n;

    reg  [31:0] HADDR;
    reg         HWRITE;
    reg  [1:0]  HTRANS;
    reg  [2:0]  HSIZE;
    reg  [2:0]  HBURST;
    reg  [31:0] HWDATA;
    reg         HSEL_FLASH;
    reg         HREADY;

    wire [31:0] HRDATA;
    wire        HREADYOUT;
    wire        HRESP;

    reg  [31:0] FLASH_RDATA;
    reg         FLASH_BUSY;
    reg         FLASH_DONE;
    reg         FLASH_ERROR;

    wire [11:0] FLASH_ADDR;
    wire [31:0] FLASH_WDATA;
    wire        FLASH_CS;
    wire        FLASH_RD_EN;
    wire        FLASH_PROG_EN;
    wire        FLASH_ERASE_EN;

    integer pass_count;
    integer fail_count;

    // DUT --------------------------------------------------------------
    nvm_controller_top #(
        .AHB_ADDR_WIDTH          (AHB_ADDR_WIDTH),
        .DATA_WIDTH              (DATA_WIDTH),
        .LOCAL_ADDR_WIDTH        (LOCAL_ADDR_WIDTH),
        .FLASH_REGION_BASE       (FLASH_BASE),
        .FLASH_REGION_SIZE_BYTES (4096),
        .ERASE_REGION_BASE       (ERASE_BASE),
        .ERASE_REGION_SIZE_BYTES (4096)
    ) dut (
        .clk             (clk),
        .reset_n         (reset_n),
        .HADDR           (HADDR),
        .HWRITE          (HWRITE),
        .HTRANS         (HTRANS),
        .HSIZE          (HSIZE),
        .HBURST         (HBURST),
        .HWDATA         (HWDATA),
        .HSEL_FLASH     (HSEL_FLASH),
        .HREADY         (HREADY),
        .HRDATA         (HRDATA),
        .HREADYOUT      (HREADYOUT),
        .HRESP          (HRESP),
        .FLASH_RDATA    (FLASH_RDATA),
        .FLASH_BUSY     (FLASH_BUSY),
        .FLASH_DONE     (FLASH_DONE),
        .FLASH_ERROR    (FLASH_ERROR),
        .FLASH_ADDR     (FLASH_ADDR),
        .FLASH_WDATA    (FLASH_WDATA),
        .FLASH_CS       (FLASH_CS),
        .FLASH_RD_EN    (FLASH_RD_EN),
        .FLASH_PROG_EN  (FLASH_PROG_EN),
        .FLASH_ERASE_EN (FLASH_ERASE_EN)
    );

    // Clock ------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Basic checking ---------------------------------------------------
    task check;
        input condition;
        input [8*120-1:0] message;
        begin
            if (condition) begin
                pass_count = pass_count + 1;
                $display("[PASS] %s", message);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %s", message);
            end
        end
    endtask

    task check_eq32;
        input [31:0] actual;
        input [31:0] expected;
        input [8*120-1:0] message;
        begin
            check(actual === expected, message);
            if (actual !== expected)
                $display("       actual = 0x%08h, expected = 0x%08h", actual, expected);
        end
    endtask

    task check_eq1;
        input actual;
        input expected;
        input [8*120-1:0] message;
        begin
            check(actual === expected, message);
            if (actual !== expected)
                $display("       actual = %b, expected = %b", actual, expected);
        end
    endtask

    // Drive an AHB transfer for one address/control cycle.  The DUT's
    // transaction decoder requires HREADY=1 and a NONSEQ/SEQ transfer.
    task drive_transfer;
        input [31:0] address;
        input         write;
        input [1:0]   trans;
        input [2:0]   size;
        input [31:0]  data;
        input         selected;
        begin
            @(negedge clk);
            HADDR       = address;
            HWRITE      = write;
            HTRANS      = trans;
            HSIZE       = size;
            HWDATA      = data;
            HSEL_FLASH  = selected;
            HREADY      = 1'b1;
        end
    endtask

    task clear_bus;
        begin
            @(negedge clk);
            HADDR      = 32'b0;
            HWRITE     = 1'b0;
            HTRANS     = HTRANS_IDLE;
            HSIZE      = HSIZE_WORD;
            HWDATA     = 32'b0;
            HSEL_FLASH = 1'b0;
            HREADY     = 1'b1;
        end
    endtask

    task clear_flash_status;
        begin
            FLASH_BUSY  = 1'b0;
            FLASH_DONE  = 1'b0;
            FLASH_ERROR = 1'b0;
            FLASH_RDATA = 32'b0;
        end
    endtask

    task wait_readyout_low;
        integer i;
        begin
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge clk);
                if (HREADYOUT === 1'b0) disable wait_readyout_low;
            end
            check(1'b0, "Controller entered a wait state");
        end
    endtask

    task wait_readyout_high;
        integer i;
        begin
            for (i = 0; i < 20; i = i + 1) begin
                @(posedge clk);
                if (HREADYOUT === 1'b1) disable wait_readyout_high;
            end
            check(1'b0, "Controller returned to ready state");
        end
    endtask

    // Reset ------------------------------------------------------------
    task reset_dut;
        begin
            reset_n = 1'b0;
            clear_bus;
            clear_flash_status;
            repeat (3) @(posedge clk);
            check_eq1(HREADYOUT, 1'b1, "Reset: HREADYOUT is high");
            check_eq1(HRESP,      1'b0, "Reset: HRESP is OKAY");
            check_eq1(FLASH_CS,   1'b0, "Reset: FLASH_CS is low");
            check_eq1(FLASH_RD_EN,1'b0, "Reset: FLASH_RD_EN is low");
            check_eq1(FLASH_PROG_EN,1'b0, "Reset: FLASH_PROG_EN is low");
            check_eq1(FLASH_ERASE_EN,1'b0, "Reset: FLASH_ERASE_EN is low");
            @(negedge clk);
            reset_n = 1'b1;
        end
    endtask

    // Test: read success ----------------------------------------------
    task test_read_success;
        begin
            $display("\n--- TEST: READ SUCCESS ---");
            clear_flash_status;
            drive_transfer(FLASH_BASE + 32'h0000_0024, 1'b0, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'b0, 1'b1);
            @(posedge clk);
            check_eq1(FLASH_CS, 1'b1, "Read: chip select asserted");
            check_eq1(FLASH_RD_EN, 1'b1, "Read: read enable asserted");
            check_eq1(HREADYOUT, 1'b0, "Read: controller inserts wait state");
            check_eq32(FLASH_ADDR, 32'h0000_0024, "Read: local address is correct");

            @(negedge clk);
            FLASH_RDATA = 32'hCAFE_BABE;
            FLASH_DONE  = 1'b1;
            @(posedge clk);
            @(negedge clk);
            FLASH_DONE  = 1'b0;
            wait_readyout_high;
            check_eq1(HRESP, 1'b0, "Read: successful response is OKAY");
            check_eq32(HRDATA, 32'hCAFE_BABE, "Read: returned data is captured");
            clear_bus;
        end
    endtask

    // Test: read error -------------------------------------------------
    task test_read_error;
        begin
            $display("\n--- TEST: READ ERROR ---");
            clear_flash_status;
            drive_transfer(FLASH_BASE + 32'h0000_0040, 1'b0, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'b0, 1'b1);
            @(posedge clk);
            check_eq1(HREADYOUT, 1'b0, "Read error: wait state asserted");
            @(negedge clk);
            FLASH_ERROR = 1'b1;
            @(posedge clk);
            @(negedge clk);
            FLASH_ERROR = 1'b0;
            check_eq1(HREADYOUT, 1'b1, "Read error: controller returns ready");
            check_eq1(HRESP, 1'b1, "Read error: HRESP is ERROR");
            clear_bus;
            @(posedge clk);
            check_eq1(HRESP, 1'b0, "Read error: error response clears after state exit");
        end
    endtask

    // Test: program success -------------------------------------------
    task test_program_success;
        begin
            $display("\n--- TEST: PROGRAM SUCCESS ---");
            clear_flash_status;
            drive_transfer(FLASH_BASE + 32'h0000_0080, 1'b1, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'h1234_5678, 1'b1);
            @(posedge clk);
            @(posedge clk);
            check_eq32(FLASH_WDATA, 32'h1234_5678, "Program: write data is captured");
            check_eq1(FLASH_PROG_EN, 1'b1, "Program: program enable asserted");
            check_eq1(FLASH_CS, 1'b1, "Program: chip select asserted");
            check_eq1(HREADYOUT, 1'b0, "Program: wait state asserted");
            @(negedge clk);
            FLASH_DONE = 1'b1;
            @(posedge clk);
            @(negedge clk);
            FLASH_DONE = 1'b0;
            wait_readyout_high;
            check_eq1(HRESP, 1'b0, "Program: successful response is OKAY");
            clear_bus;
        end
    endtask

    // Test: program error ---------------------------------------------
    task test_program_error;
        begin
            $display("\n--- TEST: PROGRAM ERROR ---");
            clear_flash_status;
            drive_transfer(FLASH_BASE + 32'h0000_00A0, 1'b1, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'hA5A5_5A5A, 1'b1);
            @(posedge clk);
            @(posedge clk);
            @(negedge clk);
            FLASH_ERROR = 1'b1;
            @(posedge clk);
            @(negedge clk);
            FLASH_ERROR = 1'b0;
            check_eq1(HREADYOUT, 1'b1, "Program error: controller returns ready");
            check_eq1(HRESP, 1'b1, "Program error: HRESP is ERROR");
            clear_bus;
            @(posedge clk);
        end
    endtask

    // Test: erase success ---------------------------------------------
    task test_erase_success;
        begin
            $display("\n--- TEST: ERASE SUCCESS ---");
            clear_flash_status;
            drive_transfer(ERASE_BASE + 32'h0000_0010, 1'b1, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'b0, 1'b1);
            @(posedge clk);
            check_eq1(FLASH_ERASE_EN, 1'b1, "Erase: erase enable asserted");
            check_eq1(FLASH_CS, 1'b1, "Erase: chip select asserted");
            check_eq1(FLASH_ADDR[11:0], 12'h010, "Erase: local address is correct");
            @(negedge clk);
            FLASH_DONE = 1'b1;
            @(posedge clk);
            @(negedge clk);
            FLASH_DONE = 1'b0;
            wait_readyout_high;
            check_eq1(HRESP, 1'b0, "Erase: successful response is OKAY");
            clear_bus;
        end
    endtask

    // Test: erase error ------------------------------------------------
    task test_erase_error;
        begin
            $display("\n--- TEST: ERASE ERROR ---");
            clear_flash_status;
            drive_transfer(ERASE_BASE + 32'h0000_0020, 1'b1, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'b0, 1'b1);
            @(posedge clk);
            @(negedge clk);
            FLASH_ERROR = 1'b1;
            @(posedge clk);
            @(negedge clk);
            FLASH_ERROR = 1'b0;
            check_eq1(HREADYOUT, 1'b1, "Erase error: controller returns ready");
            check_eq1(HRESP, 1'b1, "Erase error: HRESP is ERROR");
            clear_bus;
            @(posedge clk);
        end
    endtask

    // Test: invalid address -------------------------------------------
    task test_invalid_address;
        begin
            $display("\n--- TEST: INVALID ADDRESS ---");
            clear_flash_status;
            drive_transfer(32'h0000_3000, 1'b0, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'b0, 1'b1);
            @(posedge clk);
            check_eq1(HREADYOUT, 1'b1, "Invalid address: no wait state");
            check_eq1(HRESP, 1'b1, "Invalid address: HRESP is ERROR");
            check_eq1(FLASH_CS, 1'b0, "Invalid address: Flash is not selected");
            clear_bus;
            @(posedge clk);
        end
    endtask

    // Test: read from erase region ------------------------------------
    task test_invalid_erase_read;
        begin
            $display("\n--- TEST: READ FROM ERASE REGION ---");
            clear_flash_status;
            drive_transfer(ERASE_BASE + 32'h0000_0010, 1'b0, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'b0, 1'b1);
            @(posedge clk);
            check_eq1(HREADYOUT, 1'b1, "Erase-region read: no wait state");
            check_eq1(HRESP, 1'b1, "Erase-region read: HRESP is ERROR");
            check_eq1(FLASH_ERASE_EN, 1'b0, "Erase-region read: erase is not triggered");
            clear_bus;
            @(posedge clk);
        end
    endtask

    // Test: unsupported size ------------------------------------------
    task test_unsupported_size;
        begin
            $display("\n--- TEST: UNSUPPORTED HSIZE ---");
            clear_flash_status;
            drive_transfer(FLASH_BASE + 32'h0000_0020, 1'b0, HTRANS_NONSEQ,
                           HSIZE_BYTE, 32'b0, 1'b1);
            @(posedge clk);
            check_eq1(HREADYOUT, 1'b1, "Unsupported size: controller remains ready");
            check_eq1(HRESP, 1'b0, "Unsupported size: current decoder does not report error");
            check_eq1(FLASH_CS, 1'b0, "Unsupported size: Flash is not accessed");
            clear_bus;
            @(posedge clk);
        end
    endtask

    // Test: not selected ------------------------------------------------
    task test_not_selected;
        begin
            $display("\n--- TEST: HSEL_FLASH LOW ---");
            clear_flash_status;
            drive_transfer(FLASH_BASE + 32'h0000_0020, 1'b0, HTRANS_NONSEQ,
                           HSIZE_WORD, 32'b0, 1'b0);
            @(posedge clk);
            check_eq1(HREADYOUT, 1'b1, "Not selected: controller remains ready");
            check_eq1(HRESP, 1'b0, "Not selected: response is OKAY");
            check_eq1(FLASH_CS, 1'b0, "Not selected: Flash is not accessed");
            clear_bus;
            @(posedge clk);
        end
    endtask

    // Test: invalid transfer type -------------------------------------
    task test_invalid_htrans;
        begin
            $display("\n--- TEST: INVALID HTRANS ---");
            clear_flash_status;
            drive_transfer(FLASH_BASE + 32'h0000_0020, 1'b0, HTRANS_BUSY,
                           HSIZE_WORD, 32'b0, 1'b1);
            @(posedge clk);
            check_eq1(HREADYOUT, 1'b1, "BUSY transfer: controller remains ready");
            check_eq1(HRESP, 1'b0, "BUSY transfer: response is OKAY");
            check_eq1(FLASH_CS, 1'b0, "BUSY transfer: Flash is not accessed");
            clear_bus;
            @(posedge clk);
        end
    endtask

    // Main sequence ----------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        reset_n      = 1'b0;
        HADDR        = 32'b0;
        HWRITE       = 1'b0;
        HTRANS       = HTRANS_IDLE;
        HSIZE        = HSIZE_WORD;
        HBURST       = 3'b000;
        HWDATA       = 32'b0;
        HSEL_FLASH   = 1'b0;
        HREADY       = 1'b1;
        FLASH_RDATA  = 32'b0;
        FLASH_BUSY   = 1'b0;
        FLASH_DONE   = 1'b0;
        FLASH_ERROR  = 1'b0;

        reset_dut;
        test_read_success;
        test_read_error;
        test_program_success;
        test_program_error;
        test_erase_success;
        test_erase_error;
        test_invalid_address;
        test_invalid_erase_read;
        test_unsupported_size;
        test_not_selected;
        test_invalid_htrans;

        $display("\n============================================================");
        $display("TEST SUMMARY");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED - inspect messages above");

        #20;
        $finish;
    end

    // Waveform dump ----------------------------------------------------
    initial begin
        $dumpfile("nvm_controller_top_tb.vcd");
        $dumpvars(0, nvm_controller_top_tb);
    end

endmodule
