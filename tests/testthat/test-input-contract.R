analysis_file <- file.path(
  normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/"),
  "analysis",
  "check_inputs.R"
)
source(analysis_file)

testthat::test_that("input contract reports every missing logical input", {
  root <- tempfile("empty-controlled-data-")
  dir.create(root)
  report <- check_inputs(root, execution = FALSE)

  testthat::expect_equal(nrow(report), 6L)
  testthat::expect_true(all(!report$present))
  testthat::expect_setequal(
    report$logical_name,
    c(
      "clinical",
      "raw_clinical",
      "rna_counts",
      "protein",
      "protein_qc",
      "hallmark"
    )
  )
  testthat::expect_error(
    check_inputs(root, execution = TRUE),
    "Missing required controlled inputs"
  )
})

testthat::test_that("input contract checks names without reading contents", {
  root <- tempfile("controlled-contract-")
  dir.create(root)
  dir.create(file.path(root, "SIC_detailed_analysis_phase1"))
  paths <- expected_input_contract(root)$path
  dir.create(dirname(paths[[2]]), recursive = TRUE, showWarnings = FALSE)
  invisible(vapply(paths, file.create, logical(1)))

  report <- check_inputs(root, execution = TRUE)
  testthat::expect_true(all(report$present))
  testthat::expect_true(all(report$access_class == "controlled_or_licensed"))
})
