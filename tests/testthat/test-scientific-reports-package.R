repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")

sr_root <- file.path(repo_root, "submission", "manuscript_files", "scientific_reports")
qa_root <- file.path(repo_root, "submission", "qa")
support_root <- file.path(repo_root, "submission", "manuscript_support")

read_repo_text <- function(path) {
  paste(readLines(file.path(repo_root, path), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

testthat::test_that("Scientific Reports baseline analysis is locked", {
  path <- file.path(qa_root, "scientific_reports_baseline_lock.json")
  testthat::expect_true(file.exists(path))
  lock <- jsonlite::read_json(path, simplifyVector = TRUE)
  testthat::expect_identical(lock$source_tag, "jic-submission-v1.0")
  testthat::expect_true(isTRUE(lock$all_match))
  testthat::expect_true(all(lock$files$match))
})

testthat::test_that("Scientific Reports editorial maps are complete", {
  text_map <- read.delim(file.path(support_root, "scientific_reports_text_map.tsv"), check.names = FALSE)
  ref_map <- read.delim(file.path(support_root, "scientific_reports_reference_map.tsv"), check.names = FALSE)
  crossref <- read.delim(file.path(support_root, "scientific_reports_crossref_map.tsv"), check.names = FALSE)
  allowed <- c("unchanged", "clarification", "interpretive expansion", "claim restriction", "journal compliance", "structural relocation", "cross-reference renumbering")
  testthat::expect_true(all(text_map$edit_class %in% allowed))
  testthat::expect_false(any(text_map$destination_section == ""))
  testthat::expect_true(all(ref_map$verification_status == "verified"))
  testthat::expect_setequal(crossref$old_id, paste0("A", 1:9))
  testthat::expect_setequal(crossref$new_id, paste0("S", 1:9))
})

testthat::test_that("superseded candidate files are removed and final asset is identified", {
  notice <- read_repo_text("submission/manuscript_files/scientific_reports/FINAL_PACKAGE_NOTICE.md")
  testthat::expect_match(notice, "Superseded journal-submission binaries", fixed = TRUE)
  testthat::expect_match(notice, "scientific-reports-submission-v1.1-assets.zip", fixed = TRUE)
  testthat::expect_match(notice, "07928a393f5cd937d37ca1d601492631e7c4d2c90072ab8825536f06c524afdb", fixed = TRUE)
})

testthat::test_that("machine-readable S1-S8 workbooks remain available in the Git tree", {
  expected <- sprintf(
    "Supplementary_Table_S%d_%s.xlsx",
    1:8,
    c(
      "Clinical_variable_definitions",
      "Clinical_univariable_Cox",
      "RNA_gene_wise_Cox_PH",
      "RNA_Hallmark_GSEA",
      "Protein_wise_Cox_PH",
      "Protein_Hallmark_GSEA",
      "Cross_omics_models",
      "D5_availability_IPW"
    )
  )
  testthat::expect_true(all(file.exists(file.path(sr_root, expected))))
})

testthat::test_that("current manuscript numerical audit is complete", {
  audit <- read.delim(file.path(qa_root, "scientific_reports_numeric_audit.tsv"), check.names = FALSE)
  testthat::expect_equal(nrow(audit), 27L)
  testthat::expect_true(all(audit$match))
  testthat::expect_true(all(c("D1 heme NES/FDR", "D5 EMT NES/FDR", "maximum weighted absolute SMD") %in% audit$variable))
})

testthat::test_that("final package QA records Table 1 and pagination validation", {
  qa <- read_repo_text("submission/qa/scientific_reports_final_package_QA.md")
  testthat::expect_match(qa, "108 comparisons, 0 mismatches", fixed = TRUE)
  testthat::expect_match(qa, "potassium (`K`)", fixed = TRUE)
  testthat::expect_match(qa, "43 pages", fixed = TRUE)
  testthat::expect_match(qa, "16-page", fixed = TRUE)
})

testthat::test_that("legacy STROBE audit remains complete as provenance", {
  audit <- read.delim(file.path(sr_root, "STROBE_Scientific_Reports_audit.tsv"), check.names = FALSE)
  testthat::expect_false(any(audit$where_reported == ""))
  testthat::expect_true(all(audit$status == "verified"))
})
