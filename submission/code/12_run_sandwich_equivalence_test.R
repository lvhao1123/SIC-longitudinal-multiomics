rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(survival); library(digest)})

CLOSEOUT <- file.path(PROJECT_DIR, "submission")
VALIDATION <- file.path(CLOSEOUT, "validation")
dir.create(VALIDATION, recursive = TRUE, showWarnings = FALSE)
tolerance <- 1e-10

formal_files <- c(
  file.path(AVAIL_OUT, "11_Cox_entry4_SOFA_D3.csv"),
  file.path(AVAIL_OUT, "08_weight_diagnostics.csv"),
  file.path(AVAIL_OUT, "14_all_weighted_Hallmark_results.csv")
)
formal_hash_before <- vapply(formal_files, digest::digest, character(1), file = TRUE, algo = "sha256", serialize = FALSE)

expr <- readRDS(file.path(RNA_OUT, "RNA_TMM_logCPM_gene_by_sample.rds"))
clinical <- fread(INPUT$clinical, data.table = FALSE) |>
  mutate(day_num = as.integer(day_num), stop = as.numeric(surv_time), event = as.integer(sTatus))
weights <- fread(file.path(AVAIL_OUT, "controlled_participant_level/weights_entry4_SOFA_D3_controlled.csv"), data.table = FALSE) |>
  filter(available == 1L)
d5_map <- clinical |>
  filter(day_num == 5L, SampleName %in% colnames(expr)) |>
  select(PatientID, SampleName) |>
  distinct(PatientID, .keep_all = TRUE)
meta <- weights |>
  left_join(clinical |> filter(day_num == 1L) |> select(PatientID, stop, event), by = "PatientID") |>
  left_join(d5_map, by = "PatientID") |>
  filter(stop > 4) |>
  transmute(SampleName, entry = 4, stop, event, center = factor(center), analysis_weight, rowid = seq_len(n()))
stopifnot(nrow(meta) > 0L, !anyNA(meta), all(meta$SampleName %in% colnames(expr)))

representatives <- c("ALAS2", "KLF1", "GATA1", "STAT1", "NDUFS1", "HSPA5", "E2F1", "MTOR")
genes <- unique(c(head(rownames(expr), 20L), representatives[representatives %in% rownames(expr)]))

fit_one <- function(gene) {
  d <- meta
  d$gene_z <- as.numeric(scale(expr[gene, meta$SampleName]))
  manual_fit <- coxph(
    Surv(entry, stop, event) ~ gene_z + strata(center), data = d,
    weights = analysis_weight, ties = "efron", robust = FALSE, x = TRUE, y = TRUE,
    control = coxph.control(iter.max = 50, eps = 1e-9)
  )
  beta_manual <- unname(coef(manual_fit)["gene_z"])
  dfbeta <- residuals(manual_fit, type = "dfbeta", weighted = TRUE)
  se_manual <- sqrt(sum(as.numeric(dfbeta)^2))
  z_manual <- beta_manual / se_manual
  p_manual <- 2 * pnorm(-abs(z_manual))

  cluster_fit <- coxph(
    Surv(entry, stop, event) ~ gene_z + strata(center) + cluster(rowid), data = d,
    weights = analysis_weight, ties = "efron", robust = TRUE, x = TRUE, y = TRUE,
    control = coxph.control(iter.max = 50, eps = 1e-9)
  )
  sm <- summary(cluster_fit)$coefficients
  beta_cluster <- unname(sm["gene_z", "coef"])
  se_cluster <- unname(sm["gene_z", "robust se"])
  z_cluster <- beta_cluster / se_cluster
  p_cluster <- 2 * pnorm(-abs(z_cluster))

  data.table(
    gene_symbol = gene,
    beta_manual = beta_manual, beta_unique_cluster = beta_cluster,
    robust_SE_manual = se_manual, robust_SE_unique_cluster = se_cluster,
    Wald_z_manual = z_manual, Wald_z_unique_cluster = z_cluster,
    p_manual = p_manual, p_unique_cluster = p_cluster,
    abs_diff_beta = abs(beta_manual - beta_cluster),
    abs_diff_robust_SE = abs(se_manual - se_cluster),
    abs_diff_Wald_z = abs(z_manual - z_cluster),
    abs_diff_p = abs(p_manual - p_cluster)
  )
}

result <- rbindlist(lapply(genes, fit_one))
fwrite(result, file.path(VALIDATION, "robust_SE_equivalence_test.csv"))
summary_tbl <- data.table(
  metric = c("coefficient", "robust_SE", "Wald_z", "P_value"),
  max_absolute_difference = c(max(result$abs_diff_beta), max(result$abs_diff_robust_SE),
                              max(result$abs_diff_Wald_z), max(result$abs_diff_p)),
  tolerance = tolerance
)
summary_tbl[, passed := max_absolute_difference <= tolerance]
fwrite(summary_tbl, file.path(VALIDATION, "robust_SE_equivalence_summary.tsv"), sep = "\t")

formal_hash_after <- vapply(formal_files, digest::digest, character(1), file = TRUE, algo = "sha256", serialize = FALSE)
hash_audit <- data.table(
  formal_result_file = file.path(basename(AVAIL_OUT), basename(formal_files)),
  sha256_before = formal_hash_before,
  sha256_after = formal_hash_after,
  unchanged = formal_hash_before == formal_hash_after
)
fwrite(hash_audit, file.path(VALIDATION, "formal_result_hash_unchanged.tsv"), sep = "\t")

if (!all(summary_tbl$passed)) stop("Lin-Wei sandwich equivalence tolerance failed")
if (!all(hash_audit$unchanged)) stop("A formal frozen result changed during equivalence validation")
cat("Sandwich equivalence passed for", nrow(result), "genes\n")
