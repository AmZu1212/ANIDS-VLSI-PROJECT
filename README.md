# ANIDS VLSI Project

ANIDS stands for Anomaly Network Intrusion Detection System. A NIDS monitors network traffic in order to detect malicious activity, unauthorized access, or abnormal behavior. This project implements an ASIC-oriented hardware accelerator for an ANIDS datapath, based on an autoencoder-style anomaly detection model. The design receives a 128-bit input vector, processes it through a pipelined neural-network inference core, applies a programmable lookup-based activation function, calculates a reconstruction loss, and compares the loss against a programmable threshold to classify the input as anomalous or non-anomalous.

This repository contains the full hardware implementation and verification environment for the project, including synthesizable SystemVerilog RTL, RTL unit and integration testbenches, timing-oriented system testbenches, a C++ integer comparison model, and documentation for the main design and verification flows.


## RTL Design

The main RTL is under `ANIDS/src`.

| File/Folder | Purpose |
| --- | --- |
| `ANIDS/src/anids_top.sv` | Top-level wrapper connecting APB, DMA input, core, register file, and result status logic. |
| `ANIDS/src/anids_core.sv` | Main ANIDS core datapath and pipeline-stage integration. |
| `ANIDS/src/regfile.sv` | APB-accessible register file used for control, model weights, biases, LUT programming, threshold, and result status. |
| `ANIDS/src/mem_fetch_unit.sv` | Captures incoming 128-bit DMA vectors for the core. |
| `ANIDS/src/result_status_encoder.sv` | Converts core completion/outlier status into software-visible result codes. |
| `ANIDS/src/core/` | Core processing blocks: input layer, hidden layer, output layer, lookup layer, loss function, outlier detector, pipeline manager, ReLU, and LUT RAM wrapper. |

The main programmable configuration includes:

| Item | Description |
| --- | --- |
| `N` | Active vector length. Current full tests use `N = 128`. |
| Hidden weights/biases | 64 hidden neurons, each with 128 input weights. |
| Output weights/biases | 128 output neurons, each with 64 hidden-input weights. |
| LUT/function table | 256-entry signed 8-bit lookup table. |
| Threshold | Signed 8-bit anomaly threshold. |
| Result register | Encodes idle, waiting, anomaly, and non-anomaly states. |

## Pipeline Timing

For `N = 128`, the input vector is processed in 2-bit feature pairs:

```text
128 bits / 2 bits per cycle = 64 cycles per major stage
```

The timing testbenches report:

```text
start_core -> RESULT_REG update = 264 cycles
result-to-result gap            = 64 cycles
```

With the intended 5 ns clock period:

```text
Pipe fill latency = 264 cycles * 5 ns = 1320 ns = 1.32 us
Operational gap   = 64 cycles * 5 ns  = 320 ns
Throughput        = 128 bits / 320 ns = 400 Mb/s
```

The timing benches are:

| Testbench | Purpose |
| --- | --- |
| `ANIDS/tb/pipeline_timing_tb.sv` | Measures first-result pipeline fill latency. |
| `ANIDS/tb/two_vector_test_tb.sv` | Measures steady-state result-to-result latency using two streamed vectors. |

## Running RTL Testbenches

The root `run.py` script compiles and runs a SystemVerilog testbench with Icarus Verilog. It also moves the generated VCD file into `outputs/` and launches GTKWave if available.

Run a testbench from the repository root:

```bash
python ./run.py pipeline_timing_tb.sv
```

Examples:

```bash
python ./run.py relu_unit_tb.sv
python ./run.py pipeline_manager_tb.sv
python ./run.py pipeline_timing_tb.sv
python ./run.py two_vector_test_tb.sv
```

Open a generated waveform manually:

```bash
gtkwave ./outputs/pipeline_timing_tb.vcd
```

## RTL Testbench Coverage

RTL testbenches are located under `ANIDS/tb`.

| Area | Location | Examples |
| --- | --- | --- |
| Unit tests | `ANIDS/tb/unit/` | ReLU, input layer, memory mapper, fetch unit, hidden/output neuron units, outlier detector, status encoder. |
| Integration tests | `ANIDS/tb/integration/` | APB read/write, hidden layer, output layer, lookup layer, loss function, pipeline manager, LUT RAM. |
| System/timing tests | `ANIDS/tb/` | Pipeline fill timing and two-vector steady-state timing. |

See the detailed testbench documentation:

```text
Documentation/Testbenches.md
```

## C++ Model Comparison

The `ANIDS Model` folder contains a C++ integer model used to compare final RTL loss/anomaly results against an independent software implementation of the datapath.

Key files:

| File/Folder | Purpose |
| --- | --- |
| `ANIDS Model/cpp/anids_model.cpp` | C++ integer model of the ANIDS datapath. |
| `ANIDS Model/rtl/anids_model_compare_tb.sv` | RTL comparison testbench for full `anids_top`. |
| `ANIDS Model/run_test` | Python runner for one RTL vs. C++ comparison case. |
| `ANIDS Model/tests/` | Test folders containing weights, threshold, LUT contents, and input vectors. |

Run one comparison test:

```bash
cd "ANIDS Model"
python ./run_test sparse_directed_signed
```

Run all included model tests:

```powershell
cd "ANIDS Model"
$tests = Get-ChildItem -LiteralPath ".\tests" -Directory | Sort-Object Name
foreach ($test in $tests) {
  python .\run_test $test.Name
}
```

The current RTL vs. C++ comparison suite includes:

| Test Case | Vectors Checked | Result |
| --- | ---: | --- |
| `dense_directed_signed` | 1 | PASS |
| `random_full_model_mixed` | 64 | PASS |
| `sparse_directed_signed` | 1 | PASS |
| `zero_model_ones` | 1 | PASS |
| `zero_model_zeros` | 1 | PASS |

Detailed model documentation:

```text
Documentation/ANIDS Model.md
ANIDS Model/Guide.md
ANIDS Model/Results.md
```

## Documentation

The main documentation files are under `Documentation/`.

| File | Purpose |
| --- | --- |
| `Documentation/Testbenches.md` | Detailed explanation of RTL unit, integration, and system testbenches. |
| `Documentation/ANIDS Model.md` | Detailed explanation of the C++ model, test structure, runner, and RTL comparison bench. |
| `Documentation/Programmers Guide.md` | Register/programming-oriented design documentation. |
| `Documentation/LUT Programming Guide.md` | LUT programming details. |
| `Documentation/Sub Block Descriptions.md` | Block-level design descriptions. |
| `Documentation/Main Block Descriptions.md` | High-level block descriptions. |
| `Documentation/Synthesis Results.md` | Compile/synthesis-related notes. |
| `Documentation/sigmoid lut data.csv` | LUT table data used by tests. |

## Tool Requirements

Typical local usage expects:

| Tool | Used For |
| --- | --- |
| Python 3 | Running `run.py` and model comparison runners. |
| Icarus Verilog (`iverilog`, `vvp`) | Compiling and running SystemVerilog simulations. |
| GTKWave | Viewing generated VCD waveforms. |
| `g++` or `clang++` | Building the C++ comparison model. |

## Generated Outputs

Generated simulation and build products are written under:

```text
outputs/
ANIDS Model/build/
ANIDS Model/tests/<test_name>/outputs/
```

These include compiled simulation files, VCD waveforms, C++ executables, generated APB programs, and comparison outputs.

## Current Verification Status

At the current project state:

```text
RTL timing testbenches pass.
RTL vs. C++ model comparison tests all pass.
No RTL vs. C++ comparison test failed or was skipped.
```

Important confirmed timing values:

```text
Pipe fill latency to RESULT_REG = 264 cycles = 1.32 us at 5 ns
Steady-state result gap         = 64 cycles  = 320 ns at 5 ns
Throughput                      = 400 Mb/s
```
