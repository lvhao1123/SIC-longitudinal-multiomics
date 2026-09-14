rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")

suppressPackageStartupMessages({
  library(readxl); library(data.table); library(dplyr); library(stringr)
  library(tibble); library(survival); library(fgsea); library(future); library(future.apply)
})

log_file <- file.path(LOG_OUT, "02_Protein_run.log")
zz <- file(log_file, open = "wt")
sink(zz, type = "output", split = TRUE)
sink(zz, type = "message", append = TRUE)
on.exit({sink(type = "message"); sink(type = "output"); close(zz)}, add = TRUE)

cat("SIC longitudinal plasma proteome reanalysis\nStart:", format(Sys.time()), "\n")
cat("Primary: protein_z + strata(center)\n")
cat("Sensitivity: protein_z + sample_median_z + strata(center)\n")

protein_raw <- as.data.frame(read_excel(INPUT$protein, sheet = "proteins_annotation"), check.names = FALSE)
qc <- fread(INPUT$protein_qc, data.table = FALSE)
clinical <- fread(INPUT$clinical, data.table = FALSE) |>
  mutate(
    day_num = as.integer(day_num), Time = paste0("D", day_num),
    center = factor(str_extract(SampleName, "^[^_]+")),
    event = as.integer(sTatus), stop = as.numeric(surv_time)
  )

sample_cols <- grep("_d[135]$", names(protein_raw), value = TRUE)
matched_samples <- intersect(sample_cols, clinical$SampleName)
if (length(matched_samples) != 431L) stop("Expected 431 matched SIC proteome samples; got ", length(matched_samples))

annotation <- tibble(
  row_id = seq_len(nrow(protein_raw)),
  uniprot_id = as.character(protein_raw[[1]]),
  gene_symbol = str_trim(str_split_fixed(as.character(protein_raw[[2]]), ";", 2)[, 1]),
  row_median_abundance = apply(as.matrix(protein_raw[, matched_samples, drop = FALSE]), 1, median, na.rm = TRUE)
)

# Deterministic duplicate resolution: pass both QC filters, lowest within-batch linear-scale CV,
# then highest median abundance, then original row order.
qc_keep <- qc |>
  filter(pass_both == 1, !is.na(gene_symbol), gene_symbol != "") |>
  select(uniprot_id, gene_symbol, median_within_batch_linear_CV_pct,
         clinical_missing_rate, pass_CV20, pass_missing30, pass_both)

candidates <- annotation |>
  inner_join(qc_keep, by = c("uniprot_id", "gene_symbol")) |>
  arrange(gene_symbol, median_within_batch_linear_CV_pct, desc(row_median_abundance), row_id)

duplicate_audit <- candidates |>
  group_by(gene_symbol) |>
  mutate(n_candidates = n(), selected = row_number() == 1L) |>
  ungroup()
selected <- duplicate_audit |> filter(selected)

fwrite(duplicate_audit, file.path(PROTEIN_OUT, "00_Protein_QC_duplicate_resolution_audit.csv"))
fwrite(selected, file.path(PROTEIN_OUT, "00_Protein_selected_features.csv"))

expr <- as.matrix(protein_raw[selected$row_id, matched_samples, drop = FALSE])
storage.mode(expr) <- "double"
rownames(expr) <- selected$gene_symbol
if (anyDuplicated(rownames(expr))) stop("Duplicate protein symbols remain")

meta <- clinical[match(matched_samples, clinical$SampleName), , drop = FALSE]
stopifnot(all(meta$SampleName == matched_samples))
meta$sample_median <- apply(expr, 2, median, na.rm = TRUE)
meta$sample_missing_fraction <- colMeans(is.na(expr))
fwrite(meta |> select(SampleName, PatientID, Time, day_num, center, sample_median,
                      sample_missing_fraction, stop, event),
       file.path(PROTEIN_OUT, "00_Protein_sample_QC.csv"))
saveRDS(expr, file.path(PROTEIN_OUT, "Protein_QC_gene_by_sample.rds"), compress = FALSE)

prepare_day <- function(day) {
  time <- paste0("D", day); entry <- unname(ENTRY_DAY[time])
  md <- meta |> filter(day_num == day, stop > entry)
  x <- t(expr[, md$SampleName, drop = FALSE])
  x <- scale(x); x[!is.finite(x)] <- NA_real_
  list(time = time, entry = entry, meta = md, expr = x)
}

extract_coef <- function(fit) {
  sm <- summary(fit); cr <- sm$coefficients["protein_z", , drop = FALSE]
  ci <- sm$conf.int["protein_z", , drop = FALSE]
  tibble(
    logHR = unname(cr[1, "coef"]), HR = unname(ci[1, "exp(coef)"]),
    SE = unname(cr[1, "se(coef)"]), z = unname(cr[1, "z"]), pval = unname(cr[1, "Pr(>|z|)"]),
    lower95 = unname(ci[1, "lower .95"]), upper95 = unname(ci[1, "upper .95"])
  )
}

fit_protein <- function(x, md, entry, adjust_median) {
  d <- data.frame(
    entry = entry, stop = md$stop, event = md$event, protein_z = as.numeric(x),
    median_z = as.numeric(scale(md$sample_median)), center = droplevels(md$center)
  )
  d <- d[complete.cases(d), , drop = FALSE]
  form <- if (adjust_median) {
    Surv(entry, stop, event) ~ protein_z + median_z + strata(center)
  } else Surv(entry, stop, event) ~ protein_z + strata(center)
  fit <- coxph(
    form, data = d, ties = "efron", x = TRUE, y = TRUE, model = TRUE,
    control = coxph.control(iter.max = 50, eps = 1e-9)
  )
  co <- extract_coef(fit)
  ph <- cox.zph(fit, transform = "km", terms = FALSE, global = FALSE)
  rr <- match("protein_z", rownames(ph$table)); if (is.na(rr)) rr <- 1L
  bind_cols(co, tibble(
    PH_chisq = unname(ph$table[rr, "chisq"]), PH_p = unname(ph$table[rr, "p"]),
    fit_ok = is.finite(co$z) && is.finite(co$pval) && co$SE > 0,
    N = nrow(d), Events = sum(d$event)
  ))
}

run_day_model <- function(day, model) {
  obj <- prepare_day(day); adjust <- identical(model, "median_center_sensitivity")
  expected <- EXPECTED[EXPECTED$Omics == "Protein" & EXPECTED$Time == obj$time, ]
  if (nrow(obj$meta) != expected$N || sum(obj$meta$event) != expected$Events) stop(obj$time, " risk set mismatch")
  fits <- lapply(seq_len(ncol(obj$expr)), function(j) tryCatch(
    fit_protein(obj$expr[, j], obj$meta, obj$entry, adjust),
    error = function(e) tibble(
      logHR = NA_real_, HR = NA_real_, SE = NA_real_, z = NA_real_, pval = NA_real_,
      lower95 = NA_real_, upper95 = NA_real_, PH_chisq = NA_real_, PH_p = NA_real_,
      fit_ok = FALSE, N = nrow(obj$meta), Events = sum(obj$meta$event), error = conditionMessage(e)
    )
  ))
  bind_rows(fits) |>
    mutate(
      Time = obj$time, model = model, gene_symbol = colnames(obj$expr),
      padj = p.adjust(pval, "BH"), PH_FDR = p.adjust(PH_p, "BH"),
      PH_pass_nominal = is.finite(PH_p) & PH_p >= 0.05, entry_day = obj$entry
    ) |>
    relocate(Time, model, gene_symbol)
}

jobs <- expand.grid(day = c(1L, 3L, 5L), model = c("center_primary", "median_center_sensitivity"),
                    stringsAsFactors = FALSE)
future::plan(future::multisession, workers = 3L)
results <- future_lapply(seq_len(nrow(jobs)), function(i) run_day_model(jobs$day[i], jobs$model[i]), future.seed = TRUE)
future::plan(future::sequential)

all_cox <- bind_rows(results)
for (i in seq_len(nrow(jobs))) {
  fwrite(results[[i]], file.path(PROTEIN_OUT, paste0("01_D", jobs$day[i], "_", jobs$model[i], "_cox_zph.csv")))
}
fwrite(all_cox, file.path(PROTEIN_OUT, "02_all_Protein_models_cox_zph.csv"))

hallmark <- gmtPathways(INPUT$hallmark)
names(hallmark) <- str_remove(names(hallmark), "^HALLMARK_")
run_gsea <- function(tbl, analysis) {
  ranks <- tbl$z; names(ranks) <- tbl$gene_symbol
  ranks <- sort(ranks[is.finite(ranks) & tbl$fit_ok], decreasing = TRUE)
  set.seed(20260711)
  fgseaMultilevel(
    pathways = hallmark, stats = ranks, sampleSize = 1001, nPermSimple = 10000,
    minSize = 15, maxSize = 500, eps = 0, scoreType = "std", nproc = 1
  ) |>
    as_tibble() |>
    mutate(
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
gsea <- bind_rows(gsea) |>
  mutate(pathway = str_remove(pathway, "^HALLMARK_"),
         direction = if_else(NES > 0, "positive mortality association", "negative mortality association"))
fwrite(gsea |> select(-leadingEdge), file.path(PROTEIN_OUT, "03_Protein_Hallmark_all_models.csv"))

leading <- gsea |> select(analysis, pathway, NES, padj, leadingEdge) |>
  tidyr::unnest_longer(leadingEdge, values_to = "gene_symbol")
fwrite(leading, file.path(PROTEIN_OUT, "04_Protein_Hallmark_leading_edge_long.csv"))

diagnostics <- all_cox |>
  group_by(Time, model) |>
  summarise(
    N = max(N), Events = max(Events), features = n(), fits_ok = sum(fit_ok),
    positive_z_fraction = mean(z > 0, na.rm = TRUE), feature_FDR05 = sum(padj < 0.05, na.rm = TRUE),
    nominal_PH_fail = sum(PH_p < 0.05, na.rm = TRUE), PH_FDR05 = sum(PH_FDR < 0.05, na.rm = TRUE),
    .groups = "drop"
  )
fwrite(diagnostics, file.path(PROTEIN_OUT, "05_Protein_model_diagnostics.csv"))
saveRDS(list(expr = expr, meta = meta, cox = all_cox, gsea = gsea),
        file.path(PROTEIN_OUT, "Protein_reanalysis_objects.rds"), compress = FALSE)
writeLines(capture.output(sessionInfo()), file.path(PROTEIN_OUT, "sessionInfo_Protein.txt"))
cat("Completed:", format(Sys.time()), "\n")
print(diagnostics)
