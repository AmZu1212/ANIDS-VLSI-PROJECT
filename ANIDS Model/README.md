# ANIDS C++ Model

This folder contains a C++ bit-accurate model for the ANIDS datapath and a test runner that compares the C++ result against RTL simulation.

The term "golden model" is intentionally avoided here. This is a C++ model used for comparison.

## Test Folder Format

Each test lives under:

```text
ANIDS Model/tests/<test_name>/
```

Required input files:

```text
weights.txt
threshold.txt
loss_function.txt
inputs.txt
```

Generated output files:

```text
outputs/program.prog
outputs/cpp.out
outputs/verilog.out
outputs/diff.out
```

## weights.txt

Supported directives:

```text
N <value>
HLW <hidden_neuron> <feature_index> <value>
HLB <hidden_neuron> <value>
OLW <output_neuron> <hidden_index> <value>
OLB <output_neuron> <value>
```

Values may be decimal or hex, for example `64`, `-64`, `0x40`, or `0xC0`.
Weights and biases are interpreted as signed Q0.7 8-bit values.

Unspecified weights and biases default to zero.

## threshold.txt

One signed Q0.7 8-bit threshold value:

```text
16
```

## loss_function.txt

One LUT/function-table value per line:

```text
LUT <address> <value>
```

The runner also accepts the shorter form:

```text
<address> <value>
```

The value is the signed Q0.7 8-bit value programmed into that LUT address. The
example tests use the values from `Documentation/sigmoid_lut_table.csv`.

## inputs.txt

One 128-bit DMA vector per line, written as hex:

```text
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
00000000000000000000000000000000
```

## Run

From `ANIDS Model`:

```text
./run_test sparse_directed_signed
```

From the repository root:

```text
python "ANIDS Model/run_test" sparse_directed_signed
```

The runner:

1. Generates `program.prog` from `weights.txt`, `threshold.txt`, and `loss_function.txt`.
2. Builds and runs the C++ model.
3. Builds and runs the RTL comparison testbench.
4. Writes `cpp.out` and `verilog.out`.
5. Compares loss/anomaly results and writes `diff.out`.

All generated files are written under the test folder's `outputs/` directory.

Output line format:

```text
RESULT vector=<index> loss=<signed_loss> anomaly=<0_or_1>
```

## Included Tests

| Test folder | Purpose |
| --- | --- |
| `zero_model_zeros` | Full-capacity model with an all-zero input vector and high threshold. |
| `zero_model_ones` | Full-capacity model with an all-ones input vector and lower threshold. |
| `sparse_directed_signed` | Directed sparse signed weights and biases. Exercises mixed signs, ReLU zeroing, LUT mapping, and thresholding. |
| `dense_directed_signed` | Directed denser signed weights. Exercises stronger hidden/output activations and signed LUT behavior. |
| `random_full_model_mixed` | Full-capacity model with all 16,384 weights explicitly programmed, 64 streamed vectors, and both anomaly and non-anomaly outputs. |
