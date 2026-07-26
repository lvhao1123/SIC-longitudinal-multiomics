# SIC longitudinal multi-omics analysis

This repository is the data-free reproducibility archive supporting a multicentre
longitudinal study of landmark-specific mortality-associated whole-blood RNA-seq
and plasma protein programmes in Day-1-defined sepsis-induced coagulopathy.

Final repository URL:

https://github.com/lvhao1123/SIC-longitudinal-multiomics

## Controlled-data boundary

Individual-level clinical, whole-blood RNA-seq and plasma proteomic data from
CMAISE/OMIX011182 are controlled-access data and are not redistributed here.
Authorised investigators must obtain formal approval from the National Genomics
Data Center:

https://ngdc.cncb.ac.cn/omix/release/OMIX011182

Use of the controlled dataset should identify accession `OMIX011182`. The
OMIX011182 record instructs users to cite: Nature Communications. 2025;16:10328.
https://doi.org/10.1038/s41467-025-65271-4 (PMID: 41285725).

The authors are not authorised to redistribute controlled source files,
participant identifiers, traceable sample identifiers, original centre
identifiers, individual observation probabilities or individual
inverse-observation weights.

The repository does not replace the OMIX application process and does not grant
rights in the controlled source data.

## Repository contents

The public reproducibility layer contains:

- frozen and provenance-verified analysis code;
- repository-relative interfaces for authorised local execution;
- aggregate non-identifiable result tables and figure source data;
- numerical-truth and SHA-256 manifest layers;
- data-free privacy, semantic and reproducibility tests;
- `renv.lock` and software-environment records.

Public centre labels are anonymised as `Centre 01` to `Centre 30`.

## Scientific Reports v1.1 final package

The exact author-confirmed final submission package is distributed with the
GitHub Release as:

`scientific-reports-submission-v1.1-assets.zip`

Expected asset size and SHA-256:

- `37,592,790` bytes
- `07928a393f5cd937d37ca1d601492631e7c4d2c90072ab8825536f06c524afdb`

The asset contains the final manuscript, the pagination-authoritative 16-page
Supplementary Information PDF, the editable Supplementary DOCX, the corrected
STROBE checklist, Supplementary Tables S1-S9, the field dictionary, and
independent PNG/TIFF/PDF files for Figures 1-4 and Supplementary Figures S1-S9.
The corrected Supplementary Figure S2 contains all six scenario labels and the
`Prespecified scenario` marker.

Superseded JIC and pre-final Scientific Reports binary files have been removed
from the current branch. The immutable `jic-submission-v1.0` tag preserves the
historical JIC package. The cover letter is private and is not included in the
repository or asset.

Release QA and file mappings are documented in:

- `submission/qa/scientific_reports_final_package_QA.md`;
- `submission/qa/scientific_reports_figure_audit.tsv`;
- `submission/qa/scientific_reports_numeric_audit.tsv`;
- `submission/release_manifests/scientific-reports-figure-map-v1.1.tsv`;
- `submission/release_manifests/scientific-reports-submission-v1.1-release-assets.tsv`.

## Reproducibility scope

Data-free quality-assurance tests can be run without controlled source data. A
complete numerical rerun requires separately authorised CMAISE/OMIX011182 files
supplied locally through the documented input contract.

### Data-free validation

From the repository root in R:

```r
source("tests/testthat.R")
```

Canonical hash verification can also be run directly:

```r
source("scripts/verify_canonical_hashes.R")
```

The GitHub Actions workflow performs only data-free checks and does not execute
participant-level analyses.

### Authorised complete execution

After obtaining formal data access, keep the controlled files outside Git and
set the required environment variables as described in:

- `docs/DATA_ACCESS.md`;
- `docs/DATA_DICTIONARY.md`;
- `docs/REPRODUCIBILITY.md`.

The authorised launcher is:

```r
source("analysis/run_authorized.R")
```

Participant-level intermediates must remain under ignored local paths such as
`private_outputs/` and `private_audit/`.

## Software environment

The frozen analysis used R 4.4.2. Package versions are recorded in `renv.lock`,
and the main environment details are documented in
`docs/SOFTWARE_ENVIRONMENT.md`.

A clean dependency restore can be started with:

```r
renv::restore()
```

## Citation

Citation metadata are provided in `CITATION.cff`. Until the associated article
and archived repository release receive persistent identifiers, cite the exact
GitHub release used and the repository authors. The README will be updated with
the article DOI and archival DOI after publication metadata become available.

## Licensing

- Original software is licensed under the MIT License in `LICENSE`.
- Eligible original documentation, figures and aggregate non-identifiable
  source data are licensed under CC BY 4.0 as described in
  `LICENSE-CONTENT.md`.
- Exact scope, exclusions and manuscript-file treatment are defined in
  `LICENSE_SCOPE.md`.
- Controlled and third-party resource notices are provided in
  `THIRD_PARTY_NOTICES.md`.

No repository licence applies to CMAISE/OMIX011182 participant-level data,
MSigDB Hallmark gene-set files or other third-party materials.

## Release history

The immutable original submission snapshot for the *Journal of Intensive Care*
is versioned as `jic-submission-v1.0`:

https://github.com/lvhao1123/SIC-longitudinal-multiomics/releases/tag/jic-submission-v1.0

The Scientific Reports final submission snapshot will be versioned as
`scientific-reports-submission-v1.1`:

https://github.com/lvhao1123/SIC-longitudinal-multiomics/releases/tag/scientific-reports-submission-v1.1

The v1.1 snapshot preserves the frozen cohort, estimands, models and aggregate
source data while replacing the journal-facing package and independent figure
files with the author-confirmed final versions.
