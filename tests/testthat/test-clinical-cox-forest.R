test_that("clinical Cox forest production bundle is complete", {
  root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  source_path <- file.path(
    root,
    "submission/public_source_data/SourceData_Supplementary_Figure_A9.tsv"
  )
  figure_base <- file.path(
    root,
    "submission/figures/Supplementary_Figure_A9_clinical_univariable_Cox"
  )

  expect_true(file.exists(file.path(
    root,
    "submission/code/21_make_clinical_cox_forest.R"
  )))
  expect_true(file.exists(source_path))

  dat <- data.table::fread(source_path, data.table = FALSE)
  expect_equal(nrow(dat), 41L)
  expect_true(all(dat$N == 504L))
  expect_true(all(dat$Events == 84L))
  expect_setequal(
    c("Variable", "Label", "Contrast", "HR", "Lower95", "Upper95",
      "P_value", "BH_FDR", "PH_p", "Nonlinearity_LRT_p"),
    intersect(
      c("Variable", "Label", "Contrast", "HR", "Lower95", "Upper95",
        "P_value", "BH_FDR", "PH_p", "Nonlinearity_LRT_p"),
      names(dat)
    )
  )

  for (ext in c("pdf", "svg", "tiff", "png")) {
    path <- paste0(figure_base, ".", ext)
    expect_true(file.exists(path), info = path)
    expect_gt(file.info(path)$size, 10000)
  }
})
