"""Build the Scientific Reports composite Supplementary Information document.

This wrapper delegates to the frozen journal-conversion builder and intentionally
writes only public supplementary outputs.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent
BUILDER = HERE / "30_build_scientific_reports_manuscript.py"


def load_builder():
    spec = importlib.util.spec_from_file_location("scientific_reports_builder", BUILDER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load builder: {BUILDER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    module = load_builder()
    module.OUT.mkdir(parents=True, exist_ok=True)
    module.build_supplementary(
        module.OUT / "Scientific_Reports_Supplementary_Information.docx"
    )
    print("Built Scientific Reports Supplementary Information DOCX")


if __name__ == "__main__":
    main()
