original_centres <- sprintf("SyntheticSite%02d", seq_len(30L))

test_that("submission supplementary files S1-S8 are independently uploadable", {
  root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  out <- file.path(root, "submission/supplementary_files")
  expected <- c(
    "Supplementary_Table_S1_Clinical_variable_definitions.xlsx",
    "Supplementary_Table_S2_Clinical_univariable_Cox.xlsx",
    "Supplementary_Table_S3_RNA_gene_wise_Cox_PH.xlsx",
    "Supplementary_Table_S4_RNA_Hallmark_GSEA.xlsx",
    "Supplementary_Table_S5_Protein_wise_Cox_PH.xlsx",
    "Supplementary_Table_S6_Protein_Hallmark_GSEA.xlsx",
    "Supplementary_Table_S7_Cross_omics_models.xlsx",
    "Supplementary_Table_S8_D5_availability_IPW.xlsx"
  )
  expect_true(file.exists(file.path(
    root,
    "submission/code/22_build_supplementary_workbooks.mjs"
  )))
  expect_true(dir.exists(out))
  for (name in expected) {
    path <- file.path(out, name)
    expect_true(file.exists(path), info = name)
    minimum_size <- if (startsWith(name, "Supplementary_Table_S1_")) 5000 else 10000
    expect_gt(file.info(path)$size, minimum_size)
  }

  manifest <- file.path(
    root,
    "submission/manuscript_support/Supplementary_upload_manifest.tsv"
  )
  expect_true(file.exists(manifest))
  manifest_dat <- data.table::fread(manifest, data.table = FALSE)
  expect_true(all(paste0("S", 1:8) %in% manifest_dat$manuscript_id))
  expect_true(all(paste0("A", 1:9) %in% manifest_dat$manuscript_id))
})

test_that("submission supplementary workbooks contain no direct identifiers or original centre labels", {
  root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  workbooks <- list.files(
    file.path(root, "submission/supplementary_files"),
    pattern = "\\.xlsx$",
    full.names = TRUE
  )
  identifier_offending <- character()
  centre_offending <- character()
  for (workbook in workbooks) {
    for (sheet in readxl::excel_sheets(workbook)) {
      values <- suppressMessages(readxl::read_excel(
        workbook,
        sheet = sheet,
        col_names = FALSE,
        .name_repair = "minimal"
      ))
      visible_cells <- trimws(as.character(unlist(values, use.names = FALSE)))
      visible_cells <- visible_cells[!is.na(visible_cells) & nzchar(visible_cells)]
      if (any(visible_cells %in% c("PatientID", "SampleName"))) {
        identifier_offending <- c(identifier_offending, paste(basename(workbook), sheet, sep = ":"))
      }
      leaked <- original_centres[vapply(
        original_centres,
        function(code) any(visible_cells == code | visible_cells == paste0("center=", code)),
        logical(1)
      )]
      if (length(leaked)) {
        centre_offending <- c(
          centre_offending,
          paste(basename(workbook), sheet, paste(leaked, collapse = ","), sep = ":")
        )
      }
    }
  }
  if (length(identifier_offending)) {
    testthat::fail(paste("Direct identifiers found in:", paste(identifier_offending, collapse = ", ")))
  }
  if (length(centre_offending)) {
    testthat::fail(paste("Original centre labels found in:", paste(centre_offending, collapse = ", ")))
  }
  expect_length(identifier_offending, 0L)
  expect_length(centre_offending, 0L)
})

test_that("S8 uses Centre 01-Centre 30 in public centre-bearing sheets", {
  root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  s8 <- file.path(
    root,
    "submission/supplementary_files/Supplementary_Table_S8_D5_availability_IPW.xlsx"
  )
  centre <- suppressMessages(readxl::read_excel(s8, sheet = "Centre_positivity"))
  balance <- suppressMessages(readxl::read_excel(s8, sheet = "Balance_SMD"))
  expect_true(all(grepl("^Centre [0-9]{2}$", centre$center)))
  centre_terms <- balance$variable[startsWith(balance$variable, "center=")]
  expect_true(all(grepl("^center=Centre [0-9]{2}$", centre_terms)))
  expect_setequal(unique(centre$center), sprintf("Centre %02d", seq_len(30L)))
})
