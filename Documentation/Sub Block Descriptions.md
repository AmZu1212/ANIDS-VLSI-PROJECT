# Block Descriptions

This document describes the ANIDS sub-units used inside the core datapath.

## 2.7.1 Pipeline Manager

**File:** `ANIDS/src/core/pipeline_manager.sv`

**In a nutshell:** Controls the four-stage streaming pipeline, requests DMA vectors through the memory fetch unit, buffers incoming vectors in a small FIFO, and generates the per-stage enable signals and shared counter.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `start` | Input | 1 bit | Starts pipeline operation when high. Clears pipeline/FIFO state when low. |
| `N` | Input | `APB_DATA_WIDTH` = 8 bits | Active vector length. The design normally uses `N = 128`. |
| `mfu_features` | Input | `PIPELINE_VECTOR_WIDTH` = 128 bits | Feature vector returned by the memory fetch unit. |
| `mfu_updated` | Input | 1 bit | Pulse indicating `mfu_features` contains a newly captured DMA vector. |
| `fetch` | Output | 1 bit | Request pulse sent to the memory fetch unit to fetch another vector. |
| `hidden_layer_enable` | Output | 1 bit | Enables the hidden layer for the current pipeline epoch. |
| `output_layer_enable` | Output | 1 bit | Enables the output layer for the current pipeline epoch. |
| `lookup_layer_enable` | Output | 1 bit | Enables the lookup layer for the current pipeline epoch. |
| `loss_layer_enable` | Output | 1 bit | Enables the loss function for the current pipeline epoch. |
| `next_vector` | Output | `PIPELINE_VECTOR_WIDTH` = 128 bits | Vector currently assigned to the hidden layer. |
| `validate_vector` | Output | `PIPELINE_VECTOR_WIDTH` = 128 bits | Original input vector aligned with the loss stage for validation. |
| `counter` | Output | `PIPELINE_COUNTER_WIDTH` = 7 bits | Shared per-stage step counter. For `N = 128`, counts 0 to 63. |

**Operation:** The block keeps a 4-entry FIFO of fetched vectors. When `start` is high and FIFO space exists, it asserts `fetch`. When `mfu_updated` arrives, the returned vector is pushed into the FIFO. The manager then advances vectors through the hidden, output, lookup, and loss stages in `N/2`-cycle epochs.

## 2.7.2 Hidden Layer

**File:** `ANIDS/src/core/hidden_layer.sv`

**In a nutshell:** Instantiates 64 hidden neurons and 64 ReLU units. Each hidden neuron accumulates weighted input-feature contributions and then passes its result through ReLU.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `enable` | Input | 1 bit | Enables hidden-layer processing. |
| `N` | Input | `APB_DATA_WIDTH` = 8 bits | Active vector length. |
| `features` | Input | `HL_FEATURE_PAIR_WIDTH` = 2 bits | Current pair of input feature bits. |
| `counter` | Input | `PIPELINE_COUNTER_WIDTH` = 7 bits | Selects the current input-feature pair and weight addresses. |
| `regfile` | Input | `REG_COUNT` entries x `APB_DATA_WIDTH` = 16584 x 8 bits, signed | Full APB-programmed model register array. Provides hidden weights and biases. |
| `results` | Output | 64 entries x `HL_RESULT_WIDTH` = 64 x 8 bits, signed | ReLU-clamped hidden-layer neuron outputs. |
| `ready` | Output | 64 bits | Per-neuron ready pulses from the hidden neuron units. |

**Operation:** For neuron `i`, weights are read from `HL_WEIGHT_BASE + i*128 + counter*2` and `HL_WEIGHT_BASE + i*128 + counter*2 + 1`. The bias is read from `HL_BIAS_BASE + i`. Each neuron produces one signed Q0.7 result after the last pair step, and the ReLU unit clamps negative values to zero.

## 2.7.3 Hidden Layer Unit

**File:** `ANIDS/src/core/hidden_layer_unit.sv`

**In a nutshell:** Implements one hidden-layer neuron. It gates two weights by the current two input bits, accumulates over the vector, adds bias, saturates, and emits a signed Q0.7 result.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `enable` | Input | 1 bit | Enables accumulation. When low, accumulator is cleared. |
| `N` | Input | `APB_DATA_WIDTH` = 8 bits | Active vector length. |
| `counter` | Input | `PIPELINE_COUNTER_WIDTH` = 7 bits | Current feature-pair index. |
| `features_in` | Input | `HL_FEATURE_PAIR_WIDTH` = 2 bits | Two binary input features for this cycle. |
| `weight_0` | Input | `HL_WEIGHT_WIDTH` = 8 bits, signed | Weight for `features_in[0]`, signed Q0.7. |
| `weight_1` | Input | `HL_WEIGHT_WIDTH` = 8 bits, signed | Weight for `features_in[1]`, signed Q0.7. |
| `bias` | Input | `HL_BIAS_WIDTH` = 8 bits, signed | Neuron bias, signed Q0.7. |
| `result` | Output | `HL_RESULT_WIDTH` = 8 bits, signed | Final saturated neuron result, signed Q0.7. |
| `ready` | Output | 1 bit | Pulses high when `result` is valid. |

**Operation:** The input bits act like mux enables: if a feature bit is `1`, its weight contributes to the sum; if it is `0`, the contribution is zero. The unit accumulates pair sums until `counter == (N >> 1) - 1`, adds the bias, saturates to signed 8-bit range, outputs `result`, pulses `ready`, and clears the accumulator.

## 2.7.4 ReLU Unit

**File:** `ANIDS/src/core/relu_unit.sv`

**In a nutshell:** Clamps negative signed Q0.7 values to zero.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `in_data` | Input | `RELU_WIDTH` = 8 bits, signed | Signed Q0.7 input value. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `ready` | Input | 1 bit | Indicates `in_data` is valid. |
| `out_data` | Output | `RELU_WIDTH` = 8 bits | ReLU output. Negative values become `0`; non-negative values pass through. |

**Operation:** When `ready` is high, the block checks the sign bit. If `in_data` is negative, `out_data` becomes zero. Otherwise, `out_data` equals `in_data`.

## 2.7.5 Output Layer

**File:** `ANIDS/src/core/output_layer.sv`

**In a nutshell:** Instantiates 128 output-layer processing units. Each output neuron consumes the 64 hidden-layer results over 64 cycles and produces one signed Q0.7 output result.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `enable` | Input | 1 bit | Enables output-layer processing. |
| `N` | Input | `APB_DATA_WIDTH` = 8 bits | Active vector length. |
| `hidden_results` | Input | 64 entries x `OL_INPUT_WIDTH` = 64 x 8 bits, signed | Hidden-layer outputs used as input to the output layer. |
| `counter` | Input | `PIPELINE_COUNTER_WIDTH` = 7 bits | Selects the current hidden input and output weight. |
| `regfile` | Input | `REG_COUNT` entries x `APB_DATA_WIDTH` = 16584 x 8 bits, signed | Full APB-programmed model register array. Provides output weights and biases. |
| `results` | Output | 128 entries x `OL_RESULT_WIDTH` = 128 x 8 bits, signed | Output-layer neuron results. |
| `ready` | Output | 128 bits | Per-output-neuron ready pulses. |

**Operation:** For output neuron `i`, the block reads weight `OL_WEIGHT_BASE + i*64 + counter` and bias `OL_BIAS_BASE + i`. Each neuron multiplies one hidden result by one weight per cycle and produces its final output after the last step.

## 2.7.6 Output Layer Processing Unit

**File:** `ANIDS/src/core/output_layer_processing_unit.sv`

**In a nutshell:** Implements one output-layer neuron using signed Q0.7 multiply-accumulate, bias add, saturation, and ready signaling.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `enable` | Input | 1 bit | Enables accumulation. When low, accumulator is cleared. |
| `N` | Input | `APB_DATA_WIDTH` = 8 bits | Active vector length. |
| `counter` | Input | `PIPELINE_COUNTER_WIDTH` = 7 bits | Current hidden-input index. |
| `hidden_in` | Input | `OL_INPUT_WIDTH` = 8 bits, signed | Current hidden-layer result, signed Q0.7. |
| `weight` | Input | `OL_WEIGHT_WIDTH` = 8 bits, signed | Current output-layer weight, signed Q0.7. |
| `bias` | Input | `OL_BIAS_WIDTH` = 8 bits, signed | Output-neuron bias, signed Q0.7. |
| `result` | Output | `OL_RESULT_WIDTH` = 8 bits, signed | Final saturated output-neuron result, signed Q0.7. |
| `ready` | Output | 1 bit | Pulses high when `result` is valid. |

**Operation:** Each cycle, the unit multiplies `hidden_in * weight`, truncates the product back to Q0.7, and accumulates it. At `counter == (N >> 1) - 1`, it truncates the accumulator, adds bias, saturates to signed 8-bit range, outputs `result`, pulses `ready`, and clears the accumulator.

## 2.7.7 Lookup Layer

**File:** `ANIDS/src/core/lookup_layer.sv`

**In a nutshell:** Maps output-layer values into LUT addresses, reads activation-function values from two 256-entry LUT RAMs, and buffers the looked-up pairs for the loss stage.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset for lookup-layer control and pair banks. Does not clear the SRAM LUT contents. |
| `lookup_enable` | Input | 1 bit | Enables LUT address issue and result capture. |
| `loss_enable` | Input | 1 bit | Enables output of buffered function values to the loss function. |
| `N` | Input | `APB_DATA_WIDTH` = 8 bits | Active vector length. |
| `counter` | Input | `PIPELINE_COUNTER_WIDTH` = 7 bits | Current output pair index / loss pair index. |
| `lut_wr_addr` | Input | `LUT_ADDR_WIDTH` = 8 bits | APB-programmed LUT write address. |
| `lut_wr_data` | Input | `LUT_DATA_WIDTH` = 8 bits | APB-programmed LUT write data, interpreted later as signed Q0.7. |
| `lut_wr_en` | Input | 1 bit | Enables LUT write. |
| `result_0` | Input | `LF_RESULT_IN_WIDTH` = 8 bits, signed | First output-layer value in the current pair. |
| `result_1` | Input | `LF_RESULT_IN_WIDTH` = 8 bits, signed | Second output-layer value in the current pair. |
| `function_0` | Output | `LUT_DATA_WIDTH` = 8 bits, signed | First looked-up activation value for the loss stage. |
| `function_1` | Output | `LUT_DATA_WIDTH` = 8 bits, signed | Second looked-up activation value for the loss stage. |
| `lookup_ready` | Output | 1 bit | Pulses when a full lookup sweep has been captured. |

**Operation:** Two `memory_mapper` instances convert signed Q0.7 output results into unsigned LUT addresses. Two LUT RAMs are read in parallel so two activation values are returned per cycle. The lookup layer stores returned pairs in double-buffered pair banks, then serves them to the loss function when `loss_enable` is active. One APB LUT write writes the same address/data to both LUT RAMs.

## 2.7.8 Memory Mapper

**File:** `ANIDS/src/core/memory_mapper.sv`

**In a nutshell:** Converts a signed Q0.7 value into an ascending unsigned LUT address.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `in_value` | Input | `MMAP_IN_WIDTH` = 8 bits, signed | Signed Q0.7 value from the output layer. |
| `lut_addr` | Output | `MMAP_ADDR_WIDTH` = 8 bits | Unsigned LUT address. |

**Operation:** For the 256-entry LUT case, the mapper flips the sign bit and keeps the remaining bits:

```text
lut_addr = {~in_value[7], in_value[6:0]}
```

This maps the most negative Q0.7 code to address `0`, zero to address `128`, and the most positive code to address `255`.

## 2.7.9 Loss Function

**File:** `ANIDS/src/core/loss_function.sv`

**In a nutshell:** Compares the original input vector bits against the reconstructed/activated output values and accumulates an absolute-error loss.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `enable` | Input | 1 bit | Enables loss accumulation. When low, accumulator is cleared. |
| `N` | Input | `APB_DATA_WIDTH` = 8 bits | Active vector length. |
| `counter` | Input | `PIPELINE_COUNTER_WIDTH` = 7 bits | Current feature-pair index. |
| `x_in` | Input | `LF_FEATURE_PAIR_WIDTH` = 2 bits | Original input feature pair aligned with this loss cycle. |
| `function_0` | Input | `LF_RESULT_IN_WIDTH` = 8 bits, signed | First activation/LUT output value, signed Q0.7. |
| `function_1` | Input | `LF_RESULT_IN_WIDTH` = 8 bits, signed | Second activation/LUT output value, signed Q0.7. |
| `result` | Output | `LF_OUT_WIDTH` = 8 bits, signed | Final accumulated loss after truncation. |
| `ready` | Output | 1 bit | Pulses high when `result` is valid. |

**Operation:** Each cycle, the block converts the two original feature bits into signed numeric values (`0` or `1`), subtracts the corresponding LUT outputs, takes absolute values, sums the pair error, and accumulates it. At the last pair, it truncates the accumulator to 8 bits, outputs `result`, pulses `ready`, and clears the accumulator.

## 2.7.10 Outlier Detector

**File:** `ANIDS/src/core/outlier_detector.sv`

**In a nutshell:** Compares the final loss against the programmed threshold and generates a one-cycle outlier decision pulse.

| Pin | Direction | Size | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Core clock. |
| `resetN` | Input | 1 bit | Active-low reset. |
| `ready` | Input | 1 bit | Indicates `data_in` is valid from the loss function. |
| `data_in` | Input | `LF_OUT_WIDTH` = 8 bits, signed | Final loss value. |
| `threshold` | Input | `APB_DATA_WIDTH` = 8 bits, signed | Programmed outlier threshold. |
| `outlier_pulse` | Output | 1 bit | High for one cycle when `data_in > threshold`. |
| `output_ready` | Output | 1 bit | Pulses high when the outlier comparison has completed. |

**Operation:** When `ready` is high, the block compares `data_in` against `threshold`. If the loss is greater than the threshold, `outlier_pulse` is asserted for one clock. `output_ready` marks the comparison as complete.
