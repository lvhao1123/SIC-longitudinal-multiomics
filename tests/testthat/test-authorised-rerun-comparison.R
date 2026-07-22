comparison_file <- file.path(
  normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/"),
  "scripts",
  "compare_authorised_rerun.R"
)
source(comparison_file)

testthat::test_that("authorised rerun comparison distinguishes exact and numeric-equivalent tables", {
  frozen <- tempfile("frozen-")
  audit <- tempfile("audit-")
  out <- tempfile("qa-")
  dir.create(frozen)
  dir.create(audit)

  utils::write.csv(data.frame(id = "a", value = 1), file.path(frozen, "exact.csv"), row.names = FALSE)
  file.copy(file.path(frozen, "exact.csv"), file.path(audit, "exact.csv"))
  utils::write.csv(data.frame(id = "a", value = 1), file.path(frozen, "tiny.csv"), row.names = FALSE)
  utils::write.csv(data.frame(id = "a", value = 1 + 1e-14), file.path(audit, "tiny.csv"), row.names = FALSE)
  utils::write.csv(data.frame(id = "a", value = 1), file.path(frozen, "different.csv"), row.names = FALSE)
  utils::write.csv(data.frame(id = "b", value = 1), file.path(audit, "different.csv"), row.names = FALSE)
  utils::write.csv(
    data.frame(
      check = paste0("check_", seq_len(65)), observed = 1, expected = 1,
      pass = TRUE, severity = "error"
    ),
    file.path(audit, "FINAL_QA_SUMMARY.csv"), row.names = FALSE
  )

  result <- compare_authorised_rerun(frozen, audit, out, tolerance = 1e-12)

  testthat::expect_equal(result$file_audit$class[result$file_audit$relative_path == "exact.csv"], "exact")
  testthat::expect_equal(result$file_audit$class[result$file_audit$relative_path == "tiny.csv"], "numeric_equivalent")
  testthat::expect_equal(result$file_audit$class[result$file_audit$relative_path == "different.csv"], "different")
  testthat::expect_true(file.exists(file.path(out, "authorised_reproducibility_summary.tsv")))
})
