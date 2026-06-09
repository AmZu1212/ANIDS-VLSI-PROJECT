# ANIDS Verilog Testbenches

This document describes the SystemVerilog testbenches used to verify the ANIDS RTL design. The focus here is the RTL unit and integration verification under `ANIDS/tb` and the additional RTL verification benches under `Verification`. The C++ model comparison environment under `ANIDS Model` is intentionally not documented here, since it is a separate flow.

The testbenches are mostly self-checking. They drive known input values into the DUT, compare the DUT output against an expected value, and terminate with `$error` or `$fatal` if a mismatch is detected. Most benches also dump a VCD waveform so the internal behavior can be inspected if a failure occurs.

## Testbench Summary

| Testbench | Category | Main DUT | Main Purpose |
| --- | --- | --- | --- |
| `ANIDS/tb/unit/relu_unit_tb.sv` | Unit | `relu_unit` | Checks ReLU clamp, ready gating, reset, and hold behavior. |
| `ANIDS/tb/unit/memory_mapper_tb.sv` | Unit | `memory_mapper` | Sweeps signed 8-bit values and verifies LUT address mapping. |
| `ANIDS/tb/unit/input_layer_tb.sv` | Unit | `input_layer` | Checks 2-bit feature-pair extraction from a 128-bit vector. |
| `ANIDS/tb/unit/mem_fetch_unit_tb.sv` | Unit | `mem_fetch_unit` | Verifies DMA fetch/valid handshake and feature-vector capture. |
| `ANIDS/tb/unit/hidden_layer_unit_tb.sv` | Unit | `hidden_layer_unit` | Checks one hidden neuron MAC path, bias, ready timing, and saturation. |
| `ANIDS/tb/unit/output_layer_processing_unit_tb.sv` | Unit | `output_layer_processing_unit` | Checks one output neuron MAC path, bias, ready timing, and saturation. |
| `ANIDS/tb/unit/outlier_detector_tb.sv` | Unit | `outlier_detector` | Verifies threshold comparison and single-cycle outlier pulses. |
| `ANIDS/tb/unit/result_status_encoder_tb.sv` | Unit | `result_status_encoder` | Checks status encoding into `RESULT_REG` style values. |
| `ANIDS/tb/integration/apb_rw_tb.sv` | Integration | `anids_top` | Checks APB write/read access through the top-level register interface. |
| `ANIDS/tb/integration/hidden_layer_tb.sv` | Integration | `hidden_layer` + `regfile` | Verifies all-neuron hidden layer behavior with APB-programmed weights. |
| `ANIDS/tb/integration/output_layer_tb.sv` | Integration | `output_layer` + `regfile` | Verifies all-neuron output layer behavior with APB-programmed weights. |
| `ANIDS/tb/integration/lut_ram_tb.sv` | Integration | `spram8x256_cb` | Writes and reads every LUT RAM address. |
| `ANIDS/tb/integration/lookup_layer_tb.sv` | Integration | `lookup_layer` | Checks LUT programming, result mapping, ready timing, and ping-pong buffering. |
| `ANIDS/tb/integration/loss_function_tb.sv` | Integration | `loss_function` | Checks accumulated loss calculation over feature/function pairs. |
| `ANIDS/tb/integration/pipeline_manager_tb.sv` | Integration | `pipeline_manager` + `mem_fetch_unit` | Verifies pipeline stage enable sequencing and vector alignment. |
| `ANIDS/tb/pipeline_timing_tb.sv` | System | `anids_top` | Measures first-result end-to-end pipeline fill timing. |
| `ANIDS/tb/two_vector_test_tb.sv` | System | `anids_top` | Measures result-to-result spacing with two streamed vectors. |
| `Verification/zero_order/zero_order_tb.sv` | System | `anids_top` | Manual zero-order end-to-end status and timing smoke test. |
| `Verification/zero_order/zero_order_loss_compare_tb.sv` | Comparison | `anids_top` | Emits RTL loss/outlier values for zero-order Python comparison. |
| `Verification/zero_order/weighted_loss_compare_tb.sv` | Comparison | `anids_top` | Emits RTL loss/outlier values for generated weighted Python comparison. |
| `Verification/numeric_checks/tb/hidden_stage_tb.sv` | Numeric | `hidden_layer` | Runs generated hidden-layer cases and prints RTL outputs. |
| `Verification/numeric_checks/tb/output_stage_tb.sv` | Numeric | `output_layer` | Runs generated output-layer cases and prints RTL outputs. |
| `Verification/numeric_checks/tb/loss_stage_tb.sv` | Numeric | `loss_function` | Runs generated loss-stage cases and prints RTL loss values. |
| `Verification/numeric_checks/tb/core_stage_tb.sv` | Numeric | `anids_top` | Runs generated full-core cases and prints final RTL loss/outlier. |
| `Verification/numeric_checks/tb/dense_core_stress_tb.sv` | Numeric/System | `anids_top` | Runs one dense full-core stress case with timeout protection. |

## Unit Testbenches

### `relu_unit_tb.sv`

Path: `ANIDS/tb/unit/relu_unit_tb.sv`

This testbench verifies the smallest activation block in the design, the `relu_unit`. The unit receives a signed input and produces an unsigned/non-negative output. The behavior under test is simple but important: when the input is positive, the output should pass the value through; when the input is negative, the output should clamp to zero.

The testbench also checks the control behavior around `resetN` and `ready`. During reset, the output is forced to zero. When `ready` is low, the unit should hold its previous output rather than accepting the new input value. When `ready` is high, the unit evaluates the current input value and updates the output.

The tested cases include positive values, zero, `-1`, a larger negative value, the maximum positive 8-bit value, and cases where `ready` is intentionally held low. This gives coverage for the main activation behavior as well as the enable/hold behavior around it.

### `memory_mapper_tb.sv`

Path: `ANIDS/tb/unit/memory_mapper_tb.sv`

This testbench verifies the `memory_mapper` block, which converts a signed result value into an unsigned LUT address. This block is used before the lookup layer so signed neural output values can index the programmed lookup table.

The testbench performs a full sweep over the signed 8-bit input range from `-128` to `127`. For each value, it computes the expected mapped address in the testbench and compares it to the DUT output. The expected mapping flips the sign bit and keeps the remaining value bits, which converts the signed ordering into the address space used by the LUT.

This is a combinational testbench. It does not require a clock because the output should change directly in response to `in_value`. The full-range sweep is useful because it catches edge-case mapping errors at both ends of the signed range, especially around `-128`, `-1`, `0`, and `127`.

### `input_layer_tb.sv`

Path: `ANIDS/tb/unit/input_layer_tb.sv`

This testbench verifies the `input_layer`, which selects the current 2-bit feature pair from a 128-bit input vector. The ANIDS datapath processes the input vector in pairs of bits, and the pipeline counter determines which pair is active in the current cycle.

The bench drives a fixed 128-bit pattern and checks several counter positions. It verifies that counter `0` selects bits `[1:0]`, counter `1` selects bits `[3:2]`, counter `2` selects bits `[5:4]`, and counter `63` selects the final pair at bits `[127:126]`. This confirms that the low-to-high bit ordering used by the input layer matches the expected pipeline ordering.

It also checks reset and enable behavior. During reset, the output pair is zero. When `enable` is low, the output is also zero, even if the input vector contains nonzero data. After activity, dropping `enable` clears the current feature output back to zero.

### `mem_fetch_unit_tb.sv`

Path: `ANIDS/tb/unit/mem_fetch_unit_tb.sv`

This testbench verifies the `mem_fetch_unit`, which handles the local fetch handshake for incoming DMA vector data. The block receives a `fetch` request from the pipeline manager, waits until the external side presents a valid 128-bit vector, captures that vector, and asserts `updated` when the new feature vector is available.

The test starts by checking reset behavior and idle behavior. It then drives a fetch request with no valid data yet, verifying that the unit enters a pending state and asserts `ready`. While pending, changes on `mem_data` should not update the output until `valid` is asserted. Once `valid` arrives, the DUT latches the vector into `features_out`, asserts `updated`, and returns to idle.

The bench then repeats the sequence with a second vector to confirm that multiple fetches work correctly and that the old feature vector is held until a new valid transaction completes. This verifies both sides of the handshake: the request side from the pipeline and the valid-data side from DMA.

### `hidden_layer_unit_tb.sv`

Path: `ANIDS/tb/unit/hidden_layer_unit_tb.sv`

This testbench verifies one `hidden_layer_unit`, meaning one hidden-layer neuron datapath. The block receives a 2-bit feature pair, two signed weights, a signed bias, the active counter value, and `N`. It accumulates weighted contributions over the input vector and produces one signed hidden result when the final pair has been processed.

The first directed case checks a short `N = 4` operation, which corresponds to two feature-pair cycles. The testbench programs simple Q0.7 values and verifies that the unit accumulates the two pair contributions, truncates the accumulator correctly, adds bias, and asserts `ready` only on the final cycle.

The test also checks the pulse behavior of `ready`: after the output is produced, disabling the unit should drop `ready` while the registered result remains held. Finally, it runs full-length `N = 128` cases that intentionally overflow the positive and negative ranges. These cases verify that the result saturates at `+127` and `-128` instead of wrapping.

### `output_layer_processing_unit_tb.sv`

Path: `ANIDS/tb/unit/output_layer_processing_unit_tb.sv`

This testbench verifies one output-layer neuron datapath, `output_layer_processing_unit`. This block consumes hidden-layer results one at a time, multiplies each by its corresponding signed output weight, accumulates the result, applies bias, and produces a signed output-layer result.

The basic math test uses a short `N = 4` case so the output is generated after two cycles. It checks that a first multiply-accumulate contribution is stored internally, that no final result is produced before the final cycle, and that the result and accumulator are correct at completion.

Additional sections cover one-cycle completion for very small `N`, disable behavior, accumulator reset after re-enable, and both positive and negative saturation. The positive saturation case uses maximum positive hidden values, weights, and bias over a full 64-cycle output stage. The negative saturation case uses negative input values with positive weights and negative bias. Together, these tests verify arithmetic, control, ready timing, accumulator cleanup, and saturation.

### `outlier_detector_tb.sv`

Path: `ANIDS/tb/unit/outlier_detector_tb.sv`

This testbench verifies the final thresholding block, `outlier_detector`. The block compares the computed loss value against a threshold and generates an `outlier_pulse` when the loss is greater than the threshold. It also generates `output_ready` when a valid comparison has been made.

The testbench checks that reset clears both outputs and that `ready = 0` blocks evaluation. It then verifies three important comparison cases: below threshold, exactly equal to threshold, and above threshold. Equal-to-threshold is expected to be non-anomalous because the outlier condition is strictly greater than the threshold.

The bench also includes signed negative comparison cases. These are important because the data and threshold buses use signed Q0.7-style values in parts of the design. The final checks confirm that `outlier_pulse` and `output_ready` are single-cycle outputs and drop when `ready` goes low.

### `result_status_encoder_tb.sv`

Path: `ANIDS/tb/unit/result_status_encoder_tb.sv`

This testbench verifies `result_status_encoder`, the block that converts core control events into software-visible result register values. The status values used by the bench are:

| Status | Value | Meaning |
| --- | --- | --- |
| `STATUS_NOT_ANOMALY` | `0` | Final result is non-anomalous. |
| `STATUS_ANOMALY` | `1` | Final result is anomalous. |
| `STATUS_WAITING` | `2` | Core is running and waiting for a terminal result. |
| `STATUS_IDLE` | `3` | Core is stopped or idle. |

The bench verifies that reset disables writes, that the first active cycle writes idle status, and that each status transition creates a one-cycle write pulse. It then asserts `start` and checks that the block writes the waiting status. When `done` arrives with `outlier_pulse = 1`, the encoder writes anomaly status. When `done` arrives without an outlier pulse, it writes non-anomaly status.

A key part of this test is the result hold behavior. After a terminal result, the status remains visible for several cycles so software polling the APB register has time to observe it. After the hold window, the encoder returns to waiting if `start` is still asserted. Dropping `start` returns the status to idle.

## Integration Testbenches

### `apb_rw_tb.sv`

Path: `ANIDS/tb/integration/apb_rw_tb.sv`

This integration testbench instantiates the full `anids_top` and verifies basic APB register access. It connects the APB interface, system clock/reset, result interrupt, and DMA pins, but the main behavior under test is register read/write correctness.

The test writes each register address from `0` to `` `REG_COUNT - 1`` with its own index value. After the write phase, it reads every register back through the APB interface and checks that the returned value matches the value that was written.

This test is important because most of the design is configured through the APB register file: start control, `N`, threshold, hidden weights, hidden biases, output weights, output biases, and LUT programming registers. If the APB register path is broken, the rest of the programmed tests cannot be trusted.

### `hidden_layer_tb.sv`

Path: `ANIDS/tb/integration/hidden_layer_tb.sv`

This testbench verifies the integrated `hidden_layer`, which contains 64 hidden-layer neuron units operating in parallel and reading weights/biases from the register file. Unlike the unit test, this bench checks the address indexing and neuron-to-register mapping used by the complete hidden layer.

The bench instantiates both `regfile` and `hidden_layer`. It programs selected hidden weights and biases using APB write tasks, then enables the layer and drives feature pairs over several counter cycles. The first section checks basic math and feature gating. For example, one neuron is programmed so both feature bits contribute, another is programmed so only one feature bit should contribute, and another is bias-only.

The weight indexing section uses later feature-pair positions to confirm that each neuron reads the correct entries from the hidden-weight region. This catches bugs where the counter, neuron index, or base address calculation might be off. The final section verifies ready and hold behavior after the layer completes.

### `output_layer_tb.sv`

Path: `ANIDS/tb/integration/output_layer_tb.sv`

This testbench verifies the integrated `output_layer`, which contains 128 output neurons operating in parallel. The layer reads output weights and biases from the register file and consumes the 64 hidden-layer results.

The bench instantiates `regfile` and `output_layer`, programs selected output weights/biases through APB, and drives controlled hidden-result values. The math section checks that an output neuron accumulates the correct hidden-result contributions and applies bias. It also checks that different output neurons use independent weight blocks, so one neuron's programmed weights do not affect another neuron.

The weight selection section programs only late hidden-index slots for selected neurons, then steps the counter from zero to the final index. This verifies that the output layer uses the current counter to select the correct hidden input and the correct weight address. The final checks confirm that `ready` drops after completion while the last result remains stable.

### `lut_ram_tb.sv`

Path: `ANIDS/tb/integration/lut_ram_tb.sv`

This testbench verifies the single-port LUT RAM macro wrapper `spram8x256_cb`. The LUT is used by the lookup layer to map signed output-layer values into programmed function values.

The bench writes every address in the RAM with a simple data pattern equal to the address value truncated to the data width. After the write phase, it reads every address back and compares the RAM output to the expected value.

This is a full address-space memory test. It verifies chip select, write enable, output enable assumptions, address decode, and data retention for all `256` LUT entries.

### `lookup_layer_tb.sv`

Path: `ANIDS/tb/integration/lookup_layer_tb.sv`

This testbench verifies the `lookup_layer`, which maps output-layer results through the programmed LUT and stores looked-up function values for the loss stage. It checks both the LUT write path and the pipeline buffering behavior between lookup and loss.

The test first programs several LUT entries corresponding to mapped addresses for signed values such as `-128`, `0`, `127`, `-1`, `1`, `-64`, `32`, and `-32`. It also rewrites the zero entry to prove that later writes override earlier values.

The first lookup sequence fills one internal bank while `loss_enable` is inactive. The bench confirms that the loss output lanes remain hidden while the lookup side is still filling the bank, and that `lookup_ready` pulses only after the bank has been captured. It then enables the loss side and reads the stored bank values back by pair.

The second sequence overlaps lookup and loss activity. While the loss side reads the previous bank, the lookup side fills the next bank. This verifies the ping-pong buffering scheme and confirms that the read bank and write bank are kept separate in steady-state operation.

### `loss_function_tb.sv`

Path: `ANIDS/tb/integration/loss_function_tb.sv`

This testbench verifies the `loss_function` block, which compares the original input feature pair against the lookup-layer function outputs and accumulates an absolute-error style loss value over the vector.

The testbench includes a small behavioral model inside the bench. For each pair, it computes:

```text
abs(x0 - function_0) + abs(x1 - function_1)
```

It then accumulates this value and compares the DUT result after truncation. The single-pair test checks the shortest valid operation. The two-pair test verifies accumulation over multiple cycles. The signed-values test checks sign extension and negative function values. The disable test confirms that disabling the block clears an in-progress accumulation and that the next run starts cleanly.

This bench is important because the loss stage is the last numeric stage before thresholding. Errors here directly affect anomaly decisions.

### `pipeline_manager_tb.sv`

Path: `ANIDS/tb/integration/pipeline_manager_tb.sv`

This testbench verifies the `pipeline_manager` together with a real `mem_fetch_unit`. The pipeline manager is responsible for sequencing the major processing stages and aligning the current input vector with the delayed validation vector used by the loss stage.

The bench starts with reset and idle checks, then asserts `start` and supplies DMA vectors through the memory fetch unit. As each new epoch begins, the expected stage enables are checked:

| Epoch | Expected Active Stages |
| --- | --- |
| First epoch | Hidden stage only. |
| Second epoch | Hidden and output stages. |
| Third epoch | Hidden, output, and lookup stages. |
| Fourth epoch | Hidden, output, lookup, and loss stages. |
| Steady state | All four pipeline stages active. |

The test also checks `next_vector` and `validate_vector`. `next_vector` should hold the most recently fetched vector for the hidden stage, while `validate_vector` should lag behind so the loss stage compares against the correct original input. Finally, dropping `start` should return the pipeline manager to idle, clear stage enables, clear vectors, and reset the counter.

## Top-Level System And Timing Testbenches

### `pipeline_timing_tb.sv`

Path: `ANIDS/tb/pipeline_timing_tb.sv`

This testbench is an end-to-end timing probe for the full `anids_top`. It programs a simple zero-order model through APB, sends one all-zero DMA vector, starts the core, and records the cycle numbers of important internal events.

The measured events include:

| Event | Meaning |
| --- | --- |
| `start_core` | Core start command is accepted. |
| `fetch_next_vector` | Pipeline requests the first input vector. |
| `mfu_updated` | Memory fetch unit has captured the DMA vector. |
| `hidden_layer_enable` | Hidden stage begins processing. |
| `output_layer_enable` | Output stage begins processing. |
| `lookup_layer_enable` | Lookup stage begins processing. |
| `loss_layer_enable` | Loss stage begins processing. |
| `loss_ready` | Loss result becomes valid. |
| `core_done` | Core signals completion. |
| `status_wr_en` | Result status write is generated. |
| `RESULT_REG update` | Software-visible result register updates. |

After capturing the timestamps, the bench prints cycle differences between consecutive stages and the total `start -> RESULT_REG` latency. It also checks that the final result register contains `STATUS_NOT_ANOMALY` for the programmed all-zero case.

This is the testbench used to justify the pipeline fill latency. It is not mainly a functional random test; it is a controlled timing measurement bench.

### `two_vector_test_tb.sv`

Path: `ANIDS/tb/two_vector_test_tb.sv`

This top-level testbench verifies steady-state result spacing using two DMA vectors. Like the timing probe, it programs a simple zero-order model through APB and sends all-zero vectors. The difference is that this bench sends two vectors and records both completion events.

The bench captures:

| Captured Value | Meaning |
| --- | --- |
| `start_cycle` | Cycle when the core starts. |
| `first_done_cycle` | Cycle of the first `done` pulse. |
| `second_done_cycle` | Cycle of the second `done` pulse. |
| `first_result_cycle` | Cycle of the first terminal `RESULT_REG` update. |
| `second_result_cycle` | Cycle of the second terminal `RESULT_REG` update. |

The important output is the gap between the two done events and the gap between the two result-register updates. For the full `N = 128` case, this is the result-to-result pipeline interval. After the two results are observed, the bench writes `START_REG = 0` and confirms that the status returns to idle.

## Verification Folder RTL Benches

The benches in `Verification` are part of the older and Python-driven RTL verification flows. They are still Verilog/SystemVerilog benches, but their main role is often to emit RTL results in a machine-readable format so Python scripts can compare them against a reference model.

### `zero_order_tb.sv`

Path: `Verification/zero_order/zero_order_tb.sv`

This is a manual end-to-end system bench for a zero-order configuration of the full `anids_top`. In this configuration, hidden and output weights/biases remain at their reset default of zero, and only the LUT entry corresponding to zero is programmed. This makes the expected behavior simple and easy to reason about.

The bench runs multiple sections. First, it sends an all-zero vector and checks that the final status is non-anomalous. Second, it sends an all-ones vector with a different threshold/LUT setup and checks that the final status becomes anomalous. These cases verify APB programming, DMA input, start/stop control, status polling, and final anomaly reporting.

The bench also includes timing analysis sections. One section records the first-result path through the pipeline, similar to `pipeline_timing_tb`. Another sends enough vectors to observe multiple terminal events and prints the steady-state gap between results and `core_done` events. This makes the bench both a functional smoke test and a timing-observation tool.

### `zero_order_loss_compare_tb.sv`

Path: `Verification/zero_order/zero_order_loss_compare_tb.sv`

This testbench is used by the Python zero-order comparison flow. It instantiates `anids_top`, programs the same simple zero-order cases, sends one DMA vector, waits for terminal status, and prints a structured line containing the RTL loss, outlier bit, and result status.

The two cases are:

| Case | Input Data | Programming Intent |
| --- | --- | --- |
| `zero_case` | All-zero vector | Expected non-anomalous zero-order behavior. |
| `ones_case` | All-ones vector | Expected anomalous zero-order behavior. |

Unlike the self-checking unit tests, this bench mainly reports RTL values. The pass/fail decision is performed by the Python script that parses the `RTL_COMPARE` output and compares it against the reference model.

### `weighted_loss_compare_tb.sv`

Path: `Verification/zero_order/weighted_loss_compare_tb.sv`

This testbench is used by the Python weighted comparison flow. It runs the full `anids_top` with generated program files that configure nonzero hidden weights, output weights, biases, LUT data, threshold, and `N`.

The bench runs two generated cases:

| Case | Program File | Vector File |
| --- | --- | --- |
| `dense_weighted_case` | `Verification/zero_order/generated/dense_weighted_case.prog` | `Verification/zero_order/generated/dense_weighted_case.data` |
| `sparse_weighted_case` | `Verification/zero_order/generated/sparse_weighted_case.prog` | `Verification/zero_order/generated/sparse_weighted_case.data` |

For each case, the bench resets the top-level design, writes the program file over APB, sends the DMA vector, waits for `core_done`, and prints `RTL_WEIGHTED_COMPARE` with the final loss and outlier bit. The external Python runner compares those values against the reference model.

## Numeric Check RTL Benches

The numeric check benches are generated-case RTL benches. They are designed to run many deterministic cases and print compact RTL result lines. The Python numeric-check scripts then parse those result lines and compare them against expected values generated by the reference model.

### `hidden_stage_tb.sv`

Path: `Verification/numeric_checks/tb/hidden_stage_tb.sv`

This bench verifies the integrated `hidden_layer` across 30 generated cases. For each case, it resets the DUT, loads a generated register program directly into the `regfile_bus`, loads a generated 128-bit input vector, and runs the hidden layer for 64 pair-processing cycles.

After the final cycle, the bench checks that every hidden neuron asserts `ready`. It then prints one line containing all 64 hidden results in byte form:

```text
RTL_HIDDEN case=hidden_xxx data=...
```

The bench itself checks readiness and file validity. The detailed numeric comparison is performed by the Python runner, which compares the printed RTL results against the expected hidden-stage results.

### `output_stage_tb.sv`

Path: `Verification/numeric_checks/tb/output_stage_tb.sv`

This bench verifies the integrated `output_layer` across 30 generated cases. Each case provides a generated output-layer program and a file containing 64 hidden input values. The bench loads the program directly into the register-file bus, drives the hidden inputs, runs the output layer for 64 cycles, and checks that all 128 output neurons assert `ready`.

At the end of each case, it prints all 128 output results in byte form:

```text
RTL_OUTPUT case=output_xxx data=...
```

The purpose is to isolate the output layer numeric behavior from the rest of the pipeline. This makes it easier to debug errors in output weights, bias addition, accumulator truncation, saturation, or neuron indexing without involving the hidden, lookup, loss, or top-level control stages.

### `loss_stage_tb.sv`

Path: `Verification/numeric_checks/tb/loss_stage_tb.sv`

This bench verifies the `loss_function` across 30 generated cases. For each case, it loads a generated input vector and a generated list of 128 lookup/function output values. It then feeds the loss function one feature pair and two function values per cycle for 64 cycles.

After the final cycle, the bench checks that `ready` is asserted and prints the final RTL loss:

```text
RTL_LOSS case=loss_xxx loss=...
```

This test isolates the final loss accumulation stage. It is useful for finding errors in absolute-difference arithmetic, signed interpretation of lookup outputs, accumulation, truncation, and final ready timing.

### `core_stage_tb.sv`

Path: `Verification/numeric_checks/tb/core_stage_tb.sv`

This bench verifies full-core behavior through `anids_top` across 10 generated cases. Each case includes a generated APB program and a generated DMA vector. The bench resets the top-level design, writes the program over APB, starts the core, sends the vector, waits for `core_done`, and prints the final loss and outlier bit.

The printed output format is:

```text
RTL_CORE case=core_xxx loss=... outlier=...
```

This is a full-system numeric check, so it covers APB programming, register-file mapping, DMA input, pipeline sequencing, hidden layer, output layer, lookup layer, loss function, and outlier detection. The Python runner performs the final comparison against expected reference-model values.

### `dense_core_stress_tb.sv`

Path: `Verification/numeric_checks/tb/dense_core_stress_tb.sv`

This bench runs one dense full-core stress case through `anids_top`. The program file is much larger than the smaller generated cases and is intended to exercise a more fully populated model configuration.

The bench resets the design, writes the dense program file over APB, sends the generated vector, starts the core, waits for `core_done`, and prints:

```text
RTL_DENSE_CORE loss=... outlier=...
```

It also includes a cycle timeout guard. If the core does not complete by cycle `120000`, the bench reports a timeout and finishes with an error. This prevents a broken control path from causing the simulation to hang forever.

## Common Verification Patterns

Several patterns repeat across the testbenches:

1. Reset is always applied before meaningful checking begins. This ensures internal state, accumulators, valid flags, and result registers start from a known state.
2. APB write tasks model the normal programming path used by software. Integration and system benches use these tasks to configure registers, weights, biases, threshold, and LUT entries.
3. DMA send tasks wait for `dma_ack` before asserting `dma_valid`. This keeps the testbench aligned with the top-level input handshake.
4. Most benches check one-cycle ready or write pulses explicitly. This is important because many pipeline events are pulse-based rather than level-based.
5. Numeric benches separate RTL execution from reference comparison. The SystemVerilog bench prints deterministic result lines, and Python scripts compare those lines against expected values.

## What The Testbench Suite Covers

The current suite gives coverage at several levels:

| Level | Coverage |
| --- | --- |
| Local unit behavior | ReLU, memory mapping, feature selection, fetch handshake, neuron MAC units, thresholding, status encoding. |
| Layer integration | Hidden layer, output layer, lookup layer, loss function, LUT RAM, and pipeline manager. |
| Top-level control | APB programming, DMA handshake, start/stop behavior, result status updates, and `done` signaling. |
| Timing | First-result pipe fill latency and steady-state result-to-result latency. |
| Numeric regression | Generated hidden, output, loss, full-core, and dense full-core cases compared externally against reference outputs. |

Together, these testbenches verify both the individual datapath blocks and the full ANIDS processing flow. The unit tests make local failures easier to isolate, while the integration and system benches prove that the blocks are connected, programmed, sequenced, and timed correctly in the complete design.
