# Reproducibility guide

## Data-free validation

From repository root:

```r
source("analysis/check_inputs.R")
check_inputs("path/to/authorised/data", execution = FALSE)
```

Canonical SHA-256 and privacy tests do not require controlled data:

```r
source("tests/testthat.R")
```

## Authorised complete execution

Set the environment variables outside the repository:

- `CMAISE_DATA_DIR`: authorised local OMIX011182 analysis directory;
- `SIC_OUTPUT_DIR`: a new ignored output directory;
- optionally `R_LIBS_USER`: restored private R library.

Then run:

```r
source("analysis/run_authorized.R")
```

The canonical scripts are not edited by the launcher. Participant-level intermediates remain in ignored local output paths. Do not point `SIC_OUTPUT_DIR` at the historical frozen result directory.

## Provenance

`docs/provenance/canonical_code_inventory.tsv` records the original frozen hashes. `scripts/verify_canonical_hashes.R` verifies all exact files and records the sanitized configuration derivative. Full reruns require controlled data obtained independently from the repository.
