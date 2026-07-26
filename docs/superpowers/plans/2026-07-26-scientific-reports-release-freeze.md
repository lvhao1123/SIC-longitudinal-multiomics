# Scientific Reports Release Freeze Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and validate the immutable `scientific-reports-submission-v1.1` reproducibility snapshot from the author-confirmed final manuscript package without changing `jic-submission-v1.0`.

**Architecture:** Work only on `release/scientific-reports-submission-v1.1-final-726`, use the final DOCX/PDF package as the submission authority, and retain existing vector/high-resolution figures only when rendered content matches the authoritative embedded figures. Release-specific manifests and tests enforce file hashes, privacy boundaries, pagination authority, corrected Supplementary Figure S2, and JIC tag immutability.

**Tech Stack:** Git/GitHub, R 4.4.2 and `testthat`, Python 3 for OOXML/PDF/image inspection, ImageMagick/Pillow for render comparisons, SHA-256 manifests, DOCX/PDF/XLSX/ZIP publication files.

## Global Constraints

- Do not modify, delete, move or replace `jic-submission-v1.0` or its Release assets.
- Final tag and Release name: `scientific-reports-submission-v1.1`.
- Final Release URL retained in manuscript and cover letter: `https://github.com/lvhao1123/SIC-longitudinal-multiomics/releases/tag/scientific-reports-submission-v1.1`.
- Manuscript pagination authority: 43 pages in the author's Microsoft Word environment; Table 1 is on page 43.
- Supplementary Information pagination authority: the supplied 16-page `Scientific_Reports_Supplementary_Information.pdf`.
- The editable Supplementary DOCX may render as 17 pages in LibreOffice; content completeness, not renderer-identical pagination, is the gate.
- Figures embedded in the final manuscript and 16-page Supplementary PDF are the scientific authority.
- Corrected Supplementary Figure S2 must contain all six scenario labels and the `Prespecified scenario` marker.
- `Cover_Letter_Final.docx` must not enter the public repository.
- Participant-level data, traceable identifiers, original centre labels, individual observation probabilities and individual IPW weights must not enter the public repository.

---

### Task 1: Record release invariants and baseline state

**Files:**
- Create: `submission/qa/jic_release_immutability_check.txt`
- Create: `docs/RELEASE_HISTORY.md`
- Modify: `tests/testthat/test-public-release-metadata.R`

**Interfaces:**
- Consumes: immutable JIC tag `jic-submission-v1.0`; current branch metadata.
- Produces: machine-checkable release-history expectations used by later QA.

- [ ] **Step 1: Add failing metadata tests**

Add expectations that `README.md` identifies `scientific-reports-submission-v1.1` as current, identifies `jic-submission-v1.0` as previous immutable release, and that `CITATION.cff` reports version `1.1.0`.

- [ ] **Step 2: Run the metadata test and confirm failure**

Run:

```r
source("tests/testthat.R")
```

Expected: failures for current release text and version `1.1.0` before metadata is updated.

- [ ] **Step 3: Write the immutable-release record**

Create `submission/qa/jic_release_immutability_check.txt` containing the verified JIC tag name, the pre-release target commit SHA, and explicit PASS criteria that the target and historical files remain unchanged.

- [ ] **Step 4: Write release history**

Create `docs/RELEASE_HISTORY.md` documenting:

- `jic-submission-v1.0` as immutable JIC submission snapshot;
- `scientific-reports-submission-v1.1` as the pending Scientific Reports snapshot;
- Scientific Reports S1-S9 naming versus historical JIC A1-A9 naming;
- shared controlled-data boundary and distinct manuscript/figure packaging.

- [ ] **Step 5: Commit**

```bash
git add tests/testthat/test-public-release-metadata.R docs/RELEASE_HISTORY.md submission/qa/jic_release_immutability_check.txt
git commit -m "test: protect release history and Scientific Reports metadata"
```

### Task 2: Import authoritative submission files

**Files:**
- Create: `submission/manuscript_files/Scientific_Reports_final_726.docx`
- Create: `submission/manuscript_files/Scientific_Reports_Supplementary_Information.pdf`
- Create: `submission/manuscript_files/Supplementary_methods_figures726.docx`
- Create: `submission/manuscript_files/STROBE_Final_726.docx`
- Create: `submission/manuscript_files/Scientific_Reports_Supplementary_Tables_S1-S8_and_Field_Dictionary.zip`
- Create: `submission/manuscript_files/Supplementary_Table_S9_Complete_baseline_characteristics.xlsx`
- Modify: `submission/manuscript_files/README.md`
- Test: `tests/testthat/test-scientific-reports-submission-files.R`

**Interfaces:**
- Consumes: author-confirmed files and SHA-256 values.
- Produces: stable submission-facing binary paths and hash expectations.

- [ ] **Step 1: Add failing file-presence and hash tests**

Create a test containing these exact SHA-256 expectations:

```text
Scientific_Reports_final_726.docx c2b7628752c69088da9fd2f329b8675f9222c5615ab10f96c4c2753b41ebb2fe
Scientific_Reports_Supplementary_Information.pdf 35baa2f462fc5575876fda8c6b198dfa16b804a6d826351ee87570db6c37fb30
Supplementary_methods_figures726.docx 81e9d2ed62bf75b123c9ec72d2ac15c15a10ea4bd8f5f50f706caa21adc24342
STROBE_Final_726.docx 3b8ef6ee72dd36ed503ea57d448eaafae0f95a433714d93a6982dd732cff5d0f
Scientific_Reports_Supplementary_Tables_S1-S8_and_Field_Dictionary.zip c39b2ff3b0ecbf662cdd3035cd9a1b0ef46ac4b10ed3f3de9b24b99bc44b6439
Supplementary_Table_S9_Complete_baseline_characteristics.xlsx c703d8545a54f163e6e330f90c7c2574ee1706a9a00c530bfd5a679b4054d5e3
```

Also assert that no file matching `Cover_Letter` exists under `submission/`.

- [ ] **Step 2: Run the new test and confirm failure**

Run:

```r
testthat::test_file("tests/testthat/test-scientific-reports-submission-files.R")
```

Expected: missing-file failures.

- [ ] **Step 3: Upload the six authoritative files**

Upload each binary without conversion or metadata mutation. Preserve exact bytes and names.

- [ ] **Step 4: Update the manuscript-files README**

Document the 43-page manuscript authority, 16-page PDF authority, renderer-dependent DOCX pagination, public/private boundary, and exclusion of the cover letter.

- [ ] **Step 5: Run the test and confirm pass**

Run:

```r
testthat::test_file("tests/testthat/test-scientific-reports-submission-files.R")
```

Expected: all presence, SHA-256 and exclusion checks pass.

- [ ] **Step 6: Commit**

```bash
git add submission/manuscript_files tests/testthat/test-scientific-reports-submission-files.R
git commit -m "docs: import final Scientific Reports submission package"
```

### Task 3: Audit and freeze authoritative figures

**Files:**
- Create: `scripts/audit_scientific_reports_figures.py`
- Create: `submission/qa/scientific_reports_figure_audit.tsv`
- Create/modify: `submission/figures/Figure1_study_design_risksets_availability.*`
- Create/modify: `submission/figures/Figure2_RNA_core_NES.*`
- Create/modify: `submission/figures/Figure3_Protein_core_NES.*`
- Create/modify: `submission/figures/Figure4_CrossOmics_integrated_A_to_F.*`
- Create: `submission/figures/Supplementary_Figure_S1_centre_positivity.*` through `Supplementary_Figure_S9_clinical_univariable_Cox.*`
- Create: `submission/release_manifests/scientific-reports-figure-map-v1.1.tsv`
- Test: `tests/testthat/test-scientific-reports-figures.R`

**Interfaces:**
- Consumes: final manuscript embedded images, 16-page Supplementary PDF figures, existing independent files and aggregate source-data paths.
- Produces: one authoritative figure family per manuscript figure and a deterministic mapping table.

- [ ] **Step 1: Add failing figure-map tests**

Require 13 figure identifiers (`Figure 1`-`Figure 4`, `Supplementary Figure S1`-`S9`), one authoritative source, at least PNG and TIFF independent files, and one source-data path per row.

- [ ] **Step 2: Implement the audit script**

The script must:

- extract DOCX images from `word/media/`;
- render the 16-page PDF pages containing S1-S9;
- identify figure files using dimensions and document order;
- compute SHA-256, pixel dimensions and perceptual comparison metrics;
- mark existing SVG/PDF/TIFF as `retain` only when rendered content matches the authoritative figure;
- mark mismatches as `replace`;
- assert that corrected S2 includes all six coloured scenario labels and the `Prespecified scenario` annotation in the supplied authoritative file set;
- write `submission/qa/scientific_reports_figure_audit.tsv`.

- [ ] **Step 3: Run the audit and inspect mismatches**

Run:

```bash
python scripts/audit_scientific_reports_figures.py --repo-root .
```

Expected: Figure 1-3 and at least S2/S4/S9 require explicit review or replacement; Figure 4 and scientifically equivalent figures may retain original vector/high-resolution files.

- [ ] **Step 4: Replace or retain files according to strategy A**

Use the authoritative embedded figure for scientific content. Retain an old vector file only when rendered labels, numbers, panel order and graphical content are equivalent. Generate replacement PNG/TIFF/PDF from the authoritative content when no equivalent vector source exists.

- [ ] **Step 5: Create S1-S9 figure names and mapping**

Create the Scientific Reports naming layer while leaving JIC A1-A9 files available only through the old tag/history. Populate the figure map with exact independent-file and source-data paths.

- [ ] **Step 6: Run figure tests and visual QA**

Run:

```r
testthat::test_file("tests/testthat/test-scientific-reports-figures.R")
```

Render every final PNG/TIFF/PDF and inspect for clipping, missing labels, unreadable legends, panel loss and numerical disagreement.

- [ ] **Step 7: Commit**

```bash
git add scripts/audit_scientific_reports_figures.py submission/figures submission/qa/scientific_reports_figure_audit.tsv submission/release_manifests/scientific-reports-figure-map-v1.1.tsv tests/testthat/test-scientific-reports-figures.R
git commit -m "fig: freeze Scientific Reports authoritative figures"
```

### Task 4: Validate tables and numerical truth against the final manuscript

**Files:**
- Create: `scripts/audit_scientific_reports_numbers.py`
- Create: `submission/qa/scientific_reports_numeric_audit.tsv`
- Create: `submission/qa/scientific_reports_table_audit.tsv`
- Test: `tests/testthat/test-scientific-reports-numeric-audit.R`

**Interfaces:**
- Consumes: final manuscript/SI text, S1-S9 workbooks, existing locked numerical outputs and figure-source data.
- Produces: explicit PASS/FAIL rows for every reported core value and Table 1/S9 mapping.

- [ ] **Step 1: Add failing audit-output tests**

Require audit coverage for cohort/event counts, NES/FDR examples, contemporaneous correlations, forward beta estimates, minimum observation probability, maximum raw weight, effective sample size, maximum weighted absolute SMD, NES Spearman correlation, direction agreement and Jaccard overlap.

- [ ] **Step 2: Implement numeric extraction and comparison**

Parse DOCX XML and PDF text without OCR. Compare reported values to the existing aggregate locked outputs and source-data files. Use exact string comparison for counts and controlled numeric tolerances matching displayed precision for continuous values.

- [ ] **Step 3: Validate Table 1 as a strict S9 subset**

Compare characteristic names, group summaries, SMD and P values. Record every mapped row and fail on any mismatch.

- [ ] **Step 4: Validate all supplementary workbooks**

Confirm S1-S8 and field dictionary entries exist in the ZIP, each workbook opens, expected worksheets are present, and S9 opens independently.

- [ ] **Step 5: Run the audit and tests**

Run:

```bash
python scripts/audit_scientific_reports_numbers.py --repo-root .
Rscript -e 'testthat::test_file("tests/testthat/test-scientific-reports-numeric-audit.R")'
```

Expected: zero unresolved numeric or Table 1/S9 mismatches.

- [ ] **Step 6: Commit**

```bash
git add scripts/audit_scientific_reports_numbers.py submission/qa/scientific_reports_numeric_audit.tsv submission/qa/scientific_reports_table_audit.tsv tests/testthat/test-scientific-reports-numeric-audit.R
git commit -m "test: audit final manuscript numbers and tables"
```

### Task 5: Update release metadata and manifests

**Files:**
- Modify: `README.md`
- Modify: `CITATION.cff`
- Modify: `submission/public_manifest.tsv`
- Create: `submission/release_manifests/scientific-reports-submission-v1.1.tsv`
- Modify: `tests/testthat/test-public-release-metadata.R`
- Create: `tests/testthat/test-scientific-reports-release-manifest.R`

**Interfaces:**
- Consumes: final file tree and SHA-256 values from Tasks 2-4.
- Produces: complete release metadata and manifest gates.

- [ ] **Step 1: Update README**

Identify the current pending release as Scientific Reports v1.1, preserve the controlled-data boundary, list the final package, and identify JIC v1.0 as an immutable previous release.

- [ ] **Step 2: Update CITATION.cff**

Set `version: 1.1.0`; use the actual release date only at final publication; retain repository URL and controlled-data description.

- [ ] **Step 3: Regenerate manifests**

Generate a release-specific TSV containing every public file path, byte size, role and SHA-256. Regenerate `submission/public_manifest.tsv` from the same tree after excluding private/editorial files.

- [ ] **Step 4: Add manifest tests**

Assert that all manifest paths exist, sizes and SHA-256 values match, no cover-letter/private path appears, and all required Scientific Reports package files and S1-S9 figures are present.

- [ ] **Step 5: Run metadata and manifest tests**

Run:

```r
source("tests/testthat.R")
```

Expected: metadata and manifest tests pass.

- [ ] **Step 6: Commit**

```bash
git add README.md CITATION.cff submission/public_manifest.tsv submission/release_manifests tests/testthat
git commit -m "release: prepare Scientific Reports v1.1 metadata"
```

### Task 6: Run final privacy, document and repository QA

**Files:**
- Create: `submission/qa/scientific_reports_final_QA.tsv`
- Create: `submission/qa/scientific_reports_document_render_QA.txt`
- Modify only when a test exposes a release-specific defect.

**Interfaces:**
- Consumes: complete candidate release tree.
- Produces: final evidence required before PR merge and tag creation.

- [ ] **Step 1: Render and inspect documents**

Render the main DOCX and editable Supplementary DOCX; separately render the supplied 16-page PDF. Record:

- author-confirmed main manuscript authority: 43 pages;
- author-confirmed Supplementary PDF authority: 16 pages;
- LibreOffice Supplementary DOCX variance when present;
- no empty pages, clipping, overlap, missing figures or truncated tables.

- [ ] **Step 2: Run privacy scans**

Scan filenames and text-bearing files for participant/sample identifier patterns, original centre names, individual probabilities/weights, private repository names and cover-letter/editorial content. Inspect binary package contents for unexpected files.

- [ ] **Step 3: Run canonical and data-free tests**

Run:

```r
source("scripts/verify_canonical_hashes.R")
source("tests/testthat.R")
```

Expected: zero failures.

- [ ] **Step 4: Verify JIC immutability**

Re-fetch `jic-submission-v1.0`, confirm its target/content hashes match the baseline record, and append post-change PASS evidence to `submission/qa/jic_release_immutability_check.txt`.

- [ ] **Step 5: Write final QA summary**

`submission/qa/scientific_reports_final_QA.tsv` must contain one row per gate with `PASS`, evidence path and timestamp. No `WARN` may remain for scientific content, privacy, figures, numbers, tables, manifests or release history.

- [ ] **Step 6: Commit**

```bash
git add submission/qa
git commit -m "test: complete Scientific Reports release QA"
```

### Task 7: Review, merge, tag and publish

**Files:**
- No content changes after the final QA commit except an actual release date update before the final tag.

**Interfaces:**
- Consumes: all-PASS branch and exact head SHA.
- Produces: merged immutable tag and public GitHub Release.

- [ ] **Step 1: Open a pull request**

Open `release/scientific-reports-submission-v1.1-final-726` into `main` with a checklist linking all QA evidence.

- [ ] **Step 2: Review changed files and CI**

Confirm the PR contains no cover letter/private data, no unexpected deletions of analysis assets, and no modification to the historical JIC tag or Release.

- [ ] **Step 3: Update final release date and rerun tests**

Set the actual date in `CITATION.cff`, regenerate affected manifests, run the complete test suite, and commit exactly once.

- [ ] **Step 4: Merge using the verified head SHA**

Use a merge method that preserves an auditable final commit. Record the merged commit SHA.

- [ ] **Step 5: Create the immutable tag**

Create `scientific-reports-submission-v1.1` from the recorded merged commit. Do not create or move this tag before merge.

- [ ] **Step 6: Create the GitHub Release**

Title: `Scientific Reports submission reproducibility snapshot v1.1`.

Release notes must state the controlled-data boundary, list the manuscript/SI/STROBE/tables/figures, identify corrected Supplementary Figure S2, and link OMIX011182.

- [ ] **Step 7: Verify anonymous access**

Open the Release in a signed-out/private browser, download the source archive and any assets, verify hashes against `scientific-reports-submission-v1.1.tsv`, and confirm the manuscript/cover-letter URL resolves.

- [ ] **Step 8: Final submission gate**

Only after anonymous verification, upload the unchanged manuscript and cover letter to Scientific Reports. If the Release URL differs from the planned URL, stop and update both documents before submission.
