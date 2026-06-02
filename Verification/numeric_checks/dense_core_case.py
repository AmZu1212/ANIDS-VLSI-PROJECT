from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path

from Verification.scripts.anids_reference_model import (
    DMA_VECTOR_WIDTH,
    HIDDEN_NEURON_COUNT,
    OUTPUT_NEURON_COUNT,
    Q07_WIDTH,
    AnidsConfig,
    run_anids_model_detailed,
    to_signed,
    wrap_unsigned,
)


ROOT = Path(__file__).resolve().parent
GENERATED_DIR = ROOT / "generated" / "dense_core"

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

Q07_NONZERO = [-128, -96, -64, -48, -32, -16, -8, -4, -2, -1, 1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 127]


@dataclass
class DenseCoreExpected:
    loss: int
    outlier: int
    threshold: int
    vector_hex: str
    hidden_first8: list[int]
    output_first8: list[int]


def _patterned_q07(index: int, salt: int) -> int:
    return Q07_NONZERO[((index * 7) + salt) % len(Q07_NONZERO)]


def _build_vector() -> int:
    pair_pattern = [0b00, 0b01, 0b10, 0b11, 0b01, 0b11, 0b10, 0b00]
    value = 0
    for pair_idx in range(64):
        pair = pair_pattern[pair_idx % len(pair_pattern)]
        value |= (pair & 0x3) << (pair_idx * 2)
    return value


def _build_config() -> tuple[int, AnidsConfig]:
    vector = _build_vector()

    hidden_weights = []
    for neuron_idx in range(HIDDEN_NEURON_COUNT):
        weights = []
        for weight_idx in range(DMA_VECTOR_WIDTH):
            weights.append(_patterned_q07(neuron_idx * DMA_VECTOR_WIDTH + weight_idx, 3))
        hidden_weights.append(weights)

    hidden_biases = [_patterned_q07(idx, 5) for idx in range(HIDDEN_NEURON_COUNT)]

    output_weights = []
    for neuron_idx in range(OUTPUT_NEURON_COUNT):
        weights = []
        for weight_idx in range(HIDDEN_NEURON_COUNT):
            weights.append(_patterned_q07(neuron_idx * HIDDEN_NEURON_COUNT + weight_idx, 11))
        output_weights.append(weights)

    output_biases = [_patterned_q07(idx, 17) for idx in range(OUTPUT_NEURON_COUNT)]

    function_lut = [_patterned_q07(addr, 23) for addr in range(256)]

    config = AnidsConfig(
        n=128,
        threshold=0,
        hidden_weights=hidden_weights,
        hidden_biases=hidden_biases,
        output_weights=output_weights,
        output_biases=output_biases,
        function_lut=function_lut,
    )

    _, _, loss, _ = run_anids_model_detailed(vector, config)
    threshold = to_signed(loss - 1 if loss > -128 else loss, Q07_WIDTH)
    config.threshold = threshold
    return vector, config


def _core_prog_writes(config: AnidsConfig) -> list[tuple[int, int]]:
    writes: list[tuple[int, int]] = [(START_REG, 0), (N_REG, config.n), (THRESHOLD_REG, config.threshold)]

    for neuron_idx, weights in enumerate(config.hidden_weights):
        base = HL_WEIGHT_BASE + neuron_idx * DMA_VECTOR_WIDTH
        for weight_idx, value in enumerate(weights):
            writes.append((base + weight_idx, value))

    for neuron_idx, bias in enumerate(config.hidden_biases):
        writes.append((HL_BIAS_BASE + neuron_idx, bias))

    for neuron_idx, weights in enumerate(config.output_weights):
        base = OL_WEIGHT_BASE + neuron_idx * HIDDEN_NEURON_COUNT
        for weight_idx, value in enumerate(weights):
            writes.append((base + weight_idx, value))

    for neuron_idx, bias in enumerate(config.output_biases):
        writes.append((OL_BIAS_BASE + neuron_idx, bias))

    for addr, value in enumerate(config.function_lut):
        writes.append((LUT_ADDR_REG, addr))
        writes.append((LUT_DATA_REG, value))
        writes.append((LUT_CTRL_REG, 1))
        writes.append((LUT_CTRL_REG, 0))

    return writes


def _write_prog(path: Path, writes: list[tuple[int, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        for addr, data in writes:
            f.write(f"{addr:04X} {wrap_unsigned(data, 8):02X}\n")


def _write_vector(path: Path, vector: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{vector:032X}\n", encoding="ascii")


def _write_expected(path: Path, expected: DenseCoreExpected) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(asdict(expected), indent=2), encoding="ascii")


def generate_dense_core_case() -> tuple[Path, Path, Path, DenseCoreExpected]:
    vector, config = _build_config()
    hidden, output, loss, outlier = run_anids_model_detailed(vector, config)

    expected = DenseCoreExpected(
        loss=loss,
        outlier=outlier,
        threshold=config.threshold,
        vector_hex=f"{vector:032X}",
        hidden_first8=hidden[:8],
        output_first8=output[:8],
    )

    prog_path = GENERATED_DIR / "dense_core_full.prog"
    vector_path = GENERATED_DIR / "dense_core_full.vector"
    expected_path = GENERATED_DIR / "dense_core_full_expected.json"

    _write_prog(prog_path, _core_prog_writes(config))
    _write_vector(vector_path, vector)
    _write_expected(expected_path, expected)
    return prog_path, vector_path, expected_path, expected


if __name__ == "__main__":
    prog_path, vector_path, expected_path, expected = generate_dense_core_case()
    print(f"Generated dense core program: {prog_path}")
    print(f"Generated dense core vector : {vector_path}")
    print(f"Expected summary file      : {expected_path}")
    print(f"Expected loss              : {expected.loss}")
    print(f"Expected outlier           : {expected.outlier}")
