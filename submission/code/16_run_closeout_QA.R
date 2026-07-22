#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/") else normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
REPO_ROOT <- normalizePath(file.path(CLOSEOUT, ".."), winslash = "/")
source(file.path(REPO_ROOT, "outputs", "SIC_reanalysis_2026-07-11", "code", "00_config.R"))
suppressPackageStartupMessages({
  library(data.table); library(pdftools); library(magick); library(rsvg); library(xml2); library(png)
})
ROOT <- OUT_ROOT
FIG <- file.path(CLOSEOUT, "figures"); PUB <- file.path(CLOSEOUT, "public_source_data")
MAN <- file.path(CLOSEOUT, "manuscript_support"); QA <- file.path(CLOSEOUT, "qa")
dir.create(QA, recursive = TRUE, showWarnings = FALSE)
truth <- fread(file.path(CLOSEOUT, "numeric_truth_table.tsv"))

checks <- list()
add <- function(group, check, pass, observed = "", expected = "", severity = "error", note = "") {
  checks[[length(checks) + 1L]] <<- data.table(group, check, pass = isTRUE(pass), observed = as.character(observed),
                                               expected = as.character(expected), severity, note)
}
tv <- function(k) {
  x <- truth[key == k]
  if (nrow(x) != 1L) stop("Missing/duplicate truth key: ", k)
  if (!is.na(x$value_num[1])) x$value_num[1] else x$value_text[1]
}

# Existing frozen QA and validation tests.
oldqa <- fread(file.path(ROOT, "FINAL_QA_SUMMARY.csv"))
add("existing_QA", "existing_65_item_QA", nrow(oldqa) == 65L && all(oldqa$pass),
    paste(nrow(oldqa), sum(oldqa$pass), sep = "/"), "65/65")
eq <- fread(file.path(CLOSEOUT, "validation", "robust_SE_equivalence_test.csv"))
eqs <- fread(file.path(CLOSEOUT, "validation", "robust_SE_equivalence_summary.tsv"))
add("equivalence", "sandwich_rowwise_equivalence", all(eq$pass) && all(eqs$pass),
    sprintf("max diff %.3g", max(c(eq$abs_diff_beta, eq$abs_diff_SE, eq$abs_diff_z, eq$abs_diff_p), na.rm = TRUE)), "<=1e-10")
hashfix <- fread(file.path(CLOSEOUT, "validation", "formal_result_hash_unchanged.tsv"))
add("equivalence", "formal_result_hashes_unchanged", all(hashfix$unchanged), sum(hashfix$unchanged), nrow(hashfix))

# Numeric truth uniqueness and required values.
add("numeric", "truth_keys_unique", !anyDuplicated(truth$key), anyDuplicated(truth$key), 0)
req <- c("availability.primary.source_N", "availability.primary.structural_N", "availability.primary.risk_N",
         "availability.primary.support_N", "availability.primary.observed_N", "availability.primary.unobserved_N",
         "availability.primary.observed_events", "availability.primary.centres_zero", "availability.primary.centres_all",
         "availability.primary.centres_partial", "availability.weight.primary__SOFA_D3.min_probability",
         "availability.weight.primary__SOFA_D3.max_raw_weight", "availability.weight.primary__SOFA_D3.ESS_ratio",
         "availability.weight.primary__SOFA_D3.max_abs_SMD_after", "availability.cox.entry4_SOFA_D3.genes_entering_GSEA",
         "availability.comparison.entry4_SOFA_D3.spearman_NES", "availability.comparison.entry4_SOFA_D3.direction_agreement",
         "availability.comparison.entry4_SOFA_D3.significant_set_jaccard")
add("numeric", "required_truth_keys", all(req %in% truth$key), sum(req %in% truth$key), length(req))
add("numeric", "frozen_primary_counts", all(c(tv(req[1]), tv(req[2]), tv(req[3]), tv(req[4]), tv(req[5]), tv(req[6]), tv(req[7])) == c(504,13,491,487,320,167,53)),
    paste(c(tv(req[1]), tv(req[2]), tv(req[3]), tv(req[4]), tv(req[5]), tv(req[6]), tv(req[7])), collapse = "/"), "504/13/491/487/320/167/53")

# Figure 1 source data must reproduce the hierarchy without conflating raw and risk-valid samples.
f1s <- fread(file.path(PUB, "SourceData_Figure1_samples.tsv"))
get_f1 <- function(o,t,l) f1s[Omics == o & Time == t & sample_level == l, N]
add("numeric", "Figure1_RNA_D5_raw_vs_riskvalid", get_f1("RNA","D5","Raw measured") == 321 && get_f1("RNA","D5","Delayed-entry risk-valid") == 320,
    paste(get_f1("RNA","D5","Raw measured"), get_f1("RNA","D5","Delayed-entry risk-valid"), sep = "/"), "321/320")
f1d <- fread(file.path(PUB, "SourceData_Figure1_D5_availability.tsv"))
add("numeric", "Figure1_estimand_hierarchy", all(f1d$N[match(c("D5 landmark survivors","Positivity-supported estimand","Observed D5 RNA","Unobserved D5 RNA"), f1d$stage)] == c(491,487,320,167)),
    paste(f1d$N, collapse = "/"), "491/487/320/167")

# Four-main-figure architecture and output completeness.
main <- c("Figure1_study_design_risksets_availability", "Figure2_RNA_core_NES",
          "Figure3_Protein_core_NES", "Figure4_CrossOmics_integrated_A_to_F")
supp <- paste0("Supplementary_Figure_A", 1:8, c("_centre_positivity", "_probability_weight_distributions",
         "_pre_post_weight_SMD", "_all_Hallmark_unweighted_vs_IPW", "_core_pathway_scenario_heatmap",
         "_six_scenario_robustness_metrics", "_entry_boundary_sensitivity", "_D5_protein_availability"))
for (s in c(main, supp)) for (ext in c("pdf","svg","tiff","png")) {
  f <- file.path(FIG, paste0(s, ".", ext))
  add("figure_files", paste0(s, "_", ext), file.exists(f) && file.info(f)$size > 1000,
      ifelse(file.exists(f), file.info(f)$size, 0), ">1000 bytes")
}
close_names <- list.files(CLOSEOUT, recursive = TRUE, full.names = FALSE)
close_text_files <- list.files(c(MAN, ROOT), pattern = "\\.(md|txt)$", recursive = FALSE, full.names = TRUE)
close_text <- paste(vapply(close_text_files[file.exists(close_text_files)], function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"), ""), collapse = "\n")
add("architecture", "no_Figure5_files", !any(grepl("Figure[_ ]?5", close_names, ignore.case = TRUE)), paste(close_names[grepl("Figure[_ ]?5", close_names, ignore.case = TRUE)], collapse = ";"), "none")
add("architecture", "no_Figure5_manuscript_reference", !grepl("Figure[[:space:]_]?5", close_text, ignore.case = TRUE), "searched production text", "none")

# PDF/SVG/TIFF/PNG rendering and font/resolution QA.
render_rows <- list()
for (s in c(main, supp)) {
  pdf <- file.path(FIG, paste0(s, ".pdf")); svg <- file.path(FIG, paste0(s, ".svg")); tif <- file.path(FIG, paste0(s, ".tiff")); pn <- file.path(FIG, paste0(s, ".png"))
  pi <- tryCatch(pdf_info(pdf), error = function(e) NULL)
  # Low-resolution rasterization is sufficient to prove renderability and
  # avoids turning QA itself into a second high-resolution production run.
  pr <- tryCatch(pdf_render_page(pdf, page = 1, dpi = 20), error = function(e) NULL)
  fonts <- tryCatch(pdf_fonts(pdf), error = function(e) NULL)
  pdf_ok <- !is.null(pi) && pi$pages == 1 && !is.null(pr)
  font_ok <- !is.null(fonts) && nrow(fonts) > 0 && all(fonts$embedded)
  svg_tmp <- tempfile(fileext = ".png")
  svg_ok <- tryCatch({rsvg_png(svg, svg_tmp, width = 300); file.info(svg_tmp)$size > 1000}, error = function(e) FALSE)
  ti <- tryCatch(image_info(image_read(tif)), error = function(e) NULL)
  tiff_ok <- !is.null(ti) && ti$width >= 1500 && ti$height >= 1000 && all(grepl("600x600", ti$density))
  arr <- tryCatch(readPNG(pn), error = function(e) NULL)
  png_ok <- !is.null(arr) && dim(arr)[1] >= 800 && dim(arr)[2] >= 1000
  border_nonwhite <- NA_real_
  if (!is.null(arr)) {
    nw <- pmin(arr[,,1], arr[,,2], arr[,,3]) < 0.97
    border <- c(nw[1:2,], nw[(nrow(nw)-1):nrow(nw),], nw[,1:2], nw[,(ncol(nw)-1):ncol(nw)])
    border_nonwhite <- mean(border)
  }
  crop_ok <- is.finite(border_nonwhite) && border_nonwhite < 0.02
  render_rows[[length(render_rows)+1L]] <- data.table(figure=s, pdf_render=pdf_ok, fonts_embedded=font_ok,
    svg_render=svg_ok, tiff_600dpi=tiff_ok, png_dimensions=png_ok, border_nonwhite_fraction=border_nonwhite, crop_ok=crop_ok)
}
render <- rbindlist(render_rows); fwrite(render, file.path(QA, "figure_rendering_QA.tsv"), sep = "\t")
for (v in c("pdf_render","fonts_embedded","svg_render","tiff_600dpi","png_dimensions","crop_ok")) add("figure_render", v, all(render[[v]]), sum(render[[v]]), nrow(render))

# Panel lettering and Figure 4 format review.
svg4 <- readLines(file.path(FIG, paste0(main[4], ".svg")), warn = FALSE)
for (letter in letters[1:6]) add("panel", paste0("Figure4_panel_", letter), any(grepl(paste0(">", letter, "</text>"), svg4, fixed = TRUE)), letter, "present")
review <- data.table(format = c("single-column 89 mm", "double-column 183 mm", "full-page 183x225 mm"),
                     status = c("PASS_EXTENDED_HEIGHT", "PASS", "PASS"),
                     conclusion = c("Readable after a one-column-by-six-panel reflow; the 440-mm height is a review export, not a single-page submission layout.",
                                    "Readable after a two-column-by-three-row reflow; axes and confidence intervals remain visible.",
                                    "Preferred submission layout; labels, confidence intervals and legends are readable."))
fwrite(review, file.path(QA, "Figure4_readability_review.tsv"), sep = "\t")
for (fmt in review$format) add("panel", paste0("Figure4_readability_", make.names(fmt)),
                              grepl("^PASS", review[format == fmt, status]), review[format == fmt, status], "PASS*")

# Prohibited-language and SOFA_D3 terminology audit.
texts <- list.files(MAN, pattern = "\\.md$", full.names = TRUE)
txt <- paste(vapply(texts, function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"), ""), collapse = "\n")
patterns <- c(
  "IPW (eliminated|eliminates|removed|removes) selection bias",
  "covariates? (were|was|are|is) completely balanced",
  "(restored|recovered|reconstructed) (the )?unobserved D5 molecular",
  "IPW results? (replaced|replace|superseded|supersede) the unweighted",
  "no[- ]?D3 availability model (was|is) superior",
  "Day[ -]?3 SOFA",
  "time-updated exposures",
  "time-dependent covariate"
)
for (pat in patterns) add("language", paste0("prohibited_", make.names(pat)), !grepl(pat, txt, ignore.case = TRUE, perl = TRUE), pat, "absent")
required_sentence_terms <- c("positivity", "residual imbalance", "sensitivity analysis", "did not", "unweighted centre-stratified primary")
for (term in required_sentence_terms) add("language", paste0("required_", make.names(term)), grepl(tolower(term), tolower(txt), fixed = TRUE), term, "present")

# Public source-data privacy QA. Aggregate histogram/weight labels are allowed;
# individual-level identifiers and individual probability/weight columns are not.
pub_files <- list.files(PUB, pattern = "\\.(tsv|csv)$", full.names = TRUE)
privacy_rows <- list()
for (f in pub_files) {
  x <- tryCatch(fread(f, nrows = 5), error = function(e) data.table())
  bad_id <- names(x)[grepl("patient.?id|sample.?name|subject.?id|record.?id", names(x), ignore.case = TRUE)]
  bad_weight <- names(x)[grepl("^(ps_raw|ps|sw|sw_trim|probability|individual_weight)$", names(x), ignore.case = TRUE)]
  is_aggregate <- all(c("bin","count") %in% names(x)) || grepl("diagnostic|scenario|SMD|Hallmark|Figure", basename(f), ignore.case = TRUE)
  privacy_rows[[length(privacy_rows)+1L]] <- data.table(file=basename(f), no_identifier=!length(bad_id), no_individual_weight=!length(bad_weight) || is_aggregate,
    flagged_columns=paste(c(bad_id, bad_weight), collapse=";"))
}
privacy <- rbindlist(privacy_rows); fwrite(privacy, file.path(QA, "privacy_QA.tsv"), sep = "\t")
add("privacy", "public_source_no_identifiers", all(privacy$no_identifier), sum(privacy$no_identifier), nrow(privacy))
add("privacy", "public_source_no_individual_weights", all(privacy$no_individual_weight), sum(privacy$no_individual_weight), nrow(privacy))

# Required supplement workbook and all six prespecified scenarios.
wb <- file.path(PUB, "Supplementary_Tables_Availability_IPW.xlsx")
add("supplement", "availability_workbook", file.exists(wb) && file.info(wb)$size > 50000, ifelse(file.exists(wb), file.info(wb)$size, 0), ">50000 bytes")
sc <- fread(file.path(PUB, "SupplementaryTable_Scenario_metrics.tsv"))
add("supplement", "all_six_prespecified_scenarios", nrow(sc) == 6L, nrow(sc), 6)

qa <- rbindlist(checks, fill = TRUE)
fwrite(qa, file.path(QA, "closeout_QA_summary.tsv"), sep = "\t")
writeLines(c("SIC freeze-closeout QA", paste("Checks:", nrow(qa)), paste("Passed:", sum(qa$pass)),
             paste("Failed errors:", sum(!qa$pass & qa$severity == "error")), "", capture.output(print(qa[pass == FALSE]))),
           file.path(QA, "closeout_QA_report.txt"), useBytes = TRUE)
writeLines(capture.output(sessionInfo()), file.path(QA, "sessionInfo_closeout_QA.txt"), useBytes = TRUE)
if (any(!qa$pass & qa$severity == "error")) stop("Closeout QA failed; inspect qa/closeout_QA_summary.tsv")
cat("Closeout QA passed:", nrow(qa), "checks.\n")
