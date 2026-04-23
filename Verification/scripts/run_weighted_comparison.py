from __future__ import annotations

import re
import subprocess
import sys

from anids_reference_model import run_anids_model_detailed
from generate_weighted_test_cases import REPO_ROOT, generate_case_files, iter_cases


RTL_PATTERN = re.compile(r"RTL_WEIGHTED_COMPARE case=(?P<case>\S+) loss=(?P<loss>-?\d+) outlier=(?P<outlier>[01])")


def run_rtl_compare_tb() -> dict[str, tuple[int, int]]:
    cmd = [sys.executable, "run.py", "verification/zero_order/weighted_loss_compare_tb.sv"]
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

    results: dict[str, tuple[int, int]] = {}
    for line in proc.stdout.splitlines():
        match = RTL_PATTERN.search(line)
        if match:
            results[match.group("case")] = (int(match.group("loss")), int(match.group("outlier")))
    return results


def main() -> int:
    cases = iter_cases()
    for case in cases:
        generate_case_files(case)

    rtl_results = run_rtl_compare_tb()
    failed = False

    for case in cases:
        hidden, output, reference_loss, reference_outlier = run_anids_model_detailed(case.vector, case.config)
        rtl_loss, rtl_outlier = rtl_results[case.name]
        print(f"\nCASE {case.name}")
        print(f"NOTES: {case.notes}")
        print(f"VECTOR: 0x{case.vector:032X}")
        print(f"HIDDEN[0:8]: {hidden[:8]}")
        print(f"OUTPUT[0:8]: {output[:8]}")
        print(
            f"REFERENCE loss={reference_loss} outlier={reference_outlier} | "
            f"RTL loss={rtl_loss} outlier={rtl_outlier}"
        )
        if (reference_loss, reference_outlier) != (rtl_loss, rtl_outlier):
            failed = True

    if failed:
        print("\nWEIGHTED_COMPARE_FAILED")
        return 1

    print("\nWEIGHTED_COMPARE_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
