args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(if (length(args)) args[[1]] else ".", winslash = "/")
submission_root <- file.path(repo_root, "submission")

if (!requireNamespace("digest", quietly = TRUE)) {
  stop("Package 'digest' is required")
}

files <- list.files(
  submission_root,
  recursive = TRUE,
  full.names = TRUE,
  all.files = FALSE,
  include.dirs = FALSE
)

# Exclude generated interpreter caches and the manifest itself. These files are
# machine- and runtime-specific, are ignored by Git, and must never become
# release assets or manifest entries.
normalized_files <- normalizePath(files, winslash = "/", mustWork = TRUE)
transient <- grepl(
  "(^|/)(__pycache__|[.]pytest_cache)(/|$)|[.](pyc|pyo)$",
  normalized_files,
  ignore.case = TRUE
)
files <- files[!transient & basename(files) != "public_manifest.tsv"]

relative <- substring(
  normalizePath(files, winslash = "/"),
  nchar(repo_root) + 2L
)

role_from_path <- function(path) {
  if (grepl("/figures/", path)) return("publication_figure")
  if (grepl("/supplementary_files/", path)) return("supplementary_workbook")
  if (grepl("/manuscript_files/", path)) return("submission_manuscript_file")
  if (grepl("/public_source_data/", path)) return("aggregate_source_data")
  if (grepl("/manuscript_support/", path)) return("manuscript_support")
  if (grepl("/code/", path)) return("submission_production_code")
  if (grepl("/tests/", path)) return("submission_test")
  if (grepl("/qa/", path)) return("aggregate_QA")
  if (grepl("numeric_truth", path)) return("numeric_truth")
  "repository_interface"
}

manifest <- data.frame(
  path = relative,
  bytes = as.numeric(file.info(files)$size),
  role = vapply(relative, role_from_path, character(1)),
  sha256 = vapply(
    files,
    digest::digest,
    character(1),
    algo = "sha256",
    serialize = FALSE,
    file = TRUE
  ),
  stringsAsFactors = FALSE
)
manifest <- manifest[order(manifest$path), ]

write.table(
  manifest,
  file.path(submission_root, "public_manifest.tsv"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE,
  na = ""
)
cat(nrow(manifest), "submission assets recorded.\n")
