rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")

suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(tidyr); library(stringr)
  library(fgsea); library(purrr); library(sandwich); library(lmtest)
})

log_file <- file.path(LOG_OUT, "03_CrossOmics_run.log")
zz <- file(log_file, open = "wt")
sink(zz, type = "output", split = TRUE)
sink(zz, type = "message", append = TRUE)
on.exit({sink(type = "message"); sink(type = "output"); close(zz)}, add = TRUE)

rna_file <- file.path(RNA_OUT, "RNA_TMM_logCPM_gene_by_sample.rds")
protein_file <- file.path(PROTEIN_OUT, "Protein_QC_gene_by_sample.rds")
if (!file.exists(rna_file) || !file.exists(protein_file)) stop("Run RNA and Protein scripts first")

clinical <- fread(INPUT$clinical, data.table = FALSE) |>
  mutate(
    day_num = as.integer(day_num), Time = paste0("D", day_num),
    center = factor(str_extract(SampleName, "^[^_]+")),
    status60 = as.integer(sTatus), sex_num = as.numeric(sex),
    age_z = as.numeric(scale(age)), SOFA_z = as.numeric(scale(SOFA))
  )
rna_expr <- readRDS(rna_file)
protein_expr <- readRDS(protein_file)
hallmark <- gmtPathways(INPUT$hallmark)
names(hallmark) <- str_remove(names(hallmark), "^HALLMARK_")

CORE <- c(
  "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE",
  "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "COAGULATION", "COMPLEMENT",
  "HEME_METABOLISM", "EPITHELIAL_MESENCHYMAL_TRANSITION", "TGF_BETA_SIGNALING",
  "APICAL_JUNCTION", "HYPOXIA", "OXIDATIVE_PHOSPHORYLATION",
  "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS"
)
stopifnot(all(CORE %in% names(hallmark)))

# One-direction rank score. For each sample, features are transformed to fractional ranks;
# the pathway score is mean rank(pathway members)-0.5. Within-time z-scaling below makes
# this affine-equivalent to standard one-direction rank-based single-sample scores.
rank_score_matrix <- function(expr, pathways) {
  ranks <- apply(expr, 2, function(x) rank(x, ties.method = "average", na.last = "keep") / sum(is.finite(x)))
  if (is.vector(ranks)) ranks <- matrix(ranks, ncol = 1, dimnames = dimnames(expr))
  out <- vapply(names(pathways), function(p) {
    idx <- intersect(pathways[[p]], rownames(expr))
    if (length(idx) < 10L) return(rep(NA_real_, ncol(expr)))
    colMeans(ranks[idx, , drop = FALSE], na.rm = TRUE) - 0.5
  }, numeric(ncol(expr)))
  out <- t(out)
  colnames(out) <- colnames(expr)
  out
}

scores_to_long <- function(score, omics) {
  as.data.frame(score) |>
    tibble::rownames_to_column("Pathway") |>
    pivot_longer(-Pathway, names_to = "SampleName", values_to = "Score") |>
    left_join(clinical, by = "SampleName") |>
    group_by(Time, Pathway) |>
    mutate(Score_time_z = as.numeric(scale(Score))) |>
    ungroup() |>
    mutate(Omics = omics)
}

rna_score <- rank_score_matrix(rna_expr, hallmark[CORE]) |> scores_to_long("RNA")
protein_score <- rank_score_matrix(protein_expr, hallmark[CORE]) |> scores_to_long("Protein")

protein_median <- data.frame(
  SampleName = colnames(protein_expr),
  ProteinMedian = apply(protein_expr, 2, median, na.rm = TRUE)
) |>
  left_join(clinical |> select(SampleName, Time), by = "SampleName") |>
  group_by(Time) |>
  mutate(ProteinMedian_time_z = as.numeric(scale(ProteinMedian))) |>
  ungroup()

fwrite(rna_score, file.path(CROSS_OUT, "01_RNA_patient_core_pathway_rank_scores.csv"))
fwrite(protein_score, file.path(CROSS_OUT, "02_Protein_patient_core_pathway_rank_scores.csv"))
fwrite(protein_median, file.path(CROSS_OUT, "03_Protein_sample_global_intensity.csv"))

patient_cov <- clinical |>
  arrange(day_num) |>
  distinct(PatientID, .keep_all = TRUE) |>
  select(PatientID, age_z, SOFA_z, sex_num, status60, surv_time)

same <- rna_score |>
  select(PatientID, Time, Pathway, RNA = Score_time_z) |>
  inner_join(protein_score |> select(PatientID, Time, Pathway, Protein = Score_time_z, SampleName),
             by = c("PatientID", "Time", "Pathway")) |>
  left_join(patient_cov, by = "PatientID") |>
  left_join(protein_median |> select(SampleName, ProteinMedian_time_z), by = "SampleName") |>
  left_join(clinical |> select(SampleName, center), by = "SampleName")

partial_spearman <- function(d) {
  d <- d |> filter(complete.cases(RNA, Protein, age_z, SOFA_z, sex_num, center, ProteinMedian_time_z))
  if (nrow(d) < 30 || sd(d$RNA) == 0 || sd(d$Protein) == 0) {
    return(tibble(N = nrow(d), partial_rho = NA_real_, pval = NA_real_))
  }
  rr <- resid(lm(RNA ~ age_z + SOFA_z + sex_num + center + ProteinMedian_time_z, data = d))
  rp <- resid(lm(Protein ~ age_z + SOFA_z + sex_num + center + ProteinMedian_time_z, data = d))
  ct <- suppressWarnings(cor.test(rr, rp, method = "spearman", exact = FALSE))
  tibble(N = nrow(d), partial_rho = unname(ct$estimate), pval = ct$p.value)
}

same_result <- same |>
  group_by(Time, Pathway) |>
  group_modify(~ partial_spearman(.x)) |>
  ungroup() |>
  group_by(Time) |>
  mutate(FDR = p.adjust(pval, "BH")) |>
  ungroup()
fwrite(same_result, file.path(CROSS_OUT, "04_same_time_RNA_Protein_partial_spearman.csv"))

make_forward <- function(t1, t2) {
  r1 <- rna_score |> filter(Time == t1) |> select(PatientID, Pathway, RNA_t1 = Score_time_z)
  p1 <- protein_score |> filter(Time == t1) |>
    select(PatientID, Pathway, Protein_t1 = Score_time_z, ProteinSample_t1 = SampleName)
  p2 <- protein_score |> filter(Time == t2) |>
    select(PatientID, Pathway, Protein_t2 = Score_time_z, ProteinSample_t2 = SampleName)
  r1 |> inner_join(p1, by = c("PatientID", "Pathway")) |>
    inner_join(p2, by = c("PatientID", "Pathway")) |>
    left_join(patient_cov, by = "PatientID") |>
    left_join(protein_median |> select(ProteinSample_t1 = SampleName, ProteinMedian_t1 = ProteinMedian_time_z),
              by = "ProteinSample_t1") |>
    left_join(protein_median |> select(ProteinSample_t2 = SampleName, ProteinMedian_t2 = ProteinMedian_time_z),
              by = "ProteinSample_t2") |>
    left_join(clinical |> select(ProteinSample_t2 = SampleName, Center_t2 = center), by = "ProteinSample_t2") |>
    filter(surv_time > ifelse(t2 == "D3", 2, 4))
}

robust_term <- function(d, formula, term) {
  vars <- all.vars(formula)
  d <- d[complete.cases(d[, vars, drop = FALSE]), , drop = FALSE]
  if (nrow(d) < 30) return(tibble(N = nrow(d), beta = NA_real_, SE = NA_real_, lower95 = NA_real_, upper95 = NA_real_, pval = NA_real_))
  fit <- lm(formula, data = d)
  co <- lmtest::coeftest(fit, vcov. = sandwich::vcovHC(fit, type = "HC3"))
  b <- co[term, "Estimate"]; se <- co[term, "Std. Error"]
  tibble(N = nrow(d), beta = b, SE = se, lower95 = b - 1.96 * se, upper95 = b + 1.96 * se,
         pval = co[term, "Pr(>|t|)"])
}

forward_one <- function(t1, t2) {
  d <- make_forward(t1, t2)
  d |>
    group_by(Pathway) |>
    group_modify(~ robust_term(
      .x,
      Protein_t2 ~ RNA_t1 + Protein_t1 + age_z + SOFA_z + sex_num + Center_t2 + ProteinMedian_t2,
      "RNA_t1"
    )) |>
    ungroup() |>
    mutate(Direction = paste("RNA", t1, "to Protein", t2), FDR = p.adjust(pval, "BH"))
}
forward <- bind_rows(forward_one("D1", "D3"), forward_one("D3", "D5"))
fwrite(forward, file.path(CROSS_OUT, "05_forward_cross_lag_HC3.csv"))

make_reverse <- function(t1, t2) {
  p1 <- protein_score |> filter(Time == t1) |>
    select(PatientID, Pathway, Protein_t1 = Score_time_z, ProteinSample_t1 = SampleName)
  r1 <- rna_score |> filter(Time == t1) |> select(PatientID, Pathway, RNA_t1 = Score_time_z)
  r2 <- rna_score |> filter(Time == t2) |> select(PatientID, Pathway, RNA_t2 = Score_time_z)
  p1 |> inner_join(r1, by = c("PatientID", "Pathway")) |>
    inner_join(r2, by = c("PatientID", "Pathway")) |>
    left_join(patient_cov, by = "PatientID") |>
    left_join(protein_median |> select(ProteinSample_t1 = SampleName, ProteinMedian_t1 = ProteinMedian_time_z),
              by = "ProteinSample_t1") |>
    left_join(clinical |> select(ProteinSample_t1 = SampleName, Center_t1 = center), by = "ProteinSample_t1") |>
    filter(surv_time > ifelse(t2 == "D3", 2, 4))
}

reverse_one <- function(t1, t2) {
  d <- make_reverse(t1, t2)
  d |>
    group_by(Pathway) |>
    group_modify(~ robust_term(
      .x,
      RNA_t2 ~ Protein_t1 + RNA_t1 + age_z + SOFA_z + sex_num + Center_t1 + ProteinMedian_t1,
      "Protein_t1"
    )) |>
    ungroup() |>
    mutate(Direction = paste("Protein", t1, "to RNA", t2), FDR = p.adjust(pval, "BH"))
}
reverse <- bind_rows(reverse_one("D1", "D3"), reverse_one("D3", "D5"))
fwrite(reverse, file.path(CROSS_OUT, "06_reverse_cross_lag_HC3.csv"))

coverage <- bind_rows(
  tibble(Omics = "RNA", Pathway = CORE, detected = sapply(hallmark[CORE], function(x) sum(x %in% rownames(rna_expr))),
         total = lengths(hallmark[CORE])),
  tibble(Omics = "Protein", Pathway = CORE, detected = sapply(hallmark[CORE], function(x) sum(x %in% rownames(protein_expr))),
         total = lengths(hallmark[CORE]))
) |> mutate(coverage = detected / total)
fwrite(coverage, file.path(CROSS_OUT, "07_core_pathway_feature_coverage.csv"))

saveRDS(list(rna_score = rna_score, protein_score = protein_score, same = same_result,
             forward = forward, reverse = reverse, coverage = coverage),
        file.path(CROSS_OUT, "CrossOmics_reanalysis_objects.rds"), compress = FALSE)
writeLines(capture.output(sessionInfo()), file.path(CROSS_OUT, "sessionInfo_CrossOmics.txt"))

cat("Completed:", format(Sys.time()), "\n")
print(same_result |> filter(FDR < 0.05))
print(forward |> filter(FDR < 0.05))
print(reverse |> filter(FDR < 0.05))
