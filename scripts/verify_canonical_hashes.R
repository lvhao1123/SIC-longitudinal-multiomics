args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args)) args[[1]] else "."
repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)

if (!requireNamespace("digest", quietly = TRUE)) {
  stop("Package 'digest' is required")
}

inventory_path <- file.path(
  repo_root,
  "docs",
  "provenance",
  "canonical_code_inventory.tsv"
)
inventory <- read.delim(
  inventory_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

destination <- file.path(repo_root, inventory$destination_path)
if (!all(file.exists(destination))) {
  stop(
    "Missing canonical files:\n",
    paste(inventory$destination_path[!file.exists(destination)], collapse = "\n")
  )
}

destination_sha256 <- vapply(
  destination,
  digest::digest,
  character(1),
  algo = "sha256",
  serialize = FALSE,
  file = TRUE
)

result <- transform(
  inventory,
  destination_sha256 = unname(destination_sha256),
  exact_match = unname(destination_sha256) == original_sha256
)

required <- result$exact_match_required
if (!all(result$exact_match[required])) {
  stop("One or more exact frozen files failed SHA-256 verification")
}
if (!all(result$classification[!required] == "sanitized_config_derivative")) {
  stop("Every non-exact file must be classified as a sanitized configuration derivative")
}
if (any(result$exact_match[!required])) {
  stop("The tracked configuration unexpectedly matches the workstation-specific original")
}

manifest_path <- file.path(
  repo_root,
  "docs",
  "provenance",
  "migration_manifest.tsv"
)
write.table(
  result,
  manifest_path,
  sep = "\t",
  row.names = FALSE,
  quote = FALSE,
  na = ""
)

cat(
  sum(result$exact_match_required),
  "exact frozen files verified;",
  sum(!result$exact_match_required),
  "sanitized configuration derivative recorded.\n"
)
