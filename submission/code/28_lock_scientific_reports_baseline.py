"""Lock Scientific Reports conversion inputs to the immutable JIC release hashes."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

REQUIRED = (
    "submission/manuscript_files/JIC_manuscript_clean.docx",
    "submission/manuscript_files/Additional_file_1_Supplementary_methods_and_figures.docx",
    "submission/manuscript_files/Additional_file_2_Supplementary_Tables_S1-S8.zip",
    "submission/manuscript_files/STROBE_checklist_cohort_completed.docx",
    "submission/numeric_truth_table.tsv",
    "submission/numeric_truth_dictionary.tsv",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--manifest", type=Path, default=Path("submission/public_manifest.tsv"))
    parser.add_argument("--out", type=Path, default=Path("submission/qa/scientific_reports_baseline_lock.json"))
    args = parser.parse_args()
    repo = args.repo_root.resolve()
    with (repo / args.manifest).open(encoding="utf-8", newline="") as handle:
        rows = {row["path"]: row for row in csv.DictReader(handle, delimiter="\t")}
    files = []
    for rel in REQUIRED:
        if rel not in rows:
            raise RuntimeError(f"Required baseline path is absent from the manifest: {rel}")
        path = repo / rel
        if not path.exists():
            raise FileNotFoundError(path)
        expected = rows[rel]["sha256"]
        observed = sha256(path)
        files.append({"path": rel, "expected_sha256": expected, "observed_sha256": observed, "match": expected == observed})
    report = {"source_tag": "jic-submission-v1.0", "manifest": str(args.manifest), "files": files, "all_match": all(x["match"] for x in files)}
    out = repo / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    if not report["all_match"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
