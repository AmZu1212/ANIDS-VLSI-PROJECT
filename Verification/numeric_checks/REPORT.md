# ANIDS Numeric Checks Report

## Scope

This report summarizes the current RTL-vs-reference verification status for the ANIDS design.

It covers:

- the staged numeric-check suite under `Verification/numeric_checks`
- the simple end-to-end comparison flows under `Verification/scripts`
- the current cycle-level timing probe at [ANIDS/tb/pipeline_timing_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/tb/pipeline_timing_tb.sv)

All results below were refreshed from current runs in this repo.

---

## Current Run Status

| Flow | Command | Current Result |
| --- | --- | --- |
| Zero-order comparison | `python Verification/scripts/run_zero_order_comparison.py` | PASS |
| Weighted comparison | `python Verification/scripts/run_weighted_comparison.py` | PASS |
| Numeric checks | `python Verification/numeric_checks/run_numeric_checks.py` | PASS |
| Dense core stress | `python Verification/numeric_checks/run_dense_core_check.py` | PASS |
| Zero-order system bench | `python run.py Verification/zero_order/zero_order_tb.sv` | PASS |
| Pipeline timing probe | `python run.py ANIDS/tb/pipeline_timing_tb.sv` | PASS |

Fresh summary lines:

```text
COMPARE_PASSED
WEIGHTED_COMPARE_PASSED
SUMMARY hidden=30 output=30 loss=30 core=10 total=100
NUMERIC_CHECKS_PASSED
DENSE_CORE_CHECK_PASSED
ZERO_ORDER SYSTEM TB PASSED
PIPELINE_TIMING TB PASSED
```

---

## Numeric-Check Summary

| Category | Test Count | Result |
| --- | ---: | --- |
| Hidden-stage randomized tests | 30 | PASS |
| Output-stage randomized tests | 30 | PASS |
| Loss-stage randomized tests | 30 | PASS |
| Full-core randomized tests | 10 | PASS |
| Total | 100 | PASS |

Primary runner:

```powershell
python Verification/numeric_checks/run_numeric_checks.py
```

---

## What Is Verified

| Block | Verified Behavior |
| --- | --- |
| Hidden layer | 2-bit feature gating, hidden-weight addressing, accumulation, `TRUN8`, bias saturating add, ReLU |
| Output layer | signed `Q0.7 x Q0.7` multiply, product truncation back to `Q0.7`, accumulation, `TRUN8`, bias saturating add |
| Loss function | per-feature delta math, absolute value math, MAE accumulation, final `TRUN8` |
| Full core | stage composition, APB programming, LUT programming path, mapper/LUT interaction, end-to-end loss result, anomaly decision |

Important clarification:

- The standalone loss-stage bench does **not** instantiate `lookup_layer`.
- It feeds precomputed `function_0/function_1` values directly into [`loss_function.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/loss_function.sv).
- So mapper behavior and LUT programming are verified by the **full-core** checks, not by the isolated loss-stage bench.

---

## Detailed Breakdown

### 1. Hidden-Stage Checks

Files:

- [Verification/numeric_checks/numeric_check_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/numeric_check_cases.py)
- [Verification/numeric_checks/tb/hidden_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/hidden_stage_tb.sv)

Case count:

| Item | Value |
| --- | ---: |
| Hidden-stage tests | 30 |

What is randomized per case:

| Input | Randomized Content |
| --- | --- |
| Input vector | full 128-bit feature vector as 64 random 2-bit pairs |
| Active hidden neurons | 6 random neurons out of 64 |
| Hidden weights | 12 random nonzero weights inside each active neuron |
| Hidden biases | 1 random bias per active neuron |

What the testbench does:

1. Resets the DUT.
2. Loads a generated hidden-stage register image directly into the `regfile` bus view.
3. Loads one generated 128-bit input vector.
4. Drives the hidden layer for 64 steps with `counter = 0..63`.
5. Waits for final-cycle `ready` from all 64 hidden neurons.
6. Dumps all 64 hidden outputs as 8-bit values.

What is compared:

- RTL hidden outputs from [`hidden_layer.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/hidden_layer.sv)
- Python golden outputs from `run_hidden_stage(...)`

### 2. Output-Stage Checks

Files:

- [Verification/numeric_checks/numeric_check_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/numeric_check_cases.py)
- [Verification/numeric_checks/tb/output_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/output_stage_tb.sv)

Case count:

| Item | Value |
| --- | ---: |
| Output-stage tests | 30 |

What is randomized per case:

| Input | Randomized Content |
| --- | --- |
| Hidden-result vector | 64 signed `Q0.7` values |
| Active output neurons | 8 random neurons out of 128 |
| Output weights | 10 random nonzero weights inside each active neuron |
| Output biases | 1 random bias per active neuron |

What the testbench does:

1. Resets the DUT.
2. Loads the generated output-stage register image directly into the `regfile` bus view.
3. Loads one generated 64-entry hidden-result bank.
4. Drives the output layer for 64 steps with `counter = 0..63`.
5. Waits for final-cycle `ready` from all 128 output neurons.
6. Dumps all 128 output values as 8-bit signed data.

What is compared:

- RTL output-layer outputs from [`output_layer.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/output_layer.sv)
- Python golden outputs from `run_output_stage(...)`

### 3. Loss-Stage Checks

Files:

- [Verification/numeric_checks/numeric_check_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/numeric_check_cases.py)
- [Verification/numeric_checks/tb/loss_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/loss_stage_tb.sv)

Case count:

| Item | Value |
| --- | ---: |
| Loss-stage tests | 30 |

What is randomized per case:

| Input | Randomized Content |
| --- | --- |
| Original input vector | full 128-bit feature vector |
| Output-result vector | 128 signed `Q0.7` values |
| Derived function results | 128 precomputed signed values after mapper+LUT lookup |

What the testbench does:

1. Resets the DUT.
2. Loads one generated original 128-bit input vector.
3. Loads one generated 128-entry bank of precomputed function outputs.
4. Drives the loss function for 64 steps:
   `counter = 0..63`, `x_in = original_vector[2*counter +: 2]`,
   `function_0 = function_results[2*counter]`,
   `function_1 = function_results[2*counter+1]`.
5. Captures the final `result` when `ready` is asserted.

What is compared:

- RTL loss output from [`loss_function.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/loss_function.sv)
- Python golden output from `loss_result_direct(...)`

What this proves:

- per-feature delta math is correct
- absolute-value logic is correct
- MAE accumulation is correct
- final loss truncation is correct

### 4. Full-Core Checks

Files:

- [Verification/numeric_checks/numeric_check_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/numeric_check_cases.py)
- [Verification/numeric_checks/tb/core_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/core_stage_tb.sv)

Case count:

| Item | Value |
| --- | ---: |
| Full-core tests | 10 |

What is randomized per case:

| Input | Randomized Content |
| --- | --- |
| Original input vector | full 128-bit vector |
| Hidden layer | sparse random signed weights and biases |
| Output layer | sparse random signed weights and biases |
| Function LUT | random signed entries at all addresses used by the generated output results |
| Threshold | randomized near the expected loss so both anomaly and non-anomaly cases appear |

What the testbench does:

1. Resets [`anids_top.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/anids_top.sv).
2. Programs the full register map over APB.
3. Starts the engine by writing `START_REG = 1`.
4. Delivers one DMA vector through the real MFU/top-level path.
5. Waits for internal `core_done`.
6. Captures `core_loss_result` and `core_outlier_pulse`.

What is compared:

- RTL end-to-end result from the real top/core path
- Python golden outputs from `run_anids_model_detailed(...)`

This is the check that proves:

- stage composition is correct
- regfile programming is interpreted correctly
- mapper/LUT path is behaving correctly in context
- threshold compare and anomaly classification are correct

### 5. Dense Full-Core Stress Check

Files:

- [Verification/numeric_checks/dense_core_case.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/dense_core_case.py)
- [Verification/numeric_checks/run_dense_core_check.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/run_dense_core_check.py)
- [Verification/numeric_checks/tb/dense_core_stress_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/dense_core_stress_tb.sv)

Current result:

```text
RTL_DENSE_CORE loss=11 outlier=1
DENSE_CORE_EXPECTED loss=11 outlier=1 threshold=10
DENSE_CORE_CHECK_PASSED
```

This check uses a dense patterned configuration instead of sparse randomized weights, so it is useful as a heavier integration/stress sanity pass.

---

## Functional Performance Numbers

Clock assumption:

| Parameter | Value |
| --- | --- |
| Clock frequency | 200 MHz |
| Clock period | 5 ns |

Measured cycle-level timing from [ANIDS/tb/pipeline_timing_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/tb/pipeline_timing_tb.sv):

| Metric | Cycles from `start_core` | Time |
| --- | ---: | ---: |
| `fetch_next_vector` | 1 | 5 ns |
| first `mfu_updated` | 3 | 15 ns |
| hidden enable | 5 | 25 ns |
| output enable | 69 | 345 ns |
| lookup enable | 133 | 665 ns |
| loss enable | 197 | 985 ns |
| `loss_ready` | 261 | 1.305 us |
| `core_done` | 262 | 1.310 us |
| `status_wr_en` | 263 | 1.315 us |
| `RESULT_REG` update | 264 | 1.320 us |

Steady-state observations from [Verification/zero_order/zero_order_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/zero_order/zero_order_tb.sv):

| Metric | Cycles | Time |
| --- | ---: | ---: |
| internal `core_done` gap | 64 | 0.32 us |
| externally polled terminal-status gap | 65 | 0.325 us |

Steady-state throughput using the 64-cycle internal pipeline spacing:

| Metric | Value |
| --- | --- |
| Results per second | 3.125 Mresults/s |
| 128-bit vectors per second | 3.125 Mvectors/s |
| Equivalent input bandwidth | 400 Mb/s |
| Equivalent input bandwidth | 50 MB/s |

Important interpretation:

- `262` cycles is the internal completion point at `core_done`.
- `264` cycles is the hardware-visible result write into `RESULT_REG`.
- `265` cycles is what the polling-oriented zero-order system bench observed for the first terminal status, because that bench sees the result through APB polling, not through an internal event probe.

---

## Known Verification Notes

| Item | Status |
| --- | --- |
| Hidden/output stage math | Matched golden model |
| Loss-stage math | Matched golden model |
| Full-core pre-threshold math | Matched golden model |
| Final anomaly decision | Matched golden model |
| Randomized signed weights/biases | Covered |
| Randomized function LUT contents | Covered |
| Dense full-core stress case | Covered |

Important notes:

- The LUT memory does not clear on reset in the current RTL.
- The full-core generators compensate by explicitly programming the LUT entries used by each case.
- The standalone loss-stage bench bypasses mapper/LUT hardware and therefore should be read as a pure loss-math check.

---

## Folder Layout

| Path | Purpose |
| --- | --- |
| [Verification/numeric_checks/numeric_check_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/numeric_check_cases.py) | deterministic randomized case generation |
| [Verification/numeric_checks/run_numeric_checks.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/run_numeric_checks.py) | top-level staged numeric-check runner |
| [Verification/numeric_checks/run_dense_core_check.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/run_dense_core_check.py) | dense full-core stress runner |
| [Verification/numeric_checks/tb/hidden_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/hidden_stage_tb.sv) | hidden-stage RTL checker |
| [Verification/numeric_checks/tb/output_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/output_stage_tb.sv) | output-stage RTL checker |
| [Verification/numeric_checks/tb/loss_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/loss_stage_tb.sv) | isolated loss-math RTL checker |
| [Verification/numeric_checks/tb/core_stage_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/core_stage_tb.sv) | end-to-end core RTL checker |
| [Verification/numeric_checks/tb/dense_core_stress_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/numeric_checks/tb/dense_core_stress_tb.sv) | dense full-core stress bench |

---

## Conclusion

| Area | Current Status |
| --- | --- |
| Stage-by-stage functional math | PASS |
| End-to-end functional math | PASS |
| Dense full-core stress | PASS |
| Pipeline latency characterization | Measured and refreshed |
| Randomized numeric-check infrastructure | In place |

Current confidence level:

- The staged RTL math matches the Python golden model on the current 100-case randomized suite.
- The simple and weighted end-to-end comparison flows also match the reference model.
- The dense full-core stress case matches the expected loss/outlier result.
- The current zero-order timing behavior is `262` cycles to `core_done` and `264` cycles to the hardware-visible `RESULT_REG` write for the measured `N=128` case.
