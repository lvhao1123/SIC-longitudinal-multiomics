repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")

read_repo_text <- function(path) {
  paste(readLines(file.path(repo_root, path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

testthat::test_that("final Scientific Reports release metadata are present", {
  required <- c(
    "submission/qa/scientific_reports_final_package_QA.md",
    "submission/qa/scientific_reports_figure_audit.tsv",
    "submission/qa/scientific_reports_numeric_audit.tsv",
    "submission/release_manifests/scientific-reports-figure-map-v1.1.tsv",
    "submission/release_manifests/scientific-reports-submission-v1.1-release-assets.tsv",
    "submission/manuscript_files/scientific_reports/FINAL_PACKAGE_NOTICE.md"
  )
  testthat::expect_true(all(file.exists(file.path(repo_root, required))))
})

testthat::test_that("release asset identity is frozen", {
  assets <- read.delim(
    file.path(repo_root, "submission/release_manifests/scientific-reports-submission-v1.1-release-assets.tsv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  testthat::expect_equal(nrow(assets), 1L)
  testthat::expect_equal(assets$asset, "scientific-reports-submission-v1.1-assets.zip")
  testthat::expect_equal(assets$bytes, 37592778)
  testthat::expect_equal(
    assets$sha256,
    "74839e4eb03ce91645e7e38c18f34e3019ded076609c8610d912542c0d79d664"
  )
  testthat::expect_equal(assets$status, "ready_for_release_upload")
})

testthat::test_that("authoritative figure audit covers all figures and corrected S2", {
  audit <- read.delim(
    file.path(repo_root, "submission/qa/scientific_reports_figure_audit.tsv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  testthat::expect_equal(nrow(audit), 13L)
  testthat::expect_true(all(c("Figure 1", "Figure 4", "Supplementary Figure S1", "Supplementary Figure S9") %in% audit$figure))
  s2 <- audit[audit$figure == "Supplementary Figure S2", , drop = FALSE]
  testthat::expect_equal(nrow(s2), 1L)
  testthat::expect_match(s2$status, "corrected_six_scenario_legend", fixed = TRUE)
})

testthat::test_that("current core numerical audit has no mismatch", {
  audit <- read.delim(
    file.path(repo_root, "submission/qa/scientific_reports_numeric_audit.tsv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  testthat::expect_equal(nrow(audit), 27L)
  testthat::expect_true(all(audit$match))
  testthat::expect_true("maximum weighted absolute SMD" %in% audit$variable)
})

testthat::test_that("final QA records current Table 1 and pagination authorities", {
  qa <- read_repo_text("submission/qa/scientific_reports_final_package_QA.md")
  testthat::expect_match(qa, "43 pages", fixed = TRUE)
  testthat::expect_match(qa, "16-page", fixed = TRUE)
  testthat::expect_match(qa, "108 comparisons, 0 mismatches", fixed = TRUE)
  testthat::expect_match(qa, "potassium (`K`)", fixed = TRUE)
  testthat::expect_match(qa, "cover letter is intentionally excluded", ignore.case = TRUE)
})
