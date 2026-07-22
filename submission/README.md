# Submission-production layer

This directory is a repository interface over the frozen statistical outputs. It does not redefine the estimand, refit formal models or replace the canonical analysis.

- `code/`: figure, manuscript, evidence and QA production scripts with repository-relative interfaces;
- `tests/`: frozen semantic and sandwich-equivalence test entry points;
- `figures/`: four main figures, eight availability/IPW supplementary figures and the exploratory clinical Cox forest plot (A9) in PDF, SVG, TIFF and PNG;
- `supplementary_files/`: submission-ready aggregate workbooks S1-S8; participant-level CMAISE data are not redistributed;
- `manuscript_files/`: clean manuscript, Additional files 1 and 2, and the completed STROBE cohort checklist;
- `public_source_data/`: aggregate, non-identifiable figure and supplementary-table source data;
- `manuscript_support/`: numeric stubs, figure legends, Methods, Results, Limitations and evidence specifications;
- `qa/`: aggregate QA summaries only;
- `numeric_truth_table.tsv` and `numeric_truth_dictionary.tsv`: the single numeric truth layer for manuscript production.

`manuscript_support/Supplementary_upload_manifest.tsv` maps manuscript labels S1-S8 and A1-A9 to the exact submission files. The clinical univariable forest plot is supplementary descriptive context; it does not establish independent predictors or alter the frozen molecular analyses.

The historical `07_Freeze_Closeout` name appears only in archived explanatory prose. Executable paths in this repository use `submission/`.
