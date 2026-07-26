# Scientific Reports release freeze design

## Objective

Freeze a Scientific Reports submission-specific, data-free reproducibility release that exactly matches the author-confirmed final manuscript package while preserving the immutable Journal of Intensive Care release history.

## Authoritative submission files

The Scientific Reports release uses the following author-confirmed files as the only submission-facing sources of truth:

- `Scientific_Reports_final_726.docx` — 43-page manuscript in the author's Microsoft Word environment; Table 1 is on page 43.
- `Scientific_Reports_Supplementary_Information.pdf` — 16-page pagination-authoritative Supplementary Information exported from Microsoft Word.
- `Supplementary_methods_figures726.docx` — editable Supplementary Information source; renderer-dependent pagination is not treated as a release failure when content is complete.
- `STROBE_Final_726.docx` — final cohort-study checklist using the author-confirmed page-number convention.
- `Scientific_Reports_Supplementary_Tables_S1-S8_and_Field_Dictionary.zip` — machine-readable Supplementary Tables S1-S8 and field dictionary.
- `Supplementary_Table_S9_Complete_baseline_characteristics.xlsx` — machine-readable Supplementary Table S9.

`Cover_Letter_Final.docx` remains a private submission document and is excluded from the public reproducibility repository.

## Version isolation

- Existing immutable release: `jic-submission-v1.0`.
- New isolated working branch: `release/scientific-reports-submission-v1.1-final-726`.
- New final tag and Release: `scientific-reports-submission-v1.1`.
- The manuscript and cover letter retain the existing final Release URL: `https://github.com/lvhao1123/SIC-longitudinal-multiomics/releases/tag/scientific-reports-submission-v1.1`.
- The old JIC tag, tag target, release assets and historical manifest must never be edited, deleted, moved or replaced.
- If a defect is found after publication of the Scientific Reports release, create a new immutable patch tag rather than moving `scientific-reports-submission-v1.1`.

## Figure authority and publication files

The scientific content of Figures 1-4 and Supplementary Figures S1-S9 is defined by the figures embedded in the author-confirmed final manuscript and the 16-page Supplementary Information PDF.

Use figure strategy A:

1. Extract the embedded figures from the final files.
2. Compare them with existing repository PNG, TIFF, PDF and SVG files by hash and rendered appearance.
3. Preserve original vector/high-resolution files only when they are scientifically and visually equivalent to the authoritative embedded figure.
4. Replace any file whose labels, numbers, panel order, legends, annotations or plotted content differ.
5. Supplementary Figure S2 is explicitly replaced by the corrected version in the latest Supplementary Information files; the six scenario labels and the `Prespecified scenario` marker must be present.
6. Generate a Scientific Reports figure map linking each manuscript figure to the independent publication file and aggregate source-data file.
7. Preserve all JIC A1-A9 figure files inside the immutable JIC tag; Scientific Reports files use S1-S9 names.

## Public reproducibility scope

The release includes all legally publishable material needed to audit or reproduce reported outputs:

- frozen analysis code and QA scripts;
- authorised local-rerun interfaces;
- `renv.lock` and software environment records;
- locked numerical outputs and numeric-truth tables/dictionaries;
- aggregate result tables and figure-source data;
- Figures 1-4 and Supplementary Figures S1-S9 in suitable publication formats;
- Supplementary Tables S1-S9 and the S1-S8 field dictionary;
- final manuscript, 16-page Supplementary Information PDF, editable Supplementary Information DOCX and STROBE checklist;
- release-specific SHA-256 manifest, figure map, README, citation metadata, release history and QA reports.

The public release excludes participant-level clinical or omic data, participant or traceable sample identifiers, original centre identifiers, individual observation probabilities, individual IPW weights, cover letters and private editorial records.

## Pagination rules

- Manuscript pagination authority: 43 pages in the author's Microsoft Word environment.
- Supplementary Information pagination authority: the supplied 16-page PDF.
- The editable DOCX may render as 17 pages in LibreOffice because the final abbreviation lines can flow to an additional page; this is renderer variance, not content failure.
- Automated QA validates completeness, absence of blank pages, absence of clipping and presence of S1-S9/Table S9 rather than requiring identical DOCX page count across rendering engines.

## Release namespace and manifests

Use Scientific Reports-specific names under `submission/manuscript_files/` and do not store the new manuscript under JIC filenames.

Create or update:

- `submission/release_manifests/scientific-reports-submission-v1.1.tsv`
- `submission/release_manifests/scientific-reports-figure-map-v1.1.tsv`
- `submission/qa/jic_release_immutability_check.txt`
- `docs/RELEASE_HISTORY.md`

The current aggregate manifest may be regenerated, but the JIC release-specific record remains immutable.

## Mandatory release gates

1. Document gate: final files are present, clean and complete; Word manuscript authority is 43 pages and PDF supplement authority is 16 pages.
2. Numeric gate: manuscript and figure numbers match locked outputs for cohorts, events, NES/FDR, correlations, beta coefficients, IPW diagnostics, direction agreement and Jaccard overlap.
3. Table gate: Table 1 is a strict subset of S9 and all S1-S9 files are readable and correctly mapped.
4. Figure gate: independent figures are scientifically identical to the authoritative embedded figures; corrected S2 is used.
5. Privacy gate: no participant-level or restricted material is included.
6. Repository gate: data-free tests, canonical hashes, paths, metadata and manifests pass.
7. History gate: `jic-submission-v1.0` remains unchanged.
8. Link gate: the final Release URL is publicly and anonymously accessible before journal submission.

## Publication sequence

1. Create isolated branch from current `main`.
2. Commit this approved design and the implementation plan.
3. Import authoritative final files and corrected figures.
4. Update Scientific Reports metadata, manifests, tests and documentation.
5. Run full QA and record evidence.
6. Open and review a pull request against `main`.
7. Merge only after all gates pass.
8. Create `scientific-reports-submission-v1.1` from the unique merged commit.
9. Create the GitHub Release and verify anonymous access and hashes.
