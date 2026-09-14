#!/usr/bin/env Rscript

# Reviewer-requested post hoc centre-sensitivity analysis.
# This script does not replace the frozen centre-adjusted cross-omic analysis.
# It fits the same 15-pathway model family with and without centre adjustment,
# then exports aggregate results only. Participant-level inputs remain local.

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(sandwich)
  library(lmtest)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, env, default = NA_character_) {
  hit <- which(args == flag)
  if (length(hit) && hit[1] < length(args)) return(args[hit[1] + 1L])
  value <- Sys.getenv(env, unset = default)
  if (!nzchar(value)) default else value
}

cross_dir <- arg_value("--crossomics-dir", "SIC_CROSSOMICS_DIR")
clinical_file <- arg_value("--clinical", "SIC_CLINICAL_ANNOTATION")
out_dir <- arg_value("--out", "SIC_REVISION_OUTPUT", "revision/aggregate_results/IFN_centre_sensitivity")

if (is.na(cross_dir) || is.na(clinical_file)) {
  stop("Provide --crossomics-dir and --clinical, or set SIC_CROSSOMICS_DIR and SIC_CLINICAL_ANNOTATION.")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

CORE <- c(
  "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE",
  "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "COAGULATION", "COMPLEMENT",
  "HEME_METABOLISM", "EPITHELIAL_MESENCHYMAL_TRANSITION", "TGF_BETA_SIGNALING",
  "APICAL_JUNCTION", "HYPOXIA", "OXIDATIVE_PHOSPHORYLATION",
  "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS"
)
SELECTED <- c("INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "OXIDATIVE_PHOSPHORYLATION")

rna <- fread(file.path(cross_dir, "01_RNA_patient_core_pathway_rank_scores.csv"), data.table = FALSE)
protein <- fread(file.path(cross_dir, "02_Protein_patient_core_pathway_rank_scores.csv"), data.table = FALSE)
protein_median <- fread(file.path(cross_dir, "03_Protein_sample_global_intensity.csv"), data.table = FALSE)
clinical <- fread(clinical_file, data.table = FALSE)
# Base assignments avoid a recursive-evaluation defect observed in the
# project-locked development build of dplyr on this Windows/R 4.4 runtime.
clinical$day_num <- as.integer(clinical$day_num)
clinical$Time <- paste0("D", clinical$day_num)
clinical$center <- factor(sub("_.*$", "", clinical$SampleName))
clinical$sex_num <- as.numeric(clinical$sex)
clinical$age_z <- as.numeric(scale(clinical$age))
clinical$SOFA_z <- as.numeric(scale(clinical$SOFA))

stopifnot(all(CORE %in% unique(rna$Pathway)), all(CORE %in% unique(protein$Pathway)))

patient_cov <- clinical |>
  arrange(day_num) |>
  distinct(PatientID, .keep_all = TRUE) |>
  select(PatientID, age_z, SOFA_z, sex_num, surv_time)

same <- rna |>
  select(PatientID, Time, Pathway, RNA = Score_time_z) |>
  inner_join(protein |> select(PatientID, Time, Pathway, Protein = Score_time_z, SampleName),
             by = c("PatientID", "Time", "Pathway")) |>
  left_join(patient_cov, by = "PatientID") |>
  left_join(protein_median |> select(SampleName, ProteinMedian_time_z), by = "SampleName") |>
  left_join(clinical |> select(SampleName, center), by = "SampleName")

same_fit <- function(d, with_center) {
  required <- c("RNA", "Protein", "age_z", "SOFA_z", "sex_num", "ProteinMedian_time_z")
  if (with_center) required <- c(required, "center")
  d <- d[complete.cases(d[, required, drop = FALSE]), , drop = FALSE]
  if (nrow(d) < 30L || sd(d$RNA) == 0 || sd(d$Protein) == 0) {
    return(tibble(N = nrow(d), estimate = NA_real_, lower95 = NA_real_, upper95 = NA_real_, pval = NA_real_))
  }
  rhs <- c("age_z", "SOFA_z", "sex_num", "ProteinMedian_time_z", if (with_center) "center")
  f_rna <- reformulate(rhs, response = "RNA")
  f_protein <- reformulate(rhs, response = "Protein")
  rr <- resid(lm(f_rna, data = d))
  rp <- resid(lm(f_protein, data = d))
  ct <- suppressWarnings(cor.test(rr, rp, method = "spearman", exact = FALSE))
  tibble(N = nrow(d), estimate = unname(ct$estimate), lower95 = NA_real_, upper95 = NA_real_, pval = ct$p.value)
}

same_results <- bind_rows(lapply(c(FALSE, TRUE), function(with_center) {
  same |>
    filter(Pathway %in% CORE) |>
    group_by(Time, Pathway) |>
    group_modify(~ same_fit(.x, with_center)) |>
    ungroup() |>
    group_by(Time) |>
    mutate(FDR = p.adjust(pval, method = "BH")) |>
    ungroup() |>
    mutate(
      analysis = "Same-time partial Spearman",
      centre_adjustment = ifelse(with_center, "With centre", "Without centre"),
      interval = Time,
      variance = "Spearman test; confidence interval not estimated"
    )
}))

make_forward <- function(t1, t2) {
  r1 <- rna |> filter(Time == t1) |> select(PatientID, Pathway, RNA_t1 = Score_time_z)
  p1 <- protein |> filter(Time == t1) |> select(PatientID, Pathway, Protein_t1 = Score_time_z)
  p2 <- protein |> filter(Time == t2) |> select(PatientID, Pathway, Protein_t2 = Score_time_z, ProteinSample_t2 = SampleName)
  r1 |>
    inner_join(p1, by = c("PatientID", "Pathway")) |>
    inner_join(p2, by = c("PatientID", "Pathway")) |>
    left_join(patient_cov, by = "PatientID") |>
    left_join(protein_median |> select(ProteinSample_t2 = SampleName, ProteinMedian_t2 = ProteinMedian_time_z),
              by = "ProteinSample_t2") |>
    left_join(clinical |> select(ProteinSample_t2 = SampleName, Center_t2 = center), by = "ProteinSample_t2") |>
    filter(surv_time > ifelse(t2 == "D3", 2, 4))
}

forward_fit <- function(d, with_center) {
  rhs <- c("RNA_t1", "Protein_t1", "age_z", "SOFA_z", "sex_num", "ProteinMedian_t2",
           if (with_center) "Center_t2")
  f <- reformulate(rhs, response = "Protein_t2")
  d <- d[complete.cases(d[, all.vars(f), drop = FALSE]), , drop = FALSE]
  if (nrow(d) < 30L) {
    return(tibble(N = nrow(d), estimate = NA_real_, lower95 = NA_real_, upper95 = NA_real_, pval = NA_real_))
  }
  fit <- lm(f, data = d)
  co <- lmtest::coeftest(fit, vcov. = sandwich::vcovHC(fit, type = "HC3"))
  b <- unname(co["RNA_t1", "Estimate"])
  se <- unname(co["RNA_t1", "Std. Error"])
  tibble(N = nrow(d), estimate = b, lower95 = b - 1.96 * se, upper95 = b + 1.96 * se,
         pval = unname(co["RNA_t1", "Pr(>|t|)"]))
}

forward_results <- bind_rows(lapply(list(c("D1", "D3"), c("D3", "D5")), function(pair) {
  d <- make_forward(pair[1], pair[2])
  bind_rows(lapply(c(FALSE, TRUE), function(with_center) {
    d |>
      filter(Pathway %in% CORE) |>
      group_by(Pathway) |>
      group_modify(~ forward_fit(.x, with_center)) |>
      ungroup() |>
      mutate(
        FDR = p.adjust(pval, method = "BH"),
        analysis = "Forward linear model",
        centre_adjustment = ifelse(with_center, "With centre", "Without centre"),
        interval = paste0(pair[1], " to ", pair[2]),
        variance = "HC3"
      )
  }))
}))

all_results <- bind_rows(same_results, forward_results) |>
  select(analysis, interval, centre_adjustment, Pathway, N, estimate, lower95, upper95, pval, FDR, variance) |>
  arrange(analysis, interval, Pathway, centre_adjustment)

selected_results <- all_results |>
  filter(Pathway %in% SELECTED) |>
  mutate(
    analysis_class = "reviewer-requested post hoc centre-sensitivity analysis",
    primary_status = ifelse(centre_adjustment == "With centre", "Matches frozen centre-adjusted specification", "Post hoc comparator")
  )

fwrite(all_results, file.path(out_dir, "IFN_centre_sensitivity_all_15_pathways.tsv"), sep = "\t", na = "NA")
fwrite(selected_results, file.path(out_dir, "SourceData_Supplementary_Figure_S13_IFN_centre_sensitivity.tsv"), sep = "\t", na = "NA")
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_IFN_centre_sensitivity.txt"))

cat("Completed reviewer-requested post hoc centre-sensitivity analysis.\n")
print(selected_results)
