# AHB-Lite to NVM/Flash Controller

## 1. Project Overview

This project implements a modular **AHB-Lite slave-side NVM/Flash controller** using Verilog HDL.

The controller acts as an interface between a RISC-V processor system connected through an **AHB-Lite interconnect** and an external NVM/Flash memory IP.

It receives AHB-Lite read and write transactions, decodes the target address and operation type, controls the Flash memory interface, and returns read data or transaction status to the AHB-Lite bus.

The design is intended for integration into a larger RISC-V-based SoC.

---

## 2. Main Objectives

- Implement an AHB-Lite-compatible controller interface.
- Decode valid AHB-Lite transactions.
- Capture address and control information.
- Validate the requested address region.
- Support Flash read operations.
- Support Flash program operations.
- Support erase-region operations.
- Control Flash interface signals through a finite-state machine.
- Capture Flash read data and return it to the processor.
- Handle Flash completion and error responses.
- Verify the RTL through simulation and waveform analysis.

---

## 3. High-Level Architecture

The controller consists of the following major blocks:

1. AHB Transaction Decoder
2. Address and Control Register
3. Address Decoder
4. Control FSM
5. Write Data Register
6. Read Data Register
7. Flash Interface
8. Top-Level Controller Integration

### Simplified Architecture

```text
                 AHB-Lite Bus
                      |
                      v
            AHB Transaction Decoder
                      |
                      v
            Address/Control Register
                      |
                      v
                Address Decoder
                      |
                      v
                  Control FSM
                      |
                      v
                Flash Interface
                      |
                      v
                NVM/Flash IP
Write Data Path
HWDATA
   |
   v
Write Data Register
   |
   v
Flash Interface
   |
   v
FLASH_WDATA
Read Data Path
FLASH_RDATA
     |
     v
Read Data Register
     |
     v
HRDATA
4. Supported AHB-Lite Signals
Signal	Width	Description
HADDR	32 bits	AHB transaction address
HWRITE	1 bit	Indicates read or write operation
HWDATA	32 bits	Write data from the master
HTRANS	2 bits	AHB transfer type
HSIZE	3 bits	Transfer size
HBURST	3 bits	Burst information
HSEL_FLASH	1 bit	Selects the Flash controller
HREADY	1 bit	Indicates that the previous transfer is complete
HRDATA	32 bits	Read data returned to the master
HREADYOUT	1 bit	Indicates completion of the current controller transaction
HRESP	1 bit	AHB response status


5. AHB Transaction Assumptions
5.1 Word Transfers Only
The current transaction decoder accepts only 32-bit word transfers:
HSIZE = 3'b010
Other transfer sizes are not accepted as valid transactions.
At present, unsupported transfer sizes are ignored rather than reported as an AHB error.
This behavior may be changed in a future version if explicit error reporting is required.
5.2 Valid AHB Transfer Conditions
A transfer is considered valid only when all the following conditions are satisfied:
HSEL_FLASH = 1
HREADY     = 1
HTRANS     = NONSEQ or SEQ
HSIZE      = 3'b010
The accepted transfer types are:
HTRANS	Meaning	Accepted
2'b00	IDLE	No
2'b01	BUSY	No
2'b10	NONSEQ	Yes
2'b11	SEQ	Yes


5.3 Single-Transfer Operation
The current controller is designed to process individual AHB-Lite transactions.
Although HBURST is present in the top-level interface, burst handling is not currently implemented.
Therefore:
- HBURST is currently unused.
- Burst length tracking is not implemented.
- Burst boundary checking is not implemented.
- Each accepted transfer is handled independently.
5.4 Address and Control Capture
The controller captures the address and write direction when capture_en is asserted.
HADDR  → addr_reg
HWRITE → hwrite_reg
The Control FSM uses the registered values:
addr_reg
hwrite_reg
instead of directly using the live HADDR and HWRITE signals.
This ensures that the controller operates on stable transaction information during the internal Flash operation.
6. Address Decoding
The Address Decoder receives:
addr_reg[31:0]
It generates the following signals:
Signal	Description
addr_valid	Indicates whether the address belongs to a supported region
local_addr	Address translated into the Flash controller's local address space
flash_region	Indicates a normal Flash data region
erase_region_select	Indicates the erase-control region


The exact address ranges are defined in the Address Decoder RTL.
Invalid addresses are detected by the Address Decoder and handled by the Control FSM.
7. Supported Operations
7.1 Flash Read
A Flash read transaction is identified by:
valid_transfer = 1
flash_region   = 1
hwrite_reg     = 0
The read operation follows this sequence:
IDLE
  |
  v
READ_START
  |
  v
READ_WAIT
  |
  v
IDLE
During a read operation:
- FLASH_CS is asserted.
- FLASH_RD_EN is asserted during READ_START.
- The controller waits for FLASH_DONE.
- FLASH_RDATA is captured into the Read Data Register.
- The captured data is returned through HRDATA.
- HREADYOUT is asserted when the transaction completes.
7.2 Flash Program
A Flash program transaction is identified by:
valid_transfer = 1
flash_region   = 1
hwrite_reg     = 1
The program operation follows this sequence:
IDLE
  |
  v
PROGRAM_DATA
  |
  v
PROGRAM_START
  |
  v
PROGRAM_WAIT
  |
  v
IDLE
During a program operation:
- HWDATA is captured into the Write Data Register.
- The stored write data is supplied to the Flash Interface.
- FLASH_CS is asserted.
- FLASH_PROG_EN is asserted.
- The controller waits for FLASH_DONE.
- A Flash error causes a transition to ERROR_STATE.
7.3 Flash Erase
An erase operation is initiated by a write transaction targeting the erase region:
valid_transfer      = 1
erase_region_select = 1
hwrite_reg          = 1
The erase operation follows this sequence:
IDLE
  |
  v
ERASE_START
  |
  v
ERASE_WAIT
  |
  v
IDLE
During an erase operation:
- FLASH_CS is asserted.
- FLASH_ERASE_EN is asserted.
- The controller waits for FLASH_DONE.
- A Flash error causes a transition to ERROR_STATE.
7.4 Invalid Operations
The following conditions are treated as errors by the Control FSM:
- Access to an invalid address.
- A read operation targeting the erase region.
- A Flash error during a read, program, or erase operation.
The FSM enters:
ERROR_STATE
and asserts:
HRESP = 1'b1
The controller then returns to IDLE.
8. Control FSM
The controller uses the following states:
State	Description
IDLE	Waits for a valid AHB-Lite transaction
READ_START	Starts a Flash read
READ_WAIT	Waits for Flash read completion
PROGRAM_DATA	Captures or prepares program data
PROGRAM_START	Starts a Flash program operation
PROGRAM_WAIT	Waits for program completion
ERASE_START	Starts a Flash erase operation
ERASE_WAIT	Waits for erase completion
ERROR_STATE	Handles an invalid operation or Flash error


FSM Outputs
The Control FSM generates:
FLASH_CS
FLASH_RD_EN
FLASH_PROG_EN
FLASH_ERASE_EN
read_active
wd_capture_en
HREADYOUT
HRESP
9. Flash Interface
The Flash Interface connects the controller logic to the external NVM/Flash memory IP.
Controller-to-Flash Signals
Signal	Width	Description
FLASH_ADDR	32 bits	Flash address
FLASH_WDATA	32 bits	Flash write data
FLASH_CS	1 bit	Flash chip select
FLASH_RD_EN	1 bit	Flash read enable
FLASH_PROG_EN	1 bit	Flash program enable
FLASH_ERASE_EN	1 bit	Flash erase enable


Flash-to-Controller Signals
Signal	Width	Description
FLASH_RDATA	32 bits	Read data from Flash
FLASH_BUSY	1 bit	Indicates that the Flash is busy
FLASH_DONE	1 bit	Indicates operation completion
FLASH_ERROR	1 bit	Indicates an operation error


10. Flash IP Assumptions
10.1 FLASH_DONE
The controller uses FLASH_DONE to determine when a Flash operation has completed.
For a successful operation, the expected Flash response is:
FLASH_DONE  = 1'b1
FLASH_ERROR = 1'b0
When FLASH_DONE is detected, the FSM returns to IDLE.
10.2 FLASH_ERROR
The controller uses FLASH_ERROR to detect a Flash operation failure.
When:
FLASH_ERROR = 1'b1
the FSM transitions to:
ERROR_STATE
The current FSM checks FLASH_ERROR before FLASH_DONE.
Therefore, if both signals are asserted simultaneously:
FLASH_DONE  = 1'b1
FLASH_ERROR = 1'b1
the error condition takes priority.
10.3 FLASH_BUSY Is Currently Not Used
The FLASH_BUSY signal is present in the Flash interface and is passed to the controller interface.
However, the current Control FSM does not use FLASH_BUSY in its state-transition logic.
The FSM currently waits for:
FLASH_DONE
or detects:
FLASH_ERROR
Therefore:
- FLASH_BUSY does not directly control the FSM.
- No state transition currently depends on FLASH_BUSY.
- The controller does not independently stall based on FLASH_BUSY.
- Busy-state filtering is not implemented in the current RTL.
- The signal is retained for future enhancement and interface compatibility.
Future versions may use FLASH_BUSY to explicitly monitor Flash operation progress.
10.4 Flash IP Simulation Model
A black-box declaration only defines the ports of the Flash IP. It does not automatically provide functional behavior during simulation.
For complete simulation, the Flash IP must provide either:
1. A functional simulation model, or
2. A behavioral Flash model or testbench stub.
The simulation model should generate appropriate values for:
FLASH_RDATA
FLASH_BUSY
FLASH_DONE
FLASH_ERROR
Without a valid Flash behavioral model, the controller may remain in a wait state or may not complete the transaction as expected.
11. Reset Assumptions
The controller uses a common active-low reset:
reset_n
The reset is applied to the sequential blocks, including:
- Address/Control Register
- Write Data Register
- Read Data Register
- Control FSM
After reset, the Control FSM enters:
IDLE
The address/control registers and data registers are reset to zero.
12. AHB Response Convention
The controller uses a one-bit HRESP signal.
HRESP	Meaning
1'b0	OKAY
1'b1	ERROR


The current design does not use a two-bit response field.
The response signal is returned through the AHB interconnect to the RISC-V processor system.
13. Verification
The RTL is verified using simulation and waveform analysis.
The testbench includes scenarios for:
- Reset behavior
- Flash read
- Flash program
- Flash erase
- Flash error response
- Invalid address
- Invalid operation
- Unsupported transfer size
- Invalid HTRANS
- HSEL_FLASH deassertion
- AHB transaction acceptance and completion
- FSM state transitions
- Flash control signal generation
- Read and write data register operation
Verification Note
Complete end-to-end verification depends on the availability of a valid Flash behavioral model or functional Flash IP simulation model.
The current RTL verification focuses on:
- Transaction decoding
- Address decoding
- FSM behavior
- Read and write data register operation
- Flash interface control logic
- AHB response generation
14. Project Directory
ahb-lite-nvm-flash-controller/
│
├── rtl/
│   ├── nvm_controller_top.v
│   ├── nvm_transaction_decoder.v
│   ├── nvm_address_control_reg.v
│   ├── nvm_address_decoder.v
│   ├── nvm_control_fsm.v
│   ├── nvm_write_data_reg.v
│   ├── nvm_read_data_reg.v
│   └── nvm_flash_interface.v
│
├── tb/
│   └── nvm_controller_top_tb.v
│
├── docs/
│   └── nvm_microarchitecture.png
│
├── simulation/
│   ├── nvm_verification.wcfg
│   └── waveform_screenshots/
│
├── README.md
└── .gitignore
15. Tools Used
- Verilog HDL
- Xilinx Vivado
- RTL simulation
- Waveform analysis
- AHB-Lite protocol concepts
- FSM-based digital design
- Memory-mapped peripheral design
16. Current Project Status
The project includes:
- Modular Verilog RTL
- AHB-Lite transaction decoding
- Address and control capture
- Flash-region and erase-region decoding
- FSM-based read, program, and erase control
- Read and write data registers
- Flash interface logic
- RTL simulation testbench
- Microarchitecture documentation
The external Flash IP is currently treated as a black-box/interface-level component.
Future Improvements
- Integrate a functional Flash simulation model.
- Use FLASH_BUSY in the Control FSM.
- Add explicit AHB error handling for unsupported transfer sizes.
- Implement burst transaction support.
- Improve protocol-level verification.
- Integrate the controller into the complete RISC-V SoC.