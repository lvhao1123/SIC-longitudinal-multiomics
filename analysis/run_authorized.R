args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(
  Sys.getenv("SIC_PROJECT_DIR", unset = getwd()),
  winslash = "/",
  mustWork = TRUE
)
data_dir <- Sys.getenv("CMAISE_DATA_DIR", unset = "")
if (!nzchar(data_dir)) {
  stop("Set CMAISE_DATA_DIR to the authorised OMIX011182 directory")
}

source(file.path(repo_root, "analysis", "check_inputs.R"))
invisible(check_inputs(data_dir, execution = TRUE))

output_dir <- Sys.getenv(
  "SIC_OUTPUT_DIR",
  unset = file.path(repo_root, "private_outputs", "SIC_reanalysis_2026-07-11")
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

Sys.setenv(
  SIC_PROJECT_DIR = repo_root,
  CMAISE_DATA_DIR = normalizePath(data_dir, winslash = "/", mustWork = TRUE),
  SIC_OUTPUT_DIR = normalizePath(output_dir, winslash = "/", mustWork = TRUE)
)

old_wd <- setwd(repo_root)
on.exit(setwd(old_wd), add = TRUE)

# The frozen statistical scripts and their order remain unchanged. The only
# inserted stage assembles the clinical Excel workbook from already-generated
# CSV tables; it does not refit or modify any statistical result.
frozen_code <- file.path(repo_root, "outputs", "SIC_reanalysis_2026-07-11", "code")
stages <- c(
  file.path(frozen_code, "00b_build_official_gene_map.R"),
  file.path(frozen_code, "01_run_RNA_TMM_cox_fgsea.R"),
  file.path(frozen_code, "01b_finalize_RNA_GSEA.R"),
  file.path(frozen_code, "02_run_Protein_QC_cox_fgsea.R"),
  file.path(frozen_code, "02b_finalize_Protein_GSEA.R"),
  file.path(frozen_code, "03_run_patient_scores_crossomics.R"),
  file.path(frozen_code, "05_compare_historical_and_summarize.R"),
  file.path(frozen_code, "06_build_RNA_normalization_robustness.R"),
  file.path(frozen_code, "09_build_clinical_tables.R"),
  file.path(repo_root, "analysis", "build_clinical_workbook.R"),
  file.path(frozen_code, "10_run_availability_IPW_sensitivity.R"),
  file.path(frozen_code, "04_make_figures_tables.R"),
  file.path(frozen_code, "08_validate_final_outputs.R"),
  file.path(frozen_code, "07_freeze_manifest.R")
)

rscript <- file.path(R.home("bin"), "Rscript.exe")
for (stage in stages) {
  message("===== RUNNING ", basename(stage), " =====")
  status <- system2(rscript, stage)
  if (!identical(status, 0L)) {
    stop("Authorised stage failed: ", basename(stage), " (status ", status, ")")
  }
}
