from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]

DMA_VECTOR_WIDTH = 128
HIDDEN_NEURON_COUNT = 64
OUTPUT_NEURON_COUNT = 128
Q07_WIDTH = 8
HL_ACC_WIDTH = 15
OL_ACC_WIDTH = 15
LF_ACC_WIDTH = 15
LUT_ADDR_WIDTH = 8


def wrap_unsigned(value: int, bits: int) -> int:
    return value & ((1 << bits) - 1)


def to_signed(value: int, bits: int) -> int:
    value = wrap_unsigned(value, bits)
    sign_bit = 1 << (bits - 1)
    return value - (1 << bits) if value & sign_bit else value


def wrap_signed(value: int, bits: int) -> int:
    return to_signed(value, bits)


def trunc_slice_signed(value: int, in_bits: int, msb: int, width: int) -> int:
    raw = wrap_unsigned(value, in_bits)
    lsb = msb - width + 1
    sliced = (raw >> lsb) & ((1 << width) - 1)
    return to_signed(sliced, width)


def saturating_add_q07(lhs: int, rhs: int) -> int:
    total = lhs + rhs
    if total > 127:
        return 127
    if total < -128:
        return -128
    return total


def relu_q07(value: int) -> int:
    return value if value > 0 else 0


def input_layer_pair(feature_vector: int, counter: int) -> int:
    if counter < 0:
        return 0
    bit0 = (feature_vector >> (counter * 2)) & 0x1
    bit1 = (feature_vector >> (counter * 2 + 1)) & 0x1
    return (bit1 << 1) | bit0


def direct_pair(feature_vector: int, counter: int) -> int:
    bit0 = (feature_vector >> (counter * 2)) & 0x1
    bit1 = (feature_vector >> (counter * 2 + 1)) & 0x1
    return (bit1 << 1) | bit0


def memory_mapper(in_value: int, in_width: int = 8, addr_width: int = LUT_ADDR_WIDTH) -> int:
    raw = wrap_unsigned(in_value, in_width)
    if addr_width == in_width:
        mapped = ((~(raw >> (in_width - 1)) & 0x1) << (in_width - 1)) | (raw & ((1 << (in_width - 1)) - 1))
    else:
        mapped = ((~(raw >> (in_width - 1)) & 0x1) << (addr_width - 1)) | ((raw >> 1) & ((1 << (addr_width - 1)) - 1))
    return wrap_unsigned(mapped, addr_width)


def hidden_neuron_result(feature_vector: int, weights: list[int], bias: int, n: int) -> int:
    acc = 0
    last_pair_index = (n >> 1) - 1
    for counter in range(last_pair_index + 1):
        pair = input_layer_pair(feature_vector, counter - 1)
        f0 = pair & 0x1
        f1 = (pair >> 1) & 0x1
        gated0 = weights[counter * 2] if f0 else 0
        gated1 = weights[counter * 2 + 1] if f1 else 0
        pair_sum = wrap_signed(gated0 + gated1, 9)
        acc_next = wrap_signed(acc + pair_sum, HL_ACC_WIDTH)
        if counter == last_pair_index:
            trunc8 = trunc_slice_signed(acc_next, HL_ACC_WIDTH, HL_ACC_WIDTH - 1, Q07_WIDTH)
            return relu_q07(saturating_add_q07(trunc8, bias))
        acc = acc_next
    raise RuntimeError("hidden_neuron_result: empty loop")


def hidden_neuron_result_direct(feature_vector: int, weights: list[int], bias: int, n: int) -> int:
    acc = 0
    last_pair_index = (n >> 1) - 1
    for counter in range(last_pair_index + 1):
        pair = direct_pair(feature_vector, counter)
        f0 = pair & 0x1
        f1 = (pair >> 1) & 0x1
        gated0 = weights[counter * 2] if f0 else 0
        gated1 = weights[counter * 2 + 1] if f1 else 0
        pair_sum = wrap_signed(gated0 + gated1, 9)
        acc_next = wrap_signed(acc + pair_sum, HL_ACC_WIDTH)
        if counter == last_pair_index:
            trunc8 = trunc_slice_signed(acc_next, HL_ACC_WIDTH, HL_ACC_WIDTH - 1, Q07_WIDTH)
            return relu_q07(saturating_add_q07(trunc8, bias))
        acc = acc_next
    raise RuntimeError("hidden_neuron_result_direct: empty loop")


def output_neuron_result(hidden_results: list[int], weights: list[int], bias: int, n: int) -> int:
    acc = 0
    last_step_index = (n >> 1) - 1
    for counter in range(last_step_index + 1):
        product_full = wrap_signed(hidden_results[counter] * weights[counter], 16)
        product_q07 = trunc_slice_signed(product_full, 16, 14, 8)
        acc_next = wrap_signed(acc + product_q07, OL_ACC_WIDTH)
        if counter == last_step_index:
            trunc8 = trunc_slice_signed(acc_next, OL_ACC_WIDTH, OL_ACC_WIDTH - 1, Q07_WIDTH)
            return saturating_add_q07(trunc8, bias)
        acc = acc_next
    raise RuntimeError("output_neuron_result: empty loop")


def run_hidden_stage(feature_vector: int, config: AnidsConfig) -> list[int]:
    return [
        hidden_neuron_result_direct(feature_vector, config.hidden_weights[idx], config.hidden_biases[idx], config.n)
        for idx in range(HIDDEN_NEURON_COUNT)
    ]


def run_output_stage(hidden_results: list[int], config: AnidsConfig) -> list[int]:
    return [
        output_neuron_result(hidden_results, config.output_weights[idx], config.output_biases[idx], config.n)
        for idx in range(OUTPUT_NEURON_COUNT)
    ]


def loss_result(feature_vector: int, output_results: list[int], lut_entries: list[int], n: int) -> int:
    acc = 0
    last_pair_index = (n >> 1) - 1
    for counter in range(last_pair_index + 1):
        pair = input_layer_pair(feature_vector, counter - 1)
        x0 = pair & 0x1
        x1 = (pair >> 1) & 0x1
        r0 = output_results[counter * 2]
        r1 = output_results[counter * 2 + 1]
        f0 = lut_entries[memory_mapper(r0)]
        f1 = lut_entries[memory_mapper(r1)]
        delta0 = x0 - f0
        delta1 = x1 - f1
        abs0 = abs(delta0)
        abs1 = abs(delta1)
        pair_sum = abs0 + abs1
        acc_next = wrap_signed(acc + pair_sum, LF_ACC_WIDTH)
        if counter == last_pair_index:
            return trunc_slice_signed(acc_next, LF_ACC_WIDTH, LF_ACC_WIDTH - 1, Q07_WIDTH)
        acc = acc_next
    raise RuntimeError("loss_result: empty loop")


def loss_result_direct(feature_vector: int, output_results: list[int], lut_entries: list[int], n: int) -> int:
    acc = 0
    last_pair_index = (n >> 1) - 1
    for counter in range(last_pair_index + 1):
        pair = direct_pair(feature_vector, counter)
        x0 = pair & 0x1
        x1 = (pair >> 1) & 0x1
        r0 = output_results[counter * 2]
        r1 = output_results[counter * 2 + 1]
        f0 = lut_entries[memory_mapper(r0)]
        f1 = lut_entries[memory_mapper(r1)]
        delta0 = x0 - f0
        delta1 = x1 - f1
        abs0 = abs(delta0)
        abs1 = abs(delta1)
        pair_sum = abs0 + abs1
        acc_next = wrap_signed(acc + pair_sum, LF_ACC_WIDTH)
        if counter == last_pair_index:
            return trunc_slice_signed(acc_next, LF_ACC_WIDTH, LF_ACC_WIDTH - 1, Q07_WIDTH)
        acc = acc_next
    raise RuntimeError("loss_result_direct: empty loop")


@dataclass
class AnidsConfig:
    n: int
    threshold: int
    hidden_weights: list[list[int]]
    hidden_biases: list[int]
    output_weights: list[list[int]]
    output_biases: list[int]
    function_lut: list[int]


def run_anids_model_detailed(feature_vector: int, config: AnidsConfig) -> tuple[list[int], list[int], int, int]:
    hidden = [
        hidden_neuron_result(feature_vector, config.hidden_weights[idx], config.hidden_biases[idx], config.n)
        for idx in range(HIDDEN_NEURON_COUNT)
    ]
    output = [
        output_neuron_result(hidden, config.output_weights[idx], config.output_biases[idx], config.n)
        for idx in range(OUTPUT_NEURON_COUNT)
    ]
    mae_loss = loss_result(feature_vector, output, config.function_lut, config.n)
    anomaly = 1 if mae_loss > config.threshold else 0
    return hidden, output, mae_loss, anomaly


def run_anids_model(feature_vector: int, config: AnidsConfig) -> tuple[int, int]:
    _, _, mae_loss, anomaly = run_anids_model_detailed(feature_vector, config)
    return mae_loss, anomaly


def load_hex_vector(path: str | Path, bits: int = DMA_VECTOR_WIDTH) -> int:
    raw = Path(path).read_text().strip().splitlines()[0].strip()
    return wrap_unsigned(int(raw, 16), bits)


def zero_initialized_model(n: int, threshold: int, lut_updates: dict[int, int]) -> AnidsConfig:
    hidden_weights = [[0 for _ in range(DMA_VECTOR_WIDTH)] for _ in range(HIDDEN_NEURON_COUNT)]
    hidden_biases = [0 for _ in range(HIDDEN_NEURON_COUNT)]
    output_weights = [[0 for _ in range(HIDDEN_NEURON_COUNT)] for _ in range(OUTPUT_NEURON_COUNT)]
    output_biases = [0 for _ in range(OUTPUT_NEURON_COUNT)]
    function_lut = [0 for _ in range(1 << LUT_ADDR_WIDTH)]
    for addr, value in lut_updates.items():
        function_lut[addr] = to_signed(value, Q07_WIDTH)
    return AnidsConfig(
        n=n,
        threshold=to_signed(threshold, Q07_WIDTH),
        hidden_weights=hidden_weights,
        hidden_biases=hidden_biases,
        output_weights=output_weights,
        output_biases=output_biases,
        function_lut=function_lut,
    )
