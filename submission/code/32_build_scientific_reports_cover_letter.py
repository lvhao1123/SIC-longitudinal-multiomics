"""Build the private Scientific Reports cover letter outside the repository."""
from __future__ import annotations

import argparse
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    module = load_builder()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    module.build_cover_letter(args.out)
    text = "\n".join(p.text for p in module.Document(args.out).paragraphs)
    required = (
        "This manuscript was previously submitted to the Journal of Intensive Care and is now being submitted to Scientific Reports following a Springer Nature journal-transfer recommendation.",
        "We have no preferred reviewers and request no reviewer exclusions.",
        "We have had no prior discussions with a Scientific Reports Editorial Board Member regarding this work.",
    )
    missing = [x for x in required if x not in text]
    if missing:
        raise RuntimeError(f"Cover letter is missing required statements: {missing}")
    print(f"Built private cover letter: {args.out}")


if __name__ == "__main__":
    main()
