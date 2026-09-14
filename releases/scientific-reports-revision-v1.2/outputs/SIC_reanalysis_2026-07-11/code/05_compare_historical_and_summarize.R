rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(stringr); library(tidyr)})

old_rna_dir <- file.path(SOURCE_DIR, "FINAL_RNA_center_stratified_analysis")
old_rna_gsea_file <- file.path(SOURCE_DIR, "FINAL_RNA_Figure2_publication", "02_RNA_fgsea_FINAL_completed.csv")
old_protein_dir <- file.path(SOURCE_DIR, "FINAL_center_stratified_protein_analysis")

new_rna <- fread(file.path(RNA_OUT, "02_all_RNA_TMM_center_stratified_cox_zph.csv"), data.table = FALSE)
new_rna_gsea <- fread(file.path(RNA_OUT, "03_RNA_TMM_Hallmark_primary_PHpass.csv"), data.table = FALSE)
new_protein <- fread(file.path(PROTEIN_OUT, "02_all_Protein_models_cox_zph.csv"), data.table = FALSE)
new_protein_gsea <- fread(file.path(PROTEIN_OUT, "03_Protein_Hallmark_all_models.csv"), data.table = FALSE)

rna_cmp <- bind_rows(lapply(c("D1", "D3", "D5"), function(tm) {
  old <- fread(file.path(old_rna_dir, paste0("01_", tm, "_center_stratified_cox_zph.csv")), data.table = FALSE)
  new <- new_rna |> filter(Time == tm)
  m <- inner_join(old |> select(gene_symbol, old_z = z), new |> select(gene_symbol, new_z = z), by = "gene_symbol")
  tibble(
    Time = tm, common_features = nrow(m),
    spearman_z = cor(m$old_z, m$new_z, method = "spearman", use = "complete.obs"),
    pearson_z = cor(m$old_z, m$new_z, method = "pearson", use = "complete.obs"),
    direction_agreement = mean(sign(m$old_z) == sign(m$new_z), na.rm = TRUE)
  )
}))

old_rg <- fread(old_rna_gsea_file, data.table = FALSE) |>
  mutate(
    Time = str_extract(analysis, "^D[135]"),
    new_analysis = if_else(str_detect(analysis, "PHpass"), "PH_pass", "Primary")
  )
rna_gsea_cmp <- inner_join(
  old_rg |> select(Time, analysis = new_analysis, pathway, old_NES = NES),
  new_rna_gsea |> select(Time, analysis, pathway, new_NES = NES),
  by = c("Time", "analysis", "pathway")
) |>
  group_by(Time, analysis) |>
  summarise(
    common_pathways = n(), spearman_NES = cor(old_NES, new_NES, method = "spearman", use = "complete.obs"),
    direction_agreement = mean(sign(old_NES) == sign(new_NES), na.rm = TRUE), .groups = "drop"
  )

protein_cmp <- bind_rows(lapply(c("D1", "D3", "D5"), function(tm) {
  old <- fread(file.path(old_protein_dir, paste0("01_", tm, "_center_stratified_primary_cox_zph.csv")), data.table = FALSE)
  new <- new_protein |> filter(Time == tm, model == "center_primary")
  m <- inner_join(old |> select(gene_symbol, old_z = z), new |> select(gene_symbol, new_z = z), by = "gene_symbol")
  tibble(
    Time = tm, common_features = nrow(m),
    spearman_z = cor(m$old_z, m$new_z, method = "spearman", use = "complete.obs"),
    pearson_z = cor(m$old_z, m$new_z, method = "pearson", use = "complete.obs"),
    direction_agreement = mean(sign(m$old_z) == sign(m$new_z), na.rm = TRUE)
  )
}))

old_pg <- fread(file.path(old_protein_dir, "03_fgseaMultilevel_center_primary_PH_and_intensity_sensitivity.csv"), data.table = FALSE)
protein_gsea_cmp <- inner_join(
  old_pg |> select(analysis, pathway, old_NES = NES),
  new_protein_gsea |> select(analysis, pathway, new_NES = NES),
  by = c("analysis", "pathway")
) |>
  group_by(analysis) |>
  summarise(
    common_pathways = n(), spearman_NES = cor(old_NES, new_NES, method = "spearman", use = "complete.obs"),
    direction_agreement = mean(sign(old_NES) == sign(new_NES), na.rm = TRUE), .groups = "drop"
  )

fwrite(rna_cmp, file.path(AUDIT_DIR, "RNA_TMM_vs_previous_feature_rank_comparison.csv"))
fwrite(rna_gsea_cmp, file.path(AUDIT_DIR, "RNA_TMM_vs_previous_pathway_comparison.csv"))
fwrite(protein_cmp, file.path(AUDIT_DIR, "Protein_newQC_vs_previous_feature_rank_comparison.csv"))
fwrite(protein_gsea_cmp, file.path(AUDIT_DIR, "Protein_newQC_vs_previous_pathway_comparison.csv"))

top_gsea <- function(x, analysis_col, primary_regex) x |>
  filter(str_detect(.data[[analysis_col]], primary_regex), padj < .05) |>
  arrange(.data[[analysis_col]], padj, desc(abs(NES))) |>
  group_by(.data[[analysis_col]]) |>
  slice_head(n = 15) |>
  ungroup()
rna_top <- new_rna_gsea |> filter(analysis == "Primary", padj < .05) |>
  arrange(Time, padj, desc(abs(NES))) |> group_by(Time) |> slice_head(n = 15) |> ungroup()
fwrite(rna_top, file.path(AUDIT_DIR, "RNA_primary_top_Hallmark.csv"))
fwrite(top_gsea(new_protein_gsea, "analysis", "center_primary$"), file.path(AUDIT_DIR, "Protein_primary_top_Hallmark.csv"))

cat("RNA feature comparison\n"); print(rna_cmp)
cat("RNA pathway comparison\n"); print(rna_gsea_cmp)
cat("Protein feature comparison\n"); print(protein_cmp)
cat("Protein pathway comparison\n"); print(protein_gsea_cmp)
