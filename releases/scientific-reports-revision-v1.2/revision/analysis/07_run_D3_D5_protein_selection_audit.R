#!/usr/bin/env Rscript

# Reviewer-requested descriptive audit of plasma-proteomic measurement at the
# later landmarks. No weighting or outcome model is fitted. Only aggregate,
# public-safe results are exported.

suppressPackageStartupMessages({
  library(data.table)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, env, default = NA_character_) {
  hit <- which(args == flag)
  if (length(hit) && hit[1] < length(args)) return(args[hit[1] + 1L])
  value <- Sys.getenv(env, unset = default)
  if (!nzchar(value)) default else value
}
clinical_file <- arg_value("--clinical", "SIC_CLINICAL_ANNOTATION")
protein_score_file <- arg_value("--protein-scores", "SIC_PROTEIN_SCORES")
out_dir <- arg_value("--out", "SIC_REVISION_OUTPUT", "revision/aggregate_results/protein_selection_audit")
if (is.na(clinical_file) || is.na(protein_score_file)) stop("Provide --clinical and --protein-scores.")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

clinical_long <- fread(clinical_file)
clinical_long[, center := sub("_.*$", "", SampleName)]
baseline <- clinical_long[day_num == 1]
stopifnot(!anyDuplicated(baseline$PatientID))
protein <- fread(protein_score_file, select = c("PatientID", "Time"))
protein <- unique(protein)

smd_cont <- function(x, g) {
  a <- x[g == 1 & is.finite(x)]; b <- x[g == 0 & is.finite(x)]
  if (length(a) < 2 || length(b) < 2) return(NA_real_)
  den <- sqrt((var(a) + var(b)) / 2)
  if (!is.finite(den) || den == 0) return(NA_real_)
  (mean(a) - mean(b)) / den
}
smd_bin <- function(x, g) {
  a <- x[g == 1 & !is.na(x)]; b <- x[g == 0 & !is.na(x)]
  if (!length(a) || !length(b)) return(NA_real_)
  p1 <- mean(a == 1); p0 <- mean(b == 1)
  den <- sqrt((p1 * (1 - p1) + p0 * (1 - p0)) / 2)
  if (!is.finite(den) || den == 0) return(NA_real_)
  (p1 - p0) / den
}

audit_landmark <- function(time, entry) {
  measured_ids <- protein[Time == time, PatientID]
  d <- copy(baseline[surv_time > entry])
  d[, measured := as.integer(PatientID %in% measured_ids)]
  d[, subsequent_death := as.integer(sTatus == 1 & surv_time > entry)]
  centre_counts <- d[, .(observed = sum(measured), eligible = .N), by = center]
  centre_counts[, support := as.integer(observed > 0)]
  d <- merge(d, centre_counts[, .(center, centre_support = support)], by = "center", all.x = TRUE)

  cont <- list(age = d$age, baseline_SOFA = d$SOFA, baseline_lactate = d$lac)
  bin <- list(sex_male = d$sex, subsequent_60_day_death = d$subsequent_death,
              empirical_centre_support = d$centre_support)
  rows <- rbindlist(c(
    lapply(names(cont), function(v) data.table(variable = v, level = NA_character_,
                                                SMD = smd_cont(cont[[v]], d$measured))),
    lapply(names(bin), function(v) data.table(variable = v, level = NA_character_,
                                               SMD = smd_bin(bin[[v]], d$measured)))
  ), fill = TRUE)
  for (lev in sort(unique(d$infectionSite_SD))) {
    rows <- rbind(rows, data.table(variable = "infection_source", level = lev,
                                   SMD = smd_bin(as.integer(d$infectionSite_SD == lev), d$measured)), fill = TRUE)
  }
  rows[, `:=`(
    Time = time,
    entry_day = entry,
    risk_eligible_N = nrow(d),
    measured_N = sum(d$measured),
    unmeasured_N = sum(d$measured == 0),
    max_absolute_SMD = max(abs(SMD), na.rm = TRUE),
    analysis_class = "reviewer-requested descriptive proteomic-selection audit"
  )]

  centre_public <- centre_counts[, .(
    Time = time,
    entry_day = entry,
    eligible_patients = sum(eligible),
    measured_patients = sum(observed),
    empirical_centres = .N,
    zero_observation_centres = sum(observed == 0),
    partial_observation_centres = sum(observed > 0 & observed < eligible),
    all_observation_centres = sum(observed == eligible),
    minimum_positive_fraction = min(observed[observed > 0] / eligible[observed > 0]),
    median_fraction = median(observed / eligible),
    maximum_fraction = max(observed / eligible)
  )]
  list(smd = rows, centre = centre_public)
}

res <- list(audit_landmark("D3", 2), audit_landmark("D5", 4))
smd <- rbindlist(lapply(res, `[[`, "smd"), fill = TRUE)
centre <- rbindlist(lapply(res, `[[`, "centre"), fill = TRUE)
mapping <- data.table(
  parent_recruiting_hospitals_reported = 43L,
  empirical_analytic_center_prefixes_in_fixed_D1_SIC_cohort = uniqueN(baseline$center),
  exact_hospital_to_prefix_mapping_available = FALSE,
  interpretation = "The deidentified analytical field supports 30 empirical prefix strata; a one-to-one mapping to the 43 parent recruitment hospitals is unavailable and is not inferred."
)

fwrite(smd, file.path(out_dir, "D3_D5_protein_measured_vs_unmeasured_SMD.tsv"), sep = "\t", na = "NA")
fwrite(centre, file.path(out_dir, "D3_D5_protein_centre_support_summary.tsv"), sep = "\t", na = "NA")
fwrite(mapping, file.path(out_dir, "parent_hospital_analytic_strata_audit.tsv"), sep = "\t")
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_protein_selection_audit.txt"))
print(centre)
print(mapping)
