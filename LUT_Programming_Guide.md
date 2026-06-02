# LUT Programming Guide

This guide explains how to build and program the ANIDS activation-function LUT.

It is written so that you can replace the current sigmoid range with any other
range, for example `[-6, 6]`, `[-10, 10]`, or something else, as long as you
understand how the mapper and the LUT interact.

## What The LUT Stores

The activation LUT is:

- `256` entries deep
- `8` bits wide per entry
- programmed through the APB/LUT write path

Relevant files:

- [anids_defines.vh](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/anids_defines.vh)
- [memory_mapper.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/memory_mapper.sv)
- [lookup_layer.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/lookup_layer.sv)
- [spram8x256_cb.sv](/e:/Git-Repos/ANIDS-VLSI-PROJECT/ANIDS/src/core/spram8x256_cb.sv)

The LUT does not store floating-point values. It stores `8-bit signed Q0.7`
values as raw bytes.

One important implementation detail:

- the lookup layer contains two LUT RAM instances
- a single APB LUT write broadcasts the same address/data to both of them

So when you program LUT address `i`, both lookup paths receive the same LUT
entry.

## Important Addressing Rule

The LUT addresses are `0` through `255`.

The lowest mathematical input does **not** go to address `1`. It goes to
address `0`.

With the current mapper:

```text
addr = {~in_value[7], in_value[6:0]}
```

This means:

- most negative mapper input -> address `0`
- zero mapper input -> address `128`
- most positive mapper input -> address `255`

Examples:

| Mapper Input Bits | Signed Q0.7 Value | LUT Address |
| ----------------- | ----------------- | ----------- |
| `10000000`        | `-1.0`            | `0`         |
| `11000000`        | `-0.5`            | `64`        |
| `00000000`        | `0.0`             | `128`       |
| `01000000`        | `0.5`             | `192`       |
| `01111111`        | `0.9921875`       | `255`       |

So the LUT is ordered from lowest mathematical input at address `0` to highest
mathematical input at address `255`.

## Two Different X Domains

There are two different notions of "X" here:

1. The **mapper input domain**
   This is the actual hardware value entering `memory_mapper`.
   It is an `8-bit signed Q0.7` number, approximately in `[-1.0, 0.9921875]`.

2. The **mathematical function domain**
   This is the real X-axis range you want the LUT to represent, such as:
   - `[-6, 6]`
   - `[-10, 10]`

These are not the same numeric scale.

What you are really doing is using the mapper input domain as a normalized
indexing domain, and deciding that:

- address `0` represents your chosen `x_min`
- address `255` represents your chosen `x_max`

Everything in between is sampled linearly.

## Step 1: Choose The Mathematical X Range

Pick the real input range you want the LUT to approximate.

Examples:

- sigmoid over `[-6, 6]`
- sigmoid over `[-10, 10]`
- tanh over `[-4, 4]`

Call the endpoints:

```text
x_min
x_max
```

For example:

```text
x_min = -10
x_max = 10
```

## Step 2: Cut The X Axis Into 256 Samples

Because the LUT has `256` entries, you need `256` sampled X values.

Use:

```text
x[i] = x_min + i * (x_max - x_min) / 255
```

for:

```text
i = 0, 1, 2, ..., 255
```

Why divide by `255` and not `256`:

- because both endpoints are included
- `i = 0` should map to `x_min`
- `i = 255` should map to `x_max`

Example for `[-10, 10]`:

```text
x[0]   = -10.0
x[1]   = -10 + 20/255
x[128] ~= 0.039215686
x[255] = 10.0
```

Note that with `256` points, the exact midpoint is between two entries. So
`x[128]` is close to zero, not exactly zero.

## Step 3: Evaluate The Mathematical Function

For each sampled X value, compute:

```text
y[i] = f(x[i])
```

For sigmoid:

```text
y[i] = 1 / (1 + e^(-x[i]))
```

Example:

```text
y[0]   = sigmoid(-10)
y[255] = sigmoid(10)
```

## Step 4: Convert The Real Value Into Signed Q0.7

The LUT stores `8-bit signed Q0.7`.

That means:

- `1` sign bit
- `7` fractional bits
- scale factor `128`

To quantize a real value `y` into signed `Q0.7`:

```text
q = round(y * 128)
```

Then saturate to the signed 8-bit range:

```text
q_sat = min(127, max(-128, q))
```

Then encode that signed integer as an 8-bit two's-complement byte.

Examples:

| Real Value | Q0.7 Integer | Raw 8-bit Value |
| ---------- | ------------ | ---------------- |
| `0.0`      | `0`          | `0x00`           |
| `0.5`      | `64`         | `0x40`           |
| `0.992`    | `127`        | `0x7F`           |
| `-0.25`    | `-32`        | `0xE0`           |
| `-1.0`     | `-128`       | `0x80`           |

For sigmoid specifically, outputs are in `(0, 1)`, so your stored values will
normally be between:

- `0x00`
- `0x7F`

They will not normally be negative.

## Step 5: Write Each Quantized Value Into The Matching Address

After quantization:

- store `q_sat` for sample `i` into LUT address `i`

So:

- address `0` gets the function value for `x_min`
- address `255` gets the function value for `x_max`

This is the key rule.

For example, if your function range is `[-10, 10]`:

- LUT address `0` stores `f(-10)`
- LUT address `255` stores `f(10)`

## Step 6: Program The LUT Through APB

The RTL programs LUT entries using:

- `LUT_ADDR_REG`
- `LUT_DATA_REG`
- `LUT_CTRL_REG`

Recommended programming rule:

1. keep `START_REG = 0` while loading configuration and LUT contents
2. write all required LUT entries
3. only then set `START_REG = 1` to run the core

This matches the verification benches and generated program files.

The sequence for one LUT entry is:

1. write address into `LUT_ADDR_REG`
2. write the 8-bit quantized value into `LUT_DATA_REG`
3. write `1` into `LUT_CTRL_REG`
4. write `0` into `LUT_CTRL_REG`

Pseudo-sequence:

```text
write(LUT_ADDR_REG, i)
write(LUT_DATA_REG, lut_byte[i])
write(LUT_CTRL_REG, 1)
write(LUT_CTRL_REG, 0)
```

This is exactly how the current Python-generated program files load LUT entries.

At the signal level, the APB benches perform a normal APB write:

1. drive `paddr`, `pwdata`, `psel=1`, `pwrite=1`, `penable=0`
2. on the next clock, assert `penable=1`
3. wait for `pready`
4. then drop `psel`, `penable`, and `pwrite`

You do not need anything special beyond a normal APB write transaction.

## Step 7: Program All LUT Entries For Deterministic Startup

Do not rely on reset to clear the LUT contents.

The lookup-layer RAM contents are not reset by the normal core reset path. For
deterministic behavior, the safest rule is:

- write all `256` LUT addresses explicitly before using the core

Even if many entries happen to be zero, explicitly programming them avoids
stale-memory behavior from previous runs.

## Full Formula Summary

For address `i`:

```text
x[i] = x_min + i * (x_max - x_min) / 255
y[i] = f(x[i])
q[i] = round(y[i] * 128)
q_sat[i] = min(127, max(-128, q[i]))
lut_byte[i] = q_sat[i] encoded as signed 8-bit two's complement
```

Then write:

```text
address i <- lut_byte[i]
```

## Example: Sigmoid Over [-10, 10]

Use:

```text
x_min = -10
x_max = 10
f(x) = 1 / (1 + e^(-x))
```

Then:

```text
x[i] = -10 + 20 * i / 255
```

and:

```text
lut[i] = sat_q07(sigmoid(x[i]))
```

Where `sat_q07(...)` means:

1. multiply by `128`
2. round
3. clamp to `[-128, 127]`
4. encode as 8-bit signed

## Common Mistakes

### 1. Using Address 1 As The First Entry

Do not do this.

The first LUT entry is address `0`, not address `1`.

### 2. Dividing By 256 Instead Of 255

Do not use:

```text
(x_max - x_min) / 256
```

That will miss the top endpoint.

Use:

```text
(x_max - x_min) / 255
```

### 3. Forgetting Q0.7 Scaling

Do not write floating-point values directly.

The LUT stores signed `Q0.7` bytes, not reals.

### 4. Forgetting Saturation

If the quantized value exceeds the signed 8-bit range, clamp it before writing.

### 5. Confusing The Mapper Domain With The Mathematical X Domain

The mapper input is signed `Q0.7`, but you are free to interpret the LUT range
as `[-6, 6]`, `[-10, 10]`, or something else.

That scaling choice is defined by how you build the table.

## Recommended Checklist

When creating a new LUT:

1. Choose `x_min` and `x_max`
2. Decide the function `f(x)`
3. Generate `256` samples with endpoint-inclusive spacing
4. Compute all `f(x[i])`
5. Convert each one to signed `Q0.7`
6. Store entry `i` at address `i`
7. Keep `START_REG = 0`
8. Program all `256` LUT entries through `LUT_ADDR`, `LUT_DATA`, `LUT_CTRL`
9. Start the core only after LUT loading is complete

## Practical Interpretation

You can think of the LUT like this:

- `memory_mapper` converts the signed neuron result into an address
- address `0` means "lowest modeled X"
- address `255` means "highest modeled X"
- the LUT entry at that address stores the quantized function value

So if you change the modeled function range from `[-6, 6]` to `[-10, 10]`, the
hardware does not change. Only the LUT contents change.
