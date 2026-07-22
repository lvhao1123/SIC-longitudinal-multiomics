compare_authorised_rerun <- function(frozen_dir, audit_dir, output_dir, tolerance = 1e-12,
                                     pre_post_comparison = NULL) {
  frozen_dir <- normalizePath(frozen_dir, winslash = "/", mustWork = TRUE)
  audit_dir <- normalizePath(audit_dir, winslash = "/", mustWork = TRUE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  frozen_files <- list.files(frozen_dir, pattern = "[.]csv$", recursive = TRUE, full.names = TRUE)
  rel <- substring(frozen_files, nchar(frozen_dir) + 2L)
  audit_files <- file.path(audit_dir, rel)
  keep <- file.exists(audit_files)
  frozen_files <- frozen_files[keep]
  audit_files <- audit_files[keep]
  rel <- rel[keep]

  binary_identical <- function(a, b) {
    identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))
  }
  values_identical <- function(a, b) {
    if (!identical(is.na(a), is.na(b))) return(FALSE)
    identical(as.character(a[!is.na(a)]), as.character(b[!is.na(b)]))
  }

  file_rows <- lapply(seq_along(rel), function(i) {
    if (binary_identical(frozen_files[[i]], audit_files[[i]])) {
      return(data.frame(
        relative_path = rel[[i]], class = "exact", max_abs_numeric_diff = 0,
        structure_equal = TRUE, nonnumeric_equal = TRUE, stringsAsFactors = FALSE
      ))
    }

    x <- tryCatch(utils::read.csv(frozen_files[[i]], check.names = FALSE, stringsAsFactors = FALSE),
                  error = function(e) NULL)
    y <- tryCatch(utils::read.csv(audit_files[[i]], check.names = FALSE, stringsAsFactors = FALSE),
                  error = function(e) NULL)
    structure_equal <- !is.null(x) && !is.null(y) &&
      identical(dim(x), dim(y)) && identical(names(x), names(y))
    if (!structure_equal) {
      return(data.frame(
        relative_path = rel[[i]], class = "different", max_abs_numeric_diff = NA_real_,
        structure_equal = FALSE, nonnumeric_equal = FALSE, stringsAsFactors = FALSE
      ))
    }

    numeric_columns <- names(x)[vapply(x, is.numeric, logical(1)) & vapply(y, is.numeric, logical(1))]
    nonnumeric_columns <- setdiff(names(x), numeric_columns)
    numeric_na_equal <- all(vapply(numeric_columns, function(n) identical(is.na(x[[n]]), is.na(y[[n]])), logical(1)))
    numeric_diffs <- vapply(numeric_columns, function(n) {
      keep_num <- !is.na(x[[n]]) & !is.na(y[[n]])
      if (!any(keep_num)) return(0)
      max(abs(x[[n]][keep_num] - y[[n]][keep_num]))
    }, numeric(1))
    max_diff <- if (length(numeric_diffs)) max(numeric_diffs) else 0
    nonnumeric_equal <- all(vapply(nonnumeric_columns, function(n) values_identical(x[[n]], y[[n]]), logical(1)))
    equivalent <- numeric_na_equal && nonnumeric_equal && is.finite(max_diff) && max_diff <= tolerance

    data.frame(
      relative_path = rel[[i]],
      class = if (equivalent) "numeric_equivalent" else "different",
      max_abs_numeric_diff = max_diff,
      structure_equal = TRUE,
      nonnumeric_equal = nonnumeric_equal,
      stringsAsFactors = FALSE
    )
  })
  file_audit <- do.call(rbind, file_rows)
  file_audit$is_generated_metadata <- basename(file_audit$relative_path) %in% c(
    "FILE_MANIFEST_SHA256.csv", "FINAL_QA_SUMMARY.csv"
  )

  qa_path <- file.path(audit_dir, "FINAL_QA_SUMMARY.csv")
  qa <- utils::read.csv(qa_path, check.names = FALSE, stringsAsFactors = FALSE)
  pass_col <- if ("pass" %in% names(qa)) "pass" else "Pass"
  check_col <- if ("check" %in% names(qa)) "check" else "Check"
  observed_col <- if ("observed" %in% names(qa)) "observed" else "Observed"
  qa_pass <- as.logical(qa[[pass_col]])

  metric <- function(name, value, criterion, status = "PASS", evidence = "authorised rerun") {
    data.frame(metric = name, value = as.character(value), criterion = criterion,
               status = status, evidence = evidence, stringsAsFactors = FALSE)
  }
  selected_qa <- c(
    "RNA_D1_riskset", "RNA_D3_riskset", "RNA_D5_riskset",
    "Protein_D1_riskset", "Protein_D3_riskset", "Protein_D5_riskset",
    "RNA_D1_all_fits", "RNA_D3_all_fits", "RNA_D5_all_fits",
    "Protein_D1_all_fits", "Protein_D3_all_fits", "Protein_D5_all_fits",
    "Clinical_patients", "Clinical_deaths", "Forward_IFN_FDR_count",
    "Reverse_FDR_count", "Availability_primary_estimand_counts"
  )

  summary_rows <- list(
    metric("formal_QA_checks", nrow(qa), "65", if (nrow(qa) == 65L) "PASS" else "FAIL"),
    metric("formal_QA_passed", sum(qa_pass), "65", if (all(qa_pass)) "PASS" else "FAIL"),
    metric("common_CSV_tables", nrow(file_audit), "reported"),
    metric("exact_CSV_tables", sum(file_audit$class == "exact"), "reported"),
    metric("numeric_equivalent_CSV_tables", sum(file_audit$class == "numeric_equivalent"), "reported"),
    metric(
      "core_result_different_CSV_tables",
      sum(file_audit$class == "different" & !file_audit$is_generated_metadata),
      "0",
      if (any(file_audit$class == "different" & !file_audit$is_generated_metadata)) "FAIL" else "PASS"
    ),
    metric(
      "maximum_numeric_difference_among_equivalent_tables",
      format(max(file_audit$max_abs_numeric_diff[file_audit$class == "numeric_equivalent"], na.rm = TRUE), digits = 17),
      paste0("<=", tolerance)
    )
  )
  for (name in selected_qa) {
    hit <- which(qa[[check_col]] == name)
    if (length(hit) == 1L) {
      summary_rows[[length(summary_rows) + 1L]] <- metric(
        name, qa[[observed_col]][hit], "matches frozen QA", if (qa_pass[hit]) "PASS" else "FAIL"
      )
    }
  }

  if (!is.null(pre_post_comparison) && file.exists(pre_post_comparison)) {
    hash_audit <- utils::read.delim(pre_post_comparison, check.names = FALSE, stringsAsFactors = FALSE)
    unchanged <- as.logical(hash_audit$unchanged)
    summary_rows[[length(summary_rows) + 1L]] <- metric(
      "original_frozen_files_unchanged",
      paste0(sum(unchanged), "/", length(unchanged)),
      paste0(length(unchanged), "/", length(unchanged)),
      if (all(unchanged)) "PASS" else "FAIL",
      "pre/post SHA256 audit"
    )
  }

  summary <- do.call(rbind, summary_rows)
  utils::write.table(
    file_audit, file.path(output_dir, "authorised_reproducibility_file_audit.tsv"),
    sep = "\t", quote = FALSE, row.names = FALSE, na = ""
  )
  utils::write.table(
    summary, file.path(output_dir, "authorised_reproducibility_summary.tsv"),
    sep = "\t", quote = FALSE, row.names = FALSE, na = ""
  )
  list(summary = summary, file_audit = file_audit)
}

if (sys.nframe() == 0L && !interactive()) {
  frozen <- Sys.getenv("SIC_FROZEN_OUTPUT_DIR", unset = "")
  audit <- Sys.getenv("SIC_AUDIT_OUTPUT_DIR", unset = "")
  output <- Sys.getenv("SIC_AUDIT_SUMMARY_DIR", unset = "qa")
  pre_post <- Sys.getenv("SIC_FROZEN_PRE_POST_COMPARISON", unset = "")
  if (!nzchar(frozen) || !nzchar(audit)) {
    stop("Set SIC_FROZEN_OUTPUT_DIR and SIC_AUDIT_OUTPUT_DIR")
  }
  result <- compare_authorised_rerun(
    frozen, audit, output,
    pre_post_comparison = if (nzchar(pre_post)) pre_post else NULL
  )
  print(result$summary)
  if (any(result$summary$status == "FAIL")) quit(status = 1L)
}
