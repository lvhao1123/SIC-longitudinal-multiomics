#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/") else normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
REPO_ROOT <- normalizePath(file.path(CLOSEOUT, ".."), winslash = "/")
source(file.path(REPO_ROOT, "outputs", "SIC_reanalysis_2026-07-11", "code", "00_config.R"))
source(file.path(CLOSEOUT, "code", "26_public_centre_anonymisation.R"))
suppressPackageStartupMessages({library(data.table); library(openxlsx)})
ROOT <- OUT_ROOT
SRC <- file.path(ROOT, "06_Availability_IPW_final")
PUB <- file.path(CLOSEOUT, "public_source_data")

files <- c(
  Entry_risksets = "00_entry_riskset_counts.csv",
  Centre_positivity = "01_centre_positivity_audit.csv",
  Time_origin_audit = "02_survival_time_origin_and_60day_audit.csv",
  Covariate_missingness = "03_availability_covariate_missingness.csv",
  Protein_availability = "04_D5_Protein_descriptive_availability_and_nesting.csv",
  Prefit_diagnostics = "05_availability_prefit_rank_separation.csv",
  Weight_diagnostics = "08_weight_diagnostics.csv",
  Balance_SMD = "09_weight_balance_SMD.csv",
  Transform_constants = "10_frozen_transform_constants.csv",
  Cox_PH_audit = "13_Cox_convergence_finite_PH_summary.csv",
  Hallmark_all_models = "14_all_weighted_Hallmark_results.csv",
  Hallmark_leading_edges = "15_all_weighted_Hallmark_leading_edges.csv",
  Hallmark_comparison = "16_all_Hallmark_unweighted_vs_IPW.csv",
  Scenario_metrics = "17_all_Hallmark_comparison_metrics.csv",
  Frozen_internal_QA = "18_final_QA.csv"
)
stopifnot(all(file.exists(file.path(SRC, files))))

centre_audit <- fread(file.path(SRC, files[["Centre_positivity"]]), data.table = FALSE)
centre_map <- build_public_centre_map(centre_audit$center)

wb <- createWorkbook(creator = "SIC freeze closeout")
header <- createStyle(fgFill = "#D9EAF4", textDecoration = "bold", border = "Bottom")
for (nm in names(files)) {
  original <- fread(file.path(SRC, files[[nm]]), data.table = FALSE)
  bad <- grepl("patient.?id|samplename|subject.?id|ps_raw|sw_trim", names(original), ignore.case = TRUE)
  if (any(bad)) stop("Privacy-sensitive column in public supplement: ", paste(names(original)[bad], collapse = ", "))

  public <- anonymise_public_centre_frame(original, centre_map)
  if (nm %in% c("Centre_positivity", "Balance_SMD")) {
    assert_public_centre_labels(public, centre_map)
  }

  # Anonymisation changes label strings only. All numeric and non-label fields
  # must remain exactly identical to the frozen source table.
  label_columns <- intersect(c("center", "centre", "variable"), names(original))
  invariant_columns <- setdiff(names(original), label_columns)
  if (!identical(original[invariant_columns], public[invariant_columns])) {
    stop("Public centre anonymisation changed non-label fields in ", nm)
  }

  addWorksheet(wb, nm)
  writeData(wb, nm, public, headerStyle = header, withFilter = TRUE)
  freezePane(wb, nm, firstRow = TRUE)
  setColWidths(wb, nm, cols = seq_len(ncol(public)), widths = "auto")
  fwrite(public, file.path(PUB, paste0("SupplementaryTable_", nm, ".tsv")), sep = "\t", na = "")
}
saveWorkbook(wb, file.path(PUB, "Supplementary_Tables_Availability_IPW.xlsx"), overwrite = TRUE)
writeLines(capture.output(sessionInfo()), file.path(PUB, "sessionInfo_supplement_table_build.txt"), useBytes = TRUE)
cat("Availability/IPW supplementary workbook created from frozen result tables with public centre labels.\n")
