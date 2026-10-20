repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")
read_repo_text <- function(path) paste(readLines(file.path(repo_root, path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")

testthat::test_that("Scientific Reports metadata identifies v1.3 and retains historical releases", {
  readme <- read_repo_text("README.md")
  citation <- read_repo_text("CITATION.cff")
  url <- "https://github.com/lvhao1123/SIC-longitudinal-multiomics/releases/tag/scientific-reports-submission-v1.1"
  testthat::expect_match(readme, "scientific-reports-submission-v1.1", fixed = TRUE)
  testthat::expect_match(readme, url, fixed = TRUE)
  testthat::expect_match(readme, "jic-submission-v1.0", fixed = TRUE)
  testthat::expect_match(citation, "(?m)^version:\\s*1\\.3\\.0\\s*$", perl = TRUE)
  testthat::expect_match(citation, "(?m)^date-released:\\s*2026-10-20\\s*$", perl = TRUE)
})
