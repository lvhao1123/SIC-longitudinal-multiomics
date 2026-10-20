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

out_dir <- file.path(out_root, "A2_RNA_LOCO_centre_stability")
rank_dir <- file.path(out_dir, "internal_gene_ranks")
restricted_dir <- file.path(out_dir, "internal_restricted")
dir.create(rank_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(restricted_dir, recursive = TRUE, showWarnings = FALSE)

clinical_file <- file.path(source_dir, "SIC_504_baseline_carried_forward_annotation.csv")
logcpm_file <- file.path(frozen_dir, "01_RNA_TMM", "RNA_TMM_logCPM_gene_by_sample.rds")
primary_gsea_file <- file.path(frozen_dir, "01_RNA_TMM", "03_RNA_TMM_Hallmark_primary_PHpass.csv")
hallmark_file <- file.path(source_dir, "h.all.v2026.1.Hs.symbols.gmt")
required <- c(clinical_file, logcpm_file, primary_gsea_file, hallmark_file)
if (any(!file.exists(required))) stop("Missing input: ", paste(required[!file.exists(required)], collapse = "; "))

log_path <- file.path(out_dir, "A2_run.log")
zz <- file(log_path, open = "wt")
sink(zz, type = "output", split = TRUE)
sink(zz, type = "message", append = TRUE)
on.exit({sink(type = "message"); sink(type = "output"); close(zz)}, add = TRUE)

cat("A2 reviewer-triggered leave-one-centre-out RNA pathway stability analysis\n")
cat("Start:", format(Sys.time()), "\n")
cat("This is an internal stability analysis, not external validation.\n")

clinical <- fread(clinical_file, data.table = FALSE)
clinical$day_num <- as.integer(clinical$day_num)
clinical$event <- as.integer(clinical$sTatus)
clinical$stop <- as.numeric(clinical$surv_time)
clinical$center_raw <- sub("_.*$", "", clinical$SampleName)
logcpm <- readRDS(logcpm_file)
if (nrow(logcpm) != 14541L) stop("Expected 14,541 RNA genes; got ", nrow(logcpm))

centres <- sort(unique(clinical$center_raw[clinical$day_num == 1L]))
centre_map <- data.frame(center_raw = centres, centre_code = sprintf("C%02d", seq_along(centres)))
fwrite(centre_map, file.path(restricted_dir, "centre_code_map_L2_DO_NOT_PUBLISH.csv"))
writeLines(
  c("L2 controlled internal audit file.", "Contains empirical centre labels and must not be placed in public source data."),
  file.path(restricted_dir, "README_RESTRICTED.txt")
)

entry_map <- c(`1` = 0, `3` = 2, `5` = 4)
expected <- data.frame(day = c(1L, 3L, 5L), N = c(504L, 420L, 320L), Events = c(84L, 67L, 53L))

make_riskset <- function(day) {
  entry <- unname(entry_map[as.character(day)])
  md <- clinical[
    clinical$day_num == day & clinical$SampleName %in% colnames(logcpm) & clinical$stop > entry,
    , drop = FALSE
  ]
  sample_order <- colnames(logcpm)[colnames(logcpm) %in% md$SampleName]
  md <- md[match(sample_order, md$SampleName), , drop = FALSE]
  ex <- expected[expected$day == day, ]
  if (nrow(md) != ex$N || sum(md$event) != ex$Events) stop("Risk-set mismatch at D", day)
  md
}

risksets <- setNames(lapply(c(1L, 3L, 5L), make_riskset), c("D1", "D3", "D5"))
tasks <- do.call(rbind, lapply(c(1L, 3L, 5L), function(day) {
  md <- risksets[[paste0("D", day)]]
  present <- intersect(centres, unique(md$center_raw))
  data.frame(
    day = day,
    entry = unname(entry_map[as.character(day)]),
    center_raw = present,
    centre_code = centre_map$centre_code[match(present, centre_map$center_raw)],
    stringsAsFactors = FALSE
  )
}))
fwrite(tasks[, c("day", "entry", "centre_code")], file.path(out_dir, "A2_LOCO_task_inventory.csv"))

hallmark <- gmtPathways(hallmark_file)
names(hallmark) <- sub("^HALLMARK_", "", names(hallmark))

run_task <- function(i) {
  task <- tasks[i, ]
  tm <- paste0("D", task$day)
  md0 <- risksets[[tm]]
  md <- md0[md0$center_raw != task$center_raw, , drop = FALSE]
  md$center <- droplevels(factor(md$center_raw))
  x <- t(logcpm[, md$SampleName, drop = FALSE])
  x <- scale(x)
  x[!is.finite(x)] <- NA_real_

  fit_gene_z <- function(j) {
    d <- data.frame(
      entry = task$entry, stop = md$stop, event = md$event,
      gene_z = as.numeric(x[, j]), center = md$center
    )
    tryCatch({
      fit <- survival::coxph(
        Surv(entry, stop, event) ~ gene_z + strata(center),
        data = d, ties = "efron",
        control = survival::coxph.control(iter.max = 50, eps = 1e-9)
      )
      sm <- summary(fit)$coefficients["gene_z", , drop = FALSE]
      c(z = unname(sm[1, "z"]), fit_ok = as.numeric(is.finite(sm[1, "z"])))
    }, error = function(e) c(z = NA_real_, fit_ok = 0))
  }

  fit_mat <- do.call(rbind, lapply(seq_len(ncol(x)), fit_gene_z))
  ranks_dt <- data.table(
    gene_symbol = colnames(x), z = fit_mat[, "z"], fit_ok = as.logical(fit_mat[, "fit_ok"]),
    N = nrow(md), Events = sum(md$event), omitted_n = sum(md0$center_raw == task$center_raw),
    omitted_events = sum(md0$event[md0$center_raw == task$center_raw])
  )
  rank_file <- file.path(rank_dir, paste0(tm, "_omit_", task$centre_code, "_gene_ranks.csv.gz"))
  data.table::fwrite(ranks_dt, rank_file, compress = "gzip")

  valid <- ranks_dt[fit_ok & is.finite(z) & !is.na(gene_symbol) & nzchar(gene_symbol)]
  ranks <- valid$z; names(ranks) <- valid$gene_symbol
  ranks <- sort(ranks, decreasing = TRUE)
  set.seed(20260901 + task$day * 100 + i)
  fg <- fgsea::fgseaMultilevel(
    pathways = hallmark, stats = ranks, sampleSize = 1001, nPermSimple = 10000,
    minSize = 15, maxSize = 500, eps = 0, scoreType = "std", nproc = 1
  )
  fg <- as.data.table(fg)
  fg[, `:=`(
    Time = tm, omitted_centre = task$centre_code,
    N = nrow(md), Events = sum(md$event), omitted_n = sum(md0$center_raw == task$center_raw),
    omitted_events = sum(md0$event[md0$center_raw == task$center_raw]),
    ranked_features = length(ranks),
    pathway = sub("^HALLMARK_", "", pathway),
    leadingEdge_text = vapply(leadingEdge, paste, collapse = ";", FUN.VALUE = character(1))
  )]
  fg[, leadingEdge := NULL]
  diag <- data.frame(
    Time = tm, omitted_centre = task$centre_code, N = nrow(md), Events = sum(md$event),
    omitted_n = sum(md0$center_raw == task$center_raw),
    omitted_events = sum(md0$event[md0$center_raw == task$center_raw]),
    centres_remaining = length(unique(md$center_raw)), genes_attempted = ncol(x),
    genes_fit_ok = sum(ranks_dt$fit_ok), Hallmark_estimable = sum(is.finite(fg$NES)),
    stringsAsFactors = FALSE
  )
  list(gsea = fg, diagnostics = diag)
}

workers <- min(3L, max(1L, parallel::detectCores(logical = FALSE) - 1L))
cat("LOCO tasks:", nrow(tasks), "workers:", workers, "\n")
if (workers > 1L) {
  cl <- parallel::makePSOCKcluster(workers)
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
  parallel::clusterExport(cl, "analysis_library", envir = environment())
  parallel::clusterEvalQ(cl, {
    if (nzchar(analysis_library)) .libPaths(c(analysis_library, .libPaths()))
    library(data.table); library(survival); library(fgsea)
  })
  parallel::clusterExport(
    cl,
    c("tasks", "risksets", "logcpm", "hallmark", "rank_dir"),
    envir = environment()
  )
  parallel::clusterSetRNGStream(cl, 20260901)
  results <- parallel::parLapplyLB(cl, seq_len(nrow(tasks)), run_task)
  parallel::stopCluster(cl)
} else {
  results <- lapply(seq_len(nrow(tasks)), run_task)
}

gsea_all <- rbindlist(lapply(results, `[[`, "gsea"), fill = TRUE)
diag_all <- rbindlist(lapply(results, `[[`, "diagnostics"), fill = TRUE)
fwrite(gsea_all, file.path(out_dir, "A2_LOCO_all_Hallmark_GSEA.csv"))
fwrite(diag_all, file.path(out_dir, "A2_LOCO_model_diagnostics.csv"))

primary <- fread(primary_gsea_file)
primary <- primary[analysis == "Primary", .(Time, pathway, NES_primary = NES, padj_primary = padj)]
cmp <- merge(gsea_all, primary, by = c("Time", "pathway"), all.x = TRUE)
cmp[, `:=`(
  direction_agreement = sign(NES) == sign(NES_primary),
  LOCO_FDR05 = padj < 0.05,
  primary_FDR05 = padj_primary < 0.05
)]
fwrite(cmp, file.path(out_dir, "A2_LOCO_vs_primary_all_Hallmark.csv"))

jaccard <- function(a, b) {
  u <- union(a, b)
  if (!length(u)) return(NA_real_)
  length(intersect(a, b)) / length(u)
}
metrics <- cmp[, .(
  NES_Spearman = cor(NES, NES_primary, method = "spearman", use = "complete.obs"),
  direction_agreement = mean(direction_agreement, na.rm = TRUE),
  significant_set_Jaccard = jaccard(pathway[LOCO_FDR05 %in% TRUE], pathway[primary_FDR05 %in% TRUE]),
  LOCO_FDR05_pathways = sum(LOCO_FDR05, na.rm = TRUE),
  primary_FDR05_pathways = sum(primary_FDR05, na.rm = TRUE)
), by = .(Time, omitted_centre)]
fwrite(metrics, file.path(out_dir, "A2_LOCO_robustness_metrics_by_centre.csv"))

core <- c(
  "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE",
  "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "COAGULATION", "COMPLEMENT",
  "HEME_METABOLISM", "EPITHELIAL_MESENCHYMAL_TRANSITION", "TGF_BETA_SIGNALING",
  "APICAL_JUNCTION", "HYPOXIA", "OXIDATIVE_PHOSPHORYLATION",
  "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS"
)
core_summary <- cmp[pathway %in% core, .(
  primary_NES = unique(NES_primary)[1], primary_FDR = unique(padj_primary)[1],
  LOCO_N = .N, LOCO_NES_median = median(NES, na.rm = TRUE),
  LOCO_NES_min = min(NES, na.rm = TRUE), LOCO_NES_max = max(NES, na.rm = TRUE),
  sign_consistency_fraction = mean(sign(NES) == sign(NES_primary), na.rm = TRUE),
  FDR05_fraction = mean(padj < 0.05, na.rm = TRUE)
), by = .(Time, pathway)]
fwrite(core_summary, file.path(out_dir, "A2_core_15_pathway_LOCO_stability_summary.csv"))

overall <- metrics[, .(
  omissions = .N,
  median_NES_Spearman = median(NES_Spearman, na.rm = TRUE),
  min_NES_Spearman = min(NES_Spearman, na.rm = TRUE),
  median_direction_agreement = median(direction_agreement, na.rm = TRUE),
  min_direction_agreement = min(direction_agreement, na.rm = TRUE),
  median_significant_set_Jaccard = median(significant_set_Jaccard, na.rm = TRUE),
  min_significant_set_Jaccard = min(significant_set_Jaccard, na.rm = TRUE)
), by = Time]
fwrite(overall, file.path(out_dir, "A2_LOCO_overall_summary.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_A2.txt"))
cat("Completed:", format(Sys.time()), "\n")
print(overall)
