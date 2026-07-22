inventory_path <- file.path(
  normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/"),
  "docs",
  "provenance",
  "canonical_code_inventory.tsv"
)

testthat::test_that("canonical code matches the frozen SHA-256 inventory", {
  testthat::skip_if_not_installed("digest")
  repo_root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/"
  )
  inventory <- read.delim(inventory_path, stringsAsFactors = FALSE, check.names = FALSE)
  destinations <- file.path(repo_root, inventory$destination_path)

  testthat::expect_true(all(file.exists(destinations)))

  observed <- vapply(
    destinations,
    digest::digest,
    character(1),
    algo = "sha256",
    serialize = FALSE,
    file = TRUE
  )
  exact <- inventory$exact_match_required
  testthat::expect_identical(
    unname(observed[exact]),
    inventory$original_sha256[exact]
  )
  testthat::expect_identical(
    inventory$classification[!exact],
    "sanitized_config_derivative"
  )
  testthat::expect_false(observed[!exact] == inventory$original_sha256[!exact])
})
