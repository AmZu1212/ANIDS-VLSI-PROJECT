from __future__ import annotations

import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from anids_reference_model import REPO_ROOT, load_hex_vector, run_anids_model, zero_initialized_model


ZERO_LUT_ADDR = 1 << 7


@dataclass
class CompareCase:
    name: str
    vector_file: Path
    threshold: int
    lut_zero_value: int


CASES = [
    CompareCase(
        name="zero_case",
        vector_file=REPO_ROOT / "Verification" / "zero_order" / "data" / "dma_all_zeros.data",
        threshold=1,
        lut_zero_value=0x00,
    ),
    CompareCase(
        name="ones_case",
        vector_file=REPO_ROOT / "Verification" / "zero_order" / "data" / "dma_all_ones.data",
        threshold=0,
        lut_zero_value=0xFF,
    ),
]


RTL_PATTERN = re.compile(r"RTL_COMPARE case=(?P<case>\S+) loss=(?P<loss>-?\d+) outlier=(?P<outlier>[01]) status=(?P<status>\d+)")


def reference_for_case(case: CompareCase) -> tuple[int, int]:
    config = zero_initialized_model(
        n=128,
        threshold=case.threshold,
        lut_updates={ZERO_LUT_ADDR: case.lut_zero_value},
    )
    vector = load_hex_vector(case.vector_file)
    return run_anids_model(vector, config)


def run_rtl_compare_tb() -> dict[str, tuple[int, int, int]]:
    cmd = [sys.executable, "run.py", "Verification/zero_order/zero_order_loss_compare_tb.sv"]
    proc = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    if proc.returncode != 0:
        raise SystemExit(proc.returncode)

    results: dict[str, tuple[int, int, int]] = {}
    for line in proc.stdout.splitlines():
        match = RTL_PATTERN.search(line)
        if match:
            results[match.group("case")] = (
                int(match.group("loss")),
                int(match.group("outlier")),
                int(match.group("status")),
            )
    return results


def main() -> int:
    rtl_results = run_rtl_compare_tb()
    expected_names = {case.name for case in CASES}
    if rtl_results.keys() != expected_names:
        missing = expected_names - rtl_results.keys()
        extra = rtl_results.keys() - expected_names
        if missing:
            print(f"Missing RTL results for: {sorted(missing)}")
        if extra:
            print(f"Unexpected RTL results for: {sorted(extra)}")
        return 1

    failed = False
    for case in CASES:
        reference_loss, reference_outlier = reference_for_case(case)
        rtl_loss, rtl_outlier, rtl_status = rtl_results[case.name]
        print(
            f"REFERENCE_COMPARE case={case.name} "
            f"reference_loss={reference_loss} rtl_loss={rtl_loss} "
            f"reference_outlier={reference_outlier} rtl_outlier={rtl_outlier} "
            f"rtl_status={rtl_status}"
        )
        if (reference_loss, reference_outlier) != (rtl_loss, rtl_outlier):
            failed = True

    if failed:
        print("COMPARE_FAILED")
        return 1

    print("COMPARE_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
