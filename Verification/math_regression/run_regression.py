from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from Verification.scripts.anids_reference_model import (
    run_anids_model_detailed,
    run_hidden_stage,
    run_output_stage,
    loss_result_direct,
    to_signed,
)
from Verification.math_regression.regression_cases import generate_all_cases


HIDDEN_RE = re.compile(r"RTL_HIDDEN case=(?P<case>\S+) data=(?P<data>[0-9a-fA-F]+)")
OUTPUT_RE = re.compile(r"RTL_OUTPUT case=(?P<case>\S+) data=(?P<data>[0-9a-fA-F]+)")
LOSS_RE = re.compile(r"RTL_LOSS case=(?P<case>\S+) loss=(?P<loss>-?\d+)")
CORE_RE = re.compile(r"RTL_CORE case=(?P<case>\S+) loss=(?P<loss>-?\d+) outlier=(?P<outlier>[01])")


def _run_tb(tb_path: str) -> str:
    proc = subprocess.run(
        [sys.executable, "run.py", tb_path],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    if proc.returncode != 0:
        raise SystemExit(proc.returncode)
    return proc.stdout


def _decode_hex_bytes(hex_string: str) -> list[int]:
    return [to_signed(int(hex_string[idx:idx + 2], 16), 8) for idx in range(0, len(hex_string), 2)]


def main() -> int:
    hidden_cases, output_cases, loss_cases, core_cases = generate_all_cases()

    hidden_out = _run_tb("Verification/math_regression/tb/hidden_stage_regression_tb.sv")
    output_out = _run_tb("Verification/math_regression/tb/output_stage_regression_tb.sv")
    loss_out = _run_tb("Verification/math_regression/tb/loss_stage_regression_tb.sv")
    core_out = _run_tb("Verification/math_regression/tb/core_stage_regression_tb.sv")

    hidden_results = {m.group("case"): _decode_hex_bytes(m.group("data")) for m in HIDDEN_RE.finditer(hidden_out)}
    output_results = {m.group("case"): _decode_hex_bytes(m.group("data")) for m in OUTPUT_RE.finditer(output_out)}
    loss_results = {m.group("case"): int(m.group("loss")) for m in LOSS_RE.finditer(loss_out)}
    core_results = {m.group("case"): (int(m.group("loss")), int(m.group("outlier"))) for m in CORE_RE.finditer(core_out)}

    failed = False

    for case in hidden_cases:
        rtl = hidden_results.get(case.name)
        if rtl != case.expected:
            print(f"HIDDEN_MISMATCH {case.name}")
            failed = True

    for case in output_cases:
        rtl = output_results.get(case.name)
        if rtl != case.expected:
            print(f"OUTPUT_MISMATCH {case.name}")
            failed = True

    for case in loss_cases:
        rtl = loss_results.get(case.name)
        if rtl != case.expected_loss:
            print(f"LOSS_MISMATCH {case.name}: rtl={rtl} golden={case.expected_loss}")
            failed = True

    for case in core_cases:
        rtl = core_results.get(case.name)
        if rtl != (case.expected_loss, case.expected_outlier):
            print(f"CORE_MISMATCH {case.name}: rtl={rtl} golden={(case.expected_loss, case.expected_outlier)}")
            failed = True

    total_tests = len(hidden_cases) + len(output_cases) + len(loss_cases) + len(core_cases)
    print(f"\nSUMMARY hidden={len(hidden_cases)} output={len(output_cases)} loss={len(loss_cases)} core={len(core_cases)} total={total_tests}")

    if failed:
        print("MATH_REGRESSION_FAILED")
        return 1

    print("MATH_REGRESSION_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
