rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(stringr)
  library(tibble)
  library(survival)
  library(edgeR)
  library(fgsea)
  library(future)
  library(future.apply)
})

log_file <- file.path(LOG_OUT, "01_RNA_TMM_run.log")
zz <- file(log_file, open = "wt")
sink(zz, type = "output", split = TRUE)
sink(zz, type = "message", append = TRUE)
on.exit({sink(type = "message"); sink(type = "output"); close(zz)}, add = TRUE)

cat("SIC longitudinal RNA reanalysis\n")
cat("Start:", format(Sys.time()), "\n")
cat("Primary normalization: edgeR TMM + logCPM\n")
cat("Primary model: Surv(entry, stop, event) ~ gene_z + strata(center)\n")

clinical <- fread(INPUT$clinical, data.table = FALSE) |>
  mutate(
    day_num = as.integer(day_num),
    Time = paste0("D", day_num),
    center = factor(str_extract(SampleName, "^[^_]+")),
    event = as.integer(sTatus),
    stop = as.numeric(surv_time)
  )

stopifnot(!anyDuplicated(clinical$SampleName))
stopifnot(all(clinical$event %in% 0:1))

header <- names(fread(INPUT$rna_counts, nrows = 0, data.table = FALSE))
rna_samples <- intersect(clinical$SampleName, header)
if (length(rna_samples) != 1246L) stop("Expected 1246 SIC RNA samples; got ", length(rna_samples))

cat("Reading 61,806 raw RNA features across", length(rna_samples), "matched samples...\n")
raw <- fread(
  INPUT$rna_counts,
  select = c("gene_id", rna_samples),
  data.table = TRUE,
  showProgress = TRUE
)
raw[, ensembl_gene_id := str_remove(as.character(gene_id), "\\.[0-9]+$")]

map <- fread(INPUT$frozen_gene_map, data.table = TRUE)
map_names <- names(map)
id_col <- intersect(map_names, c("gene_id", "gene", "ensembl_gene_id"))[1]
symbol_col <- intersect(map_names, c("gene_symbol", "hgnc_symbol"))[1]
if (is.na(id_col) || is.na(symbol_col)) stop("Frozen gene map lacks ID/symbol columns")
setnames(map, c(id_col, symbol_col), c("ensembl_gene_id", "gene_symbol"))
map[, ensembl_gene_id := str_remove(as.character(ensembl_gene_id), "\\.[0-9]+$")]
map <- unique(map[!is.na(gene_symbol) & gene_symbol != "", .(ensembl_gene_id, gene_symbol)])
if (anyDuplicated(map$ensembl_gene_id)) stop("Frozen map still contains conflicting Ensembl IDs")

raw <- merge(raw, map, by = "ensembl_gene_id", all = FALSE, sort = FALSE)
if (!nrow(raw)) stop("No RNA rows mapped to gene symbols")

cat("Mapped raw rows:", nrow(raw), "\n")
count_cols <- rna_samples
agg <- raw[, lapply(.SD, sum, na.rm = TRUE), by = gene_symbol, .SDcols = count_cols]
genes <- agg$gene_symbol
counts <- as.matrix(agg[, ..count_cols])
storage.mode(counts) <- "double"
rownames(counts) <- genes
rm(raw, agg); gc()

if (any(counts < 0, na.rm = TRUE)) stop("Negative RNA counts detected")
if (anyNA(counts)) stop("RNA count matrix contains NA after aggregation")

# TMM is estimated before filtering; CPM filter is applied to the normalized library sizes.
dge_all <- DGEList(counts = counts)
dge_all <- calcNormFactors(dge_all, method = "TMM")
cpm_all <- cpm(dge_all, log = FALSE)
keep <- rowMeans(cpm_all >= 1) >= 0.20
dge <- dge_all[keep, , keep.lib.sizes = FALSE]
dge <- calcNormFactors(dge, method = "TMM")
logcpm <- cpm(dge, log = TRUE, prior.count = 1)

norm_audit <- data.frame(
  SampleName = colnames(dge),
  library_size = dge$samples$lib.size,
  norm_factor_TMM = dge$samples$norm.factors,
  effective_library_size = dge$samples$lib.size * dge$samples$norm.factors
)
fwrite(norm_audit, file.path(RNA_OUT, "00_RNA_TMM_normalization_factors.csv"))
fwrite(data.frame(
  metric = c("raw_features", "mapped_unique_symbols", "retained_CPM1_20pct", "matched_samples"),
  value = c(61806, nrow(counts), nrow(logcpm), ncol(logcpm))
), file.path(RNA_OUT, "00_RNA_filtering_summary.csv"))
saveRDS(logcpm, file.path(RNA_OUT, "RNA_TMM_logCPM_gene_by_sample.rds"), compress = FALSE)
rm(counts, cpm_all, dge_all, dge); gc()

extract_coef <- function(fit) {
  sm <- summary(fit)
  cr <- sm$coefficients["gene_z", , drop = FALSE]
  ci <- sm$conf.int["gene_z", , drop = FALSE]
  tibble(
    logHR = unname(cr[1, "coef"]), HR = unname(ci[1, "exp(coef)"]),
    SE = unname(cr[1, "se(coef)"]), z = unname(cr[1, "z"]),
    pval = unname(cr[1, "Pr(>|z|)"]),
    lower95 = unname(ci[1, "lower .95"]), upper95 = unname(ci[1, "upper .95"])
  )
}

fit_gene <- function(x, md, entry) {
  d <- data.frame(
    entry = entry, stop = md$stop, event = md$event,
    gene_z = as.numeric(x), center = droplevels(md$center)
  )
  d <- d[complete.cases(d), , drop = FALSE]
  fit <- coxph(
    Surv(entry, stop, event) ~ gene_z + strata(center), data = d,
    ties = "efron", x = TRUE, y = TRUE, model = TRUE,
    control = coxph.control(iter.max = 50, eps = 1e-9)
  )
  co <- extract_coef(fit)
  ph <- cox.zph(fit, transform = "km", terms = FALSE, global = FALSE)
  rr <- match("gene_z", rownames(ph$table)); if (is.na(rr)) rr <- 1L
  bind_cols(co, tibble(
    PH_chisq = unname(ph$table[rr, "chisq"]),
    PH_p = unname(ph$table[rr, "p"]),
    fit_ok = is.finite(co$z) && is.finite(co$pval) && co$SE > 0,
    N = nrow(d), Events = sum(d$event)
  ))
}

prepare_day <- function(day) {
  time <- paste0("D", day)
  entry <- unname(ENTRY_DAY[time])
  md <- clinical |>
    filter(day_num == day, SampleName %in% colnames(logcpm), stop > entry) |>
    arrange(match(SampleName, colnames(logcpm)))
  x <- t(logcpm[, md$SampleName, drop = FALSE])
  x <- scale(x)
  x[!is.finite(x)] <- NA_real_
  list(time = time, entry = entry, meta = md, expr = x)
}

run_day <- function(day) {
  obj <- prepare_day(day)
  exp_row <- EXPECTED[EXPECTED$Omics == "RNA" & EXPECTED$Time == obj$time, ]
  if (nrow(obj$meta) != exp_row$N || sum(obj$meta$event) != exp_row$Events) {
    stop(obj$time, " risk set mismatch")
  }
  message(obj$time, ": N=", nrow(obj$meta), ", events=", sum(obj$meta$event),
          ", genes=", ncol(obj$expr), ", centres=", nlevels(droplevels(obj$meta$center)))
  runner <- function(j) tryCatch(
    fit_gene(obj$expr[, j], obj$meta, obj$entry),
    error = function(e) tibble(
      logHR = NA_real_, HR = NA_real_, SE = NA_real_, z = NA_real_, pval = NA_real_,
      lower95 = NA_real_, upper95 = NA_real_, PH_chisq = NA_real_, PH_p = NA_real_,
      fit_ok = FALSE, N = nrow(obj$meta), Events = sum(obj$meta$event), error = conditionMessage(e)
    )
  )
  fits <- lapply(seq_len(ncol(obj$expr)), runner)
  bind_rows(fits) |>
    mutate(
      Time = obj$time, gene_symbol = colnames(obj$expr),
      padj = p.adjust(pval, "BH"), PH_FDR = p.adjust(PH_p, "BH"),
      PH_pass_nominal = is.finite(PH_p) & PH_p >= 0.05,
      entry_day = obj$entry
    ) |>
    relocate(Time, gene_symbol)
}

# Three independent landmark analyses are parallelized; each feature fit remains deterministic.
workers <- min(3L, max(1L, parallel::detectCores(logical = FALSE) - 1L))
future::plan(future::multisession, workers = workers)
cox_list <- future_lapply(c(1L, 3L, 5L), run_day, future.seed = TRUE)
future::plan(future::sequential)
names(cox_list) <- c("D1", "D3", "D5")

for (tm in names(cox_list)) {
  fwrite(cox_list[[tm]], file.path(RNA_OUT, paste0("01_", tm, "_TMM_center_stratified_cox_zph.csv")))
}
cox_all <- bind_rows(cox_list)
fwrite(cox_all, file.path(RNA_OUT, "02_all_RNA_TMM_center_stratified_cox_zph.csv"))

# GSEA is finalized by 01b_finalize_RNA_GSEA.R. Keeping that stage separate avoids
# Windows parallel back-end shutdown issues and makes Cox/GSEA checkpoints restartable.
writeLines(capture.output(sessionInfo()), file.path(RNA_OUT, "sessionInfo_RNA_Cox.txt"))
cat("Cox checkpoint completed:", format(Sys.time()), "\n")
quit(save = "no", status = 0)

hallmark <- gmtPathways(INPUT$hallmark)
names(hallmark) <- str_remove(names(hallmark), "^HALLMARK_")

run_gsea_once <- function(tbl, analysis) {
  ztbl <- tbl |> filter(fit_ok, is.finite(z), gene_symbol != "")
  if (analysis == "PH_pass") ztbl <- ztbl |> filter(PH_pass_nominal)
  ranks <- ztbl$z; names(ranks) <- ztbl$gene_symbol
  ranks <- sort(ranks, decreasing = TRUE)
  set.seed(20260711)
  res <- fgseaMultilevel(
    pathways = hallmark, stats = ranks, sampleSize = 1001,
    nPermSimple = 10000, minSize = 15, maxSize = 500,
    eps = 0, scoreType = "std"
  ) |> as_tibble()
  res$analysis <- analysis
  res$ranked_features <- length(ranks)
  res
}

gsea <- bind_rows(lapply(names(cox_list), function(tm) {
  bind_rows(run_gsea_once(cox_list[[tm]], "Primary"), run_gsea_once(cox_list[[tm]], "PH_pass")) |>
    mutate(Time = tm)
})) |>
  mutate(
    pathway = str_remove(pathway, "^HALLMARK_"),
    direction = if_else(NES > 0, "positive mortality association", "negative mortality association"),
    leadingEdge_text = vapply(leadingEdge, paste, collapse = ";", FUN.VALUE = character(1))
  )

# Target only non-estimable combinations; merge back and recalculate BH within the complete Hallmark family.
na_idx <- which(!is.finite(gsea$NES) | !is.finite(gsea$pval))
if (length(na_idx)) {
  for (i in na_idx) {
    tm <- gsea$Time[i]; analysis <- gsea$analysis[i]; target <- gsea$pathway[i]
    ztbl <- cox_list[[tm]] |> filter(fit_ok, is.finite(z), gene_symbol != "")
    if (analysis == "PH_pass") ztbl <- ztbl |> filter(PH_pass_nominal)
    ranks <- ztbl$z; names(ranks) <- ztbl$gene_symbol; ranks <- sort(ranks, decreasing = TRUE)
    hi <- fgseaMultilevel(
      pathways = hallmark[target], stats = ranks, sampleSize = 5001,
      nPermSimple = 100000, minSize = 15, maxSize = 500,
      eps = 0, scoreType = "std"
    ) |> as_tibble()
    if (nrow(hi) && is.finite(hi$NES[1]) && is.finite(hi$pval[1])) {
      for (nm in intersect(c("ES", "NES", "pval", "log2err", "size"), names(hi))) gsea[[nm]][i] <- hi[[nm]][1]
      gsea$leadingEdge[[i]] <- hi$leadingEdge[[1]]
      gsea$leadingEdge_text[i] <- paste(hi$leadingEdge[[1]], collapse = ";")
    }
  }
  gsea <- gsea |> group_by(Time, analysis) |> mutate(padj = p.adjust(pval, "BH")) |> ungroup()
}

gsea_export <- gsea |> select(-leadingEdge)
fwrite(gsea_export, file.path(RNA_OUT, "03_RNA_TMM_Hallmark_primary_PHpass.csv"))

leading <- gsea |>
  select(Time, analysis, pathway, NES, padj, leadingEdge) |>
  tidyr::unnest_longer(leadingEdge, values_to = "gene_symbol")
fwrite(leading, file.path(RNA_OUT, "04_RNA_TMM_Hallmark_leading_edge_long.csv"))

diagnostics <- cox_all |>
  group_by(Time) |>
  summarise(
    N = max(N), Events = max(Events), genes_attempted = n(), fits_ok = sum(fit_ok),
    gene_FDR05 = sum(padj < 0.05, na.rm = TRUE),
    nominal_PH_fail = sum(PH_p < 0.05, na.rm = TRUE),
    PH_FDR05 = sum(PH_FDR < 0.05, na.rm = TRUE), .groups = "drop"
  )
gsea_diag <- gsea_export |>
  group_by(Time, analysis) |>
  summarise(estimable = sum(is.finite(NES) & is.finite(pval)), FDR05 = sum(padj < 0.05, na.rm = TRUE), .groups = "drop")
fwrite(diagnostics, file.path(RNA_OUT, "05_RNA_TMM_Cox_diagnostics.csv"))
fwrite(gsea_diag, file.path(RNA_OUT, "05_RNA_TMM_GSEA_diagnostics.csv"))

saveRDS(list(cox = cox_list, gsea = gsea, logcpm = logcpm),
        file.path(RNA_OUT, "RNA_TMM_reanalysis_objects.rds"), compress = FALSE)
writeLines(capture.output(sessionInfo()), file.path(RNA_OUT, "sessionInfo_RNA.txt"))
cat("Completed:", format(Sys.time()), "\n")
print(diagnostics)
print(gsea_diag)
