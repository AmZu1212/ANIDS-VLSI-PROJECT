# Main Block Descriptions

This document describes the three main non-top-level blocks around the ANIDS datapath.

## Memory Fetch Unit

**File:** `ANIDS/src/mem_fetch_unit.sv`

**In a nutshell:** Bridges the pipeline manager's internal fetch request to the external DMA-style vector interface. It raises ready/ack, captures one 128-bit DMA vector when valid arrives, and pulses updated back to the core.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Clock used by the memory fetch unit. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `fetch` | Input | 1 bit | Internal request from the pipeline manager for a new vector. |
| `valid` | Input | 1 bit | External DMA/source valid signal. Indicates `mem_data` is valid. |
| `mem_data` | Input | `MFU_DATA_WIDTH` = 128 bits | Incoming DMA vector. |
| `ready` | Output | 1 bit | Ready/acknowledge signal back to the DMA/source. Exposed at top level as `dma_ack`. |
| `features_out` | Output | `MFU_FEATURE_WIDTH` = 128 bits | Captured feature vector sent into the core pipeline. |
| `updated` | Output | 1 bit | One-cycle pulse indicating `features_out` has just been updated. |

**Operation:** When `fetch` is asserted, the unit enters a pending state and raises `ready`. While pending, it waits for `valid`. When `valid` is high, it captures `mem_data` into `features_out`, drops `ready`, pulses `updated`, and returns to idle.

## ANIDS Core

**File:** `ANIDS/src/anids_core.sv`

**In a nutshell:** The main datapath block. It connects the programmed regfile contents, fetched vectors, pipeline manager, hidden layer, output layer, lookup layer, loss function, and outlier detector.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low core reset. |
| `regfile` | Input | `REG_COUNT` entries x `APB_DATA_WIDTH` = 16584 x 8 bits, signed | Configuration/model register array from the APB regfile. Contains control registers, threshold, weights, biases, and LUT programming registers. |
| `mfu_features` | Input | `PIPELINE_VECTOR_WIDTH` = 128 bits | Feature vector captured by the memory fetch unit. |
| `mfu_updated` | Input | 1 bit | Pulse from the memory fetch unit indicating a new vector is available. |
| `fetch_next_vector` | Output | 1 bit | Request to the memory fetch unit for another vector. |
| `done` | Output | 1 bit | Internal core completion pulse used by the surrounding top-level/status logic. Not the programmer-facing completion mechanism. |
| `outlier_pulse` | Output | 1 bit | One-cycle raw anomaly decision pulse from the outlier detector. |
| `loss_result` | Output | `LF_OUT_WIDTH` = 8 bits, signed | Final loss value from the loss function. |

**Operation:** The core reads `START_REG`, `N_REG`, `THRESHOLD_REG`, and LUT programming registers from `regfile`. The pipeline manager requests vectors and generates stage enables. The hidden layer produces 64 ReLU-clamped results, the output layer produces 128 reconstructed output values, the lookup layer applies the activation LUT, the loss function accumulates reconstruction error, and the outlier detector compares the loss against the threshold.

## Regfile

**File:** `ANIDS/src/regfile.sv`

**In a nutshell:** Implements the APB-accessible register file that stores control registers, model weights, model biases, LUT programming registers, threshold, and result status.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `pclk` | Input | 1 bit | APB clock. |
| `presetN` | Input | 1 bit | Active-low APB/regfile reset. |
| `psel` | Input | 1 bit | APB select. |
| `pwrite` | Input | 1 bit | APB write enable. `1` for write, `0` for read. |
| `penable` | Input | 1 bit | APB access phase enable. |
| `paddr` | Input | `APB_ADDR_WIDTH` = 16 bits | APB register address. |
| `pwdata` | Input | `APB_DATA_WIDTH` = 8 bits | APB write data. |
| `prdata` | Output | `APB_DATA_WIDTH` = 8 bits | APB read data. |
| `pready` | Output | 1 bit | APB ready response. This slave responds with zero wait states. |
| `hw_wr_en` | Input | 1 bit | Hardware write enable, used for hardware updates such as `RESULT_REG`. |
| `hw_wr_addr` | Input | `APB_ADDR_WIDTH` = 16 bits | Hardware write address. |
| `hw_wr_data` | Input | `APB_DATA_WIDTH` = 8 bits | Hardware write data. |
| `regfile` | Output | `REG_COUNT` entries x `APB_DATA_WIDTH` = 16584 x 8 bits | Full register array exported to the core. |

**Operation:** On reset, every register entry is set to zero. During normal operation, hardware writes have priority over APB writes. APB writes occur when `psel && penable && pwrite` is true. APB reads occur when `psel && penable && !pwrite` is true and return `regfile[paddr]` when the address is in range. `pready` is asserted for active read or write accesses.
