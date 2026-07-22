# Software environment

The frozen Windows analysis environment used R 4.4.2. Dependency versions and transitive sources are recorded in `renv.lock`; Bioconductor packages resolve against Bioconductor 3.20.

Key analysis packages include:

- survival 3.7-0;
- edgeR 4.4.2;
- fgsea 1.32.4;
- data.table 1.17.8;
- dplyr 1.2.1;
- ggplot2 4.0.1;
- testthat 3.3.2;
- org.Hs.eg.db 3.20.0.

The lockfile covers both public data-free QA and authorised local execution. The controlled dataset is not a dependency downloaded by `renv` or CI. System libraries required by figure-rendering packages remain operating-system dependencies and are documented by their R package records.

For a clean local restore:

```r
renv::restore()
```

The GitHub Actions workflow runs only parsing, SHA-256 provenance, privacy, submission-semantic and manifest tests. It never executes the controlled-data analysis launcher.
