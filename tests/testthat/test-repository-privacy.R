repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")
tracked <- system2("git", c("-C", shQuote(repo_root), "ls-files"), stdout = TRUE)
forbidden_names <- c("OMIX011182-01.csv", "OMIX011182-04.txt", "OMIX011182-05.xlsx", "SIC_504_baseline_carried_forward_annotation.csv")
source(file.path(repo_root, "submission", "code", "26_public_centre_anonymisation.R"))

testthat::test_that("controlled source data are not tracked", {
  testthat::expect_false(any(basename(tracked) %in% forbidden_names))
})

testthat::test_that("public source-data filenames are not identifiable", {
  x <- tracked[grepl("(^|/)public_source_data/", tracked)]
  testthat::expect_false(any(grepl("PatientID|SampleName|individual_weight", basename(x), ignore.case = TRUE)))
})

testthat::test_that("tracked text does not disclose local absolute paths", {
  x <- tracked[grepl("\\.(R|r|py|md|yml|yaml|tsv|csv|txt|json|cff)$", tracked)]
  content <- unlist(lapply(file.path(repo_root, x), readLines, warn = FALSE, encoding = "UTF-8"))
  testthat::expect_false(any(grepl("[A-Z]:[/\\\\](Users|AAA|GitHub|Documents|Desktop|AppData)", content)))
})

testthat::test_that("centre helper is deterministic with synthetic codes", {
  synthetic <- sprintf("SyntheticSite%02d", seq_len(30L))
  expected <- sprintf("Centre %02d", seq_len(30L))
  a <- build_public_centre_map(synthetic)
  set.seed(20260720)
  b <- build_public_centre_map(sample(synthetic))
  testthat::expect_identical(a, b)
  testthat::expect_identical(a$public_center, expected)
})

testthat::test_that("public centre source tables contain only anonymised labels", {
  p1 <- file.path(repo_root, "submission", "public_source_data", "SupplementaryTable_Centre_positivity.tsv")
  p2 <- file.path(repo_root, "submission", "public_source_data", "SupplementaryTable_Balance_SMD.tsv")
  a <- utils::read.delim(p1, check.names = FALSE, stringsAsFactors = FALSE)
  b <- utils::read.delim(p2, check.names = FALSE, stringsAsFactors = FALSE)
  testthat::expect_true(all(grepl("^Centre [0-9]{2}$", a$center)))
  z <- b$variable[startsWith(b$variable, "center=")]
  testthat::expect_true(all(grepl("^center=Centre [0-9]{2}$", z)))
})

testthat::test_that("sandwich audit uses repository-relative result names", {
  x <- readLines(file.path(repo_root, "submission", "code", "12_run_sandwich_equivalence_test.R"), warn = FALSE)
  testthat::expect_true(any(grepl("basename\\(AVAIL_OUT\\)", x)))
  testthat::expect_false(any(grepl("formal_result_file = normalizePath", x, fixed = TRUE)))
})