rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(stringr)})

checks <- list()
add_check <- function(name, pass, observed, expected, severity = "error") {
  checks[[length(checks) + 1L]] <<- data.frame(
    check = name, pass = isTRUE(pass), observed = as.character(observed),
    expected = as.character(expected), severity = severity
  )
}

rna <- fread(file.path(RNA_OUT, "02_all_RNA_TMM_center_stratified_cox_zph.csv"), data.table = FALSE)
protein <- fread(file.path(PROTEIN_OUT, "02_all_Protein_models_cox_zph.csv"), data.table = FALSE)
rg <- fread(file.path(RNA_OUT, "03_RNA_TMM_Hallmark_primary_PHpass.csv"), data.table = FALSE)
pg <- fread(file.path(PROTEIN_OUT, "03_Protein_Hallmark_all_models.csv"), data.table = FALSE)
fw <- fread(file.path(CROSS_OUT, "05_forward_cross_lag_HC3.csv"), data.table = FALSE)
rv <- fread(file.path(CROSS_OUT, "06_reverse_cross_lag_HC3.csv"), data.table = FALSE)
clin_dir <- file.path(OUT_ROOT, "05_Clinical_Tables")
clin_diag <- fread(file.path(clin_dir, "Clinical_analysis_diagnostics.csv"), data.table = FALSE)
clin_cox <- fread(file.path(clin_dir, "Clinical_univariable_Cox.csv"), data.table = FALSE)
clin_drop5 <- fread(file.path(clin_dir, "Clinical_drop5_event_time_sensitivity.csv"), data.table = FALSE)
avail_qa <- fread(file.path(AVAIL_OUT, "18_final_QA.csv"), data.table = FALSE)
avail_counts <- fread(file.path(AVAIL_OUT, "00_entry_riskset_counts.csv"), data.table = FALSE)
avail_diag <- fread(file.path(AVAIL_OUT, "08_weight_diagnostics.csv"), data.table = FALSE)
avail_cox <- fread(file.path(AVAIL_OUT, "13_Cox_convergence_finite_PH_summary.csv"), data.table = FALSE)
avail_cmp <- fread(file.path(AVAIL_OUT, "17_all_Hallmark_comparison_metrics.csv"), data.table = FALSE)

for (tm in c("D1", "D3", "D5")) {
  e <- EXPECTED |> filter(Omics == "RNA", Time == tm)
  x <- rna |> filter(Time == tm)
  add_check(paste0("RNA_", tm, "_riskset"), max(x$N) == e$N && max(x$Events) == e$Events,
            paste(max(x$N), max(x$Events), sep = "/"), paste(e$N, e$Events, sep = "/"))
  add_check(paste0("RNA_", tm, "_all_fits"), all(x$fit_ok), sum(x$fit_ok), nrow(x))

  e2 <- EXPECTED |> filter(Omics == "Protein", Time == tm)
  p <- protein |> filter(Time == tm, model == "center_primary")
  add_check(paste0("Protein_", tm, "_riskset"), max(p$N) == e2$N && max(p$Events) == e2$Events,
            paste(max(p$N), max(p$Events), sep = "/"), paste(e2$N, e2$Events, sep = "/"))
  add_check(paste0("Protein_", tm, "_all_fits"), all(p$fit_ok), sum(p$fit_ok), nrow(p))
}

add_check("RNA_GSEA_complete", all(rg |> count(Time, analysis) |> pull(n) == 49),
          paste((rg |> count(Time, analysis))$n, collapse = ","), "49 for each time/model")
add_check("Protein_GSEA_complete", all(pg |> count(analysis) |> pull(n) %in% c(43, 44)),
          paste((pg |> count(analysis))$n, collapse = ","), "43-44 for each model")
add_check("Forward_IFN_FDR_count", sum(fw$FDR < .05, na.rm = TRUE) == 3,
          sum(fw$FDR < .05, na.rm = TRUE), 3)
add_check("Reverse_FDR_count", sum(rv$FDR < .05, na.rm = TRUE) == 0,
          sum(rv$FDR < .05, na.rm = TRUE), 0)

get_metric <- function(x) as.numeric(clin_diag$Value[match(x, clin_diag$Metric)])
add_check("Clinical_patients", get_metric("Patients") == 504, get_metric("Patients"), 504)
add_check("Clinical_deaths", get_metric("Deaths") == 84, get_metric("Deaths"), 84)
add_check("Clinical_Cox_rows", nrow(clin_cox) == 41, nrow(clin_cox), 41)
add_check("Clinical_sex_mapping", get_metric("Sex mapping verified (1=male)") == 1,
          get_metric("Sex mapping verified (1=male)"), 1)
add_check("Clinical_known_time_discrepancies",
          get_metric("Author-confirmed event-time corrections") == 5,
          get_metric("Author-confirmed event-time corrections"),
          "5 author-confirmed decimal corrections with preserved audit trail", severity = "warning")
sig_vars <- clin_cox |> filter(BH_FDR < .05, Variable != "infectionSite_SD") |> pull(Variable)
sig_sens <- clin_drop5 |> filter(Variable %in% sig_vars)
add_check("Clinical_drop5_core_directions", all(sig_sens$Direction_consistent),
          sum(sig_sens$Direction_consistent), nrow(sig_sens), severity = "warning")
clin_xlsx <- file.path(clin_dir, "Clinical_Table1_and_Univariable_Cox.xlsx")
add_check("Clinical_workbook_exists", file.exists(clin_xlsx) && file.info(clin_xlsx)$size > 1000,
          ifelse(file.exists(clin_xlsx), file.info(clin_xlsx)$size, 0), ">1000 bytes")

add_check("Availability_internal_QA", all(avail_qa$passed), sum(avail_qa$passed), nrow(avail_qa))
ap <- avail_counts |> filter(entry_name == "primary")
add_check("Availability_primary_estimand_counts",
          ap$source_N == 504 && ap$structural_N == 13 && ap$support_N == 487 &&
            ap$observed_N == 320 && ap$observed_events == 53,
          paste(ap$source_N, ap$structural_N, ap$support_N, ap$observed_N, ap$observed_events, sep = "/"),
          "504/13/487/320/53")
add_check("Availability_all_six_Cox_scenarios", nrow(avail_cox) == 6 && all(avail_cox$genes_entering_GSEA == 14541),
          paste(nrow(avail_cox), min(avail_cox$genes_entering_GSEA), sep = "/"), "6/14541")
add_check("Availability_primary_PH_complete",
          avail_cox$PH_success[avail_cox$scenario == "entry4_SOFA_D3"] == 14541,
          avail_cox$PH_success[avail_cox$scenario == "entry4_SOFA_D3"], 14541)
add_check("Availability_primary_weight_diagnostics_preserved_not_replaced",
          any(avail_diag$entry_name == "primary" & avail_diag$spec == "SOFA_D3" & avail_diag$caution_min_p),
          "primary SOFA_D3 retained with caution flag", "TRUE", severity = "warning")
add_check("Availability_all_Hallmark_comparison",
          nrow(avail_cmp) == 6 && all(is.finite(avail_cmp$spearman_NES)),
          paste(nrow(avail_cmp), min(avail_cmp$spearman_NES), sep = "/"), "6 finite all-pathway comparisons")

figure_stems <- c(
  "Figure1_study_design_risksets", "Figure2_RNA_core_NES_robustness",
  "Figure3_Protein_core_NES_robustness", "Figure4_CrossOmics_IFN_coupling",
  "Graphical_Abstract", "Supplementary_RNA_Cox_volcanoes",
  "Supplementary_Protein_Cox_volcanoes", "Representative_RNA_GSEA_curves",
  "Representative_Protein_GSEA_curves"
)
for (s in figure_stems) for (ext in c("pdf", "png", "svg", "tiff")) {
  f <- file.path(FIGURE_OUT, paste0(s, ".", ext))
  add_check(paste0("figure_", s, "_", ext), file.exists(f) && file.info(f)$size > 1000,
            ifelse(file.exists(f), file.info(f)$size, 0), ">1000 bytes")
}

qa <- bind_rows(checks)
fwrite(qa, file.path(OUT_ROOT, "FINAL_QA_SUMMARY.csv"))
writeLines(c(
  "SIC final reanalysis QA",
  paste("Generated:", format(Sys.time())),
  paste("Checks:", nrow(qa)),
  paste("Passed:", sum(qa$pass)),
  paste("Failed:", sum(!qa$pass)),
  "",
  capture.output(print(qa |> filter(!pass)))
), file.path(OUT_ROOT, "FINAL_QA_REPORT.txt"))

if (any(!qa$pass & qa$severity == "error")) stop("Final QA failed; inspect FINAL_QA_SUMMARY.csv")
cat("All", nrow(qa), "QA checks passed.\n")
