# Verification Overview

This folder contains the main ANIDS verification flows.

## Main Test Suites

- `scripts/run_zero_order_comparison.py`
  Compares RTL against the Python reference model for two simple end-to-end baseline cases:
  all-zero DMA input and all-one DMA input.

- `scripts/run_weighted_comparison.py`
  Generates two nontrivial weighted test cases, runs the RTL end to end, and compares loss/outlier results against the Python reference model.

- `numeric_checks/run_numeric_checks.py`
  Runs the large numeric check suite. This verifies the hidden stage, output stage, loss stage, and full core across many generated cases against the Python reference model.

- `numeric_checks/run_dense_core_check.py`
  Runs a dense full-core stress-style check using one large generated configuration and compares the final RTL result against the reference model.

## Folder Layout

- `scripts/`
  Python helpers, the reference model, and top-level comparison runners.

- `zero_order/`
  End-to-end SystemVerilog benches and data files for the simple baseline and weighted comparison flows.

- `numeric_checks/`
  Larger staged numeric verification flow:
  generated cases, stage benches, the top-level numeric-check runner, and related documentation.

## Important Testbenches

- `zero_order/zero_order_loss_compare_tb.sv`
  RTL bench used by `run_zero_order_comparison.py`.

- `zero_order/weighted_loss_compare_tb.sv`
  RTL bench used by `run_weighted_comparison.py`.

- `zero_order/zero_order_tb.sv`
  Manual end-to-end smoke/status/timing-oriented system bench.

- `zero_order/pipeline_timing_tb.sv`
  Manual pipeline timing probe for cycle-level latency observation.

- `numeric_checks/tb/hidden_stage_tb.sv`
  Checks hidden-layer numeric outputs over many generated cases.

- `numeric_checks/tb/output_stage_tb.sv`
  Checks output-layer numeric outputs over many generated cases.

- `numeric_checks/tb/loss_stage_tb.sv`
  Checks loss-function numeric outputs over many generated cases.

- `numeric_checks/tb/core_stage_tb.sv`
  Checks full-core end-to-end numeric behavior over many generated cases.

- `numeric_checks/tb/dense_core_stress_tb.sv`
  Dense full-core stress bench used by `run_dense_core_check.py`.

## Typical Commands

```powershell
python Verification/scripts/run_zero_order_comparison.py
python Verification/scripts/run_weighted_comparison.py
python Verification/numeric_checks/run_numeric_checks.py
python Verification/numeric_checks/run_dense_core_check.py
```
