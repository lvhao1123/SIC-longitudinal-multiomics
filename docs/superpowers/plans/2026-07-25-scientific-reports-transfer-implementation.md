# Scientific Reports Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the immutable `jic-submission-v1.0` package into a fully validated Scientific Reports submission package without changing any frozen scientific result.

**Architecture:** Treat the JIC release as read-only input and generate a separate Scientific Reports submission subtree. Use deterministic Python/R builders, keep S1-S8 machine-readable, create a new S9 baseline workbook, and gate release on numerical, cross-reference, document-hygiene, rendering, privacy, manifest, and repository QA.

**Tech Stack:** Python 3, `python-docx`, OOXML/ZIP inspection, LibreOffice headless, R 4.4.2/testthat, `artifact_tool` for XLSX creation/editing, SHA-256 manifests, GitHub Actions.

## Global Constraints

- Authoritative baseline: tag `jic-submission-v1.0` only.
- Work branch: `release/scientific-reports-submission-v1.1`.
- Article type: `Article` in `Scientific Reports`.
- Title remains exactly: `Landmark-specific transcriptomic and proteomic associations with 60-day mortality in Day-1-defined sepsis-induced coagulopathy: a multicentre longitudinal cohort study`.
- No cohort count, event count, HR, CI, P value, adjusted P value, FDR, NES, pathway direction, model, estimand, figure content, or frozen QA outcome may change without a documented discrepancy and explicit author approval.
- No new statistical, subgroup, pathway, prediction, or mechanistic analysis.
- Abstract: unstructured, no references, no more than 200 words.
- Keywords: exactly six approved terms.
- Main order: Title page; Abstract; Keywords; Introduction; Results; Discussion; Methods; Data availability; References; Acknowledgements; Author contributions; Additional Information/Competing interests; Figure legends; Table 1.
- Methods includes a subsection headed `Code availability`; the final Methods subsection is `AI-assisted tools in manuscript and code preparation`.
- Main Table 1 must fit on one rendered page; the complete original table becomes Supplementary Table S9.
- Submission-facing supplementary figures are S1-S9, not A1-A9.
- Existing S1-S8 workbooks remain separate machine-readable files and retain byte identity.
- Composite Supplementary Information is delivered as DOCX and PDF and must remain below 50 MB.
- Clean files contain no comments, tracked changes, hidden text, or stale links.
- The highlighted manuscript uses yellow highlighting only for substantive additions/revisions approved in the design.
- The original JIC release remains unchanged.
- New public release tag: `scientific-reports-submission-v1.1`, created from final merged `main` and dated with the actual publication date.
- Cover Letter remains private and is never committed or released.

## File Map

### Create production scripts

- `submission/code/28_lock_scientific_reports_baseline.py`
- `submission/code/29_build_scientific_reports_table1_s9.py`
- `submission/code/30_build_scientific_reports_manuscript.py`
- `submission/code/31_build_scientific_reports_supplementary.py`
- `submission/code/32_build_scientific_reports_cover_letter.py`
- `submission/code/33_build_scientific_reports_strobe.py`
- `submission/code/34_validate_scientific_reports_package.py`
- `submission/code/35_build_scientific_reports_release_manifest.R`

### Create support files

- `submission/manuscript_support/scientific_reports_text_map.tsv`
- `submission/manuscript_support/scientific_reports_reference_map.tsv`
- `submission/manuscript_support/scientific_reports_table1_rows.tsv`
- `submission/manuscript_support/scientific_reports_crossref_map.tsv`

### Create public submission files

Under `submission/manuscript_files/scientific_reports/`:

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

### Create private submission file

- `/mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx`

### Create QA outputs

- `submission/qa/scientific_reports_baseline_lock.json`
- `submission/qa/scientific_reports_numeric_audit.tsv`
- `submission/qa/scientific_reports_cross_reference_audit.tsv`
- `submission/qa/scientific_reports_render_audit.tsv`
- `submission/qa/scientific_reports_package_validation.json`

### Create/modify tests and metadata

- Create `tests/testthat/test-scientific-reports-package.R`.
- Create `tests/testthat/test-scientific-reports-release-metadata.R`.
- Modify `README.md`.
- Modify `CITATION.cff` only on the actual release-freeze date.
- Regenerate `submission/public_manifest.tsv`; never edit it manually.

---

### Task 1: Lock the immutable baseline

**Files:**
- Create: `submission/code/28_lock_scientific_reports_baseline.py`
- Create: `submission/qa/scientific_reports_baseline_lock.json`
- Create: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: `submission/public_manifest.tsv` and required JIC release files.
- Produces: deterministic JSON with observed and expected SHA-256 values.

- [ ] **Step 1: Write the failing test**

```r
repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")

testthat::test_that("Scientific Reports baseline is locked", {
  path <- file.path(repo_root, "submission/qa/scientific_reports_baseline_lock.json")
  testthat::expect_true(file.exists(path))
  lock <- jsonlite::read_json(path, simplifyVector = TRUE)
  testthat::expect_identical(lock$source_tag, "jic-submission-v1.0")
  testthat::expect_true(isTRUE(lock$all_match))
  testthat::expect_true(all(lock$files$match))
})
```

- [ ] **Step 2: Run the test and confirm failure**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: FAIL because the JSON does not exist.

- [ ] **Step 3: Implement the hash lock**

```python
REQUIRED = (
    "submission/manuscript_files/JIC_manuscript_clean.docx",
    "submission/manuscript_files/Additional_file_1_Supplementary_methods_and_figures.docx",
    "submission/manuscript_files/Additional_file_2_Supplementary_Tables_S1-S8.zip",
    "submission/manuscript_files/STROBE_checklist_cohort_completed.docx",
    "submission/numeric_truth_table.tsv",
    "submission/numeric_truth_dictionary.tsv",
)
```

Read expected hashes from `submission/public_manifest.tsv`, calculate observed hashes, fail on any missing/mismatched file, sort rows by path, and write `source_tag`, `files`, and `all_match`.

- [ ] **Step 4: Run builder and test**

```bash
python submission/code/28_lock_scientific_reports_baseline.py \
  --repo-root . \
  --manifest submission/public_manifest.tsv \
  --out submission/qa/scientific_reports_baseline_lock.json
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add submission/code/28_lock_scientific_reports_baseline.py \
        submission/qa/scientific_reports_baseline_lock.json \
        tests/testthat/test-scientific-reports-package.R
git commit -m "test: lock Scientific Reports baseline"
```

---

### Task 2: Define editorial, reference, and cross-reference maps

**Files:**
- Create: `submission/manuscript_support/scientific_reports_text_map.tsv`
- Create: `submission/manuscript_support/scientific_reports_reference_map.tsv`
- Create: `submission/manuscript_support/scientific_reports_crossref_map.tsv`
- Modify: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: JIC manuscript paragraphs, references, figure legends, and supplementary citations.
- Produces: deterministic instructions used by all document builders.

- [ ] **Step 1: Add failing map tests**

```r
testthat::test_that("Scientific Reports maps are complete", {
  support <- file.path(repo_root, "submission/manuscript_support")
  text_map <- read.delim(file.path(support, "scientific_reports_text_map.tsv"), check.names = FALSE)
  ref_map <- read.delim(file.path(support, "scientific_reports_reference_map.tsv"), check.names = FALSE)
  crossref <- read.delim(file.path(support, "scientific_reports_crossref_map.tsv"), check.names = FALSE)
  allowed <- c("unchanged", "clarification", "interpretive expansion", "claim restriction", "journal compliance", "structural relocation", "cross-reference renumbering")
  testthat::expect_true(all(text_map$edit_class %in% allowed))
  testthat::expect_false(any(text_map$destination_section == ""))
  testthat::expect_true(all(ref_map$verification_status == "verified"))
  testthat::expect_setequal(crossref$old_id, paste0("A", 1:9))
  testthat::expect_setequal(crossref$new_id, paste0("S", 1:9))
})
```

- [ ] **Step 2: Run and confirm failure**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
```

- [ ] **Step 3: Build `scientific_reports_text_map.tsv`**

Use columns:

```text
source_order	source_heading	source_sha256	destination_section	destination_order	edit_class	highlight	approved_boundary
```

Every source paragraph receives exactly one destination. `highlight=TRUE` only for clarification, interpretive expansion, claim restriction, and journal-compliance text that is substantively new or rewritten.

- [ ] **Step 4: Build and verify the reference map**

Use columns:

```text
old_number	new_number	first_author	year	title	doi_or_pmid	primary_source_url	verification_status
```

Verify each item against the publisher page, DOI record, PubMed, Crossref, or another primary bibliographic source. Preserve citation mapping; add references only when needed for an approved interpretive clarification.

- [ ] **Step 5: Build the A1-A9 to S1-S9 cross-reference map**

Use columns:

```text
old_id	new_id	old_filename	new_filename	caption_title	main_text_locations	supplement_locations
```

- [ ] **Step 6: Run tests and commit**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
git add submission/manuscript_support/scientific_reports_*map.tsv \
        tests/testthat/test-scientific-reports-package.R
git commit -m "docs: define Scientific Reports editorial maps"
```

---

### Task 3: Create concise Table 1 and complete Supplementary Table S9

**Files:**
- Create: `submission/code/29_build_scientific_reports_table1_s9.py`
- Create: `submission/manuscript_support/scientific_reports_table1_rows.tsv`
- Create: `submission/manuscript_files/scientific_reports/Supplementary_Table_S9_Complete_baseline_characteristics.xlsx`
- Create/update: `submission/qa/scientific_reports_numeric_audit.tsv`
- Modify: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: the frozen full JIC Table 1.
- Produces: an exact retained-row map, an editable complete S9 workbook, and table-parity audit rows.

- [ ] **Step 1: Add the failing parity test**

```r
testthat::test_that("main Table 1 values are an exact subset of S9", {
  audit <- read.delim(file.path(repo_root, "submission/qa/scientific_reports_numeric_audit.tsv"), check.names = FALSE)
  x <- audit[audit$domain == "table1_vs_s9", ]
  testthat::expect_gt(nrow(x), 0)
  testthat::expect_true(all(x$match))
})
```

- [ ] **Step 2: Create the retained-row map**

Use this initial exact list:

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
Infection source overall row
Abdomen
Biliary/liver
Lung/chest
Others/unknown
Soft tissue
Urinary
Diabetes mellitus
Hypertension
Heart failure
Cerebrovascular disease
COPD
Renal failure
```

If the rendered table exceeds one page, stop and obtain author approval before removing any row.

- [ ] **Step 3: Build S9 using `artifact_tool`**

The script imports the extracted baseline table, writes all original rows and six columns, applies readable header/wrap formatting, creates a `Notes` sheet with the complete footnote and provenance, and preserves every displayed numeric string exactly.

- [ ] **Step 4: Write exact comparison rows**

For every retained cell write:

```text
domain	variable	column	main_value	s9_value	match
```

Normalise Unicode only; do not numerically round or reformat.

- [ ] **Step 5: Run test and commit**

```bash
python submission/code/29_build_scientific_reports_table1_s9.py \
  --source submission/manuscript_files/JIC_manuscript_clean.docx \
  --row-map submission/manuscript_support/scientific_reports_table1_rows.tsv \
  --s9-out submission/manuscript_files/scientific_reports/Supplementary_Table_S9_Complete_baseline_characteristics.xlsx \
  --audit-out submission/qa/scientific_reports_numeric_audit.tsv
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
git add submission/code/29_build_scientific_reports_table1_s9.py \
        submission/manuscript_support/scientific_reports_table1_rows.tsv \
        submission/manuscript_files/scientific_reports/Supplementary_Table_S9_Complete_baseline_characteristics.xlsx \
        submission/qa/scientific_reports_numeric_audit.tsv \
        tests/testthat/test-scientific-reports-package.R
git commit -m "feat: add concise Table 1 map and complete baseline S9"
```

---

### Task 4: Build clean/highlighted manuscripts and revision report

**Files:**
- Create: `submission/code/30_build_scientific_reports_manuscript.py`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_clean.docx`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_highlighted.docx`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_revision_report.docx`
- Modify: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: JIC manuscript, text/reference/table maps, S9, and cross-reference map.
- Produces: three DOCX files with stable content and formatting.

- [ ] **Step 1: Add failing manuscript tests**

```r
testthat::test_that("Scientific Reports manuscript interface is valid", {
  report <- jsonlite::read_json(file.path(repo_root, "submission/qa/scientific_reports_package_validation.json"), simplifyVector = TRUE)
  testthat::expect_identical(report$title, "Landmark-specific transcriptomic and proteomic associations with 60-day mortality in Day-1-defined sepsis-induced coagulopathy: a multicentre longitudinal cohort study")
  testthat::expect_lte(report$abstract_words, 200)
  testthat::expect_identical(report$keyword_count, 6L)
  testthat::expect_true(report$section_order_pass)
  testthat::expect_true(report$data_availability_before_references)
  testthat::expect_true(report$code_availability_in_methods)
  testthat::expect_true(report$ai_is_final_methods_subsection)
})
```

- [ ] **Step 2: Implement section reconstruction**

```python
SECTION_ORDER = (
    "Abstract", "Keywords", "Introduction", "Results", "Discussion", "Methods",
    "Data availability", "References", "Acknowledgements", "Author contributions",
    "Additional Information", "Figure legends", "Table 1",
)
KEYWORDS = (
    "Sepsis-induced coagulopathy", "Multi-omics", "Landmark analysis",
    "Transcriptomics", "Proteomics", "Mortality",
)
```

The builder must:

- preserve title, authors, affiliations, and corresponding-author details;
- write a single-paragraph abstract of no more than 200 words using frozen results only;
- convert Background to Introduction;
- order Results, Discussion, then Methods;
- merge Conclusions into the final Discussion paragraph;
- remove Discussion subheadings unless essential for readability;
- place ethics and informed consent in Methods;
- create a Methods subsection headed `Code availability`;
- place the approved AI disclosure as the final Methods subsection;
- place Data availability before References;
- place Competing interests under Additional Information;
- convert citations and references to Nature style while preserving the map;
- insert the concise Table 1 and cite Supplementary Table S9;
- replace all A1-A9 citations with S1-S9;
- add page and line numbering;
- keep all tables editable.

- [ ] **Step 3: Implement highlighted and revision-report outputs**

Yellow-highlight only paragraphs/runs marked `highlight=TRUE`. Do not add comments or tracked changes. The revision report groups changes under:

```text
clarification
interpretive expansion
claim restriction
journal compliance
structural relocation
cross-reference renumbering
```

- [ ] **Step 4: Build outputs**

```bash
python submission/code/30_build_scientific_reports_manuscript.py \
  --source submission/manuscript_files/JIC_manuscript_clean.docx \
  --text-map submission/manuscript_support/scientific_reports_text_map.tsv \
  --reference-map submission/manuscript_support/scientific_reports_reference_map.tsv \
  --table1-map submission/manuscript_support/scientific_reports_table1_rows.tsv \
  --crossref-map submission/manuscript_support/scientific_reports_crossref_map.tsv \
  --out-dir submission/manuscript_files/scientific_reports
```

- [ ] **Step 5: Render and inspect the three DOCX files**

```bash
for f in Scientific_Reports_manuscript_clean Scientific_Reports_manuscript_highlighted Scientific_Reports_revision_report; do
  python /home/oai/skills/docx/render_docx.py \
    "submission/manuscript_files/scientific_reports/${f}.docx" \
    --output_dir "/mnt/data/render_${f}" --emit_pdf
done
```

Inspect every page at 100% zoom. Confirm the main Table 1 is one page and all typography, page breaks, and figure legends are clean.

- [ ] **Step 6: Commit**

```bash
git add submission/code/30_build_scientific_reports_manuscript.py \
        submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_*.docx \
        submission/manuscript_files/scientific_reports/Scientific_Reports_revision_report.docx \
        tests/testthat/test-scientific-reports-package.R
git commit -m "feat: build Scientific Reports manuscript package"
```

---

### Task 5: Build Supplementary Information and S1-S9 submission package

**Files:**
- Create: `submission/code/31_build_scientific_reports_supplementary.py`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.docx`
- Create: `submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.pdf`
- Create: `submission/figures/scientific_reports/Supplementary_Figure_S1-*` through `S9-*` copies.
- Copy: S1-S8 workbooks into the Scientific Reports directory without changing bytes.
- Modify: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: Additional file 1, A1-A9 figures/legends, S1-S8 workbooks, S9, and cross-reference map.
- Produces: composite SI DOCX/PDF and nine separate XLSX files.

- [ ] **Step 1: Add failing package tests**

```r
testthat::test_that("Scientific Reports supplementary files are complete", {
  root <- file.path(repo_root, "submission/manuscript_files/scientific_reports")
  expected <- c(
    "Supplementary_Table_S1_Clinical_variable_definitions.xlsx",
    "Supplementary_Table_S2_Clinical_univariable_Cox.xlsx",
    "Supplementary_Table_S3_RNA_gene_wise_Cox_PH.xlsx",
    "Supplementary_Table_S4_RNA_Hallmark_GSEA.xlsx",
    "Supplementary_Table_S5_Protein_wise_Cox_PH.xlsx",
    "Supplementary_Table_S6_Protein_Hallmark_GSEA.xlsx",
    "Supplementary_Table_S7_Cross_omics_models.xlsx",
    "Supplementary_Table_S8_D5_availability_IPW.xlsx",
    "Supplementary_Table_S9_Complete_baseline_characteristics.xlsx"
  )
  testthat::expect_true(all(file.exists(file.path(root, expected))))
  testthat::expect_true(file.exists(file.path(root, "Scientific_Reports_Supplementary_Information.docx")))
  testthat::expect_true(file.exists(file.path(root, "Scientific_Reports_Supplementary_Information.pdf")))
})
```

- [ ] **Step 2: Create S1-S9 figure copies**

Create exact hash-identical submission-facing copies named:

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

Do not change pixels or metadata needed for scientific fidelity.

- [ ] **Step 3: Build composite SI DOCX**

First page: exact title and full author list. Then:

1. Supplementary Methods.
2. Supplementary Figs. S1-S9 with updated legends.
3. Supplementary Table S9.
4. Titles, descriptions, field notes, and file index for separate Tables S1-S8.

Every citation includes `Supplementary`; no individual panel is cited separately.

- [ ] **Step 4: Copy and hash-check S1-S8**

Copy the eight workbooks byte-for-byte and record source/destination hashes in `submission/qa/scientific_reports_package_validation.json`.

- [ ] **Step 5: Render DOCX, create PDF, and inspect**

```bash
python /home/oai/skills/docx/render_docx.py \
  submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.docx \
  --output_dir /mnt/data/render_sr_supp --emit_pdf
cp /mnt/data/render_sr_supp/Scientific_Reports_Supplementary_Information.pdf \
   submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.pdf
python /home/oai/skills/pdfs/scripts/render_pdf.py \
  submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.pdf \
  --output_dir /mnt/data/render_sr_supp_pdf
```

Inspect every page and confirm file size below 50 MB.

- [ ] **Step 6: Run tests and commit**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
git add submission/code/31_build_scientific_reports_supplementary.py \
        submission/figures/scientific_reports \
        submission/manuscript_files/scientific_reports/Scientific_Reports_Supplementary_Information.* \
        submission/manuscript_files/scientific_reports/Supplementary_Table_S*.xlsx \
        tests/testthat/test-scientific-reports-package.R
git commit -m "feat: build Scientific Reports supplementary package"
```

---

### Task 6: Build the private Cover Letter

**Files:**
- Create: `submission/code/32_build_scientific_reports_cover_letter.py`
- Create privately: `/mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx`
- Do not commit the DOCX.

**Interfaces:**
- Consumes: final manuscript metadata and approved transfer/reviewer statements.
- Produces: clean private Cover Letter.

- [ ] **Step 1: Implement required statements**

The builder must assert these exact strings are present:

```text
This manuscript was previously submitted to the Journal of Intensive Care and is now being submitted to Scientific Reports following a Springer Nature journal-transfer recommendation.
We have no preferred reviewers and request no reviewer exclusions.
We have had no prior discussions with a Scientific Reports Editorial Board Member regarding this work.
```

It must also confirm originality, no concurrent consideration, author approval, corresponding-author details, journal fit, controlled-data limits, and public code/results.

- [ ] **Step 2: Build and render**

```bash
python submission/code/32_build_scientific_reports_cover_letter.py \
  --manuscript submission/manuscript_files/scientific_reports/Scientific_Reports_manuscript_clean.docx \
  --out /mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx
python /home/oai/skills/docx/render_docx.py \
  /mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx \
  --output_dir /mnt/data/render_sr_cover
```

Inspect for correct addressee, no JIC residue, no reviewer names, and no implication of completed peer review.

- [ ] **Step 3: Commit the builder only**

```bash
git add submission/code/32_build_scientific_reports_cover_letter.py
git commit -m "feat: add Scientific Reports cover letter builder"
```

---

### Task 7: Update STROBE after final pagination

**Files:**
- Create: `submission/code/33_build_scientific_reports_strobe.py`
- Create: `submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_completed.docx`
- Create: `submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_audit.tsv`
- Modify: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: final rendered manuscript/SI page maps and baseline STROBE.
- Produces: completed STROBE and row-level audit.

- [ ] **Step 1: Add failing STROBE test**

```r
testthat::test_that("Scientific Reports STROBE audit is complete", {
  audit <- read.delim(file.path(repo_root, "submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_audit.tsv"), check.names = FALSE)
  testthat::expect_false(any(audit$reported_location == ""))
  testthat::expect_true(all(audit$status == "verified"))
})
```

- [ ] **Step 2: Build stable page maps**

Use final PDFs, not JIC page numbers. Map every heading and relevant paragraph to its final page.

- [ ] **Step 3: Update all STROBE rows**

Explicitly verify design, eligibility, Day-1 SIC definition, Day-3/Day-5 landmark risk sets, outcome, missing data, assay availability, positivity, IPW, Cox/PH diagnostics, multiplicity/FDR, sensitivity analyses, limitations, generalisability, ethics, and data/code availability.

- [ ] **Step 4: Render and inspect**

```bash
python /home/oai/skills/docx/render_docx.py \
  submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_completed.docx \
  --output_dir /mnt/data/render_sr_strobe
```

- [ ] **Step 5: Test and commit**

```bash
Rscript -e "testthat::test_file('tests/testthat/test-scientific-reports-package.R')"
git add submission/code/33_build_scientific_reports_strobe.py \
        submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_completed.docx \
        submission/manuscript_files/scientific_reports/STROBE_Scientific_Reports_audit.tsv \
        tests/testthat/test-scientific-reports-package.R
git commit -m "feat: update STROBE for Scientific Reports"
```

---

### Task 8: Validate the complete package and render every deliverable

**Files:**
- Create: `submission/code/34_validate_scientific_reports_package.py`
- Create/update: all Scientific Reports QA files.
- Modify: `tests/testthat/test-scientific-reports-package.R`

**Interfaces:**
- Consumes: all final public files, private Cover Letter for local-only validation, numerical truth, source data, and baseline lock.
- Produces: release gate with `all_pass=true`.

- [ ] **Step 1: Add failing release-gate test**

```r
testthat::test_that("Scientific Reports package release gate is green", {
  report <- jsonlite::read_json(file.path(repo_root, "submission/qa/scientific_reports_package_validation.json"), simplifyVector = TRUE)
  testthat::expect_true(isTRUE(report$all_pass))
  testthat::expect_equal(report$numeric_mismatches, 0L)
  testthat::expect_equal(report$broken_cross_references, 0L)
  testthat::expect_equal(report$residual_A_labels, 0L)
  testthat::expect_equal(report$privacy_findings, 0L)
  testthat::expect_equal(report$clean_comments, 0L)
  testthat::expect_equal(report$clean_tracked_changes, 0L)
})
```

- [ ] **Step 2: Implement numerical checks**

Compare all numeric tokens in Abstract, Results, Discussion, Methods, Table 1, and figure legends against frozen numerical-truth/source-data layers. Fail on new values, sign changes, denominator changes, exponent changes, or rounding changes not already present in the baseline.

- [ ] **Step 3: Implement structure/cross-reference checks**

Require:

```text
abstract <= 200 words
keywords = 6
unchanged title
Introduction + Results + Discussion <= 4500 words
Data availability before References
Code availability within Methods
AI disclosure as final Methods subsection
zero A1-A9 labels
S1-S9 figures cited
S1-S9 tables cited or indexed
Figures 1-4 cited in order
no graphical abstract
no footnotes
figure legends <= 350 words each
main display items <= 8
```

- [ ] **Step 4: Implement DOCX hygiene and privacy checks**

Inspect OOXML for comments, `w:ins`, `w:del`, `w:vanish`, broken relationships, stale JIC release links, local paths, credentials, participant identifiers, and controlled raw-data filenames.

- [ ] **Step 5: Render every DOCX/PDF and record page audit**

Use `/home/oai/skills/docx/render_docx.py` for DOCX and `/home/oai/skills/pdfs/scripts/render_pdf.py` for PDF. Write one row per page to:

```text
file	page	clipping	overlap	broken_glyph	figure_legible	table_legible	page_break_ok	status	notes
```

All rows must be `PASS`.

- [ ] **Step 6: Run package and repository tests**

```bash
python submission/code/34_validate_scientific_reports_package.py \
  --repo-root . \
  --private-cover-letter /mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx \
  --out submission/qa/scientific_reports_package_validation.json
Rscript -e "testthat::test_dir('tests/testthat')"
Rscript submission/tests/test_submission_semantics.R
Rscript submission/tests/test_sandwich_equivalence.R
git diff --check
```

Expected: zero failures and `all_pass=true`.

- [ ] **Step 7: Commit QA evidence**

```bash
git add submission/code/34_validate_scientific_reports_package.py \
        submission/qa/scientific_reports_* \
        tests/testthat/test-scientific-reports-package.R
git commit -m "test: validate Scientific Reports submission package"
```

---

### Task 9: Freeze release metadata, open PR, merge, and publish release

**Files:**
- Create: `submission/code/35_build_scientific_reports_release_manifest.R`
- Create: `tests/testthat/test-scientific-reports-release-metadata.R`
- Modify: `README.md`
- Modify: `CITATION.cff`
- Regenerate: `submission/public_manifest.tsv`

**Interfaces:**
- Consumes: green final package.
- Produces: merged release snapshot and public tag.

- [ ] **Step 1: Add failing metadata tests**

```r
repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")
read_repo_text <- function(path) paste(readLines(file.path(repo_root, path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")

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

Retain `jic-submission-v1.0` as the immutable original submission snapshot and identify `scientific-reports-submission-v1.1` as the current journal-transfer snapshot. Preserve OMIX011182 and controlled-access language.

- [ ] **Step 3: Freeze CITATION on the actual intended publication date**

```yaml
version: 1.1.0
date-released: YYYY-MM-DD
```

`YYYY-MM-DD` must equal the day the GitHub release will actually be published. If publication is delayed to another date, update through a small PR before creating the tag.

- [ ] **Step 4: Rebuild manifest**

Run the R builder to write sorted paths, bytes, roles, and SHA-256 hashes for all public Scientific Reports files. Exclude the private Cover Letter.

- [ ] **Step 5: Run final tests**

```bash
Rscript submission/code/35_build_scientific_reports_release_manifest.R
Rscript -e "testthat::test_dir('tests/testthat')"
Rscript submission/tests/test_submission_semantics.R
python submission/code/34_validate_scientific_reports_package.py \
  --repo-root . \
  --private-cover-letter /mnt/data/scientific_reports_private_submission/Scientific_Reports_Cover_Letter.docx \
  --out submission/qa/scientific_reports_package_validation.json
git diff --check
git status --short
```

- [ ] **Step 6: Commit and open PR**

```bash
git add README.md CITATION.cff submission/public_manifest.tsv \
        submission/code/35_build_scientific_reports_release_manifest.R \
        tests/testthat/test-scientific-reports-release-metadata.R \
        submission/qa/scientific_reports_package_validation.json
git commit -m "chore: freeze Scientific Reports submission release v1.1"
git push origin release/scientific-reports-submission-v1.1
```

PR title:

```text
Freeze Scientific Reports submission release v1.1
```

PR body states that the JIC release remains unchanged, no participant-level data were added, no scientific result/model/source data/figure content changed, and all QA checks passed.

- [ ] **Step 7: Review, merge, and publish**

After author review and green GitHub Actions, squash-merge to `main`. Create tag `scientific-reports-submission-v1.1` on final `main` and release title:

```text
Scientific Reports submission reproducibility snapshot v1.1
```

Do not upload the Cover Letter or controlled data.

- [ ] **Step 8: Verify unauthenticated release**

Confirm in an Incognito/InPrivate window:

- public page is not 404;
- tag and target commit are correct;
- release is Latest and not Pre-release;
- source ZIP/tar.gz download;
- archive contains all expected public Scientific Reports files;
- Cover Letter is absent;
- `jic-submission-v1.0` remains publicly accessible and unchanged.

- [ ] **Step 9: Final handoff**

Deliver the clean manuscript, highlighted manuscript, revision report, private Cover Letter, Supplementary Information DOCX/PDF, Tables S1-S9, STROBE and audit, package-validation report, and new public release URL.