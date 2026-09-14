options(stringsAsFactors = FALSE, warn = 1)

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, env) {
  hit <- which(args == flag)
  if (length(hit) && hit[1] < length(args)) return(args[hit[1] + 1L])
  Sys.getenv(env, unset = "")
}
availability_file <- arg_value("--availability", "SIC_AVAILABILITY_MATRIX")
protein_gsea_file <- arg_value("--protein-gsea", "SIC_FROZEN_PROTEIN_GSEA")
out_dir <- arg_value("--output", "SIC_A3_OUTPUT_DIR")
if (!file.exists(availability_file) || !file.exists(protein_gsea_file) || !nzchar(out_dir)) {
  stop("Provide controlled availability input, frozen aggregate protein GSEA input and output directory")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

availability <- fread(availability_file)
stopifnot(nrow(availability) == 504L, !anyDuplicated(availability$PatientID), sum(availability$Protein_D1) == 168L)
availability[, center_raw := sub("_.*$", "", SampleName)]
availability[, log2_lactate := log2(lac)]
g <- availability$Protein_D1

smd_continuous <- function(x, g) {
  x1 <- x[g == 1 & !is.na(x)]; x0 <- x[g == 0 & !is.na(x)]
  denom <- sqrt((var(x1) + var(x0)) / 2)
  if (!is.finite(denom) || denom == 0) return(NA_real_)
  (mean(x1) - mean(x0)) / denom
}
smd_binary <- function(x, g) {
  x1 <- x[g == 1 & !is.na(x)]; x0 <- x[g == 0 & !is.na(x)]
  p1 <- mean(x1); p0 <- mean(x0); pbar <- (p1 + p0) / 2
  denom <- sqrt(pbar * (1 - pbar))
  if (!is.finite(denom) || denom == 0) return(NA_real_)
  (p1 - p0) / denom
}
fmt_cont <- function(x) sprintf("%.3f [%.3f, %.3f]", median(x, na.rm = TRUE), quantile(x, .25, na.rm = TRUE), quantile(x, .75, na.rm = TRUE))
fmt_binary <- function(x) sprintf("%d/%d (%.1f%%)", sum(x == 1, na.rm = TRUE), sum(!is.na(x)), 100 * mean(x, na.rm = TRUE))

continuous <- c(age = "age", baseline_SOFA = "SOFA", log2_lactate = "log2_lactate", platelet_count = "plt", PaO2_FiO2_ratio = "pf")
binary <- c(male_sex = "sex", mortality_60d = "sTatus")
rows <- list()
for (label in names(continuous)) {
  x <- availability[[continuous[[label]]]]
  rows[[length(rows) + 1L]] <- data.table(variable = label, type = "continuous",
    measured_N = sum(g == 1 & !is.na(x)), unmeasured_N = sum(g == 0 & !is.na(x)),
    measured_summary = fmt_cont(x[g == 1]), unmeasured_summary = fmt_cont(x[g == 0]), SMD = smd_continuous(x, g))
}
for (label in names(binary)) {
  x <- availability[[binary[[label]]]]
  rows[[length(rows) + 1L]] <- data.table(variable = label, type = "binary",
    measured_N = sum(g == 1 & !is.na(x)), unmeasured_N = sum(g == 0 & !is.na(x)),
    measured_summary = fmt_binary(x[g == 1]), unmeasured_summary = fmt_binary(x[g == 0]), SMD = smd_binary(x, g))
}
for (level in sort(unique(availability$infectionSite_SD))) {
  x <- as.integer(availability$infectionSite_SD == level)
  rows[[length(rows) + 1L]] <- data.table(variable = paste0("infection_source__", gsub("[^A-Za-z0-9]+", "_", level)), type = "binary indicator",
    measured_N = sum(g == 1), unmeasured_N = sum(g == 0), measured_summary = fmt_binary(x[g == 1]),
    unmeasured_summary = fmt_binary(x[g == 0]), SMD = smd_binary(x, g))
}
smd <- rbindlist(rows, fill = TRUE)
smd[, absolute_SMD := abs(SMD)]
fwrite(smd, file.path(out_dir, "A3_D1_protein_measured_vs_unmeasured_SMD.csv"))

centre <- availability[, .(cohort_N = .N, measured_N = sum(Protein_D1)), by = center_raw]
centre[, fraction := measured_N / cohort_N]
distribution <- centre[, .(centres = .N, all_observation_centres = sum(fraction == 1),
  zero_observation_centres = sum(fraction == 0), partial_observation_centres = sum(fraction > 0 & fraction < 1),
  min_fraction = min(fraction), q25_fraction = quantile(fraction, .25), median_fraction = median(fraction),
  q75_fraction = quantile(fraction, .75), max_fraction = max(fraction))]
fwrite(distribution, file.path(out_dir, "A3_centre_measurement_fraction_distribution.csv"))

gsea <- fread(protein_gsea_file)
primary <- gsea[grepl("_center_primary$", analysis), .(Time = sub("_.*", "", analysis), pathway, NES_primary = NES, FDR_primary = padj)]
adjusted <- gsea[grepl("_median_center_sensitivity$", analysis), .(Time = sub("_.*", "", analysis), pathway, NES_adjusted = NES, FDR_adjusted = padj)]
comparison <- merge(primary, adjusted, by = c("Time", "pathway"), all = TRUE)
comparison[, direction_agreement := sign(NES_primary) == sign(NES_adjusted)]
fwrite(comparison, file.path(out_dir, "A3_existing_frozen_protein_primary_vs_global_intensity_sensitivity.csv"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_A3.txt"))
