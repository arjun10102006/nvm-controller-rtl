# AHB-Lite NVM/Flash Controller RTL

A Verilog RTL implementation of an **AHB-Lite based Non-Volatile Memory (NVM)/Flash Controller**. The controller receives read, program, and erase requests from an AHB-Lite bus and converts them into control signals for an external NVM/Flash IP.

This project includes the controller architecture, RTL modules, simulation testbench, and verification waveforms.

---

## 1. Project Overview

The NVM controller acts as an interface between an AHB-Lite system bus and an external NVM/Flash memory IP.

The controller performs the following operations:

- Read data from NVM/Flash memory
- Program/write data into NVM/Flash memory
- Erase a selected Flash region
- Decode AHB-Lite transactions
- Validate memory addresses
- Generate Flash control signals
- Capture Flash read data
- Generate AHB-Lite completion and response signals
- Handle Flash operation completion and errors

The external Flash IP is treated as a separate module. The controller communicates with the Flash IP through a dedicated Flash interface.

---

## 2. Project Objectives

The main objectives of this project are:

- Design a modular AHB-Lite slave controller
- Convert AHB-Lite transactions into NVM/Flash operations
- Implement a finite state machine for Flash control
- Support read, program, and erase operations
- Separate address decoding, control, data, and interface logic
- Verify the RTL design using a Verilog testbench
- Analyze signal transitions using simulation waveforms
- Develop a reusable controller structure for SoC integration

---

## 3. High-Level Architecture

The NVM controller consists of the following major RTL blocks:

1. AHB-Lite Transaction Decoder
2. Address and Control Register
3. Address Decoder
4. Control FSM
5. Write Data Register
6. Read Data Register
7. Flash Interface
8. Top-Level Controller Integration

### 3.1 Architecture Overview

The controller receives AHB-Lite transactions from the processor or interconnect and converts them into read, program, and erase operations for the external NVM/Flash IP.

```text
                    AHB-Lite Bus
                         |
                         v
              AHB-Lite Transaction
                     Decoder
                         |
                         v
              Address and Control
                    Register
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
```

### 3.2 Write Data Path

```text
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
```

### 3.3 Read Data Path

```text
FLASH_RDATA
     |
     v
Read Data Register
     |
     v
HRDATA
```

### 3.4 Control Path

The Control FSM generates the control signals required to operate the Flash IP.

```text
Address and Control Information
              |
              v
          Control FSM
              |
      ---------------------
      |        |          |
      v        v          v
   Read     Program     Erase
 Control    Control    Control
      |        |          |
      ---------v----------
              |
              v
        Flash Interface
```

---

## 4. AHB-Lite Interface

The controller is designed as an AHB-Lite slave.

### 4.1 AHB-Lite Input Signals

| Signal | Description |
|--------|-------------|
| `HCLK` | AHB-Lite system clock |
| `reset_n` | Active-low reset |
| `HSEL_FLASH` | Selects the NVM/Flash controller |
| `HREADY` | Indicates that the previous transfer is complete |
| `HTRANS` | Indicates the type of AHB-Lite transfer |
| `HADDR` | Address of the transfer |
| `HWRITE` | Indicates read or write direction |
| `HSIZE` | Indicates the transfer size |
| `HBURST` | Indicates the burst type |
| `HWDATA` | Write data from the AHB-Lite master |

### 4.2 AHB-Lite Output Signals

| Signal | Description |
|--------|-------------|
| `HRDATA` | Read data returned to the AHB-Lite master |
| `HREADYOUT` | Indicates completion of the current transfer |
| `HRESP` | AHB-Lite response signal |

### 4.3 AHB-Lite Response

The controller uses a one-bit `HRESP` signal:

| `HRESP` | Meaning |
|---------|---------|
| `0` | `OKAY` response |
| `1` | `ERROR` response |

---

## 5. Supported Transfer Conditions

A transfer is considered valid when all of the following conditions are satisfied:

- `HSEL_FLASH` is asserted
- `HREADY` is asserted
- `HTRANS` indicates a non-idle transfer
- `HSIZE` indicates a word transfer
- The selected address belongs to a valid controller region

The transaction decoder generates the following internal signals:

| Signal | Description |
|--------|-------------|
| `valid_transfer` | Indicates a valid AHB-Lite transfer |
| `capture_en` | Enables address and control capture |
| `read_req` | Indicates a read request |
| `write_req` | Indicates a write request |

The current design accepts only word-sized transfers.

```verilog
assign valid_transfer = HSEL_FLASH
                     && HREADY
                     && ((HTRANS == 2'b10) || (HTRANS == 2'b11))
                     && (HSIZE == 3'b010);

assign capture_en = valid_transfer;

assign read_req = valid_transfer && !HWRITE;

assign write_req = valid_transfer && HWRITE;
```

Unsupported transfer sizes are currently ignored rather than reported as an AHB-Lite error.

---

## 6. RTL Module Description

### 6.1 AHB-Lite Transaction Decoder

**Module:** `nvm_transaction_decoder.v`

The transaction decoder examines the incoming AHB-Lite control signals and determines whether the current transfer is valid.

It generates:

- `valid_transfer`
- `capture_en`
- `read_req`
- `write_req`

The decoder checks:

- Peripheral select
- Transfer validity
- Transfer size
- Read/write direction

---

### 6.2 Address and Control Register

**Module:** `nvm_address_control_reg.v`

This block stores the address and write direction of a valid AHB-Lite transaction.

The register captures information when `capture_en` is asserted.

Stored information includes:

- `HADDR`
- `HWRITE`

The outputs are:

- `addr_reg`
- `hwrite_reg`

The Control FSM uses the registered values during the Flash operation.

---

### 6.3 Address Decoder

**Module:** `nvm_address_decoder.v`

The address decoder checks the captured address and determines which memory region is selected.

The address decoder generates:

| Signal | Description |
|--------|-------------|
| `addr_valid` | Indicates whether the address is valid |
| `local_addr` | Address used internally by the Flash interface |
| `flash_region` | Indicates a normal Flash region |
| `erase_region_select` | Indicates an erase-controlled region |

The address decoder separates normal Flash access from erase-region access.

---

### 6.4 Control FSM

**Module:** `nvm_control_fsm.v`

The Control FSM manages the complete sequence of Flash operations.

It controls:

- Read operations
- Program operations
- Erase operations
- Flash control signals
- Read-data capture timing
- AHB-Lite transfer completion
- AHB-Lite response generation
- Flash error handling

The FSM uses the registered address and control information rather than relying on live AHB-Lite signals during the operation.

---

## 7. Control FSM States

The controller uses the following FSM states:

| State | Encoding | Description |
|-------|----------|-------------|
| `IDLE` | `4'd0` | Waits for a valid transaction |
| `READ_START` | `4'd1` | Starts a Flash read operation |
| `READ_WAIT` | `4'd2` | Waits for read completion |
| `PROGRAM_DATA` | `4'd3` | Prepares program data |
| `PROGRAM_START` | `4'd4` | Starts a Flash program operation |
| `PROGRAM_WAIT` | `4'd5` | Waits for program completion |
| `ERASE_START` | `4'd6` | Starts a Flash erase operation |
| `ERASE_WAIT` | `4'd7` | Waits for erase completion |
| `ERROR_STATE` | `4'd8` | Handles an operation error |

### 7.1 Read Operation

The read operation follows this sequence:

```text
IDLE
  |
  v
READ_START
  |
  v
READ_WAIT
  |
  +---- FLASH_DONE ----> IDLE
  |
  +---- FLASH_ERROR ---> ERROR_STATE
```

During a successful read:

1. The address is captured.
2. The address is decoded.
3. The FSM starts the Flash read operation.
4. The controller waits for `FLASH_DONE`.
5. `FLASH_RDATA` is captured into the Read Data Register.
6. The data is returned through `HRDATA`.
7. The controller completes the AHB-Lite transfer.

---

### 7.2 Program Operation

The program operation follows this sequence:

```text
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
  +---- FLASH_DONE ----> IDLE
  |
  +---- FLASH_ERROR ---> ERROR_STATE
```

During a program operation:

1. The address and write direction are captured.
2. The write data is captured from `HWDATA`.
3. The Flash address and write data are prepared.
4. The program command is asserted.
5. The controller waits for completion.
6. The controller generates the AHB-Lite response.

---

### 7.3 Erase Operation

The erase operation follows this sequence:

```text
IDLE
  |
  v
ERASE_START
  |
  v
ERASE_WAIT
  |
  +---- FLASH_DONE ----> IDLE
  |
  +---- FLASH_ERROR ---> ERROR_STATE
```

During an erase operation:

1. The address is captured.
2. The address decoder identifies the erase region.
3. The FSM starts the erase operation.
4. The controller waits for Flash completion.
5. The controller checks for Flash errors.
6. The AHB-Lite response is generated.

---

### 7.4 Error Handling

If the Flash IP asserts `FLASH_ERROR`, the FSM moves to `ERROR_STATE`.

The error response is reported through:

```text
HRESP = 1
```

After error handling, the FSM returns to the `IDLE` state.

---

## 8. Write Data Path

The Write Data Register stores the data received from the AHB-Lite master.

```text
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
```

The write data is captured before the Flash program operation begins.

This prevents the controller from depending on the live `HWDATA` bus during a multi-cycle Flash operation.

---

## 9. Read Data Path

The Read Data Register captures data from the Flash IP after a successful read operation.

```text
FLASH_RDATA
     |
     v
Read Data Register
     |
     v
HRDATA
```

Read data is captured when the Flash read operation completes.

The internal read-data capture condition is based on:

- Active read operation
- Flash completion indication

The captured data is then presented to the AHB-Lite master through `HRDATA`.

---

## 10. Flash Interface

**Module:** `nvm_flash_interface.v`

The Flash Interface connects the controller to the external NVM/Flash IP.

### 10.1 Flash Control Signals

| Signal | Description |
|--------|-------------|
| `FLASH_CS` | Selects the Flash IP |
| `FLASH_RD_EN` | Starts a read operation |
| `FLASH_PROG_EN` | Starts a program operation |
| `FLASH_ERASE_EN` | Starts an erase operation |
| `FLASH_ADDR` | Address sent to the Flash IP |
| `FLASH_WDATA` | Write data sent to the Flash IP |
| `FLASH_RDATA` | Read data received from the Flash IP |
| `FLASH_BUSY` | Indicates that the Flash IP is busy |
| `FLASH_DONE` | Indicates that the Flash operation is complete |
| `FLASH_ERROR` | Indicates that the Flash operation failed |

The external Flash IP is considered a separate block and is not implemented as part of this controller.

---

## 11. Reset Design

The controller uses a single active-low reset signal:

```text
reset_n
```

The reset is applied to the sequential RTL blocks, including:

- Address and Control Register
- Write Data Register
- Read Data Register
- Control FSM

When reset is asserted:

- The FSM returns to the `IDLE` state.
- Address registers are cleared.
- Control registers are cleared.
- Write data registers are cleared.
- Read data registers are cleared.
- AHB-Lite response signals return to their inactive values.

---

## 12. Design Assumptions

The current implementation is based on the following assumptions:

1. The controller operates in a single clock domain.
2. The system clock is supplied externally.
3. The controller does not contain a PLL or clock divider.
4. The design uses an active-low reset.
5. The external Flash IP provides operation completion and error indications.
6. The controller accepts word-sized AHB-Lite transfers.
7. The controller processes one AHB-Lite transaction at a time.
8. The external Flash IP is treated as a black-box interface.
9. Flash operation latency is controlled by the external Flash IP.
10. `HBURST` is present in the top-level interface but is not currently used by the controller.
11. `FLASH_BUSY` is available in the interface but is not currently used in the FSM transition logic.
12. Unsupported transfer sizes are currently ignored rather than reported as an AHB-Lite error.

---

## 13. Simulation and Verification

The project includes a Verilog testbench for functional verification.

The testbench checks:

- Reset behavior
- Valid read operation
- Read operation completion
- Read error handling
- Valid program operation
- Program error handling
- Valid erase operation
- Erase error handling
- Invalid address handling
- Read access to the erase region
- Unsupported transfer size
- Unselected controller operation
- Invalid AHB-Lite transfer type
- AHB-Lite response generation
- FSM state transitions
- Flash control signal generation

### 13.1 Verification Flow

```text
Verilog RTL
    |
    v
Testbench
    |
    v
Simulation
    |
    v
Waveform Generation
    |
    v
Signal and FSM Verification
```

### 13.2 Important Waveform Signals

The following signals can be monitored during simulation:

- `HCLK`
- `reset_n`
- `HSEL_FLASH`
- `HREADY`
- `HTRANS`
- `HSIZE`
- `HADDR`
- `HWRITE`
- `HWDATA`
- `valid_transfer`
- `capture_en`
- `read_req`
- `write_req`
- `addr_reg`
- `hwrite_reg`
- `addr_valid`
- `flash_region`
- `erase_region_select`
- `local_addr`
- `current_state`
- `next_state`
- `FLASH_CS`
- `FLASH_RD_EN`
- `FLASH_PROG_EN`
- `FLASH_ERASE_EN`
- `FLASH_ADDR`
- `FLASH_WDATA`
- `FLASH_RDATA`
- `FLASH_BUSY`
- `FLASH_DONE`
- `FLASH_ERROR`
- `HRDATA`
- `HREADYOUT`
- `HRESP`

---

## 14. External Flash IP Simulation

The Flash IP is not included in this repository because it is treated as an external IP block.

For complete simulation, one of the following is required:

- A behavioral Flash model
- A simulation model supplied by the Flash IP provider
- A Verilog stub that drives the Flash response signals
- A testbench model that generates `FLASH_DONE`, `FLASH_ERROR`, and `FLASH_RDATA`

Without a valid Flash model, signals such as the following may remain undriven or unknown:

- `FLASH_DONE`
- `FLASH_ERROR`
- `FLASH_BUSY`
- `FLASH_RDATA`

Therefore, a Flash behavioral model or valid simulation model is required for meaningful end-to-end simulation.

---

## 15. Project Directory Structure

```text
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
│
└── .gitignore
```

---

## 16. Tools Used

The project can be developed and simulated using the following tools:

- Verilog HDL
- Xilinx Vivado
- Icarus Verilog
- GTKWave
- EDA Playground
- Git
- GitHub

The exact simulation tool depends on the development and verification environment.

---

## 17. Current Project Status

### Completed

- AHB-Lite transaction decoder
- Address and control register
- Address decoder
- Control FSM
- Write data register
- Read data register
- Flash interface
- Top-level RTL integration
- Basic read, program, and erase operation flow
- Error-state handling
- Verilog testbench
- Initial waveform verification
- Microarchitecture documentation

### Current Limitations

- The external Flash IP is not included.
- A behavioral Flash model is required for complete simulation.
- `FLASH_BUSY` is currently not used in FSM transition logic.
- `HBURST` is currently unused.
- Unsupported transfer sizes are ignored rather than reported as errors.
- The controller currently processes one transaction at a time.
- Additional protocol checks may be required for complete AHB-Lite compliance.

---

## 18. Possible Future Improvements

Future improvements may include:

- Add a behavioral Flash model for simulation
- Use `FLASH_BUSY` in the FSM
- Add explicit handling for unsupported transfer sizes
- Add more complete AHB-Lite protocol checking
- Support additional transfer sizes
- Support burst transactions
- Add timeout protection for Flash operations
- Add a dedicated status register
- Add detailed error codes
- Improve address-region configurability
- Add assertions for protocol verification
- Add SystemVerilog-based verification
- Add functional coverage
- Integrate the controller with a complete SoC bus system

---

## 19. Author

**Arjun Prabhu S.**

Electronics Engineering — VLSI Design and Technology

Karpagam College of Engineering

---

## 20. License

No license has been added to this repository yet.
