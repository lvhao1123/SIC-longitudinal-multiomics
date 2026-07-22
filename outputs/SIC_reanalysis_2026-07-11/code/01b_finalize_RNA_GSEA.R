rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(stringr); library(tibble); library(fgsea); library(tidyr)})

cox_list <- setNames(lapply(c("D1", "D3", "D5"), function(tm) {
  fread(file.path(RNA_OUT, paste0("01_", tm, "_TMM_center_stratified_cox_zph.csv")), data.table = FALSE)
}), c("D1", "D3", "D5"))
cox_all <- bind_rows(cox_list)

hallmark <- gmtPathways(INPUT$hallmark)
names(hallmark) <- str_remove(names(hallmark), "^HALLMARK_")

run_one <- function(tbl, analysis) {
  ztbl <- tbl |> filter(fit_ok, is.finite(z), gene_symbol != "")
  if (analysis == "PH_pass") ztbl <- ztbl |> filter(PH_pass_nominal)
  ranks <- ztbl$z; names(ranks) <- ztbl$gene_symbol; ranks <- sort(ranks, decreasing = TRUE)
  set.seed(20260711)
  fgseaMultilevel(
    pathways = hallmark, stats = ranks, sampleSize = 1001, nPermSimple = 10000,
    minSize = 15, maxSize = 500, eps = 0, scoreType = "std", nproc = 1
  ) |> as_tibble() |> mutate(analysis = analysis, ranked_features = length(ranks))
}

gsea <- bind_rows(lapply(names(cox_list), function(tm) {
  bind_rows(run_one(cox_list[[tm]], "Primary"), run_one(cox_list[[tm]], "PH_pass")) |>
    mutate(Time = tm)
})) |>
  mutate(pathway = str_remove(pathway, "^HALLMARK_"))

na_idx <- which(!is.finite(gsea$NES) | !is.finite(gsea$pval))
if (length(na_idx)) {
  for (i in na_idx) {
    tm <- gsea$Time[i]; analysis <- gsea$analysis[i]; target <- gsea$pathway[i]
    ztbl <- cox_list[[tm]] |> filter(fit_ok, is.finite(z), gene_symbol != "")
    if (analysis == "PH_pass") ztbl <- ztbl |> filter(PH_pass_nominal)
    ranks <- ztbl$z; names(ranks) <- ztbl$gene_symbol; ranks <- sort(ranks, decreasing = TRUE)
    set.seed(20260711)
    hi <- fgseaMultilevel(
      pathways = hallmark[target], stats = ranks, sampleSize = 5001, nPermSimple = 100000,
      minSize = 15, maxSize = 500, eps = 0, scoreType = "std", nproc = 1
    ) |> as_tibble()
    if (nrow(hi) && is.finite(hi$NES[1]) && is.finite(hi$pval[1])) {
      for (nm in intersect(c("ES", "NES", "pval", "log2err", "size"), names(hi))) gsea[[nm]][i] <- hi[[nm]][1]
      gsea$leadingEdge[[i]] <- hi$leadingEdge[[1]]
    }
  }
}
gsea <- gsea |> group_by(Time, analysis) |> mutate(padj = p.adjust(pval, "BH")) |> ungroup() |>
  mutate(
    direction = if_else(NES > 0, "positive mortality association", "negative mortality association"),
    leadingEdge_text = vapply(leadingEdge, paste, collapse = ";", FUN.VALUE = character(1))
  )

fwrite(gsea |> select(-leadingEdge), file.path(RNA_OUT, "03_RNA_TMM_Hallmark_primary_PHpass.csv"))
leading <- gsea |> select(Time, analysis, pathway, NES, padj, leadingEdge) |>
  unnest_longer(leadingEdge, values_to = "gene_symbol")
fwrite(leading, file.path(RNA_OUT, "04_RNA_TMM_Hallmark_leading_edge_long.csv"))

diagnostics <- cox_all |> group_by(Time) |> summarise(
  N = max(N), Events = max(Events), genes_attempted = n(), fits_ok = sum(fit_ok),
  gene_FDR05 = sum(padj < .05, na.rm = TRUE), nominal_PH_fail = sum(PH_p < .05, na.rm = TRUE),
  PH_FDR05 = sum(PH_FDR < .05, na.rm = TRUE), .groups = "drop"
)
gsea_diag <- gsea |> group_by(Time, analysis) |> summarise(
  estimable = sum(is.finite(NES) & is.finite(pval)), FDR05 = sum(padj < .05, na.rm = TRUE), .groups = "drop"
)
fwrite(diagnostics, file.path(RNA_OUT, "05_RNA_TMM_Cox_diagnostics.csv"))
fwrite(gsea_diag, file.path(RNA_OUT, "05_RNA_TMM_GSEA_diagnostics.csv"))
saveRDS(list(cox = cox_list, gsea = gsea), file.path(RNA_OUT, "RNA_TMM_final_results.rds"), compress = FALSE)
writeLines(capture.output(sessionInfo()), file.path(RNA_OUT, "sessionInfo_RNA.txt"))
print(diagnostics); print(gsea_diag)
