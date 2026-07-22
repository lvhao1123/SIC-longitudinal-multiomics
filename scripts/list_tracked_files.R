list_tracked_files <- function(repo_root = ".") {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  system2(
    "git",
    c("-C", shQuote(repo_root), "ls-files"),
    stdout = TRUE
  )
}

run_privacy_checks <- function(repo_root = ".") {
  tracked <- list_tracked_files(repo_root)
  forbidden <- c(
    "OMIX011182-01.csv",
    "OMIX011182-04.txt",
    "OMIX011182-05.xlsx",
    "SIC_504_baseline_carried_forward_annotation.csv"
  )
  public_data <- tracked[grepl("(^|/)public_source_data/", tracked)]
  checks <- data.frame(
    check = c("controlled_inputs_not_tracked", "public_filenames_not_identifiable"),
    pass = c(
      !any(basename(tracked) %in% forbidden),
      !any(grepl("PatientID|SampleName", basename(public_data), ignore.case = TRUE))
    ),
    stringsAsFactors = FALSE
  )
  checks
}

if (sys.nframe() == 0L) {
  result <- run_privacy_checks(".")
  print(result, row.names = FALSE)
  if (!all(result$pass)) quit(status = 1L)
}
