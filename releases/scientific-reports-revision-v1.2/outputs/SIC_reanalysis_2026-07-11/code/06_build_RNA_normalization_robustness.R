rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(stringr); library(tidyr)})

new <- fread(file.path(RNA_OUT, "03_RNA_TMM_Hallmark_primary_PHpass.csv"), data.table = FALSE) |>
  select(Time, pathway, analysis, NES, padj) |>
  pivot_wider(names_from = analysis, values_from = c(NES, padj), names_prefix = "TMM_")

old <- fread(file.path(SOURCE_DIR, "FINAL_RNA_Figure2_publication", "02_RNA_fgsea_FINAL_completed.csv"), data.table = FALSE) |>
  mutate(
    Time = str_extract(analysis, "^D[135]"),
    analysis2 = if_else(str_detect(analysis, "PHpass"), "PH_pass", "Primary")
  ) |>
  select(Time, pathway, analysis = analysis2, NES, padj) |>
  pivot_wider(names_from = analysis, values_from = c(NES, padj), names_prefix = "simple_logCPM_")

z <- full_join(new, old, by = c("Time", "pathway")) |>
  mutate(
    TMM_both = padj_TMM_Primary < .05 & padj_TMM_PH_pass < .05 & sign(NES_TMM_Primary) == sign(NES_TMM_PH_pass),
    simple_both = padj_simple_logCPM_Primary < .05 & padj_simple_logCPM_PH_pass < .05 &
      sign(NES_simple_logCPM_Primary) == sign(NES_simple_logCPM_PH_pass),
    normalization_direction_same = sign(NES_TMM_Primary) == sign(NES_simple_logCPM_Primary),
    evidence_tier = case_when(
      TMM_both & simple_both & normalization_direction_same ~ "Tier 1: PH- and normalization-robust",
      TMM_both & normalization_direction_same ~ "Tier 2: TMM robust, simple-logCPM attenuated",
      simple_both & normalization_direction_same ~ "Tier 2: simple-logCPM robust, TMM attenuated",
      TMM_both | simple_both ~ "Tier 3: normalization-sensitive",
      TRUE ~ "Not robust"
    )
  ) |>
  arrange(Time, factor(evidence_tier, levels = c(
    "Tier 1: PH- and normalization-robust",
    "Tier 2: TMM robust, simple-logCPM attenuated",
    "Tier 2: simple-logCPM robust, TMM attenuated",
    "Tier 3: normalization-sensitive", "Not robust"
  )), padj_TMM_Primary)

fwrite(z, file.path(AUDIT_DIR, "RNA_Hallmark_normalization_PH_robustness.csv"))
fwrite(z |> count(Time, evidence_tier), file.path(AUDIT_DIR, "RNA_Hallmark_normalization_PH_robustness_counts.csv"))
