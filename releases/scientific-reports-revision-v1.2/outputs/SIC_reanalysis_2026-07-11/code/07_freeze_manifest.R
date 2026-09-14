rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
if (!requireNamespace("digest", quietly = TRUE)) stop("digest package is required")

files <- list.files(OUT_ROOT, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)
manifest_path <- file.path(OUT_ROOT, "FILE_MANIFEST_SHA256.csv")
files <- files[normalizePath(files, winslash = "/", mustWork = FALSE) != normalizePath(manifest_path, winslash = "/", mustWork = FALSE)]
info <- file.info(files)
manifest <- data.frame(
  relative_path = substring(normalizePath(files, winslash = "/"), nchar(normalizePath(OUT_ROOT, winslash = "/")) + 2),
  bytes = info$size,
  modified = format(info$mtime, "%Y-%m-%d %H:%M:%S %z"),
  sha256 = vapply(files, digest::digest, FUN.VALUE = character(1), file = TRUE, algo = "sha256", serialize = FALSE)
)
data.table::fwrite(manifest, manifest_path)
writeLines(capture.output(sessionInfo()), file.path(OUT_ROOT, "SESSION_INFO_FREEZE.txt"))
