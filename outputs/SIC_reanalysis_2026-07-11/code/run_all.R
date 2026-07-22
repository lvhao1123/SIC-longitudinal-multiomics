# Master restartable workflow. Each stage runs in a clean R process, which is safer on
# Windows and prevents parallel back-end state from leaking into later stages.
options(stringsAsFactors = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
scripts <- c(
  "00b_build_official_gene_map.R",
  "01_run_RNA_TMM_cox_fgsea.R",
  "01b_finalize_RNA_GSEA.R",
  "02_run_Protein_QC_cox_fgsea.R",
  "02b_finalize_Protein_GSEA.R",
  "03_run_patient_scores_crossomics.R",
  "05_compare_historical_and_summarize.R",
  "06_build_RNA_normalization_robustness.R",
  "09_build_clinical_tables.R",
  "10_run_availability_IPW_sensitivity.R",
  "04_make_figures_tables.R",
  "08_validate_final_outputs.R",
  "07_freeze_manifest.R"
)
base <- "outputs/SIC_reanalysis_2026-07-11/code"
for (s in scripts) {
  cat("\n===== RUNNING", s, "=====\n")
  status <- system2(rscript, file.path(base, s))
  if (!identical(status, 0L)) stop("Stage failed: ", s, " (status ", status, ")")
}
