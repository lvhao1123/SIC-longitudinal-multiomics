rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
source("outputs/SIC_reanalysis_2026-07-11/code/10a_availability_ipw_helpers.R")
assert_avail_packages()
suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(tidyr); library(stringr)
  library(tibble); library(survival); library(fgsea); library(ggplot2)
})
set.seed(20260712)

dir.create(AVAIL_OUT, recursive = TRUE, showWarnings = FALSE)
CONTROLLED_OUT <- file.path(AVAIL_OUT, "controlled_participant_level")
dir.create(CONTROLLED_OUT, recursive = TRUE, showWarnings = FALSE)

message("[1/7] Loading frozen inputs")
clinical <- fread(INPUT$clinical, data.table = FALSE)
logcpm <- readRDS(file.path(RNA_OUT, "RNA_TMM_logCPM_gene_by_sample.rds"))
protein_qc <- fread(file.path(PROTEIN_OUT, "00_Protein_sample_QC.csv"), data.table = FALSE)
base <- prepare_availability_base(clinical, colnames(logcpm))
d5_ids <- base$PatientID[base$RNA_D5_available == 1L]
stopifnot(nrow(base) == 504L, sum(base$event) == 84L)

message("[2/7] Running frozen timing, centre-positivity, missingness, and protein-nesting audits")
entry_audits <- lapply(AVAIL_ENTRY, build_entry_cohort, base = base, d5_rna_ids = d5_ids)
names(entry_audits) <- names(AVAIL_ENTRY)
entry_counts <- bind_rows(lapply(names(entry_audits), function(nm) {
  entry_audits[[nm]]$counts |> mutate(entry_name = nm, .before = 1)
}))
fwrite(entry_counts, file.path(AVAIL_OUT, "00_entry_riskset_counts.csv"))

centre_audit <- bind_rows(lapply(names(entry_audits), function(nm) {
  entry_audits[[nm]]$centres |> mutate(entry_name = nm, entry = AVAIL_ENTRY[[nm]], .before = 1)
}))
fwrite(centre_audit, file.path(AVAIL_OUT, "01_centre_positivity_audit.csv"))

time_audit <- audit_time_origin(base, AVAIL_ENTRY)
fwrite(time_audit, file.path(AVAIL_OUT, "02_survival_time_origin_and_60day_audit.csv"))
boundary_conflicts <- audit_boundary_conflicts(base, AVAIL_ENTRY)
fwrite(boundary_conflicts, file.path(CONTROLLED_OUT, "02b_D5_RNA_boundary_conflicts_controlled.csv"))

missingness <- bind_rows(lapply(names(entry_audits), function(nm) {
  audit_missingness(entry_audits[[nm]]$supported, nm)
}))
fwrite(missingness, file.path(AVAIL_OUT, "03_availability_covariate_missingness.csv"))
if (any(missingness$missing_N > 0L)) stop("Frozen availability covariates contain missing values; no silent deletion or imputation is allowed")

protein_nesting <- audit_protein_nesting(protein_qc, base, entry = AVAIL_ENTRY[["primary"]])
fwrite(protein_nesting, file.path(AVAIL_OUT, "04_D5_Protein_descriptive_availability_and_nesting.csv"))

message("[3/7] Fitting the four prespecified entry-4 observation models")
weight_objects <- list()
prefit_tables <- list(); zero_cell_tables <- list(); coefficient_tables <- list()
weight_diagnostics <- list(); balance_tables <- list(); transform_tables <- list()
for (spec in AVAIL_MODEL_SPECS) {
  message("  Availability model: ", spec)
  obj <- fit_observation_weights(entry_audits$primary$supported, spec)
  weight_objects[[paste0("primary__", spec)]] <- obj
  prefit_tables[[spec]] <- obj$prefit$summary
  zero_cell_tables[[spec]] <- obj$prefit$zero_cells |> mutate(spec = spec, .before = 1)
  coefficient_tables[[spec]] <- tibble(term = names(coef(obj$fit)), coefficient = unname(coef(obj$fit)), spec = spec) |>
    select(spec, everything())
  weight_diagnostics[[spec]] <- obj$diagnostics |> mutate(entry_name = "primary", entry = 4, .before = 1)
  balance_tables[[spec]] <- obj$balance |> mutate(entry_name = "primary", entry = 4, spec = spec, .before = 1)
  transform_tables[[spec]] <- as.data.frame(obj$transform_constants) |>
    rownames_to_column("transformed_variable") |> mutate(entry_name = "primary", entry = 4, spec = spec, .before = 1)
  controlled <- obj$data |>
    select(PatientID, center, centre_class, available, raw_probability, raw_weight, trimmed_weight, analysis_weight)
  fwrite(controlled, file.path(CONTROLLED_OUT, paste0("weights_entry4_", spec, "_controlled.csv")))
}

message("[4/7] Fitting prespecified entry-boundary observation models")
for (nm in c("lower", "upper")) {
  obj <- fit_observation_weights(entry_audits[[nm]]$supported, "SOFA_D3")
  key <- paste0(nm, "__SOFA_D3")
  weight_objects[[key]] <- obj
  weight_diagnostics[[key]] <- obj$diagnostics |> mutate(entry_name = nm, entry = AVAIL_ENTRY[[nm]], .before = 1)
  balance_tables[[key]] <- obj$balance |> mutate(entry_name = nm, entry = AVAIL_ENTRY[[nm]], spec = "SOFA_D3", .before = 1)
  transform_tables[[key]] <- as.data.frame(obj$transform_constants) |>
    rownames_to_column("transformed_variable") |> mutate(entry_name = nm, entry = AVAIL_ENTRY[[nm]], spec = "SOFA_D3", .before = 1)
  controlled <- obj$data |>
    select(PatientID, center, centre_class, available, raw_probability, raw_weight, trimmed_weight, analysis_weight)
  fwrite(controlled, file.path(CONTROLLED_OUT, paste0("weights_", nm, "_SOFA_D3_controlled.csv")))
}

fwrite(bind_rows(prefit_tables), file.path(AVAIL_OUT, "05_availability_prefit_rank_separation.csv"))
fwrite(bind_rows(zero_cell_tables), file.path(AVAIL_OUT, "06_availability_factor_zero_cells.csv"))
fwrite(bind_rows(coefficient_tables), file.path(AVAIL_OUT, "07_availability_model_coefficients.csv"))
fwrite(bind_rows(weight_diagnostics), file.path(AVAIL_OUT, "08_weight_diagnostics.csv"))
fwrite(bind_rows(balance_tables), file.path(AVAIL_OUT, "09_weight_balance_SMD.csv"))
fwrite(bind_rows(transform_tables), file.path(AVAIL_OUT, "10_frozen_transform_constants.csv"))

hallmark <- gmtPathways(INPUT$hallmark)
names(hallmark) <- str_remove(names(hallmark), "^HALLMARK_")
unweighted_d5 <- fread(file.path(RNA_OUT, "03_RNA_TMM_Hallmark_primary_PHpass.csv"), data.table = FALSE) |>
  filter(Time == "D5", analysis == "Primary") |>
  mutate(pathway = str_remove(pathway, "^HALLMARK_"))

scenario_table <- tribble(
  ~scenario, ~entry_name, ~spec, ~run_ph,
  "entry4_SOFA_D3", "primary", "SOFA_D3", TRUE,
  "entry4_SOFA_noD3", "primary", "SOFA_noD3", FALSE,
  "entry4_PF_PLT_D3", "primary", "PF_PLT_D3", FALSE,
  "entry4_PF_PLT_noD3", "primary", "PF_PLT_noD3", FALSE,
  "entry3.75_SOFA_D3", "lower", "SOFA_D3", FALSE,
  "entry4.25_SOFA_D3", "upper", "SOFA_D3", FALSE
)

make_metadata <- function(obj, entry_value) {
  d5_map <- clinical |>
    filter(day_num == 5L, SampleName %in% colnames(logcpm)) |>
    select(PatientID, D5_SampleName = SampleName) |>
    distinct(PatientID, .keep_all = TRUE)
  obj$data |>
    filter(available == 1L) |>
    select(-SampleName) |>
    left_join(d5_map, by = "PatientID") |>
    transmute(
      PatientID, SampleName = D5_SampleName, entry = as.numeric(entry_value),
      stop, event, center = droplevels(factor(center)), analysis_weight
    ) |>
    filter(stop > entry)
}

message("[5/7] Running delayed-entry weighted gene-wise Cox models")
cox_results <- list(); gsea_results <- list(); comparisons <- list(); comparison_metrics <- list()
for (i in seq_len(nrow(scenario_table))) {
  sc <- scenario_table[i, ]
  key <- paste0(sc$entry_name, "__", sc$spec)
  obj <- weight_objects[[key]]
  md <- make_metadata(obj, AVAIL_ENTRY[[sc$entry_name]])
  stopifnot(!anyNA(md$SampleName), all(md$SampleName %in% colnames(logcpm)))
  cox_path <- file.path(AVAIL_OUT, paste0("11_Cox_", sc$scenario, ".csv"))
  if (file.exists(cox_path)) {
    checkpoint <- fread(cox_path, data.table = FALSE)
    checkpoint_ok <- nrow(checkpoint) == nrow(logcpm) &&
      all(c("fit_valid", "z") %in% names(checkpoint)) &&
      any(checkpoint$fit_valid %in% TRUE) && any(is.finite(checkpoint$z))
    if (checkpoint_ok) {
      message("  Reusing validated checkpoint: ", sc$scenario)
      cox <- checkpoint
    } else {
      message("  Invalid checkpoint detected; refitting: ", sc$scenario)
      cox <- run_weighted_cox_matrix(logcpm, md, run_ph = isTRUE(sc$run_ph), workers = 3L)
      fwrite(cox, cox_path)
    }
  } else {
    message("  Cox scenario ", i, "/", nrow(scenario_table), ": ", sc$scenario,
            " (N=", nrow(md), ", events=", sum(md$event), ")")
    cox <- run_weighted_cox_matrix(logcpm, md, run_ph = isTRUE(sc$run_ph), workers = 3L)
    fwrite(cox, cox_path)
  }
  cox$scenario <- sc$scenario
  cox_results[[sc$scenario]] <- cox
  gsea <- run_weighted_gsea(cox, hallmark, paste0(sc$scenario, "__all_valid"))
  fwrite(gsea |> select(-leadingEdge), file.path(AVAIL_OUT, paste0("12_GSEA_", sc$scenario, "_all_valid.csv")))
  gsea_results[[paste0(sc$scenario, "__all_valid")]] <- gsea
  if (isTRUE(sc$run_ph)) {
    ph_cox <- cox |> mutate(fit_valid = fit_valid & PH_success & PH_p >= .05)
    ph_gsea <- run_weighted_gsea(ph_cox, hallmark, paste0(sc$scenario, "__PH_pass"))
    fwrite(ph_gsea |> select(-leadingEdge), file.path(AVAIL_OUT, paste0("12_GSEA_", sc$scenario, "_PH_pass.csv")))
    gsea_results[[paste0(sc$scenario, "__PH_pass")]] <- ph_gsea
  }
  cmp <- compare_hallmark_all(unweighted_d5, gsea)
  cmp$scenario <- sc$scenario
  comparisons[[sc$scenario]] <- cmp
  comparison_metrics[[sc$scenario]] <- attr(cmp, "metrics") |> mutate(scenario = sc$scenario, .before = 1)
}

all_cox_diag <- bind_rows(lapply(names(cox_results), function(nm) {
  d <- cox_results[[nm]]
  tibble(
    scenario = nm, genes_total = nrow(d), genes_converged = sum(d$converged, na.rm = TRUE),
    nonfinite_beta = sum(!d$finite_beta, na.rm = TRUE),
    nonfinite_robust_SE = sum(!d$finite_robust_SE, na.rm = TRUE),
    genes_entering_GSEA = sum(d$fit_valid, na.rm = TRUE),
    PH_attempted = sum(d$PH_attempted, na.rm = TRUE),
    PH_success = sum(d$PH_success, na.rm = TRUE),
    PH_pass = sum(d$PH_success & d$PH_p >= .05, na.rm = TRUE)
  )
}))
fwrite(all_cox_diag, file.path(AVAIL_OUT, "13_Cox_convergence_finite_PH_summary.csv"))

all_gsea_export <- bind_rows(gsea_results) |> select(-leadingEdge)
fwrite(all_gsea_export, file.path(AVAIL_OUT, "14_all_weighted_Hallmark_results.csv"))
leading_edge <- bind_rows(lapply(gsea_results, function(x) x |> select(pathway, analysis, leadingEdge_text))) |>
  separate_rows(leadingEdge_text, sep = ";") |>
  rename(gene_symbol = leadingEdge_text) |>
  filter(gene_symbol != "")
fwrite(leading_edge, file.path(AVAIL_OUT, "15_all_weighted_Hallmark_leading_edges.csv"))
all_comparisons <- bind_rows(comparisons)
fwrite(all_comparisons, file.path(AVAIL_OUT, "16_all_Hallmark_unweighted_vs_IPW.csv"))
fwrite(bind_rows(comparison_metrics), file.path(AVAIL_OUT, "17_all_Hallmark_comparison_metrics.csv"))

message("[6/7] Creating aggregate diagnostic and robustness figures")
bal <- bind_rows(balance_tables)
p_smd <- ggplot(bal |> filter(entry_name == "primary"),
                aes(x = SMD_before, xend = SMD_after, y = reorder(variable, abs(SMD_before)), color = spec)) +
  geom_segment(alpha = .55) + geom_point(aes(x = SMD_after), size = 1.8) +
  geom_vline(xintercept = c(-.1, .1), linetype = 2, color = "grey45") +
  facet_wrap(~spec, ncol = 2) + theme_bw(base_size = 9) +
  labs(x = "Standardized mean difference", y = NULL, title = "D5 RNA availability weighting balance") +
  theme(legend.position = "none")
ggsave(file.path(AVAIL_OUT, "Figure_A_weight_balance_SMD.pdf"), p_smd, width = 9, height = 8)
ggsave(file.path(AVAIL_OUT, "Figure_A_weight_balance_SMD.png"), p_smd, width = 9, height = 8, dpi = 400)

weight_plot_data <- bind_rows(lapply(names(weight_objects), function(key) {
  weight_objects[[key]]$data |>
    filter(available == 1L) |>
    transmute(scenario = key, analysis_weight)
}))
p_w <- ggplot(weight_plot_data, aes(x = analysis_weight)) +
  geom_histogram(bins = 40, fill = "#4472C4", color = "white") +
  facet_wrap(~scenario, scales = "free_y") + theme_bw(base_size = 9) +
  labs(x = "Mean-normalized truncated inverse-observation weight", y = "Observed D5 RNA patients")
ggsave(file.path(AVAIL_OUT, "Figure_B_weight_distributions.pdf"), p_w, width = 9, height = 6)
ggsave(file.path(AVAIL_OUT, "Figure_B_weight_distributions.png"), p_w, width = 9, height = 6, dpi = 400)

primary_cmp <- comparisons$entry4_SOFA_D3
p_cmp <- ggplot(primary_cmp, aes(NES_unweighted, NES_weighted, color = FDR_class)) +
  geom_hline(yintercept = 0, color = "grey80") + geom_vline(xintercept = 0, color = "grey80") +
  geom_abline(slope = 1, intercept = 0, linetype = 2) + geom_point(size = 2, alpha = .85) +
  scale_color_manual(values = c(both = "#B2182B", unweighted_only = "#EF8A62", IPW_only = "#2166AC", neither = "grey65")) +
  coord_equal() + theme_bw(base_size = 10) +
  labs(x = "Unweighted center-stratified NES", y = "IPW center-stratified NES",
       color = "FDR < 0.05", title = "All Hallmark pathways: unweighted versus primary IPW")
ggsave(file.path(AVAIL_OUT, "Figure_C_all_Hallmark_unweighted_vs_IPW.pdf"), p_cmp, width = 6.5, height = 6)
ggsave(file.path(AVAIL_OUT, "Figure_C_all_Hallmark_unweighted_vs_IPW.png"), p_cmp, width = 6.5, height = 6, dpi = 400)

core <- c("HEME_METABOLISM", "HYPOXIA", "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING",
          "INFLAMMATORY_RESPONSE", "COAGULATION", "COMPLEMENT", "REACTIVE_OXYGEN_SPECIES_PATHWAY",
          "OXIDATIVE_PHOSPHORYLATION", "MYC_TARGETS_V1", "UNFOLDED_PROTEIN_RESPONSE",
          "DNA_REPAIR", "E2F_TARGETS", "MTORC1_SIGNALING")
heat <- all_gsea_export |>
  filter(pathway %in% core, grepl("all_valid$", analysis)) |>
  mutate(pathway = factor(pathway, levels = rev(core)))
p_heat <- ggplot(heat, aes(analysis, pathway, fill = NES)) +
  geom_tile(color = "white") + geom_text(aes(label = sprintf("%.2f", NES)), size = 2.5) +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0) +
  theme_bw(base_size = 8) + theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(x = NULL, y = NULL, fill = "NES", title = "Core-pathway robustness across prespecified IPW analyses")
ggsave(file.path(AVAIL_OUT, "Figure_D_core_pathway_robustness_heatmap.pdf"), p_heat, width = 10, height = 6.5)
ggsave(file.path(AVAIL_OUT, "Figure_D_core_pathway_robustness_heatmap.png"), p_heat, width = 10, height = 6.5, dpi = 400)

message("[7/7] Writing QA, interpretation, and session files")
wd <- bind_rows(weight_diagnostics)
qa <- tibble(
  check = c(
    "source_N_504", "entry4_support_N_487", "entry4_observed_N_320", "entry4_events_53",
    "zero_all_partial_centres_3_13_14", "availability_missingness_zero",
    "protein_D3_D5_nested", "all_entry4_models_full_rank", "all_entry4_models_no_separation",
    "all_observation_centres_probability_weight_one", "all_analysis_weights_mean_one",
    "all_Cox_scenarios_produced", "all_GSEA_scenarios_produced"
  ),
  passed = c(
    entry_counts$source_N[entry_counts$entry_name == "primary"] == 504,
    entry_counts$support_N[entry_counts$entry_name == "primary"] == 487,
    entry_counts$observed_N[entry_counts$entry_name == "primary"] == 320,
    entry_counts$observed_events[entry_counts$entry_name == "primary"] == 53,
    identical(as.integer(table(entry_audits$primary$centres$class)[c("zero", "all", "partial")]), c(3L,13L,14L)),
    sum(missingness$missing_N) == 0,
    protein_nesting$D3_not_D1 == 0 && protein_nesting$D5_not_D1 == 0 && protein_nesting$D5_not_D3 == 0,
    !any(bind_rows(prefit_tables)$rank_deficient), !any(bind_rows(prefit_tables)$separation),
    all(vapply(weight_objects, function(x) all(x$data$raw_probability[x$data$centre_class == "all"] == 1 &
                                                x$data$raw_weight[x$data$centre_class == "all" & x$data$available == 1] == 1), logical(1))),
    all(abs(wd$analysis_weight_mean - 1) < 1e-10), nrow(all_cox_diag) == 6,
    length(gsea_results) == 7
  )
)
fwrite(qa, file.path(AVAIL_OUT, "18_final_QA.csv"))
if (!all(qa$passed)) stop("Final availability/IPW QA failed; inspect 18_final_QA.csv")

primary_diag <- wd |> filter(entry_name == "primary", spec == "SOFA_D3") |> slice(1)
classification <- if (any(c(primary_diag$caution_min_p, primary_diag$caution_max_raw_weight,
                            primary_diag$caution_ESS, primary_diag$caution_balance))) "caution" else "adequate"
readme <- c(
  "# Day 5 RNA availability/IPW sensitivity analysis",
  "",
  paste0("Primary diagnostic classification: **", classification, "**."),
  "",
  "The estimand comprises Day-5 landmark survivors from centres with empirical D5 RNA positivity support.",
  "Deaths at or before the landmark are structural non-availability and are not restored by IPW.",
  "The primary model is SOFA_D3 and is never replaced post hoc by a sensitivity model.",
  "Poor diagnostics are reported using the frozen thresholds and do not trigger model modification.",
  "Because survival::coxph requires cluster/id for robust=TRUE with delayed-entry Surv data, the model is fitted without id and the observation-level Lin-Wei sandwich SE is calculated directly from weighted dfbeta residuals; numerical equivalence to a unique-row cluster was verified.",
  "",
  paste0("Primary minimum predicted probability: ", signif(primary_diag$min_probability, 4)),
  paste0("Primary maximum raw weight: ", signif(primary_diag$max_raw_weight, 4)),
  paste0("Primary ESS / observed N: ", signif(primary_diag$ESS_ratio, 4)),
  paste0("Primary maximum post-weight |SMD|: ", signif(primary_diag$max_abs_SMD_after, 4)),
  "",
  "surv_time is treated as the nominal Day-1 study-time origin because exact sample timestamps are unavailable.",
  "Participant-level weights are retained only in controlled_participant_level and must not enter public source-data packages."
)
writeLines(readme, file.path(AVAIL_OUT, "README_CN.md"), useBytes = TRUE)
writeLines(capture.output(sessionInfo()), file.path(AVAIL_OUT, "sessionInfo_Availability_IPW.txt"))
message("Completed: ", AVAIL_OUT)
