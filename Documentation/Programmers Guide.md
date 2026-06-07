# ANIDS Programmer's Guide

This guide explains how software should configure and run the ANIDS core through
the APB register interface and DMA input-vector interface.

The guide is based on the current RTL in:

- [ANIDS/anids_defines.vh](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/anids_defines.vh)
- [ANIDS/src/anids_top.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/anids_top.sv)
- [ANIDS/src/regfile.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/regfile.sv)
- [ANIDS/src/mem_fetch_unit.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/mem_fetch_unit.sv)
- [ANIDS/src/core/pipeline_manager.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/pipeline_manager.sv)
- [ANIDS/src/core/lookup_layer.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/lookup_layer.sv)

## Interface Summary

| Interface | Width | Purpose |
| --- | ---: | --- |
| APB address | 16 bits | selects configuration/result register |
| APB data | 8 bits | writes weights, biases, control, threshold, LUT data |
| DMA data | 128 bits | supplies one input feature vector |
| Clock | 200 MHz | 5 ns period |

All model parameters are programmed as 8-bit values. Weights, biases, layer
outputs, LUT outputs, threshold, and loss values are interpreted as signed
two's-complement `Q0.7` values unless stated otherwise.

## Register Map

| Address | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0` | `START_REG` | R/W | bit 0 starts/stops the core |
| `1` | `N_REG` | R/W | vector length in bits, normally `128` |
| `2` | `THRESHOLD_REG` | R/W | signed threshold used by outlier detector |
| `3` | `RESULT_REG` | R/HW | final status written by hardware |
| `4` | `LUT_ADDR` | W | LUT address for indirect LUT programming |
| `5` | `LUT_DATA` | W | LUT data byte for indirect LUT programming |
| `6` | `LUT_CTRL` | W | write `1`, then `0`, to commit one LUT write |
| `7` | `FREE_REG` | R/W | currently unused free register |
| `8..8199` | hidden weights | R/W | `64 * 128` hidden-layer weights |
| `8200..8263` | hidden biases | R/W | `64` hidden-layer biases |
| `8264..16455` | output weights | R/W | `128 * 64` output-layer weights |
| `16456..16583` | output biases | R/W | `128` output-layer biases |

The APB regfile has:

```text
REG_COUNT = 16584 entries
entry width = 8 bits
regfile size = 16584 bytes = 16.584 KB = 16.195 KiB
```

The activation LUT is separate from the regfile:

```text
LUT size = 256 entries * 8 bits = 256 bytes
```

Total programmed model storage, including weights, biases, and LUT:

```text
hidden weights = 8192 bytes
hidden biases  = 64 bytes
output weights = 8192 bytes
output biases  = 128 bytes
LUT            = 256 bytes
total          = 16832 bytes = 16.832 KB = 16.438 KiB
```

## Status Values

`RESULT_REG` is written by hardware through `result_status_encoder`.

| Value | Meaning |
| ---: | --- |
| `0` | not anomaly |
| `1` | anomaly |
| `2` | waiting/running |
| `3` | idle |

Recommended software behavior:

1. Program the model while `START_REG = 0`.
2. Write `START_REG = 1`.
3. Supply DMA vectors when requested.
4. Poll `RESULT_REG` through APB address `3`.
5. Accept `RESULT_REG = 0` or `1` as the final result.
6. Write `START_REG = 0` when stopping the engine.

## APB Write Protocol

The regfile behaves as a zero-wait APB-style slave. A write uses the standard
setup/access sequence:

```text
cycle 1: paddr=addr, pwdata=data, psel=1, pwrite=1, penable=0
cycle 2: penable=1
wait until pready=1
next cycle: psel=0, penable=0, pwrite=0
```

The APB testbenches use this sequence:

```text
write(addr, data):
    set paddr, pwdata, psel=1, pwrite=1, penable=0
    on next clock set penable=1
    wait for pready
    drop psel, penable, pwrite
```

APB reads are similar, except `pwrite=0`; read data is returned on `prdata`.

## Programming Order

Use this order for deterministic behavior:

1. Hold reset low, then release reset.
2. Write `START_REG = 0`.
3. Write `N_REG`.
4. Write `THRESHOLD_REG`.
5. Program hidden weights.
6. Program hidden biases.
7. Program output weights.
8. Program output biases.
9. Program all required LUT entries.
10. Write `START_REG = 1`.
11. Supply DMA vectors when `dma_ack` is asserted.

The safest rule is to program all `256` LUT entries before starting. The LUT RAM
contents are not cleared by the normal core reset path.

## Hidden Layer Model Layout

The hidden layer has:

```text
hidden neurons = 64
input features = 128 bits
weights per hidden neuron = 128
hidden weights total = 64 * 128 = 8192
hidden biases total = 64
```

The hidden-weight address formula is:

```text
hidden_weight_addr(neuron, feature) =
    HL_WEIGHT_BASE + neuron * 128 + feature
```

where:

```text
HL_WEIGHT_BASE = 8
neuron = 0..63
feature = 0..127
```

To program one hidden-layer weight, compute the address, then perform one APB
write to that address.

Example: program hidden neuron `3`, input feature `10`, with weight `0x40`
(`+0.5` in signed `Q0.7`):

```text
addr = 8 + 3 * 128 + 10
addr = 402

APB write:
    paddr  = 402
    pwdata = 0x40
    pwrite = 1
```

The hidden-bias address formula is:

```text
hidden_bias_addr(neuron) =
    HL_BIAS_BASE + neuron
```

where:

```text
HL_BIAS_BASE = 8200
neuron = 0..63
```

Example: program hidden neuron `3` bias with `0xF0`:

```text
addr = 8200 + 3
addr = 8203

APB write:
    paddr  = 8203
    pwdata = 0xF0
    pwrite = 1
```

During execution, the hidden layer processes two feature bits per cycle:

```text
feature_0 = 2 * counter
feature_1 = 2 * counter + 1
counter = 0..(N/2 - 1)
```

For `N = 128`, hidden-layer processing takes `64` cycles.

## Output Layer Model Layout

The output layer has:

```text
output neurons = 128
hidden inputs = 64
weights per output neuron = 64
output weights total = 128 * 64 = 8192
output biases total = 128
```

The output-weight address formula is:

```text
output_weight_addr(neuron, hidden_index) =
    OL_WEIGHT_BASE + neuron * 64 + hidden_index
```

where:

```text
OL_WEIGHT_BASE = 8264
neuron = 0..127
hidden_index = 0..63
```

To program one output-layer weight, compute the address, then perform one APB
write to that address.

Example: program output neuron `20`, hidden input `7`, with weight `0x20`
(`+0.25` in signed `Q0.7`):

```text
addr = 8264 + 20 * 64 + 7
addr = 9551

APB write:
    paddr  = 9551
    pwdata = 0x20
    pwrite = 1
```

The output-bias address formula is:

```text
output_bias_addr(neuron) =
    OL_BIAS_BASE + neuron
```

where:

```text
OL_BIAS_BASE = 16456
neuron = 0..127
```

Example: program output neuron `20` bias with `0x00`:

```text
addr = 16456 + 20
addr = 16476

APB write:
    paddr  = 16476
    pwdata = 0x00
    pwrite = 1
```

For `N = 128`, output-layer processing takes `64` cycles.

## Q0.7 Encoding

Signed `Q0.7` uses one sign bit and seven fractional bits.

To encode a real value:

```text
q = round(value * 128)
q_sat = min(127, max(-128, q))
byte = q_sat encoded as signed 8-bit two's complement
```

Examples:

| Real value | Signed integer | Byte |
| ---: | ---: | --- |
| `0.0` | `0` | `0x00` |
| `0.5` | `64` | `0x40` |
| `0.9921875` | `127` | `0x7F` |
| `-0.5` | `-64` | `0xC0` |
| `-1.0` | `-128` | `0x80` |

## LUT Programming

The activation LUT has:

```text
entries = 256
entry width = 8 bits
address range = 0..255
```

The lookup layer has two internal LUT RAMs, one for each output feature in the
pair. One APB LUT write updates both RAMs with the same address/data value.

To program one LUT entry:

```text
write(LUT_ADDR, lut_address)
write(LUT_DATA, lut_byte)
write(LUT_CTRL, 1)
write(LUT_CTRL, 0)
```

`lut_byte` is an 8-bit signed `Q0.7` value encoded as a raw byte.

### LUT Address Mapping

The output-layer result entering the mapper is signed `Q0.7`. The mapper
converts that signed value into an unsigned LUT address by flipping the sign bit:

```text
lut_addr = {~in_value[7], in_value[6:0]}
```

This creates ascending address order:

| Mapper input bits | Q0.7 value | LUT address |
| --- | ---: | ---: |
| `10000000` | `-1.0` | `0` |
| `11000000` | `-0.5` | `64` |
| `00000000` | `0.0` | `128` |
| `01000000` | `0.5` | `192` |
| `01111111` | `0.9921875` | `255` |

So address `0` is the lowest modeled X value, and address `255` is the highest
modeled X value.

### Building A Function Table

For a mathematical function over a chosen range `[x_min, x_max]`, use:

```text
x[i] = x_min + i * (x_max - x_min) / 255
y[i] = f(x[i])
q[i] = round(y[i] * 128)
q_sat[i] = min(127, max(-128, q[i]))
lut_byte[i] = q_sat[i] encoded as signed 8-bit two's complement
```

for:

```text
i = 0..255
```

Then write:

```text
LUT address i <- lut_byte[i]
```

For example, sigmoid over `[-10, 10]`:

```text
x[i] = -10 + 20 * i / 255
y[i] = 1 / (1 + e^(-x[i]))
lut[i] = sat_q07(y[i])
```

## DMA Input Protocol

The DMA interface provides one full input vector at a time:

```text
dma_data  = 128-bit feature vector
dma_valid = producer-valid
dma_ack   = ANIDS ready/acknowledge
```

The memory fetch unit only accepts data after the core requests a vector. The
flow is:

1. `pipeline_manager` raises internal `fetch`.
2. `mem_fetch_unit` raises `dma_ack`.
3. External DMA drives `dma_data` and asserts `dma_valid`.
4. `mem_fetch_unit` captures `dma_data`.
5. `mem_fetch_unit` deasserts `dma_ack` and pulses internal `updated`.
6. `pipeline_manager` pushes the vector into its prefetch FIFO.

Recommended DMA behavior:

```text
wait until dma_ack == 1
drive dma_data with the 128-bit vector
assert dma_valid
hold for at least one clock edge
deassert dma_valid
wait for dma_ack to return to 0
```

The feature vector is interpreted as 64 pairs of bits:

```text
pair[counter] = dma_data[2*counter +: 2]
counter = 0..63 for N = 128
```

## Prefetch FIFO

The pipeline manager contains a small FIFO for incoming DMA vectors:

```text
FIFO_DEPTH = 4 vectors
```

It requests another vector when:

```text
fetch_inflight == 0 && fifo_count < FIFO_DEPTH
```

The FIFO lets the next vector be ready at the next pipeline boundary. For
`N = 128`, a new vector can enter the hidden stage every `64` cycles once the
pipeline is full.

## Starting The Core

To start processing:

```text
write(START_REG, 1)
```

To stop or return to idle:

```text
write(START_REG, 0)
```

The core should be configured before `START_REG` is set. Software should not
rewrite weights, biases, `N_REG`, threshold, or LUT entries while the core is
running unless that behavior is intentionally being tested.

## Reading The Result

The programmer-visible completion path is `RESULT_REG`. After starting the core,
the CPU should repeatedly read APB address `3` and decode the returned status.

For a new transaction, the safe polling rule is:

```text
first wait until RESULT_REG reads 2  (STATUS_WAITING)
then wait until RESULT_REG reads 0 or 1
```

This avoids accidentally treating an old result from the previous vector as the
new result.

The final result is held by the status encoder for `RESULT_HOLD_CYCLES = 8`
clock cycles before the status can return to `STATUS_WAITING` while `START_REG`
remains high. Software should therefore actively poll `RESULT_REG` after
providing a DMA vector.

Polling sequence:

```text
write(START_REG, 1)

seen_waiting = false

loop:
    APB read RESULT_REG, address 3
    if prdata == 2:
        seen_waiting = true
        core is still waiting/running
        keep polling
    if seen_waiting && prdata == 0:
        result = not anomaly
        stop polling
    if seen_waiting && prdata == 1:
        result = anomaly
        stop polling
    if prdata == 3:
        core is idle
        start was not accepted yet or the core is stopped
        keep polling or check START_REG/software state
    otherwise:
        this may be an old 0/1 result before the new waiting state
        keep polling
```

One APB read of `RESULT_REG` uses:

```text
cycle 1: paddr=3, psel=1, pwrite=0, penable=0
cycle 2: penable=1
wait until pready=1
sample prdata
next cycle: psel=0, penable=0
```

The important timing detail for software is the APB-visible result latency. For
`N = 128`, `RESULT_REG` is updated `264` cycles after the start event.

For the current `N = 128` timing:

```text
start_core -> RESULT_REG update = 264 cycles
```

At 200 MHz:

```text
cycle time = 5 ns
RESULT_REG latency = 264 * 5 ns = 1.32 us
```

## Timing And Throughput

For the current `N = 128` case, measured by
[ANIDS/tb/pipeline_timing_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/tb/pipeline_timing_tb.sv):

| Event | Cycle |
| --- | ---: |
| `start_core` | 43 |
| `fetch_next_vector` | 44 |
| `mfu_updated` | 46 |
| `hidden_enable` | 48 |
| `output_enable` | 112 |
| `lookup_enable` | 176 |
| `loss_enable` | 240 |
| `loss_ready` | 304 |
| internal completion | 305 |
| `status_wr_en` | 306 |
| `RESULT_REG update` | 307 |

Relative timing from `start_core`:

| Metric | Cycles | Time at 200 MHz |
| --- | ---: | ---: |
| start to fetch request | 1 | 5 ns |
| start to hidden stage | 5 | 25 ns |
| start to internal completion | 262 | 1.31 us |
| start to `RESULT_REG` update | 264 | 1.32 us |

For even `N`, the current measured rule is:

```text
stage gap = N / 2 cycles
start_core -> RESULT_REG update = 2N + 8 cycles
```

Examples:

| N | Stage gap | Internal completion | `RESULT_REG` latency |
| ---: | ---: | ---: | ---: |
| `128` | `64` cycles | `262` cycles | `264` cycles |
| `64` | `32` cycles | `134` cycles | `136` cycles |

For streaming throughput at `N = 128`, measured by
[ANIDS/tb/two_vector_test_tb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/tb/two_vector_test_tb.sv):

```text
first RESULT_REG     @ cycle 307
second RESULT_REG    @ cycle 371
result gap           = 64 cycles
```

Throughput:

```text
packet size = 128 bits = 16 bytes
steady-state result interval = 64 cycles
64 cycles * 5 ns = 320 ns
128 bits / 320 ns = 400 Mb/s = 50 MB/s
```

Important distinction:

- `1.32 us` is first-result visible latency.
- `400 Mb/s` is steady-state throughput after the pipeline is full.

## Minimal Programming Checklist

Use this as the short programmer sequence:

```text
reset core
write START_REG = 0
write N_REG = 128
write THRESHOLD_REG
write all hidden weights
write all hidden biases
write all output weights
write all output biases
program LUT entries through LUT_ADDR/LUT_DATA/LUT_CTRL
write START_REG = 1
for each vector:
    wait for dma_ack
    drive dma_data
    assert dma_valid for at least one clock edge
    deassert dma_valid
    continuously poll RESULT_REG at APB address 3
    first wait for RESULT_REG value 2
    final RESULT_REG value 0 means not anomaly
    final RESULT_REG value 1 means anomaly
write START_REG = 0 when finished
```

## Notes And Caveats

- `N` should be even. The current control logic uses `N >> 1`, so odd `N`
  values truncate the final unpaired bit.
- `RESULT_REG` is hardware-written. Software should treat address `3` as a
  result/status register during operation.
- LUT contents should be explicitly initialized by software.
- The current timing numbers are RTL simulation cycle counts, not post-layout
  static timing numbers.
- The synthesis clock constraint should still be set to `5 ns` for 200 MHz
  operation.
