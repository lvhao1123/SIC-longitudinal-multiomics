rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(tidyr); library(stringr); library(digest)})

CLOSEOUT <- file.path(PROJECT_DIR, "submission")
dirs <- file.path(CLOSEOUT, c("canonical", "superseded", "validation", "figures", "public_source_data", "manuscript", "qa", "code", "tests"))
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))

relpath <- function(x) {
  root <- normalizePath(PROJECT_DIR, winslash = "/", mustWork = TRUE)
  y <- normalizePath(x, winslash = "/", mustWork = FALSE)
  sub(paste0("^", stringr::fixed(root), "/?"), "", y)
}
sha <- function(x) digest::digest(x, file = TRUE, algo = "sha256", serialize = FALSE)

# ---- Canonical design -------------------------------------------------------
canonical_design <- file.path(PROJECT_DIR, "docs/superpowers/specs/2026-07-12-day5-rna-availability-ipw-design.md")
canonical_mirror <- file.path(PROJECT_DIR, "outputs/Day5_RNA_availability_IPW_frozen_design.md")
stopifnot(file.exists(canonical_design), file.exists(canonical_mirror), identical(sha(canonical_design), sha(canonical_mirror)))

canonical_files <- c(
  canonical_design,
  canonical_mirror,
  file.path(OUT_ROOT, "code/10a_availability_ipw_helpers.R"),
  file.path(OUT_ROOT, "code/10_run_availability_IPW_sensitivity.R"),
  file.path(OUT_ROOT, "tests/test_10_availability_ipw.R"),
  file.path(AVAIL_OUT, "README_CN.md"),
  file.path(AVAIL_OUT, "18_final_QA.csv"),
  file.path(AVAIL_OUT, "sessionInfo_Availability_IPW.txt"),
  file.path(OUT_ROOT, "FINAL_QA_SUMMARY.csv"),
  file.path(OUT_ROOT, "FILE_MANIFEST_SHA256.csv")
)
stopifnot(all(file.exists(canonical_files)))
canonical_index <- data.table(
  role = c("canonical_design", "canonical_mirror", "helper_code", "orchestration_code", "helper_test",
           "result_readme", "module_QA", "session_info", "global_QA", "existing_manifest"),
  relative_path = vapply(canonical_files, relpath, character(1)),
  sha256 = vapply(canonical_files, sha, character(1)),
  authority = c("unique", "byte-identical mirror", rep("implementation evidence", 8))
)
fwrite(canonical_index, file.path(CLOSEOUT, "canonical/canonical_design_index.tsv"), sep = "\t")

# ---- Superseded material ----------------------------------------------------
legacy_dir <- file.path(OUT_ROOT, "06_Availability_IPW")
legacy_files <- list.files(legacy_dir, recursive = TRUE, full.names = TRUE)
stopifnot(length(legacy_files) > 0L, all(file.exists(legacy_files)))
legacy_index <- data.table(
  classification = "superseded_stabilised_numerator_output",
  original_relative_path = vapply(legacy_files, relpath, character(1)),
  bytes = file.info(legacy_files)$size,
  sha256 = vapply(legacy_files, sha, character(1)),
  current_location_preserved = TRUE,
  manuscript_or_reproduction_use = "PROHIBITED"
)
fwrite(legacy_index, file.path(CLOSEOUT, "superseded/superseded_files_index.tsv"), sep = "\t")
writeLines(c(
  "# SUPERSEDED - DO NOT USE",
  "",
  "The files indexed here belong to the legacy stabilised-numerator availability/IPW implementation.",
  "They are preserved byte-for-byte at their original location for auditability and are not copied into the closeout overlay.",
  "They must not be cited in the manuscript, used to reproduce final results, or referenced by submission scripts.",
  "The only canonical design is listed in ../canonical/canonical_design_index.tsv."
), file.path(CLOSEOUT, "superseded/README_DO_NOT_USE.md"), useBytes = TRUE)

writeLines(c(
  "# Availability/IPW implementation addendum",
  "",
  "The frozen estimand, probability model, inverse-observation weights, truncation and mean-one normalisation remain unchanged.",
  "In the installed survival package, a counting-process delayed-entry Surv response with robust=TRUE requires cluster or id.",
  "Because the frozen formal model contains one row per participant and explicitly does not set id, the same weighted delayed-entry partial likelihood is fitted first.",
  "The observation-level Lin-Wei sandwich variance is then computed as the cross-product of weighted dfbeta residuals.",
  "A prespecified validation compares this implementation with an otherwise identical model using a unique row-level cluster.",
  "The validation compares coefficient, robust standard error, Wald z and two-sided P value and does not replace or regenerate any formal result.",
  "",
  "The internal identifier SOFA_D3 means baseline SOFA plus prior D3 RNA availability. It must never be described as Day 3 SOFA in manuscript-facing text."
), file.path(CLOSEOUT, "availability_IPW_implementation_addendum.md"), useBytes = TRUE)

# ---- Source manifest --------------------------------------------------------
source_candidates <- unique(c(
  unlist(INPUT, use.names = FALSE),
  list.files(file.path(OUT_ROOT, "code"), pattern = "\\.R$", full.names = TRUE),
  list.files(file.path(OUT_ROOT, "tests"), pattern = "\\.R$", full.names = TRUE),
  unlist(lapply(file.path(OUT_ROOT, c("00_audit", "01_RNA_TMM", "02_Protein", "03_CrossOmics", "04_Figures_Tables", "05_Clinical_Tables", "06_Availability_IPW_final")),
                function(d) list.files(d, recursive = TRUE, full.names = TRUE))),
  canonical_files,
  file.path(PROJECT_DIR, "work/SIC_reproducibility_archive_review/SIC_reproducibility_archive/frozen_results/CrossOmics/06_cross_lag_robustness_summary.csv"),
  file.path(PROJECT_DIR, "work/SIC_reproducibility_archive_review/SIC_reproducibility_archive/frozen_results/CrossOmics/07_same_time_robustness_summary.csv")
))
source_candidates <- source_candidates[file.exists(source_candidates) & !dir.exists(source_candidates)]
access <- ifelse(grepl("controlled_participant_level|weights_controlled|PatientLevel|patient_core_pathway", source_candidates, ignore.case = TRUE),
                 "controlled_internal", "submission_or_reproducibility")
source_files <- data.table(
  relative_path = vapply(source_candidates, relpath, character(1)),
  role = case_when(
    source_candidates %in% unlist(INPUT, use.names = FALSE) ~ "input",
    grepl("sessionInfo|SESSION_INFO", basename(source_candidates), ignore.case = TRUE) ~ "sessionInfo",
    grepl("\\.R$", source_candidates) ~ "script",
    grepl("\\.(pdf|png|svg|tiff)$", source_candidates, ignore.case = TRUE) ~ "figure",
    TRUE ~ "result_or_audit"
  ),
  access = access,
  bytes = file.info(source_candidates)$size,
  sha256 = vapply(source_candidates, sha, character(1))
)
setorder(source_files, role, relative_path)
fwrite(source_files, file.path(CLOSEOUT, "source_files.tsv"), sep = "\t")

# ---- Numeric truth table ----------------------------------------------------
truth <- as.data.table(list(
  domain = character(), key = character(), value_num = numeric(), value_text = character(),
  unit = character(), precision = integer(), source_file = character(), source_field = character(), filter = character()
))
add_truth <- function(domain, key, value_num = NA_real_, value_text = NA_character_, unit = "", precision = 3L,
                      source_file, source_field, filter = "") {
  stopifnot(length(key) == 1L, length(value_num) == 1L, length(value_text) == 1L)
  truth <<- rbind(truth, data.table(domain, key, value_num = as.numeric(value_num), value_text = as.character(value_text),
                                    unit, precision = as.integer(precision), source_file = relpath(source_file),
                                    source_field, filter), fill = TRUE)
}

entry_file <- file.path(AVAIL_OUT, "00_entry_riskset_counts.csv")
entry <- fread(entry_file)
for (i in seq_len(nrow(entry))) for (v in c("entry", "source_N", "structural_N", "risk_N", "support_N", "observed_N", "unobserved_N", "observed_events")) {
  add_truth("availability_cohort", paste("availability", entry$entry_name[i], v, sep = "."), entry[[v]][i], unit = ifelse(v == "entry", "days", "patients"),
            precision = ifelse(v == "entry", 2L, 0L), source_file = entry_file, source_field = v, filter = paste0("entry_name=", entry$entry_name[i]))
}

centre_file <- file.path(AVAIL_OUT, "01_centre_positivity_audit.csv")
centres <- fread(centre_file)
for (i in seq_len(nrow(centres))) {
  prefix <- paste("availability.centre", centres$entry_name[i], centres$center[i], sep = ".")
  add_truth("centre_positivity", paste0(prefix, ".N"), centres$N[i], unit = "patients", precision = 0L, source_file = centre_file, source_field = "N")
  add_truth("centre_positivity", paste0(prefix, ".observed"), centres$observed[i], unit = "patients", precision = 0L, source_file = centre_file, source_field = "observed")
  add_truth("centre_positivity", paste0(prefix, ".unobserved"), centres$unobserved[i], unit = "patients", precision = 0L, source_file = centre_file, source_field = "unobserved")
  add_truth("centre_positivity", paste0(prefix, ".class"), value_text = centres$class[i], unit = "category", precision = 0L, source_file = centre_file, source_field = "class")
}
for (cl in c("zero", "all", "partial")) add_truth(
  "centre_positivity", paste0("availability.primary.centres_", cl), sum(centres$entry_name == "primary" & centres$class == cl),
  unit = "centres", precision = 0L, source_file = centre_file, source_field = "class", filter = paste0("entry_name=primary;class=", cl)
)

weight_file <- file.path(AVAIL_OUT, "08_weight_diagnostics.csv")
weights <- fread(weight_file)
weight_vars <- c("min_probability", "max_probability", "max_raw_weight", "trim_p01", "trim_p99", "analysis_weight_mean",
                 "analysis_weight_min", "analysis_weight_max", "ESS", "observed_N", "ESS_ratio", "max_abs_SMD_before", "max_abs_SMD_after")
for (i in seq_len(nrow(weights))) {
  scenario <- paste(weights$entry_name[i], weights$spec[i], sep = "__")
  for (v in weight_vars) add_truth("availability_weight", paste("availability.weight", scenario, v, sep = "."), weights[[v]][i],
                                  unit = ifelse(v %in% c("observed_N"), "patients", ifelse(v == "ESS", "effective patients", "ratio")),
                                  precision = ifelse(v %in% c("observed_N"), 0L, 6L), source_file = weight_file, source_field = v, filter = paste0("entry/spec=", scenario))
  flags <- c(weights$caution_min_p[i], weights$caution_max_raw_weight[i], weights$caution_ESS[i], weights$caution_balance[i])
  add_truth("availability_weight", paste0("availability.weight.", scenario, ".diagnostic_class"), value_text = ifelse(any(flags), "caution", "adequate"),
            unit = "category", precision = 0L, source_file = weight_file, source_field = "caution_*", filter = paste0("entry/spec=", scenario))
}

# Aggregate distributions are included in the truth layer so public figures do
# not need to read or expose participant-level probabilities or weights.
controlled_map <- data.table(
  scenario = c("primary__SOFA_D3", "primary__SOFA_noD3", "primary__PF_PLT_D3", "primary__PF_PLT_noD3", "lower__SOFA_D3", "upper__SOFA_D3"),
  file = file.path(AVAIL_OUT, "controlled_participant_level", c(
    "weights_entry4_SOFA_D3_controlled.csv", "weights_entry4_SOFA_noD3_controlled.csv",
    "weights_entry4_PF_PLT_D3_controlled.csv", "weights_entry4_PF_PLT_noD3_controlled.csv",
    "weights_lower_SOFA_D3_controlled.csv", "weights_upper_SOFA_D3_controlled.csv"
  ))
)
for (i in seq_len(nrow(controlled_map))) {
  wd <- fread(controlled_map$file[i])
  p_breaks <- seq(0, 1, length.out = 31L)
  p_hist <- hist(wd$raw_probability[is.finite(wd$raw_probability)], breaks = p_breaks, plot = FALSE, include.lowest = TRUE)
  for (b in seq_along(p_hist$counts)) {
    prefix <- paste("availability.distribution", controlled_map$scenario[i], "probability", sprintf("bin%02d", b), sep = ".")
    add_truth("availability_distribution", paste0(prefix, ".mid"), p_hist$mids[b], unit = "probability", precision = 6L,
              source_file = controlled_map$file[i], source_field = "raw_probability", filter = paste0("aggregate histogram bin ", b))
    add_truth("availability_distribution", paste0(prefix, ".count"), p_hist$counts[b], unit = "patients", precision = 0L,
              source_file = controlled_map$file[i], source_field = "raw_probability", filter = paste0("aggregate histogram bin ", b))
  }
  wv <- wd$analysis_weight[wd$available == 1L & is.finite(wd$analysis_weight)]
  w_breaks <- seq(0, ceiling(max(wv) * 10) / 10, length.out = 31L)
  w_hist <- hist(wv, breaks = w_breaks, plot = FALSE, include.lowest = TRUE)
  for (b in seq_along(w_hist$counts)) {
    prefix <- paste("availability.distribution", controlled_map$scenario[i], "analysis_weight", sprintf("bin%02d", b), sep = ".")
    add_truth("availability_distribution", paste0(prefix, ".mid"), w_hist$mids[b], unit = "mean-normalised weight", precision = 6L,
              source_file = controlled_map$file[i], source_field = "analysis_weight", filter = paste0("observed aggregate histogram bin ", b))
    add_truth("availability_distribution", paste0(prefix, ".count"), w_hist$counts[b], unit = "patients", precision = 0L,
              source_file = controlled_map$file[i], source_field = "analysis_weight", filter = paste0("observed aggregate histogram bin ", b))
  }
}

cox_file <- file.path(AVAIL_OUT, "13_Cox_convergence_finite_PH_summary.csv")
cox <- fread(cox_file)
for (i in seq_len(nrow(cox))) for (v in setdiff(names(cox), "scenario")) add_truth(
  "availability_cox", paste("availability.cox", cox$scenario[i], v, sep = "."), cox[[v]][i], unit = "genes", precision = 0L,
  source_file = cox_file, source_field = v, filter = paste0("scenario=", cox$scenario[i])
)

cmp_file <- file.path(AVAIL_OUT, "17_all_Hallmark_comparison_metrics.csv")
cmp <- fread(cmp_file)
for (i in seq_len(nrow(cmp))) for (v in setdiff(names(cmp), "scenario")) add_truth(
  "availability_hallmark_comparison", paste("availability.comparison", cmp$scenario[i], v, sep = "."), cmp[[v]][i],
  unit = ifelse(v == "spearman_NES", "Spearman rho", "proportion"), precision = 6L, source_file = cmp_file, source_field = v, filter = paste0("scenario=", cmp$scenario[i])
)

cmp_detail_file <- file.path(AVAIL_OUT, "16_all_Hallmark_unweighted_vs_IPW.csv")
cmp_detail <- fread(cmp_detail_file)
for (i in seq_len(nrow(cmp_detail))) {
  prefix <- paste("availability.pathway_comparison", cmp_detail$scenario[i], cmp_detail$pathway[i], sep = ".")
  for (v in c("NES_unweighted", "FDR_unweighted", "NES_weighted", "FDR_weighted", "delta_NES", "leading_edge_jaccard")) add_truth(
    "availability_pathway_comparison", paste0(prefix, ".", v), cmp_detail[[v]][i],
    unit = ifelse(grepl("FDR", v), "BH-FDR", ifelse(grepl("jaccard", v), "proportion", "NES")), precision = 8L,
    source_file = cmp_detail_file, source_field = v, filter = paste0("scenario/pathway=", cmp_detail$scenario[i], "/", cmp_detail$pathway[i])
  )
  add_truth("availability_pathway_comparison", paste0(prefix, ".FDR_class"), value_text = cmp_detail$FDR_class[i], unit = "category", precision = 0L,
            source_file = cmp_detail_file, source_field = "FDR_class", filter = paste0("scenario/pathway=", cmp_detail$scenario[i], "/", cmp_detail$pathway[i]))
}

gsea_file <- file.path(AVAIL_OUT, "14_all_weighted_Hallmark_results.csv")
gsea <- fread(gsea_file)
for (i in seq_len(nrow(gsea))) for (v in c("NES", "padj", "size")) add_truth(
  "availability_hallmark", paste("availability.gsea", gsea$analysis[i], gsea$pathway[i], v, sep = "."), gsea[[v]][i],
  unit = ifelse(v == "NES", "NES", ifelse(v == "padj", "BH-FDR", "genes")), precision = ifelse(v == "size", 0L, 8L),
  source_file = gsea_file, source_field = v, filter = paste0("analysis/pathway=", gsea$analysis[i], "/", gsea$pathway[i])
)

smd_file <- file.path(AVAIL_OUT, "09_weight_balance_SMD.csv")
smd <- fread(smd_file)
for (i in seq_len(nrow(smd))) for (v in c("SMD_before", "SMD_after")) add_truth(
  "availability_balance", paste("availability.smd", smd$entry_name[i], smd$spec[i], make.names(smd$variable[i]), v, sep = "."), smd[[v]][i],
  unit = "SMD", precision = 6L, source_file = smd_file, source_field = v, filter = paste0("entry/spec/variable=", smd$entry_name[i], "/", smd$spec[i], "/", smd$variable[i])
)

rna_link_file <- file.path(AUDIT_DIR, "rna_sample_match_riskset.csv")
protein_link_file <- file.path(AUDIT_DIR, "protein_sample_match_riskset.csv")
for (f in c(rna_link_file, protein_link_file)) {
  d <- fread(f); omics <- ifelse(grepl("rna_", basename(f)), "RNA", "Protein")
  for (i in seq_len(nrow(d))) for (v in c("matched_n", "matched_events", "risk_valid_n", "risk_valid_events")) add_truth(
    "figure1_samples", paste("samples", omics, d$day[i], v, sep = "."), d[[v]][i], unit = "patients", precision = 0L,
    source_file = f, source_field = v, filter = paste0("day=", d$day[i])
  )
}

rna_file <- file.path(AUDIT_DIR, "RNA_Hallmark_normalization_PH_robustness.csv")
rna <- fread(rna_file)
for (i in seq_len(nrow(rna))) for (v in c("NES_TMM_Primary", "padj_TMM_Primary", "NES_TMM_PH_pass", "padj_TMM_PH_pass")) add_truth(
  "rna_pathway", paste("rna", rna$Time[i], rna$pathway[i], v, sep = "."), rna[[v]][i], unit = ifelse(grepl("NES", v), "NES", "BH-FDR"),
  precision = 8L, source_file = rna_file, source_field = v, filter = paste0("Time/pathway=", rna$Time[i], "/", rna$pathway[i])
)

protein_file <- file.path(PROTEIN_OUT, "03_Protein_Hallmark_all_models.csv")
protein <- fread(protein_file)
for (i in seq_len(nrow(protein))) for (v in c("NES", "padj", "size")) add_truth(
  "protein_pathway", paste("protein", protein$analysis[i], protein$pathway[i], v, sep = "."), protein[[v]][i],
  unit = ifelse(v == "NES", "NES", ifelse(v == "padj", "BH-FDR", "proteins")), precision = ifelse(v == "size", 0L, 8L),
  source_file = protein_file, source_field = v, filter = paste0("analysis/pathway=", protein$analysis[i], "/", protein$pathway[i])
)

same_file <- file.path(CROSS_OUT, "04_same_time_RNA_Protein_partial_spearman.csv")
same <- fread(same_file)
for (i in seq_len(nrow(same))) for (v in c("N", "partial_rho", "pval", "FDR")) add_truth(
  "cross_same_time", paste("cross.same", same$Time[i], same$Pathway[i], v, sep = "."), same[[v]][i],
  unit = ifelse(v == "N", "patients", ifelse(v == "partial_rho", "partial Spearman rho", ifelse(v == "pval", "P value", "BH-FDR"))),
  precision = ifelse(v == "N", 0L, 8L), source_file = same_file, source_field = v, filter = paste0("Time/pathway=", same$Time[i], "/", same$Pathway[i])
)

for (kind in c("forward", "reverse")) {
  f <- file.path(CROSS_OUT, ifelse(kind == "forward", "05_forward_cross_lag_HC3.csv", "06_reverse_cross_lag_HC3.csv"))
  d <- fread(f)
  for (i in seq_len(nrow(d))) for (v in c("N", "beta", "SE", "lower95", "upper95", "pval", "FDR")) add_truth(
    paste0("cross_", kind), paste("cross", kind, make.names(d$Direction[i]), d$Pathway[i], v, sep = "."), d[[v]][i],
    unit = ifelse(v == "N", "patients", ifelse(v %in% c("pval", "FDR"), ifelse(v == "pval", "P value", "BH-FDR"), "standardized coefficient")),
    precision = ifelse(v == "N", 0L, 8L), source_file = f, source_field = v, filter = paste0("Direction/pathway=", d$Direction[i], "/", d$Pathway[i])
  )
}

ox_cross_file <- file.path(PROJECT_DIR, "work/SIC_reproducibility_archive_review/SIC_reproducibility_archive/frozen_results/CrossOmics/06_cross_lag_robustness_summary.csv")
ox_same_file <- file.path(PROJECT_DIR, "work/SIC_reproducibility_archive_review/SIC_reproducibility_archive/frozen_results/CrossOmics/07_same_time_robustness_summary.csv")
ox_cross <- fread(ox_cross_file)[Feature == "OXIDATIVE_PHOSPHORYLATION"]
ox_same <- fread(ox_same_file)[Feature == "OXIDATIVE_PHOSPHORYLATION"]
for (i in seq_len(nrow(ox_cross))) for (v in c("Original_beta", "Original_FDR", "Center_primary_beta", "Center_primary_FDR")) add_truth(
  "cross_oxphos_attenuation", paste("cross.oxphos.crosslag", make.names(ox_cross$Direction[i]), v, sep = "."), ox_cross[[v]][i],
  unit = ifelse(grepl("FDR", v), "BH-FDR", "standardized coefficient"), precision = 8L, source_file = ox_cross_file, source_field = v, filter = paste0("Direction=", ox_cross$Direction[i])
)
for (i in seq_len(nrow(ox_same))) for (v in c("Original_rho", "Original_FDR", "Center_primary_rho", "Center_primary_FDR")) add_truth(
  "cross_oxphos_attenuation", paste("cross.oxphos.same", ox_same$Time[i], v, sep = "."), ox_same[[v]][i],
  unit = ifelse(grepl("FDR", v), "BH-FDR", "partial Spearman rho"), precision = 8L, source_file = ox_same_file, source_field = v, filter = paste0("Time=", ox_same$Time[i])
)

protein_avail_file <- file.path(AVAIL_OUT, "04_D5_Protein_descriptive_availability_and_nesting.csv")
pa <- fread(protein_avail_file)
for (v in names(pa)) add_truth("protein_availability", paste0("protein.availability.", v), pa[[v]][1], unit = ifelse(grepl("events", v), "events", "patients"),
                               precision = 0L, source_file = protein_avail_file, source_field = v)

# Frozen analysis constants are centralized here so that all manuscript-facing
# products read them from the numeric truth layer rather than hard-coding them.
for (x in list(
  list("analysis.fdr_threshold", 0.05, "proportion"),
  list("analysis.ph_nominal_threshold", 0.05, "proportion"),
  list("analysis.weight_trim_lower_quantile", 0.01, "quantile"),
  list("analysis.weight_trim_upper_quantile", 0.99, "quantile"),
  list("analysis.followup_horizon", 60, "days"),
  list("analysis.entry.RNA.D1", 0, "days"),
  list("analysis.entry.RNA.D3", 2, "days"),
  list("analysis.entry.RNA.D5", 4, "days"),
  list("analysis.hallmark_min_size", 15, "genes"),
  list("analysis.hallmark_max_size", 500, "genes")
)) add_truth("analysis_standard", x[[1]], x[[2]], unit = x[[3]], precision = 2L,
             source_file = canonical_design, source_field = "frozen design constant")

stopifnot(!anyDuplicated(truth$key))
required_keys <- c(
  "availability.primary.source_N", "availability.primary.structural_N", "availability.primary.support_N",
  "availability.primary.observed_N", "availability.primary.observed_events", "availability.primary.centres_zero",
  "availability.primary.centres_all", "availability.primary.centres_partial",
  "availability.weight.primary__SOFA_D3.min_probability", "availability.weight.primary__SOFA_D3.max_raw_weight",
  "availability.weight.primary__SOFA_D3.ESS_ratio", "availability.weight.primary__SOFA_D3.max_abs_SMD_after",
  "availability.cox.entry4_SOFA_D3.genes_converged", "availability.cox.entry4_SOFA_D3.genes_entering_GSEA",
  "availability.comparison.entry4_SOFA_D3.spearman_NES", "availability.comparison.entry4_SOFA_D3.direction_agreement",
  "availability.comparison.entry4_SOFA_D3.significant_set_jaccard",
  "availability.weight.primary__SOFA_D3.diagnostic_class"
)
stopifnot(all(required_keys %in% truth$key))
fwrite(truth, file.path(CLOSEOUT, "numeric_truth_table.tsv"), sep = "\t", na = "")

dictionary <- unique(truth[, .(domain, key, unit, precision, source_file, source_field, filter)])
dictionary[, manuscript_rule := fifelse(grepl("SOFA_D3", key), "Internal code only: describe as baseline SOFA plus prior D3 RNA availability",
                                 fifelse(grepl("NES", key), "Mortality-association NES; not absolute pathway activity", "Use value and unit as recorded"))]
fwrite(dictionary, file.path(CLOSEOUT, "numeric_truth_dictionary.tsv"), sep = "\t")

cat("Canonical archive and numeric truth table created:", nrow(truth), "truth rows\n")
