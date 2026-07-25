"""Make Scientific Reports reference discovery independent of Word paragraph indices."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str, marker: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new, 1), encoding="utf-8")
        print(f"Patched reference discovery in {path}")
    elif marker in text:
        print(f"Reference discovery already patched in {path}")
    else:
        raise RuntimeError(f"Expected reference-discovery interface not found in {path}")


def main() -> None:
    builder = ROOT / "submission/code/30_build_scientific_reports_manuscript.py"
    old_builder = "raw_refs = {i - 166: SRC[i] for i in range(167, 196)}"
    new_builder = """reference_paragraphs = [text for text in SRC.values() if re.match(r'^\\d+\\.\\s+', text.strip())]\nraw_refs = {}\nfor text in reference_paragraphs:\n    match = re.match(r'^(\\d+)\\.\\s+', text.strip())\n    if match is None:\n        continue\n    raw_refs[int(match.group(1))] = text\nif sorted(raw_refs) != list(range(1, 30)):\n    raise RuntimeError(f'Expected references 1-29; found {sorted(raw_refs)}')"""
    replace_once(builder, old_builder, new_builder, "Expected references 1-29")

    support = ROOT / "submission/code/29_build_scientific_reports_support.py"
    old_support = """    for old_number, paragraph in enumerate(doc.paragraphs[167:196], start=1):\n        raw = re.sub(r\"^\\d+\\.\\s*\", \"\", paragraph.text.strip())"""
    new_support = """    reference_paragraphs = [paragraph for paragraph in doc.paragraphs if re.match(r\"^\\d+\\.\\s+\", paragraph.text.strip())]\n    if len(reference_paragraphs) != 29:\n        raise RuntimeError(f\"Expected 29 numbered references; found {len(reference_paragraphs)}\")\n    for paragraph in reference_paragraphs:\n        number_match = re.match(r\"^(\\d+)\\.\\s+\", paragraph.text.strip())\n        if number_match is None:\n            continue\n        old_number = int(number_match.group(1))\n        raw = re.sub(r\"^\\d+\\.\\s*\", \"\", paragraph.text.strip())"""
    replace_once(support, old_support, new_support, "Expected 29 numbered references")


if __name__ == "__main__":
    main()
