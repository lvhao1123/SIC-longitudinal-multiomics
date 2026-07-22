repo_root <- normalizePath(
  file.path(testthat::test_path(), "..", ".."),
  winslash = "/"
)
workflow <- file.path(repo_root, ".github", "workflows", "public-qa.yml")

testthat::test_that("CI is data-free and never launches authorised analysis", {
  testthat::expect_true(file.exists(workflow))
  content <- paste(readLines(workflow, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("run_authorized|CMAISE_DATA_DIR|OMIX011182", content))
  testthat::expect_true(grepl("verify_canonical_hashes", content))
  testthat::expect_true(grepl("testthat", content))
})

testthat::test_that("CI parses only version-controlled R files", {
  content <- paste(readLines(workflow, warn = FALSE), collapse = "\n")
  testthat::expect_true(grepl("git.*ls-files", content))
  testthat::expect_false(grepl("list[.]files.*pattern.*[.]R", content))
})

testthat::test_that("CI invokes the tracked submission semantic test directly", {
  content <- paste(readLines(workflow, warn = FALSE), collapse = "\n")
  testthat::expect_true(grepl(
    "run: Rscript submission/tests/test_submission_semantics.R",
    content,
    fixed = TRUE
  ))
})
