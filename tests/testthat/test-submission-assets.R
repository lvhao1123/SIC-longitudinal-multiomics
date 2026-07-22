repo_root <- normalizePath(
  file.path(testthat::test_path(), "..", ".."),
  winslash = "/"
)
submission_root <- file.path(repo_root, "submission")

testthat::test_that("required submission layers exist", {
  required <- file.path(
    submission_root,
    c(
      "code",
      "tests",
      "figures",
      "public_source_data",
      "manuscript_support",
      "manuscript_files"
    )
  )
  testthat::expect_true(all(dir.exists(required)))
  testthat::expect_true(file.exists(file.path(submission_root, "numeric_truth_table.tsv")))
  testthat::expect_true(file.exists(file.path(submission_root, "numeric_truth_dictionary.tsv")))
})

testthat::test_that("journal submission package is complete", {
  expected <- file.path(
    submission_root,
    "manuscript_files",
    c(
      "JIC_manuscript_clean.docx",
      "Additional_file_1_Supplementary_methods_and_figures.docx",
      "Additional_file_2_Supplementary_Tables_S1-S8.zip",
      "STROBE_checklist_cohort_completed.docx"
    )
  )
  testthat::expect_true(all(file.exists(expected)))
  testthat::expect_true(all(file.info(expected)$size > 1000))
})

testthat::test_that("public aggregate tables contain no prohibited columns", {
  files <- list.files(
    file.path(submission_root, "public_source_data"),
    pattern = "\\.(tsv|csv)$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  prohibited <- "^(PatientID|SampleName|observation_probability|individual_weight)$"
  offending <- unlist(lapply(files, function(path) {
    header <- names(utils::read.delim(path, nrows = 0L, check.names = FALSE))
    hits <- header[grepl(prohibited, header, ignore.case = TRUE)]
    if (!length(hits)) return(character())
    paste(basename(path), hits, sep = ":")
  }))
  testthat::expect_length(offending, 0L)
})

testthat::test_that("each publication figure has four submission formats", {
  figures <- list.files(file.path(submission_root, "figures"), full.names = FALSE)
  stems <- sub("\\.(pdf|svg|tiff|png)$", "", figures, ignore.case = TRUE)
  extensions <- tolower(tools::file_ext(figures))
  complete <- vapply(unique(stems), function(stem) {
    setequal(extensions[stems == stem], c("pdf", "svg", "tiff", "png"))
  }, logical(1))
  testthat::expect_true(all(complete))
})

testthat::test_that("main-figure production preserves the approved panel interface", {
  script <- paste(
    readLines(file.path(submission_root, "code", "13_make_submission_figures.R"), warn = FALSE),
    collapse = "\n"
  )
  testthat::expect_match(script, "Figure 1 \\| Study design")
  testthat::expect_match(script, "Figure 2 \\| Time-specific whole-blood")
  testthat::expect_match(script, "Figure 3 \\| Time-specific plasma-protein")
  testthat::expect_match(
    script,
    "Pathway-selective contemporaneous and forward cross-omic associations"
  )
  testthat::expect_match(script, "labs\\(tag = \"a\"\\)")
  testthat::expect_match(script, "labs\\(tag = \"b\"\\)")
  testthat::expect_match(script, "labs\\(tag = \"c\"\\)")
  testthat::expect_match(script, "labs\\(tag = \"d\"\\)")
  testthat::expect_match(script, "labs\\(tag = \"e\"\\)")
  testthat::expect_match(script, "labs\\(tag = \"f\"\\)")
  testthat::expect_match(script, "\\(p4a \\| p4d\\) / \\(p4b \\| p4c\\) / \\(p4e \\| p4f\\)")
})

testthat::test_that("submission manifest excludes transient interpreter caches", {
  manifest_path <- file.path(submission_root, "public_manifest.tsv")
  testthat::expect_true(file.exists(manifest_path))
  manifest <- read.delim(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  transient <- grepl(
    "(^|/)(__pycache__|[.]pytest_cache)(/|$)|[.](pyc|pyo)$",
    manifest$path,
    ignore.case = TRUE
  )
  testthat::expect_false(
    any(transient),
    info = paste("Transient manifest entries:", paste(manifest$path[transient], collapse = ", "))
  )
  testthat::expect_true(
    all(file.exists(file.path(repo_root, manifest$path))),
    info = "Every manifest entry must resolve to a tracked repository asset"
  )
})

testthat::test_that("submission manifest matches copied protected assets", {
  testthat::skip_if_not_installed("digest")
  manifest_path <- file.path(submission_root, "public_manifest.tsv")
  testthat::expect_true(file.exists(manifest_path))
  manifest <- read.delim(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  observed <- vapply(
    file.path(repo_root, manifest$path),
    digest::digest,
    character(1),
    algo = "sha256",
    serialize = FALSE,
    file = TRUE
  )
  testthat::expect_identical(unname(observed), manifest$sha256)
})
