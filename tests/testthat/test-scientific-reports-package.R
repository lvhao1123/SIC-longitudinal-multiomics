repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")

sr_root <- file.path(repo_root, "submission", "manuscript_files", "scientific_reports")
qa_root <- file.path(repo_root, "submission", "qa")
support_root <- file.path(repo_root, "submission", "manuscript_support")

testthat::test_that("Scientific Reports baseline is locked", {
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

testthat::test_that("Scientific Reports public manuscript package is complete", {
  expected <- c(
    "Scientific_Reports_manuscript_clean.docx",
    "Scientific_Reports_manuscript_highlighted.docx",
    "Scientific_Reports_revision_report.docx",
    "Scientific_Reports_Supplementary_Information.docx",
    "Scientific_Reports_Supplementary_Information.pdf",
    "Supplementary_Table_S1_Clinical_variable_definitions.xlsx",
    "Supplementary_Table_S2_Clinical_univariable_Cox.xlsx",
    "Supplementary_Table_S3_RNA_gene_wise_Cox_PH.xlsx",
    "Supplementary_Table_S4_RNA_Hallmark_GSEA.xlsx",
    "Supplementary_Table_S5_Protein_wise_Cox_PH.xlsx",
    "Supplementary_Table_S6_Protein_Hallmark_GSEA.xlsx",
    "Supplementary_Table_S7_Cross_omics_models.xlsx",
    "Supplementary_Table_S8_D5_availability_IPW.xlsx",
    "Supplementary_Table_S9_Complete_baseline_characteristics.xlsx",
    "STROBE_Scientific_Reports_completed.docx",
    "STROBE_Scientific_Reports_audit.tsv"
  )
  testthat::expect_true(all(file.exists(file.path(sr_root, expected))))
})

testthat::test_that("main Table 1 values are an exact subset of S9", {
  audit <- read.delim(file.path(qa_root, "scientific_reports_numeric_audit.tsv"), check.names = FALSE)
  x <- audit[audit$domain == "table1_vs_s9", ]
  testthat::expect_gt(nrow(x), 0)
  testthat::expect_true(all(x$match))
})

testthat::test_that("Scientific Reports STROBE audit is complete", {
  audit <- read.delim(file.path(sr_root, "STROBE_Scientific_Reports_audit.tsv"), check.names = FALSE)
  testthat::expect_false(any(audit$where_reported == ""))
  testthat::expect_true(all(audit$status == "verified"))
})

testthat::test_that("Scientific Reports package release gate is green", {
  report <- jsonlite::read_json(file.path(qa_root, "scientific_reports_package_validation.json"), simplifyVector = TRUE)
  testthat::expect_true(isTRUE(report$all_pass))
  testthat::expect_equal(report$numeric_mismatches, 0L)
  testthat::expect_equal(report$broken_cross_references, 0L)
  testthat::expect_equal(report$residual_A_labels, 0L)
  testthat::expect_equal(report$privacy_findings, 0L)
  testthat::expect_equal(report$clean_comments, 0L)
  testthat::expect_equal(report$clean_tracked_changes, 0L)
})
