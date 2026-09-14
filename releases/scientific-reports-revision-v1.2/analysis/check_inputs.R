expected_input_contract <- function(data_dir) {
  data_dir <- normalizePath(data_dir, winslash = "/", mustWork = FALSE)
  data.frame(
    logical_name = c(
      "clinical",
      "raw_clinical",
      "rna_counts",
      "protein",
      "protein_qc",
      "hallmark"
    ),
    relative_location = c(
      "SIC_504_baseline_carried_forward_annotation.csv",
      "../OMIX011182-01.csv",
      "OMIX011182-04.txt",
      "OMIX011182-05.xlsx",
      "SIC_detailed_analysis_phase1/13_protein_feature_qc.csv",
      "h.all.v2026.1.Hs.symbols.gmt"
    ),
    role = c(
      "SIC cohort annotation and baseline covariates",
      "source clinical sample annotation",
      "whole-blood RNA count matrix",
      "plasma proteomic abundance matrix",
      "frozen protein feature QC decision table",
      "MSigDB Hallmark gene-set definitions"
    ),
    access_class = rep("controlled_or_licensed", 6L),
    stringsAsFactors = FALSE
  ) |>
    transform(path = file.path(data_dir, relative_location))
}

check_inputs <- function(data_dir, execution = FALSE) {
  contract <- expected_input_contract(data_dir)
  report <- transform(contract, present = file.exists(path))
  report <- report[c(
    "logical_name",
    "relative_location",
    "role",
    "access_class",
    "present"
  )]

  if (isTRUE(execution) && any(!report$present)) {
    stop(
      "Missing required controlled inputs: ",
      paste(report$logical_name[!report$present], collapse = ", ")
    )
  }
  report
}

if (sys.nframe() == 0L) {
  data_dir <- Sys.getenv("CMAISE_DATA_DIR", unset = "")
  execution <- "--execute" %in% commandArgs(trailingOnly = TRUE)
  if (!nzchar(data_dir)) {
    if (execution) stop("Set CMAISE_DATA_DIR before authorised execution")
    data_dir <- "."
  }
  report <- check_inputs(data_dir, execution = execution)
  print(report, row.names = FALSE)
}
