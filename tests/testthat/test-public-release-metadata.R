repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")

read_repo_text <- function(path) {
  paste(readLines(file.path(repo_root, path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

testthat::test_that("public release metadata files are present", {
  required <- c(
    "LICENSE",
    "LICENSE-CONTENT.md",
    "LICENSE_SCOPE.md",
    "THIRD_PARTY_NOTICES.md",
    "CITATION.cff",
    "README.md",
    "docs/RELEASE_HISTORY.md",
    "submission/qa/jic_release_immutability_check.txt"
  )
  testthat::expect_true(all(file.exists(file.path(repo_root, required))))
})

testthat::test_that("software and content licence boundaries are explicit", {
  software <- read_repo_text("LICENSE")
  scope <- read_repo_text("LICENSE_SCOPE.md")
  content <- read_repo_text("LICENSE-CONTENT.md")

  testthat::expect_match(software, "^MIT License")
  testthat::expect_match(software, "Hao Lyu and contributors", fixed = TRUE)
  testthat::expect_match(content, "Creative Commons Attribution 4.0", fixed = TRUE)
  testthat::expect_match(scope, "CMAISE/OMIX011182", fixed = TRUE)
  testthat::expect_match(scope, "MSigDB Hallmark", fixed = TRUE)
  testthat::expect_match(scope, "submission/manuscript_files/", fixed = TRUE)
  testthat::expect_match(scope, "not covered", fixed = TRUE)
})

testthat::test_that("citation metadata identifies Scientific Reports release version", {
  citation <- read_repo_text("CITATION.cff")
  final_url <- "https://github.com/lvhao1123/SIC-longitudinal-multiomics"

  testthat::expect_match(citation, "cff-version: 1.2.0", fixed = TRUE)
  testthat::expect_match(citation, "family-names: Lyu", fixed = TRUE)
  testthat::expect_match(citation, "given-names: Hao", fixed = TRUE)
  testthat::expect_match(citation, paste0("repository-code: ", final_url), fixed = TRUE)
  testthat::expect_match(citation, "(?m)^version:\\s*1\\.1\\.0\\s*$", perl = TRUE)
  testthat::expect_match(citation, "(?m)^date-released:\\s*\\d{4}-\\d{2}-\\d{2}\\s*$", perl = TRUE)
})

testthat::test_that("README identifies current and previous immutable releases", {
  readme <- read_repo_text("README.md")
  current_url <- paste0(
    "https://github.com/lvhao1123/",
    "SIC-longitudinal-multiomics/releases/tag/scientific-reports-submission-v1.1"
  )

  testthat::expect_match(readme, "controlled-access data", fixed = TRUE)
  testthat::expect_match(readme, "does not replace the OMIX application process", fixed = TRUE)
  testthat::expect_match(readme, "scientific-reports-submission-v1.1", fixed = TRUE)
  testthat::expect_match(readme, current_url, fixed = TRUE)
  testthat::expect_match(readme, "jic-submission-v1.0", fixed = TRUE)
  testthat::expect_match(readme, "immutable", fixed = TRUE)
  testthat::expect_match(readme, "LICENSE_SCOPE.md", fixed = TRUE)
})

testthat::test_that("release history protects the JIC snapshot", {
  history <- read_repo_text("docs/RELEASE_HISTORY.md")
  immutable <- read_repo_text("submission/qa/jic_release_immutability_check.txt")
  jic_sha <- "fb0fe912af51435a82f95b4bfe25d758fa1c6646"

  testthat::expect_match(history, "jic-submission-v1.0", fixed = TRUE)
  testthat::expect_match(history, "scientific-reports-submission-v1.1", fixed = TRUE)
  testthat::expect_match(history, "Supplementary Figure S1-S9", fixed = TRUE)
  testthat::expect_match(immutable, jic_sha, fixed = TRUE)
  testthat::expect_match(immutable, "Baseline result: IDENTICAL", fixed = TRUE)
})

testthat::test_that("OMIX accession and required source citation are documented", {
  readme <- read_repo_text("README.md")
  notices <- read_repo_text("THIRD_PARTY_NOTICES.md")
  doi <- "10.1038/s41467-025-65271-4"

  testthat::expect_match(readme, "accession `OMIX011182`", fixed = TRUE)
  testthat::expect_match(readme, doi, fixed = TRUE)
  testthat::expect_match(notices, "accession OMIX011182", fixed = TRUE)
  testthat::expect_match(notices, doi, fixed = TRUE)
  testthat::expect_match(notices, "formal\\s+OMIX controlled-access application process")
})

testthat::test_that("internal migration artefacts are absent from public staging", {
  prohibited <- c(
    "docs/PRIVATE_REPOSITORY_MIGRATION_REPORT_CN.md",
    "docs/superpowers/plans/2026-07-15-private-analysis-repository-migration.md",
    "docs/superpowers/specs/2026-07-15-analysis-repository-migration-design.md",
    "docs/superpowers/plans/2026-07-16-manuscript-v2-review-plan.md",
    "docs/superpowers/specs/2026-07-16-manuscript-v2-review-design.md",
    "docs/superpowers/plans/2026-07-20-public-centre-anonymisation.md",
    "docs/superpowers/specs/2026-07-20-public-centre-anonymisation-design.md",
    "qa/final_private_repository_QA.tsv"
  )
  testthat::expect_false(any(file.exists(file.path(repo_root, prohibited))))
})
