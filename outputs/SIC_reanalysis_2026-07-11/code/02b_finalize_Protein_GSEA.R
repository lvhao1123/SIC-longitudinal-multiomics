rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(stringr); library(tibble); library(fgsea); library(tidyr)})

all_cox <- fread(file.path(PROTEIN_OUT, "02_all_Protein_models_cox_zph.csv"), data.table = FALSE)
hallmark <- gmtPathways(INPUT$hallmark)
names(hallmark) <- str_remove(names(hallmark), "^HALLMARK_")

run_gsea <- function(tbl, analysis) {
  ranks <- tbl$z; names(ranks) <- tbl$gene_symbol
  ranks <- sort(ranks[is.finite(ranks) & tbl$fit_ok], decreasing = TRUE)
  set.seed(20260711)
  fgseaMultilevel(
    pathways = hallmark, stats = ranks, sampleSize = 1001, nPermSimple = 10000,
    minSize = 15, maxSize = 500, eps = 0, scoreType = "std", nproc = 1
  ) |> as_tibble() |> mutate(
    analysis = analysis, ranked_features = length(ranks),
    leadingEdge_text = vapply(leadingEdge, paste, collapse = ";", FUN.VALUE = character(1))
  )
}

gsea <- list()
for (tm in c("D1", "D3", "D5")) {
  p <- all_cox |> filter(Time == tm, model == "center_primary", fit_ok)
  m <- all_cox |> filter(Time == tm, model == "median_center_sensitivity", fit_ok)
  gsea[[paste0(tm, "_primary")]] <- run_gsea(p, paste0(tm, "_center_primary"))
  gsea[[paste0(tm, "_PH")]] <- run_gsea(p |> filter(PH_pass_nominal), paste0(tm, "_center_primary_PHpass"))
  gsea[[paste0(tm, "_median")]] <- run_gsea(m, paste0(tm, "_median_center_sensitivity"))
}
gsea <- bind_rows(gsea) |> mutate(
  pathway = str_remove(pathway, "^HALLMARK_"),
  direction = if_else(NES > 0, "positive mortality association", "negative mortality association")
)
fwrite(gsea |> select(-leadingEdge), file.path(PROTEIN_OUT, "03_Protein_Hallmark_all_models.csv"))
leading <- gsea |> select(analysis, pathway, NES, padj, leadingEdge) |>
  unnest_longer(leadingEdge, values_to = "gene_symbol")
fwrite(leading, file.path(PROTEIN_OUT, "04_Protein_Hallmark_leading_edge_long.csv"))

diagnostics <- all_cox |> group_by(Time, model) |> summarise(
  N = max(N), Events = max(Events), features = n(), fits_ok = sum(fit_ok),
  positive_z_fraction = mean(z > 0, na.rm = TRUE), feature_FDR05 = sum(padj < .05, na.rm = TRUE),
  nominal_PH_fail = sum(PH_p < .05, na.rm = TRUE), PH_FDR05 = sum(PH_FDR < .05, na.rm = TRUE), .groups = "drop"
)
gsea_diag <- gsea |> group_by(analysis) |> summarise(
  estimable = sum(is.finite(NES) & is.finite(pval)), FDR05 = sum(padj < .05, na.rm = TRUE), .groups = "drop"
)
fwrite(diagnostics, file.path(PROTEIN_OUT, "05_Protein_model_diagnostics.csv"))
fwrite(gsea_diag, file.path(PROTEIN_OUT, "05_Protein_GSEA_diagnostics.csv"))
saveRDS(list(cox = all_cox, gsea = gsea), file.path(PROTEIN_OUT, "Protein_final_results.rds"), compress = FALSE)
writeLines(capture.output(sessionInfo()), file.path(PROTEIN_OUT, "sessionInfo_Protein.txt"))
print(diagnostics); print(gsea_diag)
