# Rebuild all manuscript figures from aggregate data

Use R 4.4.2 and the package versions in `environment/`. From a fresh RStudio session, open this package as the working directory and run:

```r
source("plotting/run_all_figures.R")
```

Command-line equivalent, from the package root:

```
Rscript --vanilla plotting/run_all_figures.R NEW_OUTPUT_DIRECTORY
```

The entry runs each drawing script in a new `--vanilla` R process, creates all outputs in a new directory, records commands, versions, errors and warnings, and maps legacy internal stems to current S1–S15 names. Existing output directories are refused. No saved workspace, patient-level input, network access, dependency installation, model fit or FDR recalculation is used. Drawing objects under the output `private/` directory are created during this run only; they are not supplied as inputs.

Required packages: data.table, dplyr, tidyr, stringr, ggplot2, patchwork, svglite, ragg and jsonlite. The installed library is used without changing global settings. Missing packages cause a clear stop; install the recorded versions into a project library if needed.

The index covers 19 figures and 23 parts. S3 has three parts, S9 two parts (25+15 contrasts), and S15 two parts (50 pathways and 300 cells). Figure 4 retains its matched panel-e results. Physical source sizes and manuscript embedding sizes differ; preserve the approved embedding proportions.

Successful execution is distinct from numerical and visual acceptance, and aggregate-data figure reproduction is not independent patient-level statistical reproduction or confirmation of experimental QC assumptions.
