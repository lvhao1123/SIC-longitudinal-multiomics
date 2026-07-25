"""Patch deterministic Scientific Reports builders for robust DOCX discovery."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str, marker: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new, 1), encoding="utf-8")
        print(f"Patched {label} in {path}")
    elif marker in text:
        print(f"{label} already patched in {path}")
    else:
        raise RuntimeError(f"Expected {label} interface not found in {path}")


def main() -> None:
    builder = ROOT / "submission/code/30_build_scientific_reports_manuscript.py"
    old_builder = "raw_refs = {i - 166: SRC[i] for i in range(167, 196)}"
    new_builder = """reference_paragraphs = [text for text in SRC.values() if re.match(r'^\d+\.\s+', text.strip())]
raw_refs = {}
for text in reference_paragraphs:
    match = re.match(r'^(\d+)\.\s+', text.strip())
    if match is None:
        continue
    raw_refs[int(match.group(1))] = text
if sorted(raw_refs) != list(range(1, 30)):
    raise RuntimeError(f'Expected references 1-29; found {sorted(raw_refs)}')"""
    replace_once(
        builder,
        old_builder,
        new_builder,
        "Expected references 1-29",
        "reference discovery",
    )

    support = ROOT / "submission/code/29_build_scientific_reports_support.py"
    old_support = """    for old_number, paragraph in enumerate(doc.paragraphs[167:196], start=1):
        raw = re.sub(r"^\d+\.\s*", "", paragraph.text.strip())"""
    new_support = """    reference_paragraphs = [paragraph for paragraph in doc.paragraphs if re.match(r"^\d+\.\s+", paragraph.text.strip())]
    if len(reference_paragraphs) != 29:
        raise RuntimeError(f"Expected 29 numbered references; found {len(reference_paragraphs)}")
    for paragraph in reference_paragraphs:
        number_match = re.match(r"^(\d+)\.\s+", paragraph.text.strip())
        if number_match is None:
            continue
        old_number = int(number_match.group(1))
        raw = re.sub(r"^\d+\.\s*", "", paragraph.text.strip())"""
    replace_once(
        support,
        old_support,
        new_support,
        "Expected 29 numbered references",
        "support-map reference discovery",
    )

    old_cross_audit = """    text = "\n".join([p.text for p in main_doc.paragraphs] + [p.text for p in supp_doc.paragraphs])"""
    new_cross_audit = """    paragraph_text = [p.text for p in main_doc.paragraphs] + [p.text for p in supp_doc.paragraphs]
    table_text = [
        cell.text
        for document in (main_doc, supp_doc)
        for table in document.tables
        for row in table.rows
        for cell in row.cells
    ]
    text = "\n".join(paragraph_text + table_text)"""
    replace_once(
        support,
        old_cross_audit,
        new_cross_audit,
        "for document in (main_doc, supp_doc)",
        "cross-reference table-cell discovery",
    )


if __name__ == "__main__":
    main()
