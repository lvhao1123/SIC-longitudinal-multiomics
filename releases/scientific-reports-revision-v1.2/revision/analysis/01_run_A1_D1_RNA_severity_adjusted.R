options(stringsAsFactors = FALSE, warn = 1)
set.seed(20260901)

analysis_library <- Sys.getenv("SIC_R_LIBRARY", unset = "")
if (nzchar(analysis_library)) .libPaths(c(analysis_library, .libPaths()))

suppressPackageStartupMessages({
  library(data.table)
  library(survival)
  library(fgsea)
})

source_dir <- Sys.getenv("CMAISE_DATA_DIR", unset = "")
frozen_dir <- Sys.getenv("SIC_FROZEN_PRIVATE_DIR", unset = "")
out_root <- Sys.getenv("SIC_REVIEW_OUTPUT_DIR", unset = "")
if (!nzchar(source_dir) || !dir.exists(source_dir)) stop("CMAISE_DATA_DIR is not available")
if (!nzchar(frozen_dir) || !dir.exists(frozen_dir)) stop("SIC_FROZEN_PRIVATE_DIR is not available")
if (!nzchar(out_root)) stop("SIC_REVIEW_OUTPUT_DIR is required")

out_dir <- file.path(out_root, "A1_D1_RNA_severity_adjusted")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

clinical_file <- file.path(source_dir, "SIC_504_baseline_carried_forward_annotation.csv")
logcpm_file <- file.path(frozen_dir, "01_RNA_TMM", "RNA_TMM_logCPM_gene_by_sample.rds")
primary_gsea_file <- file.path(frozen_dir, "01_RNA_TMM", "03_RNA_TMM_Hallmark_primary_PHpass.csv")
hallmark_file <- file.path(source_dir, "h.all.v2026.1.Hs.symbols.gmt")
required <- c(clinical_file, logcpm_file, primary_gsea_file, hallmark_file)
if (any(!file.exists(required))) stop("Missing input: ", paste(required[!file.exists(required)], collapse = "; "))

log_path <- file.path(out_dir, "A1_run.log")
zz <- file(log_path, open = "wt")
sink(zz, type = "output", split = TRUE)
sink(zz, type = "message", append = TRUE)
on.exit({sink(type = "message"); sink(type = "output"); close(zz)}, add = TRUE)

cat("A1 reviewer-triggered Day-1 RNA severity-adjusted sensitivity analysis\n")
cat("Start:", format(Sys.time()), "\n")
cat("Frozen primary outputs are read-only and are not overwritten.\n")

clinical <- fread(clinical_file, data.table = FALSE)
clinical$day_num <- as.integer(clinical$day_num)
clinical$event <- as.integer(clinical$sTatus)
clinical$stop <- as.numeric(clinical$surv_time)
clinical$center <- factor(sub("_.*$", "", clinical$SampleName))

logcpm <- readRDS(logcpm_file)
if (nrow(logcpm) != 14541L) stop("Expected 14,541 RNA genes; got ", nrow(logcpm))

md <- clinical[
  clinical$day_num == 1L & clinical$SampleName %in% colnames(logcpm) & clinical$stop > 0,
  , drop = FALSE
]
md <- md[match(colnames(logcpm)[colnames(logcpm) %in% md$SampleName], md$SampleName), , drop = FALSE]
if (nrow(md) != 504L || sum(md$event) != 84L) stop("D1 risk-set mismatch")

needed <- c("age", "SOFA", "lac", "stop", "event", "center", "SampleName")
missing_count <- vapply(md[needed], function(x) sum(is.na(x)), integer(1))
fwrite(data.frame(variable = names(missing_count), missing_n = unname(missing_count)),
       file.path(out_dir, "A1_covariate_missingness.csv"))
if (any(missing_count > 0L)) stop("A1 covariates contain missing values; no silent complete-case deletion is permitted")
if (any(md$lac <= 0)) stop("Lactate contains non-positive values; frozen log2 transform cannot be applied")

zscore <- function(x) as.numeric((x - mean(x)) / stats::sd(x))
md$age_z <- zscore(as.numeric(md$age))
md$SOFA_z <- zscore(as.numeric(md$SOFA))
md$log2_lac <- log2(as.numeric(md$lac))
md$log2_lac_z <- zscore(md$log2_lac)

expr <- t(logcpm[, md$SampleName, drop = FALSE])
expr <- scale(expr)
expr[!is.finite(expr)] <- NA_real_

fit_one <- function(j) {
  d <- data.frame(
    entry = 0,
    stop = md$stop,
    event = md$event,
    gene_z = as.numeric(expr[, j]),
    age_z = md$age_z,
    SOFA_z = md$SOFA_z,
    log2_lac_z = md$log2_lac_z,
    center = droplevels(md$center)
  )
  tryCatch({
    fit <- coxph(
      Surv(entry, stop, event) ~ gene_z + age_z + SOFA_z + log2_lac_z + strata(center),
      data = d, ties = "efron", x = TRUE, y = TRUE,
      control = coxph.control(iter.max = 50, eps = 1e-9)
    )
    sm <- summary(fit)
    cr <- sm$coefficients["gene_z", , drop = FALSE]
    ci <- sm$conf.int["gene_z", , drop = FALSE]
    ph <- cox.zph(fit, transform = "km", terms = FALSE, global = FALSE)
    rr <- match("gene_z", rownames(ph$table)); if (is.na(rr)) rr <- 1L
    data.frame(
      logHR = unname(cr[1, "coef"]), HR = unname(ci[1, "exp(coef)"]),
      SE = unname(cr[1, "se(coef)"]), z = unname(cr[1, "z"]),
      pval = unname(cr[1, "Pr(>|z|)"]), lower95 = unname(ci[1, "lower .95"]),
      upper95 = unname(ci[1, "upper .95"]), PH_chisq = unname(ph$table[rr, "chisq"]),
      PH_p = unname(ph$table[rr, "p"]), fit_ok = TRUE, error = NA_character_,
      stringsAsFactors = FALSE
    )
  }, error = function(e) data.frame(
    logHR = NA_real_, HR = NA_real_, SE = NA_real_, z = NA_real_, pval = NA_real_,
    lower95 = NA_real_, upper95 = NA_real_, PH_chisq = NA_real_, PH_p = NA_real_,
    fit_ok = FALSE, error = conditionMessage(e), stringsAsFactors = FALSE
  ))
}

workers <- min(3L, max(1L, parallel::detectCores(logical = FALSE) - 1L))
cat("Genes:", ncol(expr), "workers:", workers, "\n")
if (workers > 1L) {
  cl <- parallel::makePSOCKcluster(workers)
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
  parallel::clusterEvalQ(cl, library(survival))
  parallel::clusterExport(cl, c("md", "expr"), envir = environment())
  fits <- parallel::parLapplyLB(cl, seq_len(ncol(expr)), fit_one)
  parallel::stopCluster(cl)
} else {
  fits <- lapply(seq_len(ncol(expr)), fit_one)
}

cox <- rbindlist(fits, fill = TRUE)
cox[, gene_symbol := colnames(expr)]
setcolorder(cox, c("gene_symbol", setdiff(names(cox), "gene_symbol")))
cox[, `:=`(
  padj = p.adjust(pval, method = "BH"),
  PH_FDR = p.adjust(PH_p, method = "BH"),
  PH_pass_nominal = is.finite(PH_p) & PH_p >= 0.05,
  N = nrow(md), Events = sum(md$event), entry_day = 0
)]
fwrite(cox, file.path(out_dir, "A1_D1_RNA_age_SOFA_log2lactate_adjusted_Cox_PH.csv"))

hallmark <- gmtPathways(hallmark_file)
names(hallmark) <- sub("^HALLMARK_", "", names(hallmark))

run_gsea <- function(tbl, analysis) {
  tbl <- tbl[tbl$fit_ok & is.finite(tbl$z) & !is.na(tbl$gene_symbol) & nzchar(tbl$gene_symbol), ]
  ranks <- tbl$z; names(ranks) <- tbl$gene_symbol
  ranks <- sort(ranks, decreasing = TRUE)
  set.seed(20260901)
  ans <- fgseaMultilevel(
    pathways = hallmark, stats = ranks, sampleSize = 1001, nPermSimple = 10000,
    minSize = 15, maxSize = 500, eps = 0, scoreType = "std", nproc = 1
  )
  ans <- as.data.table(ans)
  ans[, `:=`(
    pathway = sub("^HALLMARK_", "", pathway), analysis = analysis,
    ranked_features = length(ranks),
    direction = ifelse(NES > 0, "positive mortality association", "negative mortality association"),
    leadingEdge_text = vapply(leadingEdge, paste, collapse = ";", FUN.VALUE = character(1))
  )]
  ans[, leadingEdge := NULL]
  ans
}

gsea_adjusted <- rbindlist(list(
  run_gsea(cox, "D1_age_SOFA_log2lactate_adjusted"),
  run_gsea(cox[PH_pass_nominal == TRUE], "D1_age_SOFA_log2lactate_adjusted_PHpass")
), fill = TRUE)
fwrite(gsea_adjusted, file.path(out_dir, "A1_D1_RNA_adjusted_Hallmark_GSEA.csv"))

primary <- fread(primary_gsea_file, data.table = FALSE)
primary <- primary[primary$Time == "D1" & primary$analysis == "Primary", ]
adj_main <- as.data.frame(gsea_adjusted[gsea_adjusted$analysis == "D1_age_SOFA_log2lactate_adjusted", ])
cmp <- merge(
  primary[, c("pathway", "NES", "padj")],
  adj_main[, c("pathway", "NES", "padj")],
  by = "pathway", suffixes = c("_primary", "_adjusted"), all = TRUE
)
cmp$direction_agreement <- sign(cmp$NES_primary) == sign(cmp$NES_adjusted)
cmp$primary_FDR05 <- cmp$padj_primary < 0.05
cmp$adjusted_FDR05 <- cmp$padj_adjusted < 0.05
fwrite(cmp, file.path(out_dir, "A1_primary_vs_adjusted_all_Hallmark.csv"))

jaccard <- function(a, b) {
  u <- union(a, b)
  if (!length(u)) return(NA_real_)
  length(intersect(a, b)) / length(u)
}
metrics <- data.frame(
  metric = c(
    "N", "Events", "genes_attempted", "genes_fit_ok", "nominal_PH_fail",
    "primary_vs_adjusted_NES_Spearman", "direction_agreement", "significant_set_Jaccard",
    "primary_FDR05_pathways", "adjusted_FDR05_pathways"
  ),
  value = c(
    nrow(md), sum(md$event), nrow(cox), sum(cox$fit_ok), sum(cox$PH_p < 0.05, na.rm = TRUE),
    cor(cmp$NES_primary, cmp$NES_adjusted, method = "spearman", use = "complete.obs"),
    mean(cmp$direction_agreement, na.rm = TRUE),
    jaccard(cmp$pathway[cmp$primary_FDR05 %in% TRUE], cmp$pathway[cmp$adjusted_FDR05 %in% TRUE]),
    sum(cmp$primary_FDR05, na.rm = TRUE), sum(cmp$adjusted_FDR05, na.rm = TRUE)
  )
)
fwrite(metrics, file.path(out_dir, "A1_diagnostics_and_robustness_metrics.csv"))

core <- c(
  "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE",
  "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "COAGULATION", "COMPLEMENT",
  "HEME_METABOLISM", "EPITHELIAL_MESENCHYMAL_TRANSITION", "TGF_BETA_SIGNALING",
  "APICAL_JUNCTION", "HYPOXIA", "OXIDATIVE_PHOSPHORYLATION",
  "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS"
)
fwrite(cmp[cmp$pathway %in% core, ], file.path(out_dir, "A1_core_15_pathway_comparison.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_A1.txt"))
cat("Completed:", format(Sys.time()), "\n")
print(metrics)
