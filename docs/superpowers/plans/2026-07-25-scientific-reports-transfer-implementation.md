# Scientific Reports Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the immutable `jic-submission-v1.0` package into a fully validated Scientific Reports submission package without changing any frozen scientific result.

**Architecture:** Treat the JIC release as read-only input and generate a separate Scientific Reports submission subtree. Build outputs through deterministic Python scripts, preserve machine-readable supplementary workbooks, and validate text, numbers, cross-references, document hygiene, rendering, privacy, hashes, and release metadata before opening a pull request.

**Tech Stack:** Python 3, `python-docx`, OOXML/ZIP inspection, LibreOffice headless rendering, R 4.4.2/testthat, `artifact_tool` for XLSX editing, SHA-256 manifests, Git/GitHub Actions.

## Global Constraints

- Authoritative baseline: GitHub tag `jic-submission-v1.0` only.
- Target branch: `release/scientific-reports-submission-v1.1`.
- Target article type: `Article` in `Scientific Reports`.
- Manuscript title must remain exactly: `Landmark-specific transcriptomic and proteomic associations with 60-day mortality in Day-1-defined sepsis-induced coagulopathy: a multicentre longitudinal cohort study`.
- No cohort count, event count, HR, CI, P value, FDR, NES, pathway direction, model definition, estimand, figure, or frozen QA result may change without a separately documented discrepancy and explicit author approval.
- No new statistical analysis, pathway analysis, subgroup analysis, prediction model, or mechanistic experiment.
- Abstract must be unstructured and contain no more than 200 words.
- Keywords must be exactly six: Sepsis-induced coagulopathy; Multi-omics; Landmark analysis; Transcriptomics; Proteomics; Mortality.
- Main-text order: Title page; Abstract; Keywords; Introduction; Results; Discussion; Methods; Data availability; Code availability; References; Acknowledgements; Author contributions; Competing interests; Figure legends; Table 1.
- `AI-assisted tools in manuscript and code preparation` must be the final Methods subsection.
- Main Table 1 must fit on one rendered page; the complete baseline table becomes Supplementary Table S9.
- Submission-facing supplementary figures must be renamed from A1-A9 to S1-S9 everywhere.
- Existing S1-S8 workbooks remain separate machine-readable files.
- Composite Supplementary Information must be produced as DOCX and PDF and remain below 50 MB.
- Clean files must contain no comments or tracked changes; the highlighted manuscript uses yellow highlighting only for substantive edits defined in the approved design.
- The original `jic-submission-v1.0` tag and release must never be edited, retagged, deleted, or overwritten.
- The new release tag is `scientific-reports-submission-v1.1`, created only from the final merged `main` commit and dated with the actual publication date.
- Cover Letter is a private submission file and must not be included in the public GitHub release.

---

## File Structure

### New production scripts

- `submission/code/28_lock_scientific_reports_baseline.py` - verify baseline hashes and extract a deterministic text/table inventory.
- `submission/code/29_build_scientific_reports_manuscript.py` - build clean and highlighted main manuscripts plus revision report.
- `submission/code/30_build_scientific_reports_supplementary.py` - build the composite Supplementary Information DOCX/PDF and submission-facing S1-S9 figure copies.
- `submission/code/31_build_scientific_reports_cover_letter.py` - build the private Cover Letter.
- `submission/code/32_build_scientific_reports_strobe.py` - update STROBE after final pagination stabilises.
- `submission/code/33_validate_scientific_reports_package.py` - run semantic, numerical, cross-reference, hygiene, and package validations.
- `submission/code/34_build_scientific_reports_release_manifest.R` - rebuild the Scientific Reports manifest and SHA-256 layer.

### New manuscript support files

- `submission/manuscript_support/scientific_reports_text_map.tsv` - paragraph-level source, destination, edit class, and approval boundary.
- `submission/manuscript_support/scientific_reports_reference_map.tsv` - old reference number, new number, DOI/PMID, and verification status.
- `submission/manuscript_support/scientific_reports_table1_rows.tsv` - exact rows retained in main Table 1.
- `submission/manuscript_support/scientific_reports_crossref_map.tsv` - A1-A9 to S1-S9 and all manuscript/supplement citations.

### New submission-facing files

Create under `submission/manuscript_files/scientific_reports/`:

- `Scientific_Reports_manuscript_clean.docx`
- `Scientific_Reports_manuscript_highlighted.docx`
- `Scientific_Reports_revision_report.docx`
- `Scientific_Reports_Supplementary_Information.docx`
- `Scientific_Reports_Supplementary_Information.pdf`
- `Supplementary_Table_S1_Clinical_variable_definitions.xlsx`
- `Supplementary_Table_S2_Clinical_univariable_Cox.xlsx`
- `Supplementary_Table_S3_RNA_gene_wise_Cox_PH.xlsx`
- `Supplementary_Table_S4_RNA_Hallmark_GSEA.xlsx`
- `Supplementary_Table_S5_Protein_wise_Cox_PH.xlsx`
- `Supplementary_Table_S6_Protein_Hallmark_GSEA.xlsx`
- `Supplementary_Table_S7_Cross_omics_models.xlsx`
- `Supplementary_Table_S8_D5_availability_IPW.xlsx`
- `Supplementary_Table_S9_Complete_baseline_characteristics.xlsx`
- `STROBE_Scientific_Reports_completed.docx`
- `STROBE_Scientific_Reports_audit.tsv`

Create privately in `/mnt/data/scientific_reports_private_submission/` and do not commit:

- `Scientific_Reports_Cover_Letter.docx`

### New QA files

- `submission/qa/scientific_reports_baseline_lock.json`
- `submission/qa/scientific_reports_manuscript_validation.json`
- `submission/qa/scientific_reports_cross_reference_audit.tsv`
- `submission/qa/scientific_reports_numeric_audit.tsv`
- `submission/qa/scientific_reports_render_audit.tsv`
- `submission/qa/scientific_reports_package_validation.json`

### Tests and metadata

- Create `tests/testthat/test-scientific-reports-release-metadata.R`.
- Create `tests/testthat/test-scientific-reports-package.R`.
- Modify `README.md`.
- Modify `CITATION.cff` only immediately before the new release freeze.
- Modify `submission/public_manifest.tsv` through the manifest builder, never by hand.

---

### Task 1: Lock the immutable JIC baseline

**Files:**
- Create: `submission/code/28_lock_scientific_reports_baseline.py`
- Create: `submission/qa/scientific_reports_baseline_lock.json`
- Test: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: `submission/public_manifest.tsv`, the four JIC submission files, all frozen source-data and numerical-truth files.
- Produces: JSON containing `path`, `expected_sha256`, `observed_sha256`, `bytes`, and `match` for every required baseline file.

- [ ] **Step 1: Write the failing baseline-lock test**

```r
testthat::test_that("Scientific Reports baseline lock is complete and green", {
  path <- file.path(repo_root, "submission/qa/scientific_reports_baseline_lock.json")
  testthat::expect_true(file.exists(path))
  lock <- jsonlite::read_json(path, simplifyVector = TRUE)
  testthat::expect_identical(lock$source_tag, "jic-submission-v1.0")
  testthat::expect_true(isTRUE(lock$all_match))
  testthat::expect_true(all(lock$files$match))
})
```

- [ ] **Step 2: Run the test and verify that it fails**

Run:

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: FAIL because the lock JSON and builder do not exist.

- [ ] **Step 3: Implement deterministic hash verification**

The script must:

```python
REQUIRED = [
    "submission/manuscript_files/JIC_manuscript_clean.docx",
    "submission/manuscript_files/Additional_file_1_Supplementary_methods_and_figures.docx",
    "submission/manuscript_files/Additional_file_2_Supplementary_Tables_S1-S8.zip",
    "submission/manuscript_files/STROBE_checklist_cohort_completed.docx",
    "submission/numeric_truth_table.tsv",
    "submission/numeric_truth_dictionary.tsv",
]
```

For each path, read the expected SHA-256 from `submission/public_manifest.tsv`, calculate the observed SHA-256, fail on a missing path or mismatch, and write sorted JSON with `source_tag: jic-submission-v1.0` and `all_match`.

- [ ] **Step 4: Run the lock builder and test**

```bash
python submission/code/28_lock_scientific_reports_baseline.py \
  --repo-root . \
  --manifest submission/public_manifest.tsv \
  --out submission/qa/scientific_reports_baseline_lock.json
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: PASS and `all_match=true`.

- [ ] **Step 5: Commit**

```bash
git add submission/code/28_lock_scientific_reports_baseline.py \
        submission/qa/scientific_reports_baseline_lock.json \
        tests/testthat/test-scientific-reports-package.R
git commit -m "test: lock Scientific Reports baseline"
```

---

### Task 2: Build the approved editorial map and reference verification map

**Files:**
- Create: `submission/manuscript_support/scientific_reports_text_map.tsv`
- Create: `submission/manuscript_support/scientific_reports_reference_map.tsv`
- Create: `submission/manuscript_support/scientific_reports_crossref_map.tsv`
- Test: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: paragraphs, headings, tables, and reference list from the JIC manuscript and Supplementary Information.
- Produces: deterministic edit instructions used by Tasks 3-6.

- [ ] **Step 1: Add failing map-completeness tests**

```r
testthat::test_that("Scientific Reports editorial maps have no unresolved rows", {
  text_map <- read.delim(file.path(repo_root, "submission/manuscript_support/scientific_reports_text_map.tsv"), check.names = FALSE)
  ref_map <- read.delim(file.path(repo_root, "submission/manuscript_support/scientific_reports_reference_map.tsv"), check.names = FALSE)
  crossref <- read.delim(file.path(repo_root, "submission/manuscript_support/scientific_reports_crossref_map.tsv"), check.names = FALSE)
  testthat::expect_false(any(is.na(text_map$destination_section) | text_map$destination_section == ""))
  testthat::expect_true(all(text_map$edit_class %in% c("unchanged", "clarification", "interpretive expansion", "claim restriction", "journal compliance", "structural relocation", "cross-reference renumbering")))
  testthat::expect_false(any(ref_map$verification_status != "verified"))
  testthat::expect_setequal(crossref$old_id, paste0("A", 1:9))
  testthat::expect_setequal(crossref$new_id, paste0("S", 1:9))
})
```

- [ ] **Step 2: Run the tests and verify failure**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: FAIL because the maps are absent.

- [ ] **Step 3: Populate the text map**

Required columns:

```text
source_order	source_heading	source_sha256	destination_section	destination_order	edit_class	highlight	approved_boundary
```

Every substantive paragraph must have one destination. `highlight` is `TRUE` only for the five approved highlighted-edit classes; structural moves and systematic renumbering use `FALSE`.

- [ ] **Step 4: Populate and verify the reference map**

Required columns:

```text
old_number	new_number	first_author	year	title	doi_or_pmid	primary_source_url	verification_status
```

Verify every reference against a primary bibliographic source. Preserve citation-to-reference mapping. Add a new reference only when it directly supports an approved interpretive clarification and record `old_number=NEW`.

- [ ] **Step 5: Populate the cross-reference map**

Include exact filename and caption mappings from A1-A9 to S1-S9 plus every main-text citation location.

- [ ] **Step 6: Run tests and commit**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
git add submission/manuscript_support/scientific_reports_*.tsv tests/testthat/test-scientific-reports-package.R
git commit -m "docs: define Scientific Reports editorial maps"
```

---

### Task 3: Build the Scientific Reports main manuscript and revision report

**Files:**
- Create: `submission/code/29_build_scientific_reports_manuscript.py`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_clean.docx`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_highlighted.docx`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_revision_report.docx`
- Create: `submission/qa/scientific_reports_manuscript_validation.json`
- Test: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: baseline JIC manuscript, text map, reference map, Table 1 row map from Task 4, and final Scientific Reports release URL placeholder token `[[SCIENTIFIC_REPORTS_RELEASE_URL]]`.
- Produces: clean manuscript, highlighted manuscript, revision report, and JSON validation summary.

- [ ] **Step 1: Add failing manuscript-interface tests**

```r
testthat::test_that("Scientific Reports manuscripts satisfy structural rules", {
  report <- jsonlite::read_json(file.path(repo_root, "submission/qa/scientific_reports_manuscript_validation.json"), simplifyVector = TRUE)
  testthat::expect_true(isTRUE(report$all_pass))
  testthat::expect_lte(report$abstract_words, 200)
  testthat::expect_identical(report$keyword_count, 6L)
  testthat::expect_identical(report$title, "Landmark-specific transcriptomic and proteomic associations with 60-day mortality in Day-1-defined sepsis-induced coagulopathy: a multicentre longitudinal cohort study")
  testthat::expect_false(report$residual_A_figure_citations)
  testthat::expect_false(report$clean_has_comments)
  testthat::expect_false(report$clean_has_tracked_changes)
})
```

- [ ] **Step 2: Run the test and verify failure**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: FAIL because outputs do not exist.

- [ ] **Step 3: Implement document construction**

Use `python-docx` for paragraphs, styles, tables, section order, page numbers, and line-numbering OOXML. The builder must:

```python
SECTION_ORDER = [
    "Abstract", "Keywords", "Introduction", "Results", "Discussion", "Methods",
    "Data availability", "Code availability", "References", "Acknowledgements",
    "Author contributions", "Competing interests", "Figure legends", "Table 1",
]
KEYWORDS = [
    "Sepsis-induced coagulopathy", "Multi-omics", "Landmark analysis",
    "Transcriptomics", "Proteomics", "Mortality",
]
```

It must also:

- preserve the exact approved title and author/affiliation block;
- write a single-paragraph abstract of at most 200 words using frozen principal results only;
- relocate Background content to Introduction;
- place Results before Discussion and Methods;
- merge Conclusions into the final Discussion paragraph;
- ensure the final Methods subsection is `AI-assisted tools in manuscript and code preparation` with the approved disclosure verbatim;
- move ethics and informed-consent language into Methods;
- separate Data availability and Code availability;
- use Nature-style references while preserving mapping;
- insert one-page concise Table 1 from Task 4;
- include `Supplementary Table S9` in the Table 1 legend and Results text;
- replace every A1-A9 citation with S1-S9;
- generate a clean file with no comments or tracked changes;
- generate a highlighted file in which approved substantive text runs use yellow highlighting;
- generate a revision report grouped by edit class.

- [ ] **Step 4: Validate document XML and text**

The script must calculate and write:

```json
{
  "title": "...",
  "abstract_words": 0,
  "keyword_count": 6,
  "section_order_pass": true,
  "ird_words": 0,
  "residual_A_figure_citations": false,
  "clean_has_comments": false,
  "clean_has_tracked_changes": false,
  "highlighted_has_yellow_highlight": true,
  "ai_statement_exact": true,
  "all_pass": true
}
```

`ird_words` means Introduction + Results + Discussion words and must be no more than 4,500 unless the author approves a documented exception.

- [ ] **Step 5: Run builder and tests**

```bash
python submission/code/29_build_scientific_reports_manuscript.py \
  --source submission/manuscript_files/JIC_manuscript_clean.docx \
  --text-map submission/manuscript_support/scientific_reports_text_map.tsv \
  --reference-map submission/manuscript_support/scientific_reports_reference_map.tsv \
  --table1-map submission/manuscript_support/scientific_reports_table1_rows.tsv \
  --out-dir submission/manuscript_files/scientific_reports \
  --validation-out submission/qa/scientific_reports_manuscript_validation.json
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add submission/code/29_build_scientific_reports_manuscript.py \
        submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_*.docx \
        submission/manuscript_files/scientific_reports/Scientific_Reports_revision_report.docx \
        submission/qa/scientific_reports_manuscript_validation.json \
        tests/testthat/test-scientific-reports-package.R
git commit -m "feat: build Scientific Reports manuscript package"
```

---

### Task 4: Create concise main Table 1 and complete Supplementary Table S9

**Files:**
- Create: `submission/manuscript_support/scientific_reports_table1_rows.tsv`
- Create: `submission/manuscript_files/scientific_reports/Supplementary_Table_S9_Complete_baseline_characteristics.xlsx`
- Modify through Task 3 builder: main manuscript Table 1.
- Test: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: the frozen full Table 1 in the JIC manuscript.
- Produces: exact retained-row map and a machine-readable complete baseline workbook.

- [ ] **Step 1: Write failing table-parity tests**

```r
testthat::test_that("main Table 1 is an exact subset of Supplementary Table S9", {
  audit <- read.delim(file.path(repo_root, "submission/qa/scientific_reports_numeric_audit.tsv"), check.names = FALSE)
  subset <- audit[audit$domain == "table1_vs_s9", ]
  testthat::expect_gt(nrow(subset), 0)
  testthat::expect_true(all(subset$match))
})
```

- [ ] **Step 2: Define retained rows explicitly**

The row map must retain clinically central variables and their infection-source subrows:

```text
Age
Male sex
SOFA score
Platelet count
INR
D-dimer
Lactate
BUN
PaO2/FiO2 ratio
Infection source overall row and six source categories
Diabetes mellitus
Hypertension
Heart failure
Cerebrovascular disease
COPD
Renal failure
```

Reduce this exact list only if rendered Table 1 exceeds one page; any reduction requires author approval and an updated row map commit.

- [ ] **Step 3: Build S9 with `artifact_tool`**

Import the extracted full baseline table, write it to a workbook with:

- editable cells;
- the original six columns and all frozen rows;
- styled header row;
- wrapped variable labels;
- preserved numeric text exactly as shown in the frozen table;
- a Notes sheet containing the full footnote and provenance path;
- no formulas that alter scientific values.

- [ ] **Step 4: Verify S9 and main-table equality**

Use exact string comparison after Unicode normalisation for every retained cell, denominator, P value, and SMD. Write each comparison to `submission/qa/scientific_reports_numeric_audit.tsv`.

- [ ] **Step 5: Render and verify one-page Table 1**

```bash
python /home/oai/skills/docx/render_docx.py \
  submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_clean.docx \
  --output_dir /mnt/data/sr_main_render --emit_pdf
```

Inspect the Table 1 page at 100% zoom. Fail the task if text clips, font becomes illegible, or the table spans more than one page.

- [ ] **Step 6: Commit**

```bash
git add submission/manuscript_support/scientific_reports_table1_rows.tsv \
        submission/manuscript_files/scientific_reports/Supplementary_Table_S9_Complete_baseline_characteristics.xlsx \
        submission/qa/scientific_reports_numeric_audit.tsv \
        submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_*.docx
git commit -m "feat: add concise Table 1 and complete baseline supplement"
```

---

### Task 5: Build composite Supplementary Information and propagate S1-S9 numbering

**Files:**
- Create: `submission/code/30_build_scientific_reports_supplementary.py`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.docx`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.pdf`
- Create submission-facing copies of Supplementary Figs. S1-S9 under `submission/figures/scientific_reports/`.
- Copy S1-S8 workbooks into `submission/manuscript_files/scientific_reports/` without changing bytes.
- Test: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: Additional file 1, S1-S8 workbooks, S9, A1-A9 figures, cross-reference map.
- Produces: one composite Supplementary Information DOCX/PDF, S1-S9 submission-facing figure copies, and separate machine-readable tables S1-S9.

- [ ] **Step 1: Add failing supplementary-package tests**

```r
testthat::test_that("Scientific Reports supplementary package is complete", {
  root <- file.path(repo_root, "submission/manuscript_files/scientific_reports")
  testthat::expect_true(file.exists(file.path(root, "Scientific_Reports_Supplementary_Information.docx")))
  testthat::expect_true(file.exists(file.path(root, "Scientific_Reports_Supplementary_Information.pdf")))
  testthat::expect_true(all(file.exists(file.path(root, sprintf("Supplementary_Table_S%d%s", 1:9, c(rep("", 9)))))) == FALSE)
  report <- jsonlite::read_json(file.path(repo_root, "submission/qa/scientific_reports_package_validation.json"), simplifyVector = TRUE)
  testthat::expect_false(report$residual_A_labels)
  testthat::expect_true(report$supplement_pdf_bytes < 50 * 1024^2)
})
```

Replace the temporary filename assertion in the same commit with an explicit vector of the nine exact workbook names listed in the File Structure section; do not leave generated-name logic in the final test.

- [ ] **Step 2: Implement S1-S9 renumbering**

Create exact submission-facing copies:

```text
Supplementary_Figure_S1_centre_positivity.*
Supplementary_Figure_S2_probability_weight_distributions.*
Supplementary_Figure_S3_pre_post_weight_SMD.*
Supplementary_Figure_S4_all_Hallmark_unweighted_vs_IPW.*
Supplementary_Figure_S5_core_pathway_scenario_heatmap.*
Supplementary_Figure_S6_six_scenario_robustness_metrics.*
Supplementary_Figure_S7_entry_boundary_sensitivity.*
Supplementary_Figure_S8_D5_protein_availability.*
Supplementary_Figure_S9_clinical_univariable_Cox.*
```

Do not modify image pixels or scientific content. Verify copied-file hashes equal their A-numbered sources.

- [ ] **Step 3: Build the Supplementary Information DOCX**

The first page must contain the exact manuscript title and complete author list. Include:

1. Supplementary Methods.
2. Supplementary Figs. S1-S9 with updated legends.
3. Supplementary Table S9.
4. An index and field-note section for separate Supplementary Tables S1-S8.

Every internal and main-manuscript reference must use `Supplementary Fig. S#` or `Supplementary Table S#`.

- [ ] **Step 4: Convert to PDF and inspect**

```bash
python /home/oai/skills/docx/render_docx.py \
  submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.docx \
  --output_dir /mnt/data/sr_supp_render --emit_pdf
cp /mnt/data/sr_supp_render/Scientific_Reports_Supplementary_Information.pdf \
   submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.pdf
python /home/oai/skills/pdfs/scripts/render_pdf.py \
  submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.pdf \
  --output_dir /mnt/data/sr_supp_pdf_render
```

Inspect every page at 100% zoom. Confirm no clipped captions, stretched figures, unreadable text, blank pages, or broken glyphs.

- [ ] **Step 5: Verify byte identity of S1-S8 workbooks**

Copy each workbook and compare SHA-256 with the frozen original. Record results in the package-validation JSON.

- [ ] **Step 6: Run tests and commit**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
git add submission/code/30_build_scientific_reports_supplementary.py \
        submission/figures/scientific_reports \
        submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.* \
        submission/manuscript_files/scientific_reports/Supplementary_Table_S*.xlsx \
        tests/testthat/test-scientific-reports-package.R
git commit -m "feat: build Scientific Reports supplementary package"
```

---

### Task 6: Build the private Scientific Reports Cover Letter

**Files:**
- Create: `submission/code/31_build_scientific_reports_cover_letter.py`
- Create privately: `/mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx`
- Do not add the Cover Letter to Git.

**Interfaces:**
- Consumes: title, author/affiliation block, corresponding-author contact details, and approved transfer/reviewer statements.
- Produces: one clean private DOCX.

- [ ] **Step 1: Implement exact content checks in the builder**

The builder must assert the letter contains:

```text
Scientific Reports
Article
This manuscript was previously submitted to the Journal of Intensive Care and is now being submitted to Scientific Reports following a Springer Nature journal-transfer recommendation.
We have no preferred reviewers and request no reviewer exclusions.
We have had no prior discussions with a Scientific Reports Editorial Board Member regarding this work.
```

It must also state that the work is original, unpublished, not under consideration elsewhere, approved by all authors, and supported by controlled-access data plus public aggregate code/results.

- [ ] **Step 2: Build the DOCX**

```bash
python submission/code/31_build_scientific_reports_cover_letter.py \
  --manuscript submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_clean.docx \
  --out /mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx
```

- [ ] **Step 3: Render and visually inspect**

```bash
python /home/oai/skills/docx/render_docx.py \
  /mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx \
  --output_dir /mnt/data/sr_cover_render
```

Confirm professional one- to two-page layout, correct corresponding-author details, no JIC addressee residue, no reviewer names, and no implication of completed peer review.

- [ ] **Step 4: Commit the builder only**

```bash
git add submission/code/31_build_scientific_reports_cover_letter.py
git commit -m "feat: add Scientific Reports cover letter builder"
```

---

### Task 7: Update STROBE after pagination is stable

**Files:**
- Create: `submission/code/32_build_scientific_reports_strobe.py`
- Create: `submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_completed.docx`
- Create: `submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_audit.tsv`
- Test: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: final clean manuscript PDF page map, final Supplementary Information PDF page map, and baseline STROBE checklist.
- Produces: completed STROBE DOCX and row-level audit.

- [ ] **Step 1: Add failing STROBE audit tests**

```r
testthat::test_that("Scientific Reports STROBE audit is complete", {
  audit <- read.delim(file.path(repo_root, "submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_audit.tsv"), check.names = FALSE)
  testthat::expect_false(any(is.na(audit$reported_location) | audit$reported_location == ""))
  testthat::expect_false(any(audit$status != "verified"))
  testthat::expect_true(all(grepl("p\\.", audit$reported_location) | grepl("Not applicable", audit$reported_location)))
})
```

- [ ] **Step 2: Build a stable page map**

Extract headings and page numbers from the final rendered manuscript and Supplementary Information. Do not use approximate page numbers from the JIC version.

- [ ] **Step 3: Update every STROBE row**

Explicitly verify cohort design, eligibility, Day-1 SIC definition, Day-3/Day-5 landmark risk sets, outcome, missing data, assay availability, positivity, IPW, Cox/PH diagnostics, FDR, sensitivity analyses, limitations, generalisability, ethics, and data/code availability.

- [ ] **Step 4: Render and inspect STROBE**

```bash
python /home/oai/skills/docx/render_docx.py \
  submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_completed.docx \
  --output_dir /mnt/data/sr_strobe_render
```

Inspect every page for clipping, row splitting, unreadable columns, or stale JIC page references.

- [ ] **Step 5: Run tests and commit**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
git add submission/code/32_build_scientific_reports_strobe.py \
        submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_completed.docx \
        submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_audit.tsv \
        tests/testthat/test-scientific-reports-package.R
git commit -m "feat: update STROBE for Scientific Reports"
```

---

### Task 8: Implement cross-document, numerical, and hygiene validation

**Files:**
- Create: `submission/code/33_validate_scientific_reports_package.py`
- Create: `submission/qa/scientific_reports_cross_reference_audit.tsv`
- Create: `submission/qa/scientific_reports_numeric_audit.tsv`
- Create: `submission/qa/scientific_reports_render_audit.tsv`
- Create: `submission/qa/scientific_reports_package_validation.json`
- Test: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: all Scientific Reports submission files, frozen numerical truth, source data, figure files, baseline lock, and render outputs.
- Produces: one machine-readable release gate with `all_pass`.

- [ ] **Step 1: Define the validator schema and failing test**

```r
testthat::test_that("Scientific Reports package release gate is green", {
  report <- jsonlite::read_json(file.path(repo_root, "submission/qa/scientific_reports_package_validation.json"), simplifyVector = TRUE)
  testthat::expect_true(isTRUE(report$all_pass))
  testthat::expect_equal(report$residual_A_labels, FALSE)
  testthat::expect_equal(report$broken_cross_references, 0L)
  testthat::expect_equal(report$numeric_mismatches, 0L)
  testthat::expect_equal(report$privacy_findings, 0L)
  testthat::expect_equal(report$clean_comments, 0L)
  testthat::expect_equal(report$clean_tracked_changes, 0L)
})
```

- [ ] **Step 2: Implement scientific-text and numerical checks**

The validator must compare every numeric token in Abstract, Results, Discussion, Methods, Table 1, and figure legends against the frozen numerical-truth/source-data layers. It must fail on a new numeric result, changed sign, changed exponent, changed denominator, or changed effect estimate.

- [ ] **Step 3: Implement cross-reference checks**

Require:

- zero residual `Supplementary Figure A1-A9` or `Supplementary Fig. A1-A9`;
- all S1-S9 figures cited exactly where mapped;
- all S1-S9 tables cited or indexed;
- main Figures 1-4 cited in order;
- no Figure 5 or graphical abstract;
- all reference citations resolve to exactly one bibliography item.

- [ ] **Step 4: Implement DOCX hygiene checks**

Inspect OOXML ZIP parts for:

```text
word/comments.xml
w:ins
w:del
w:vanish
personal core-properties values
stale JIC hyperlinks
broken relationships
```

Clean submission files must have no comments, tracked changes, hidden text, or stale JIC release URLs. The highlighted manuscript may contain highlighting but no comments or tracked changes.

- [ ] **Step 5: Implement privacy and package-size checks**

Scan all new text and tabular files for participant identifiers, local Windows paths, credentials, email addresses other than author contact fields, and controlled raw-data filenames. Confirm the Supplementary Information PDF is below 50 MB.

- [ ] **Step 6: Run full validator and tests**

```bash
python submission/code/33_validate_scientific_reports_package.py \
  --repo-root . \
  --out submission/qa/scientific_reports_package_validation.json
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: PASS with `all_pass=true`.

- [ ] **Step 7: Commit**

```bash
git add submission/code/33_validate_scientific_reports_package.py \
        submission/qa/scientific_reports_*audit.tsv \
        submission/qa/scientific_reports_package_validation.json \
        tests/testthat/test-scientific-reports-package.R
git commit -m "test: validate Scientific Reports submission package"
```

---

### Task 9: Update public release metadata and manifests

**Files:**
- Create: `submission/code/34_build_scientific_reports_release_manifest.R`
- Create: `tests/testthat/test-scientific-reports-release-metadata.R`
- Modify: `README.md`
- Modify immediately before freeze: `CITATION.cff`
- Regenerate: `submission/public_manifest.tsv`

**Interfaces:**
- Consumes: final Scientific Reports package and current repository metadata.
- Produces: release-ready README, citation metadata, manifest, and metadata tests.

- [ ] **Step 1: Write failing release-metadata tests**

```r
testthat::test_that("Scientific Reports release metadata identifies v1.1", {
  readme <- read_repo_text("README.md")
  citation <- read_repo_text("CITATION.cff")
  url <- "https://github.com/lvhao1123/SIC-longitudinal-multiomics/releases/tag/scientific-reports-submission-v1.1"
  testthat::expect_match(readme, "scientific-reports-submission-v1.1", fixed = TRUE)
  testthat::expect_match(readme, url, fixed = TRUE)
  testthat::expect_match(citation, "(?m)^version:\\s*1\\.1\\.0\\s*$", perl = TRUE)
  testthat::expect_match(citation, "(?m)^date-released:\\s*\\d{4}-\\d{2}-\\d{2}\\s*$", perl = TRUE)
})
```

- [ ] **Step 2: Update README without erasing JIC history**

Add a release-history section that retains the immutable JIC release and identifies the Scientific Reports release as the current submission snapshot. Keep controlled-access language and OMIX accession unchanged.

- [ ] **Step 3: Update `CITATION.cff` at freeze time**

Set:

```yaml
version: 1.1.0
date-released: <actual GitHub release publication date>
```

Do not predate the release. Keep `Hao Lyu` identity and repository URL unchanged.

- [ ] **Step 4: Rebuild the manifest**

The R builder must include all public Scientific Reports files except the private Cover Letter. Write sorted relative paths, byte sizes, roles, and SHA-256 hashes.

- [ ] **Step 5: Run metadata tests**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-release-metadata.R')"
```

- [ ] **Step 6: Commit**

```bash
git add README.md CITATION.cff submission/public_manifest.tsv \
        submission/code/34_build_scientific_reports_release_manifest.R \
        tests/testthat/test-scientific-reports-release-metadata.R
git commit -m "chore: prepare Scientific Reports release metadata"
```

---

### Task 10: Run complete repository and visual QA

**Files:**
- Update: `submission/qa/scientific_reports_render_audit.tsv`
- No scientific content changes are permitted in this task.

**Interfaces:**
- Consumes: final repository state.
- Produces: green test logs and a page-by-page visual audit.

- [ ] **Step 1: Render all DOCX deliverables**

```bash
for f in \
  submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_clean.docx \
  submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_highlighted.docx \
  submission/manuscript_files/scientific_reports/Scientific_Reports_revision_report.docx \
  submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.docx \
  submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_completed.docx
do
  out="/mnt/data/render_$(basename "$f" .docx)"
  python /home/oai/skills/docx/render_docx.py "$f" --output_dir "$out" --emit_pdf
done
```

- [ ] **Step 2: Inspect every rendered page at 100% zoom**

Record one row per file/page in `submission/qa/scientific_reports_render_audit.tsv` with columns:

```text
file	page	clipping	overlap	broken_glyph	figure_legible	table_legible	page_break_ok	status	notes
```

Every row must have `status=PASS`.

- [ ] **Step 3: Run canonical and repository tests**

```bash
Rscript -e "testthat::test_dir('tests/testthat')"
Rscript submission/tests/test_submission_semantics.R
Rscript submission/tests/test_sandwich_equivalence.R
python submission/code/33_validate_scientific_reports_package.py --repo-root . --out submission/qa/scientific_reports_package_validation.json
```

Expected: zero failures, zero warnings requiring action, and `all_pass=true`.

- [ ] **Step 4: Run repository hygiene checks**

```bash
git diff --check
git status --short
```

Expected: no whitespace errors and only the intended final QA file modification before commit.

- [ ] **Step 5: Commit final QA evidence**

```bash
git add submission/qa/scientific_reports_render_audit.tsv \
        submission/qa/scientific_reports_package_validation.json \
        submission/public_manifest.tsv
git commit -m "test: freeze Scientific Reports submission QA"
```

---

### Task 11: Review, pull request, merge, and release

**Files:**
- No new scientific files.
- GitHub PR and Release metadata only.

**Interfaces:**
- Consumes: green release branch.
- Produces: merged main branch and public immutable release.

- [ ] **Step 1: Verify changed-file scope**

```bash
git diff --name-status main...release/scientific-reports-submission-v1.1
```

Expected: only approved design/plan, builders, Scientific Reports submission files, QA outputs, README/CITATION, manifest, and tests. No controlled raw data or Cover Letter.

- [ ] **Step 2: Push branch and open PR**

PR title:

```text
Freeze Scientific Reports submission release v1.1
```

PR body must state:

- JIC release remains unchanged;
- no participant-level data were added;
- no scientific result, model, source data, or figure content changed;
- the change is a journal-specific editorial/reporting conversion;
- all package and repository QA checks passed.

- [ ] **Step 3: Review PR changed files and GitHub Actions**

Require green Data-free repository QA and confirm the changed-file list matches Step 1.

- [ ] **Step 4: Merge only after author approval**

Use squash merge. Record the final `main` commit SHA.

- [ ] **Step 5: Create the formal release**

Create tag on final `main`:

```text
scientific-reports-submission-v1.1
```

Release title:

```text
Scientific Reports submission reproducibility snapshot v1.1
```

Do not upload the Cover Letter or participant-level data. Use the actual publication date in `CITATION.cff`.

- [ ] **Step 6: Verify release unauthenticated**

Open an InPrivate/Incognito window and confirm:

- release page is public and not 404;
- tag is exact;
- target is the merged final `main` commit;
- `Latest` is shown and `Pre-release` is absent;
- source ZIP and tar.gz download;
- the source archive contains all expected Scientific Reports public files;
- the Cover Letter is absent;
- the original `jic-submission-v1.0` release remains accessible and unchanged.

- [ ] **Step 7: Final submission handoff**

Deliver to the author:

- clean manuscript;
- highlighted manuscript;
- revision report;
- private Cover Letter;
- Supplementary Information DOCX/PDF;
- S1-S9 workbooks;
- STROBE checklist and audit;
- final package-validation report;
- public release URL.
