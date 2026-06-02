from __future__ import annotations

import random
from dataclasses import dataclass
from pathlib import Path

from Verification.scripts.anids_reference_model import (
    DMA_VECTOR_WIDTH,
    HIDDEN_NEURON_COUNT,
    OUTPUT_NEURON_COUNT,
    Q07_WIDTH,
    AnidsConfig,
    direct_pair,
    memory_mapper,
    run_anids_model_detailed,
    run_hidden_stage,
    run_output_stage,
    loss_result_direct,
    to_signed,
    wrap_unsigned,
)


ROOT = Path(__file__).resolve().parent
GENERATED_DIR = ROOT / "generated"

SEED = 20260328
HIDDEN_CASE_COUNT = 30
OUTPUT_CASE_COUNT = 30
LOSS_CASE_COUNT = 30
CORE_CASE_COUNT = 10

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

Q07_VALUES = [-128, -96, -64, -48, -32, -16, -8, -4, -2, -1, 0, 1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 127]


@dataclass
class HiddenCase:
    name: str
    vector: int
    config: AnidsConfig
    expected: list[int]


@dataclass
class OutputCase:
    name: str
    hidden_inputs: list[int]
    config: AnidsConfig
    expected: list[int]


@dataclass
class LossCase:
    name: str
    vector: int
    function_results: list[int]
    config: AnidsConfig
    expected_loss: int


@dataclass
class CoreCase:
    name: str
    vector: int
    config: AnidsConfig
    expected_loss: int
    expected_outlier: int


def _blank_config(threshold: int = 0) -> AnidsConfig:
    return AnidsConfig(
        n=128,
        threshold=to_signed(threshold, Q07_WIDTH),
        hidden_weights=[[0 for _ in range(DMA_VECTOR_WIDTH)] for _ in range(HIDDEN_NEURON_COUNT)],
        hidden_biases=[0 for _ in range(HIDDEN_NEURON_COUNT)],
        output_weights=[[0 for _ in range(HIDDEN_NEURON_COUNT)] for _ in range(OUTPUT_NEURON_COUNT)],
        output_biases=[0 for _ in range(OUTPUT_NEURON_COUNT)],
        function_lut=[0 for _ in range(256)],
    )


def _random_q07(rng: random.Random, allow_zero: bool = True) -> int:
    values = Q07_VALUES if allow_zero else [value for value in Q07_VALUES if value != 0]
    return rng.choice(values)


def _random_vector(rng: random.Random) -> int:
    value = 0
    for pair_idx in range(64):
        pair = rng.randrange(4)
        value |= (pair & 0x3) << (pair_idx * 2)
    return value


def _write_prog(path: Path, writes: list[tuple[int, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        for addr, data in writes:
            f.write(f"{addr:04X} {wrap_unsigned(data, 8):02X}\n")


def _write_vector(path: Path, vector: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        f.write(f"{vector:032X}\n")


def _write_byte_lines(path: Path, values: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        for value in values:
            f.write(f"{wrap_unsigned(value, 8):02X}\n")


def _write_lut_updates(path: Path, lut_entries: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii") as f:
        for addr, value in enumerate(lut_entries):
            if value != 0:
                f.write(f"{addr:02X} {wrap_unsigned(value, 8):02X}\n")


def _regfile_writes_for_hidden(config: AnidsConfig) -> list[tuple[int, int]]:
    writes = [(N_REG, config.n)]
    for neuron_idx, weights in enumerate(config.hidden_weights):
        base = HL_WEIGHT_BASE + neuron_idx * DMA_VECTOR_WIDTH
        for weight_idx, value in enumerate(weights):
            if value != 0:
                writes.append((base + weight_idx, value))
    for neuron_idx, bias in enumerate(config.hidden_biases):
        if bias != 0:
            writes.append((HL_BIAS_BASE + neuron_idx, bias))
    return writes


def _regfile_writes_for_output(config: AnidsConfig) -> list[tuple[int, int]]:
    writes = [(N_REG, config.n)]
    for neuron_idx, weights in enumerate(config.output_weights):
        base = OL_WEIGHT_BASE + neuron_idx * HIDDEN_NEURON_COUNT
        for weight_idx, value in enumerate(weights):
            if value != 0:
                writes.append((base + weight_idx, value))
    for neuron_idx, bias in enumerate(config.output_biases):
        if bias != 0:
            writes.append((OL_BIAS_BASE + neuron_idx, bias))
    return writes


def _regfile_writes_for_core(config: AnidsConfig) -> list[tuple[int, int]]:
    writes = [(START_REG, 0), (N_REG, config.n), (THRESHOLD_REG, config.threshold)]
    writes.extend(_regfile_writes_for_hidden(config)[1:])
    writes.extend(_regfile_writes_for_output(config)[1:])
    for addr, value in enumerate(config.function_lut):
        if value != 0:
            writes.append((LUT_ADDR_REG, addr))
            writes.append((LUT_DATA_REG, value))
            writes.append((LUT_CTRL_REG, 1))
            writes.append((LUT_CTRL_REG, 0))
    return writes


def build_hidden_cases() -> list[HiddenCase]:
    rng = random.Random(SEED + 1)
    cases: list[HiddenCase] = []
    for idx in range(HIDDEN_CASE_COUNT):
        config = _blank_config()
        vector = _random_vector(rng)
        active_neurons = rng.sample(range(HIDDEN_NEURON_COUNT), 6)
        for neuron in active_neurons:
            for weight_idx in rng.sample(range(DMA_VECTOR_WIDTH), 12):
                config.hidden_weights[neuron][weight_idx] = _random_q07(rng, allow_zero=False)
            config.hidden_biases[neuron] = _random_q07(rng)
        expected = run_hidden_stage(vector, config)
        case = HiddenCase(name=f"hidden_{idx:03d}", vector=vector, config=config, expected=expected)
        _write_prog(GENERATED_DIR / "hidden" / f"{case.name}.prog", _regfile_writes_for_hidden(config))
        _write_vector(GENERATED_DIR / "hidden" / f"{case.name}.vector", vector)
        cases.append(case)
    return cases


def build_output_cases() -> list[OutputCase]:
    rng = random.Random(SEED + 2)
    cases: list[OutputCase] = []
    for idx in range(OUTPUT_CASE_COUNT):
        config = _blank_config()
        hidden_inputs = [_random_q07(rng) for _ in range(HIDDEN_NEURON_COUNT)]
        active_neurons = rng.sample(range(OUTPUT_NEURON_COUNT), 8)
        for neuron in active_neurons:
            for weight_idx in rng.sample(range(HIDDEN_NEURON_COUNT), 10):
                config.output_weights[neuron][weight_idx] = _random_q07(rng, allow_zero=False)
            config.output_biases[neuron] = _random_q07(rng)
        expected = run_output_stage(hidden_inputs, config)
        case = OutputCase(name=f"output_{idx:03d}", hidden_inputs=hidden_inputs, config=config, expected=expected)
        _write_prog(GENERATED_DIR / "output" / f"{case.name}.prog", _regfile_writes_for_output(config))
        _write_byte_lines(GENERATED_DIR / "output" / f"{case.name}.hidden", hidden_inputs)
        cases.append(case)
    return cases


def build_loss_cases() -> list[LossCase]:
    rng = random.Random(SEED + 3)
    cases: list[LossCase] = []
    for idx in range(LOSS_CASE_COUNT):
        config = _blank_config()
        vector = _random_vector(rng)
        output_results = [_random_q07(rng) for _ in range(OUTPUT_NEURON_COUNT)]
        used_addrs = sorted({memory_mapper(value) for value in output_results})
        for addr in used_addrs:
            config.function_lut[addr] = _random_q07(rng, allow_zero=False)
        function_results = [config.function_lut[memory_mapper(value)] for value in output_results]
        expected_loss = loss_result_direct(vector, output_results, config.function_lut, config.n)
        case = LossCase(
            name=f"loss_{idx:03d}",
            vector=vector,
            function_results=function_results,
            config=config,
            expected_loss=expected_loss,
        )
        _write_vector(GENERATED_DIR / "loss" / f"{case.name}.vector", vector)
        _write_byte_lines(GENERATED_DIR / "loss" / f"{case.name}.function", function_results)
        cases.append(case)
    return cases


def build_core_cases() -> list[CoreCase]:
    rng = random.Random(SEED + 4)
    cases: list[CoreCase] = []
    for idx in range(CORE_CASE_COUNT):
        config = _blank_config()
        vector = _random_vector(rng)

        active_hidden = rng.sample(range(HIDDEN_NEURON_COUNT), 6)
        for neuron in active_hidden:
            for weight_idx in rng.sample(range(DMA_VECTOR_WIDTH), 10):
                config.hidden_weights[neuron][weight_idx] = _random_q07(rng, allow_zero=False)
            config.hidden_biases[neuron] = _random_q07(rng)

        active_output = rng.sample(range(OUTPUT_NEURON_COUNT), 8)
        for neuron in active_output:
            for weight_idx in rng.sample(range(HIDDEN_NEURON_COUNT), 8):
                config.output_weights[neuron][weight_idx] = _random_q07(rng, allow_zero=False)
            config.output_biases[neuron] = _random_q07(rng)

        _, output_results, expected_loss, _ = run_anids_model_detailed(vector, config)
        used_addrs = sorted({memory_mapper(value) for value in output_results})
        for addr in used_addrs:
            config.function_lut[addr] = _random_q07(rng, allow_zero=False)

        _, _, expected_loss, _ = run_anids_model_detailed(vector, config)
        threshold_margin = rng.choice([-4, -2, -1, 0, 1, 2, 4])
        config.threshold = to_signed(expected_loss + threshold_margin, Q07_WIDTH)
        _, _, expected_loss, expected_outlier = run_anids_model_detailed(vector, config)

        case = CoreCase(
            name=f"core_{idx:03d}",
            vector=vector,
            config=config,
            expected_loss=expected_loss,
            expected_outlier=expected_outlier,
        )
        _write_prog(GENERATED_DIR / "core" / f"{case.name}.prog", _regfile_writes_for_core(config))
        _write_vector(GENERATED_DIR / "core" / f"{case.name}.vector", vector)
        cases.append(case)
    return cases


def generate_all_cases():
    hidden = build_hidden_cases()
    output = build_output_cases()
    loss = build_loss_cases()
    core = build_core_cases()
    return hidden, output, loss, core
