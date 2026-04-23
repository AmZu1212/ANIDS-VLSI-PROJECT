from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from anids_reference_model import (
    DMA_VECTOR_WIDTH,
    HIDDEN_NEURON_COUNT,
    LUT_ADDR_WIDTH,
    OUTPUT_NEURON_COUNT,
    Q07_WIDTH,
    AnidsConfig,
    memory_mapper,
    to_signed,
    wrap_unsigned,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = REPO_ROOT / "verification" / "zero_order" / "generated"

START_REG = 0
N_REG = 1
THRESHOLD_REG = 2
LUT_ADDR_REG = 4
LUT_DATA_REG = 5
LUT_CTRL_REG = 6
HL_WEIGHT_BASE = 8
HL_WEIGHT_COUNT = 64 * 128
HL_BIAS_BASE = HL_WEIGHT_BASE + HL_WEIGHT_COUNT
OL_WEIGHT_BASE = HL_BIAS_BASE + 64
OL_BIAS_BASE = OL_WEIGHT_BASE + (128 * 64)


@dataclass
class WeightedCase:
    name: str
    vector: int
    config: AnidsConfig
    notes: str


def _blank_config(threshold: int) -> AnidsConfig:
    return AnidsConfig(
        n=128,
        threshold=to_signed(threshold, Q07_WIDTH),
        hidden_weights=[[0 for _ in range(DMA_VECTOR_WIDTH)] for _ in range(HIDDEN_NEURON_COUNT)],
        hidden_biases=[0 for _ in range(HIDDEN_NEURON_COUNT)],
        output_weights=[[0 for _ in range(HIDDEN_NEURON_COUNT)] for _ in range(OUTPUT_NEURON_COUNT)],
        output_biases=[0 for _ in range(OUTPUT_NEURON_COUNT)],
        function_lut=[0 for _ in range(1 << LUT_ADDR_WIDTH)],
    )


def build_dense_case() -> WeightedCase:
    config = _blank_config(threshold=16)
    vector = (1 << DMA_VECTOR_WIDTH) - 1

    for idx in range(2, DMA_VECTOR_WIDTH):
        config.hidden_weights[0][idx] = 64
        config.hidden_weights[1][idx] = -64
        config.hidden_weights[2][idx] = 127

    config.hidden_biases[0] = 1
    config.hidden_biases[1] = 10
    config.hidden_biases[2] = 10

    config.output_weights[0][0] = 64
    config.output_weights[0][1] = -64
    config.output_weights[0][2] = 127
    config.output_biases[0] = 5

    config.output_weights[1][0] = -128
    config.output_weights[1][2] = 64
    config.output_biases[1] = -2

    config.function_lut[memory_mapper(0)] = -16
    config.function_lut[memory_mapper(6)] = 32
    config.function_lut[memory_mapper(-3)] = -32

    return WeightedCase(
        name="dense_weighted_case",
        vector=vector,
        config=config,
        notes="Dense all-ones vector with strong hidden activations, signed output weights, and signed LUT outputs.",
    )


def build_sparse_case() -> WeightedCase:
    config = _blank_config(threshold=1)
    vector = 0x6D

    config.hidden_weights[0][2] = 64
    config.hidden_weights[0][3] = -64
    config.hidden_weights[0][4] = 32
    config.hidden_weights[0][5] = 64
    config.hidden_weights[0][7] = 96
    config.hidden_biases[0] = 4

    config.hidden_weights[1][2] = -64
    config.hidden_weights[1][3] = -64
    config.hidden_biases[1] = 1

    config.hidden_weights[2][4] = 127
    config.hidden_weights[2][5] = 127

    config.hidden_weights[3][8] = -128
    config.hidden_biases[3] = 2

    config.output_weights[0][0] = 127
    config.output_weights[0][2] = 64
    config.output_weights[0][3] = -64
    config.output_biases[0] = 1

    config.output_weights[1][0] = -128
    config.output_weights[1][2] = 127

    config.function_lut[memory_mapper(0)] = 8
    config.function_lut[memory_mapper(1)] = 16
    config.function_lut[memory_mapper(-1)] = -16

    return WeightedCase(
        name="sparse_weighted_case",
        vector=vector,
        config=config,
        notes="Sparse mixed-sign weights to exercise index alignment, ReLU zeroing, and signed LUT mapping.",
    )


def iter_cases() -> list[WeightedCase]:
    return [build_dense_case(), build_sparse_case()]


def generate_case_files(case: WeightedCase) -> tuple[Path, Path]:
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    program_path = GENERATED_DIR / f"{case.name}.prog"
    vector_path = GENERATED_DIR / f"{case.name}.data"

    writes: list[tuple[int, int]] = []
    writes.append((START_REG, 0))
    writes.append((N_REG, case.config.n))
    writes.append((THRESHOLD_REG, wrap_unsigned(case.config.threshold, 8)))

    for neuron_idx, weights in enumerate(case.config.hidden_weights):
        base = HL_WEIGHT_BASE + neuron_idx * DMA_VECTOR_WIDTH
        for weight_idx, value in enumerate(weights):
            if value != 0:
                writes.append((base + weight_idx, wrap_unsigned(value, 8)))

    for neuron_idx, bias in enumerate(case.config.hidden_biases):
        if bias != 0:
            writes.append((HL_BIAS_BASE + neuron_idx, wrap_unsigned(bias, 8)))

    for neuron_idx, weights in enumerate(case.config.output_weights):
        base = OL_WEIGHT_BASE + neuron_idx * HIDDEN_NEURON_COUNT
        for weight_idx, value in enumerate(weights):
            if value != 0:
                writes.append((base + weight_idx, wrap_unsigned(value, 8)))

    for neuron_idx, bias in enumerate(case.config.output_biases):
        if bias != 0:
            writes.append((OL_BIAS_BASE + neuron_idx, wrap_unsigned(bias, 8)))

    for addr, value in sorted(enumerate(case.config.function_lut), key=lambda item: item[0]):
        if value != 0:
            writes.append((LUT_ADDR_REG, addr))
            writes.append((LUT_DATA_REG, wrap_unsigned(value, 8)))
            writes.append((LUT_CTRL_REG, 1))
            writes.append((LUT_CTRL_REG, 0))

    with program_path.open("w", encoding="ascii") as f:
        for addr, data in writes:
            f.write(f"{addr:04X} {data:02X}\n")

    with vector_path.open("w", encoding="ascii") as f:
        f.write(f"{case.vector:032X}\n")

    return program_path, vector_path
