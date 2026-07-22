builder_file <- file.path(
  normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/"),
  "analysis",
  "build_clinical_workbook.R"
)
source(builder_file)

testthat::test_that("clinical workbook builder exposes the frozen table set", {
  clinical_dir <- tempfile("clinical-tables-")
  dir.create(clinical_dir)

  inputs <- c(
    Table1_baseline_characteristics = "Table1_baseline_characteristics.csv",
    Clinical_univariable_Cox = "Clinical_univariable_Cox.csv",
    Clinical_sparse_event_audit = "Clinical_sparse_event_audit.csv",
    Clinical_infection_source_mapping = "Clinical_infection_source_mapping.csv",
    Clinical_drop5_event_time_sensitivity = "Clinical_drop5_event_time_sensitivity.csv",
    Clinical_variable_dictionary = "Clinical_variable_dictionary.csv",
    Clinical_analysis_diagnostics = "Clinical_analysis_diagnostics.csv"
  )
  for (path in unname(inputs)) {
    utils::write.csv(data.frame(value = 1), file.path(clinical_dir, path), row.names = FALSE)
  }

  workbook <- build_clinical_workbook(clinical_dir)

  testthat::expect_true(file.exists(workbook))
  testthat::expect_gt(file.info(workbook)$size, 1000)
  testthat::expect_identical(
    readxl::excel_sheets(workbook),
    c(
      "README",
      "Table1_Baseline",
      "Univariable_Cox",
      "Sparse_Event_Audit",
      "Infection_Mapping",
      "Drop5_Time_Sensitivity",
      "Variable_Dictionary",
      "Diagnostics"
    )
  )
})

testthat::test_that("authorised runner inserts only the non-statistical workbook bridge", {
  repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")
  runner <- readLines(file.path(repo_root, "analysis", "run_authorized.R"), warn = FALSE)
  clinical_stage <- grep("09_build_clinical_tables[.]R", runner)
  workbook_stage <- grep("build_clinical_workbook[.]R", runner)
  availability_stage <- grep("10_run_availability_IPW_sensitivity[.]R", runner)

  testthat::expect_length(clinical_stage, 1L)
  testthat::expect_length(workbook_stage, 1L)
  testthat::expect_length(availability_stage, 1L)
  testthat::expect_lt(clinical_stage, workbook_stage)
  testthat::expect_lt(workbook_stage, availability_stage)
})
