#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/") else normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
REPO_ROOT <- normalizePath(file.path(CLOSEOUT, ".."), winslash = "/")
source(file.path(REPO_ROOT, "outputs", "SIC_reanalysis_2026-07-11", "code", "00_config.R"))
suppressPackageStartupMessages({library(data.table); library(stringr); library(digest); library(png)})

QA <- file.path(CLOSEOUT, "qa")
MAN <- file.path(CLOSEOUT, "manuscript_support")
PUB <- file.path(CLOSEOUT, "public_source_data")
FIG <- file.path(CLOSEOUT, "figures")
VAL <- file.path(CLOSEOUT, "validation")
dir.create(QA, recursive = TRUE, showWarnings = FALSE)
truth <- fread(file.path(CLOSEOUT, "numeric_truth_table.tsv"), na.strings = "")

checks <- list()
add <- function(group, check, pass, observed = "", expected = "", note = "") {
  checks[[length(checks) + 1L]] <<- data.table(group, check, pass = isTRUE(pass), observed = as.character(observed),
                                               expected = as.character(expected), note)
}
read_all <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
tv <- function(k) {
  z <- truth[key == k]
  if (nrow(z) != 1L) stop("Missing or duplicate truth key: ", k)
  if (!is.na(z$value_num[1])) z$value_num[1] else z$value_text[1]
}
eq_num <- function(x, y, tol = 1e-12) all(is.finite(x) == is.finite(y)) && all(abs(x - y) <= tol, na.rm = TRUE)
stars <- function(x) fifelse(x < .001, "***", fifelse(x < .01, "**", fifelse(x < .05, "*", "")))

# Figure 1: patients and centres are distinct quantities.
f1x <- fread(file.path(PUB, "SourceData_Figure1_exclusions.tsv"))
zero_patients <- f1x[category == "Patients from zero-observation centres", N]
zero_centres <- tv("availability.primary.centres_zero")
add("Figure1", "zero_observation_patients", identical(as.numeric(zero_patients), 4), zero_patients, 4)
add("Figure1", "zero_observation_centres", identical(as.numeric(zero_centres), 3), zero_centres, 3)
add("Figure1", "patients_and_centres_not_conflated", length(zero_patients) == 1L && zero_patients != zero_centres,
    paste(zero_patients, zero_centres, sep = "/"), "4 patients / 3 centres")
legends <- read_all(file.path(MAN, "Figure_legends_production.md"))
exact_f1 <- "Four patients from three zero-observation centres were excluded from the positivity-supported estimand."
add("Figure1", "exact_legend_sentence", grepl(exact_f1, legends, fixed = TRUE), exact_f1, "present")
add("Figure1", "no_three_patient_misstatement", !grepl("[Tt]hree patients from (three )?zero-observation centres", legends), "searched", "absent")

# Figure 2 and 3: labels/stars must be generated from the displayed primary FDR only.
f2 <- fread(file.path(PUB, "SourceData_Figure2_RNA.tsv"))
f3 <- fread(file.path(PUB, "SourceData_Figure3_Protein.tsv"))
f2_expected <- paste0(sprintf("%.2f", f2$NES_TMM_Primary), stars(f2$padj_TMM_Primary))
f3_expected <- paste0(sprintf("%.2f", f3$NES), stars(f3$padj))
add("Figures2_3", "Figure2_primary_FDR_star_code", identical(f2$label, f2_expected), sum(f2$label == f2_expected), nrow(f2))
add("Figures2_3", "Figure3_primary_FDR_star_code", identical(f3$label, f3_expected), sum(f3$label == f3_expected), nrow(f3))
star_terms <- c("BH-FDR < 0.05", "BH-FDR < 0.01", "BH-FDR < 0.001")
add("Figures2_3", "star_thresholds_documented", all(vapply(star_terms, grepl, logical(1), x = legends, fixed = TRUE)),
    "three thresholds", "present")
add("Figures2_3", "no_nonexistent_symbols", !grepl("dagger|section symbol|concordant significance|primary and PH-pass analyses were significant", legends, ignore.case = TRUE),
    "searched", "absent")
add("Figures2_3", "new_figure_stems_exist", all(file.exists(file.path(FIG, paste0(c("Figure2_RNA_core_NES", "Figure3_Protein_core_NES"), ".pdf")))), "2", "2")
add("Figures2_3", "old_figure_stems_absent", !length(list.files(FIG, pattern = "Figure[23]_.*_robustness", full.names = TRUE)), "0", "0")

# Methods terminology and display-name ledger.
methods <- read_all(file.path(MAN, "Methods_production.md"))
all_manuscript <- paste(vapply(list.files(MAN, pattern = "\\.(md|tsv)$", full.names = TRUE), read_all, character(1)), collapse = "\n")
required_methods <- paste0("Day-1, day-3 and day-5 molecular measurements were analysed in separate time-specific prognostic models. ",
                           "Day-3 and day-5 analyses used delayed entry at the corresponding prespecified sampling landmarks.")
add("Methods", "separate_time_specific_models", grepl(required_methods, methods, fixed = TRUE), required_methods, "present")
add("Methods", "no_time_updated_exposure_wording", !grepl("time-updated exposures", all_manuscript, ignore.case = TRUE), "searched", "absent")
add("Methods", "no_single_time_dependent_covariate_claim", !grepl("time-dependent covariate", all_manuscript, ignore.case = TRUE), "searched", "absent")

canonical_names <- c("TNF-α signaling via NF-κB", "IL-6/JAK/STAT3 signaling", "MYC targets V1",
                     "E2F targets", "DNA repair", "mTORC1 signaling")
display_text <- paste(c(f2$pathway_label, f3$pathway_label,
                        fread(file.path(PUB, "SourceData_Figure4A_same_time.tsv"))$Pathway_label), collapse = "\n")
for (nm in canonical_names) add("Terminology", paste0("display_", make.names(nm)), grepl(nm, display_text, fixed = TRUE), nm, "present")
add("Terminology", "original_Hallmark_IDs_retained",
    all(c("TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "MYC_TARGETS_V1", "E2F_TARGETS", "DNA_REPAIR", "MTORC1_SIGNALING") %in%
          unique(c(f2$pathway, f3$pathway))), "six IDs", "present")

# Supplement legends/captions completeness.
supp_fig <- read_all(file.path(MAN, "Supplementary_figure_legends_production.md"))
supp_tab <- read_all(file.path(MAN, "Supplementary_table_captions_production.md"))
fig_sections <- str_count(supp_fig, regex("^## Supplementary Figure A[1-8]", multiline = TRUE))
tab_sections <- str_count(supp_tab, regex("^## Worksheet `", multiline = TRUE))
add("Supplement", "eight_independent_figure_legends", fig_sections == 8L, fig_sections, 8)
add("Supplement", "worksheet_captions_present", tab_sections >= 1L, tab_sections, ">=1")
for (term in c("Population/analysis definition", "Variables and abbreviations", "Weighting/FDR definition", "Interpretation limitation"))
  add("Supplement", paste0("worksheet_caption_", make.names(term)), grepl(term, supp_tab, fixed = TRUE), term, "present")

# Evidence matrix structure, source traceability, and requested coverage.
ev <- fread(file.path(MAN, "manuscript_evidence_matrix.tsv"), na.strings = "")
required_cols <- c("claim_id","section","subsection","claim_text","value","unit","effect_direction","confidence_interval",
                   "FDR_or_P","numeric_truth_key","source_file","source_row_or_filter","figure_or_table",
                   "permitted_interpretation","prohibited_interpretation")
add("Evidence", "required_columns", all(required_cols %in% names(ev)), sum(required_cols %in% names(ev)), length(required_cols))
add("Evidence", "claim_ids_unique", !anyDuplicated(ev$claim_id), anyDuplicated(ev$claim_id), 0)
key_parts <- unique(trimws(unlist(strsplit(na.omit(ev$numeric_truth_key), ";", fixed = TRUE))))
key_parts <- key_parts[nzchar(key_parts)]
add("Evidence", "numeric_truth_keys_resolve", all(key_parts %in% truth$key), sum(key_parts %in% truth$key), length(key_parts))
coverage <- c("cohort and risk set", "RNA core pathway", "Protein core pathway", "same-time cross-omics",
              "forward cross-omics", "reverse cross-omics", "OXPHOS centre attenuation", "Day-5 availability/IPW",
              "Weighted versus unweighted Hallmark comparison")
for (x in coverage) add("Evidence", paste0("coverage_", make.names(x)), any(grepl(x, ev$subsection, ignore.case = TRUE)), x, "covered")
add("Evidence", "coverage_IFN_effect_estimates", any(grepl("IFN", ev$claim_text) & grepl("Figure 4f", ev$figure_or_table, ignore.case = TRUE)),
    "IFN claims linked to Figure 4F", "covered")

# Figure 4 source data must match the numeric truth layer exactly.
compare_truth_fields <- function(dat, prefix_fun, fields, check_name) {
  diffs <- c()
  for (i in seq_len(nrow(dat))) for (field in fields) {
    key <- prefix_fun(dat[i])
    key <- paste0(key, ".", field)
    diffs <- c(diffs, abs(as.numeric(dat[[field]][i]) - as.numeric(tv(key))))
  }
  add("Figure4", check_name, all(is.finite(diffs)) && max(diffs) <= 1e-12, max(diffs), "<=1e-12")
}
f4a <- fread(file.path(PUB, "SourceData_Figure4A_same_time.tsv"))
compare_truth_fields(f4a, function(r) paste("cross.same", r$Time, r$Pathway, sep = "."), c("N","partial_rho","pval","FDR"), "panel_A_matches_truth")
for (panel in c("B_forward_D1_D3", "C_forward_D3_D5")) {
  d <- fread(file.path(PUB, paste0("SourceData_Figure4", panel, ".tsv")))
  compare_truth_fields(d, function(r) paste("cross.forward", make.names(r$Direction), r$Pathway, sep = "."),
                       c("N","beta","SE","lower95","upper95","pval","FDR"), paste0("panel_", substr(panel,1,1), "_matches_truth"))
}
f4d <- fread(file.path(PUB, "SourceData_Figure4D_reverse.tsv"))
compare_truth_fields(f4d, function(r) paste("cross.reverse", make.names(r$Direction), r$Pathway, sep = "."),
                     c("N","beta","SE","lower95","upper95","pval","FDR"), "panel_D_matches_truth")
f4f <- fread(file.path(PUB, "SourceData_Figure4F_IFN_effects.tsv"))
compare_truth_fields(f4f, function(r) paste("cross.forward", make.names(r$Direction), r$Pathway, sep = "."),
                     c("N","beta","SE","lower95","upper95","pval","FDR"), "panel_F_matches_truth")
f4e <- fread(file.path(PUB, "SourceData_Figure4E_OXPHOS_attenuation.tsv"))
truth_e <- truth[domain == "cross_oxphos_attenuation" & source_field %in% c("Original_beta","Center_primary_beta","Original_rho","Center_primary_rho"), value_num]
add("Figure4", "panel_E_matches_truth", eq_num(sort(f4e$effect), sort(truth_e)), max(abs(sort(f4e$effect) - sort(truth_e))), "<=1e-12")

# Formal result hash invariance relative to pre-patch snapshot.
pre <- fread(file.path(VAL, "formal_result_hashes_pre_semantic_patch.tsv"))
pre[, relative_path := sub("^.*?/outputs/", "outputs/", formal_result_file)]
pre[, exists := file.exists(relative_path)]
pre[, observed_sha256 := fifelse(exists, vapply(relative_path, digest, character(1), file = TRUE, algo = "sha256", serialize = FALSE), NA_character_)]
pre[, unchanged := exists & sha256 == observed_sha256]
post <- pre[, .(formal_result_file = relative_path, sha256 = observed_sha256)]
fwrite(post, file.path(VAL, "formal_result_hashes_post_semantic_patch.tsv"), sep = "\t")
fwrite(pre[, .(formal_result_file = relative_path, sha256_before = sha256, sha256_after = observed_sha256, exists, unchanged)],
       file.path(VAL, "formal_result_hash_semantic_comparison.tsv"), sep = "\t")
add("Hashes", "formal_results_unchanged", all(pre$unchanged), sum(pre$unchanged), nrow(pre))

# Raster boundary check: non-white marks on the outermost pixels indicate likely clipping.
pngs <- c(list.files(FIG, pattern = "^(Figure[1-4]|Supplementary_Figure_A[1-8]).*\\.png$", full.names = TRUE),
          list.files(FIG, pattern = "^Figure4_review_.*\\.png$", full.names = TRUE))
pngs <- unique(pngs)
border_rows <- lapply(pngs, function(f) {
  a <- readPNG(f)
  edge_rgb <- rbind(cbind(a[1,,1], a[1,,2], a[1,,3]),
                    cbind(a[dim(a)[1],,1], a[dim(a)[1],,2], a[dim(a)[1],,3]),
                    cbind(a[,1,1], a[,1,2], a[,1,3]),
                    cbind(a[,dim(a)[2],1], a[,dim(a)[2],2], a[,dim(a)[2],3]))
  edge <- apply(edge_rgb, 1, min) < .97
  data.table(figure = basename(f), edge_ink_fraction = mean(edge), pass = mean(edge) < .01)
})
border <- rbindlist(border_rows)
fwrite(border, file.path(QA, "figure_axis_boundary_QA.tsv"), sep = "\t")
add("Figures", "outer_edge_clipping_check", all(border$pass), sum(border$pass), nrow(border), "Automated outer-pixel check; visual review remains required.")

qa <- rbindlist(checks, fill = TRUE)
fwrite(qa, file.path(QA, "semantic_QA_summary.tsv"), sep = "\t")
writeLines(c("SIC manuscript-interface semantic QA", paste("Checks:", nrow(qa)), paste("Passed:", sum(qa$pass)),
             paste("Failed:", sum(!qa$pass)), "", capture.output(print(qa[pass == FALSE]))),
           file.path(QA, "semantic_QA_report.txt"), useBytes = TRUE)
writeLines(capture.output(sessionInfo()), file.path(QA, "sessionInfo_semantic_QA.txt"), useBytes = TRUE)
if (any(!qa$pass)) stop("Semantic QA failed; inspect qa/semantic_QA_summary.tsv")
cat("Semantic QA passed:", nrow(qa), "checks.\n")
