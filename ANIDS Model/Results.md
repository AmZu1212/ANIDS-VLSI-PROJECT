# RTL vs. C++ Model Comparison Results

## Summary Table

| Test Case | Purpose | Vectors Checked | Result |
| --- | --- | ---: | --- |
| `dense_directed_signed` | Directed dense signed-weight case for stronger hidden/output activations and signed LUT behavior. | 1 | PASS |
| `random_full_model_mixed` | Full-capacity mixed random model with many streamed vectors and mixed anomaly outputs. | 64 | PASS |
| `sparse_directed_signed` | Directed sparse signed-weight case for mixed signs, ReLU behavior, LUT mapping, and thresholding. | 1 | PASS |
| `zero_model_ones` | Full-capacity model with an all-ones input vector and lower threshold. | 1 | PASS |
| `zero_model_zeros` | Full-capacity model with an all-zero input vector and high threshold. | 1 | PASS |

## Per-Test Results

### `dense_directed_signed`

- Purpose: Directed dense signed-weight case for stronger hidden/output activations and signed LUT behavior.
- Input vectors checked: 1
- `cpp.out` and `verilog.out` matched exactly: Yes
- Final result: PASS
- Mismatch details: None

### `random_full_model_mixed`

- Purpose: Full-capacity mixed random model with 64 streamed vectors and both anomaly/non-anomaly behavior.
- Input vectors checked: 64
- `cpp.out` and `verilog.out` matched exactly: Yes
- Final result: PASS
- Mismatch details: None

### `sparse_directed_signed`

- Purpose: Directed sparse signed-weight case for mixed signs, ReLU behavior, LUT mapping, and thresholding.
- Input vectors checked: 1
- `cpp.out` and `verilog.out` matched exactly: Yes
- Final result: PASS
- Mismatch details: None

### `zero_model_ones`

- Purpose: Full-capacity model with an all-ones input vector and lower threshold.
- Input vectors checked: 1
- `cpp.out` and `verilog.out` matched exactly: Yes
- Final result: PASS
- Mismatch details: None

### `zero_model_zeros`

- Purpose: Full-capacity model with an all-zero input vector and high threshold.
- Input vectors checked: 1
- `cpp.out` and `verilog.out` matched exactly: Yes
- Final result: PASS
- Mismatch details: None

## Sample Matching Output

Example from `zero_model_zeros`:

```text
cpp.out:     RESULT vector=0 loss=63 anomaly=0
verilog.out: RESULT vector=0 loss=63 anomaly=0
```

## Final Conclusion

All RTL vs. C++ comparison tests passed.

No test failed.

No test was skipped or left unrunning.
