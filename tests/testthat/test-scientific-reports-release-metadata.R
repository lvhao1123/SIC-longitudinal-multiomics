repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")
read_repo_text <- function(path) paste(readLines(file.path(repo_root, path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")

testthat::test_that("Scientific Reports release metadata identifies dated v1.1", {
  readme <- read_repo_text("README.md")
  citation <- read_repo_text("CITATION.cff")
  url <- "https://github.com/lvhao1123/SIC-longitudinal-multiomics/releases/tag/scientific-reports-submission-v1.1"
  testthat::expect_match(readme, "scientific-reports-submission-v1.1", fixed = TRUE)
  testthat::expect_match(readme, url, fixed = TRUE)
  testthat::expect_match(readme, "jic-submission-v1.0", fixed = TRUE)
  testthat::expect_match(citation, "(?m)^version:\\s*1\\.1\\.0\\s*$", perl = TRUE)
  testthat::expect_match(citation, "(?m)^date-released:\\s*2026-07-26\\s*$", perl = TRUE)
})
