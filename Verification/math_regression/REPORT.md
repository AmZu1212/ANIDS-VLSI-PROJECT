# ANIDS Math Regression Report

## Scope

This report summarizes the current functional-math verification status for the ANIDS RTL against the Python golden model.

Checked blocks:

| Stage | Checked Against |
|---|---|
| Hidden layer | Python hidden-stage model |
| Output layer | Python output-stage model |
| Loss function | Python loss-stage model |
| Full core | Python end-to-end model |

---

## Regression Summary

| Category | Test Count | Result |
|---|---:|---|
| Hidden-stage randomized tests | 30 | PASS |
| Output-stage randomized tests | 30 | PASS |
| Loss-stage randomized tests | 30 | PASS |
| Full-core randomized tests | 10 | PASS |
| Total | 100 | PASS |

Last regression status:

```text
SUMMARY hidden=30 output=30 loss=30 core=10 total=100
MATH_REGRESSION_PASSED
```

Run command:

```bash
python Verification/math_regression/run_regression.py
```

---

## What Is Verified

| Block | Verified Behavior |
|---|---|
| Hidden layer | 2-bit feature gating, weight selection, accumulation, TRUN8, bias saturating add, ReLU |
| Output layer | signed Q0.7 multiply, product truncation back to Q0.7, accumulation, TRUN8, bias saturating add |
| Loss function | memory mapper, function LUT lookup, signed LUT output handling, MAE accumulation, TRUN8 |
| Full core | stage composition, end-to-end loss result, anomaly decision |

---

## Detailed Test Breakdown

This section explains what each regression group actually does.

### 1. Hidden-Stage Regression

Files:

- [Verification/math_regression/regression_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/regression_cases.py)
- [Verification/math_regression/tb/hidden_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/hidden_stage_regression_tb.sv)

Case count:

| Item | Value |
|---|---:|
| Hidden-stage tests | 30 |

What is randomized per case:

| Input | Randomized Content |
|---|---|
| Input vector | full 128-bit feature vector, generated as 64 random 2-bit pairs |
| Active hidden neurons | 6 random neurons out of 64 |
| Hidden weights | 12 random nonzero weights inside each active neuron |
| Hidden biases | 1 random bias per active neuron |

What the testbench does:

1. Resets the DUT.
2. Loads a generated hidden-stage register image directly into the `regfile` bus view.
3. Loads one generated 128-bit input vector.
4. Drives the hidden layer for 64 steps:
   - `counter = 0..63`
   - `features = vector[2*counter +: 2]`
5. Waits for the final-cycle `ready` from all 64 hidden neurons.
6. Dumps all 64 hidden outputs as 8-bit values.

What is compared:

- RTL hidden outputs from [`hidden_layer.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/hidden_layer.sv)
- Python golden outputs from `run_hidden_stage(...)`

What this proves:

- feature-pair selection is correct
- hidden-weight addressing is correct
- per-neuron accumulation is correct
- `TRUN8` behavior is correct
- bias saturating add is correct
- ReLU behavior is correct

### 2. Output-Stage Regression

Files:

- [Verification/math_regression/regression_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/regression_cases.py)
- [Verification/math_regression/tb/output_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/output_stage_regression_tb.sv)

Case count:

| Item | Value |
|---|---:|
| Output-stage tests | 30 |

What is randomized per case:

| Input | Randomized Content |
|---|---|
| Hidden-result vector | 64 signed Q0.7 values |
| Active output neurons | 8 random neurons out of 128 |
| Output weights | 10 random nonzero weights inside each active neuron |
| Output biases | 1 random bias per active neuron |

What the testbench does:

1. Resets the DUT.
2. Loads the generated output-stage register image directly into the `regfile` bus view.
3. Loads one generated 64-entry hidden-result bank.
4. Drives the output layer for 64 steps:
   - `counter = 0..63`
   - each output neuron uses `hidden_results[counter]`
5. Waits for final-cycle `ready` from all 128 output neurons.
6. Dumps all 128 output values as 8-bit signed data.

What is compared:

- RTL output-layer outputs from [`output_layer.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/output_layer.sv)
- Python golden outputs from `run_output_stage(...)`

What this proves:

- output-weight addressing is correct
- signed `Q0.7 x Q0.7` multiply behavior is correct
- product truncation back to `Q0.7` is correct
- output accumulation is correct
- output bias saturating add is correct

### 3. Loss-Stage Regression

Files:

- [Verification/math_regression/regression_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/regression_cases.py)
- [Verification/math_regression/tb/loss_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/loss_stage_regression_tb.sv)

Case count:

| Item | Value |
|---|---:|
| Loss-stage tests | 30 |

What is randomized per case:

| Input | Randomized Content |
|---|---|
| Original input vector | full 128-bit feature vector |
| Output-result vector | 128 signed Q0.7 values |
| LUT contents | random signed values only at addresses actually used by that case |

What the testbench does:

1. Resets the DUT.
2. Loads one generated original 128-bit input vector.
3. Loads one generated 128-entry output-result bank.
4. Programs the function LUT through the loss-function write interface.
5. Drives the loss function for 64 steps:
   - `counter = 0..63`
   - `x_in = original_vector[2*counter +: 2]`
   - `result_0 = output_results[2*counter]`
   - `result_1 = output_results[2*counter+1]`
6. Captures the final `result` when `ready` is asserted.

What is compared:

- RTL loss output from [`loss_function.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/loss_function.sv)
- Python golden output from `loss_result_direct(...)`

What this proves:

- memory mapper behavior is correct
- LUT addressing is correct
- signed LUT output handling is correct
- per-feature delta and absolute value math is correct
- MAE accumulation is correct
- final `TRUN8` in the loss path is correct

### 4. Full-Core Regression

Files:

- [Verification/math_regression/regression_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/regression_cases.py)
- [Verification/math_regression/tb/core_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/core_stage_regression_tb.sv)

Case count:

| Item | Value |
|---|---:|
| Full-core tests | 10 |

What is randomized per case:

| Input | Randomized Content |
|---|---|
| Original input vector | full 128-bit vector |
| Hidden layer | sparse random signed weights and biases |
| Output layer | sparse random signed weights and biases |
| Function LUT | random signed entries at all addresses used by the generated output results |
| Threshold | randomized near the expected loss so both anomaly and non-anomaly cases appear |

What the testbench does:

1. Resets [`anids_top.sv`](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/anids_top.sv).
2. Programs the full register map over APB:
   - `N`
   - threshold
   - hidden weights
   - hidden biases
   - output weights
   - output biases
   - function LUT entries
3. Starts the engine by writing `START_REG = 1`.
4. Delivers one DMA vector through the real MFU/top-level path.
5. Waits for internal `core_done`.
6. Captures:
   - `core_loss_result`
   - `core_outlier_pulse`

What is compared:

- RTL end-to-end result from the real top/core path
- Python golden outputs from `run_anids_model_detailed(...)`

What this proves:

- hidden, output, and loss stage math works correctly in composition
- regfile programming is interpreted correctly by the full design
- function LUT programming path is correct
- threshold compare and anomaly classification are correct
- the end-to-end datapath matches the golden model, not just the isolated stage blocks

### Why The Regression Is Split This Way

| Group | Why It Exists |
|---|---|
| Hidden-only | catches hidden-stage math/addressing bugs without full-core overhead |
| Output-only | isolates signed multiply/accumulate and output weight indexing |
| Loss-only | isolates mapper/LUT/MAE math |
| Full-core | verifies stage composition and final anomaly result |

This split keeps debugging fast:

- if only hidden tests fail, the problem is likely in hidden-layer math or addressing
- if only output tests fail, the problem is likely in output-layer MAC logic
- if only loss tests fail, the problem is likely in mapper/LUT/MAE logic
- if only full-core tests fail, the issue is more likely in composition, control, or integration

---

## Functional Performance Numbers

Clock assumption:

| Parameter | Value |
|---|---:|
| Clock frequency | 200 MHz |
| Clock period | 5 ns |

Measured pipeline behavior:

| Metric | Cycles | Time |
|---|---:|---:|
| First internal result (`core_done`) | 198 | 0.99 us |
| First CPU-visible result (`RESULT_REG`) | 205 | 1.025 us |
| Steady-state result spacing | 64 | 0.32 us |

Steady-state throughput:

| Metric | Value |
|---|---:|
| Results per second | 3.125 Mresults/s |
| 128-bit vectors per second | 3.125 Mvectors/s |
| Equivalent input bandwidth | 400 Mb/s |
| Equivalent input bandwidth | 50 MB/s |

---

## Known Verification Notes

| Item | Status |
|---|---|
| Hidden/output stage math | Matched golden model |
| Loss-stage math | Matched golden model |
| Full-core pre-threshold math | Matched golden model |
| Final anomaly decision | Matched golden model |
| Randomized signed weights/biases | Covered |
| Randomized function LUT contents | Covered |

Important note:

- The LUT memory does not clear on reset in the current RTL.
- The regression harness compensates by explicitly programming every used LUT address in each case.
- This avoids stale-LUT-data contamination between regression cases.

---

## Folder Layout

| Path | Purpose |
|---|---|
| [Verification/math_regression/regression_cases.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/regression_cases.py) | deterministic randomized case generation |
| [Verification/math_regression/run_regression.py](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/run_regression.py) | top-level regression runner |
| [Verification/math_regression/tb/hidden_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/hidden_stage_regression_tb.sv) | hidden-stage RTL checker |
| [Verification/math_regression/tb/output_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/output_stage_regression_tb.sv) | output-stage RTL checker |
| [Verification/math_regression/tb/loss_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/loss_stage_regression_tb.sv) | loss-stage RTL checker |
| [Verification/math_regression/tb/core_stage_regression_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/Verification/math_regression/tb/core_stage_regression_tb.sv) | end-to-end core RTL checker |

---

## Conclusion

| Area | Current Status |
|---|---|
| Stage-by-stage functional math | PASS |
| End-to-end functional math | PASS |
| Pipeline latency/throughput characterization | Measured |
| Randomized regression infrastructure | In place |

Current confidence level:

- The implemented RTL math path is behaving correctly for the tested randomized cases.
- The project now has a reusable regression framework for continued verification as the RTL evolves.
