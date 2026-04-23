from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from verification.math_regression.dense_core_case import generate_dense_core_case


RTL_RE = re.compile(r"RTL_DENSE_CORE loss=(?P<loss>-?\d+) outlier=(?P<outlier>[01])")


def main() -> int:
    _, _, expected_path, expected = generate_dense_core_case()
    proc = subprocess.run(
        [sys.executable, "run.py", "verification/math_regression/tb/dense_core_stress_tb.sv"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    if proc.returncode != 0:
        return proc.returncode

    match = RTL_RE.search(proc.stdout)
    if not match:
        print("DENSE_CORE_CHECK_FAILED: no RTL result found")
        return 1

    rtl_loss = int(match.group("loss"))
    rtl_outlier = int(match.group("outlier"))

    print(
        "DENSE_CORE_EXPECTED "
        f"loss={expected.loss} outlier={expected.outlier} threshold={expected.threshold}"
    )
    print(
        "DENSE_CORE_FIRST8 "
        f"hidden={expected.hidden_first8} output={expected.output_first8}"
    )
    print(f"DENSE_CORE_EXPECTED_FILE {expected_path}")

    if (rtl_loss, rtl_outlier) != (expected.loss, expected.outlier):
        print(
            "DENSE_CORE_CHECK_FAILED "
            f"rtl=({rtl_loss}, {rtl_outlier}) "
            f"expected=({expected.loss}, {expected.outlier})"
        )
        return 1

    print("DENSE_CORE_CHECK_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
