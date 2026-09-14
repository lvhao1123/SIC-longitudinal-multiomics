#!/usr/bin/env Rscript

# Reviewer-requested finite-permutation diagnostic for the Day-5 protein
# Hallmark EMT/ECM pathway. Primary inference remains the frozen
# fgseaMultilevel result; this diagnostic does not replace or recalibrate it.

suppressPackageStartupMessages({
  library(data.table)
  library(fgsea)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, env, default = NA_character_) {
  hit <- which(args == flag)
  if (length(hit) && hit[1] < length(args)) return(args[hit[1] + 1L])
  value <- Sys.getenv(env, unset = default)
  if (!nzchar(value)) default else value
}

rank_file <- arg_value("--rank-file", "SIC_D5_PROTEIN_RANK_FILE")
gmt_file <- arg_value("--gmt", "SIC_HALLMARK_GMT")
out_dir <- arg_value("--out", "SIC_REVISION_OUTPUT", "revision/aggregate_results/D5_EMT_finite_permutation")
nperm <- as.integer(arg_value("--nperm", "SIC_FINITE_PERMUTATIONS", "10000"))
seed <- as.integer(arg_value("--seed", "SIC_RANDOM_SEED", "20260902"))

if (is.na(rank_file) || is.na(gmt_file)) stop("Provide --rank-file and --gmt, or corresponding environment variables.")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

rank_data <- fread(rank_file)
rank_data <- rank_data[fit_ok == TRUE & is.finite(z) & !is.na(gene_symbol)]
rank_data <- rank_data[!duplicated(gene_symbol)]
stats <- setNames(rank_data$z, rank_data$gene_symbol)
stats <- sort(stats, decreasing = TRUE)

pathways <- gmtPathways(gmt_file)
pathway_id <- "HALLMARK_EPITHELIAL_MESENCHYMAL_TRANSITION"
if (!pathway_id %in% names(pathways)) stop("Hallmark EMT pathway not found in GMT.")
members <- intersect(pathways[[pathway_id]], names(stats))
if (length(members) < 15L) stop("Insufficient detected EMT members.")

observed_es <- calcGseaStat(stats, match(members, names(stats)))
set.seed(seed)
null_es <- replicate(nperm, {
  idx <- sample.int(length(stats), length(members), replace = FALSE)
  calcGseaStat(stats, sort(idx))
})

empirical_p <- (sum(abs(null_es) >= abs(observed_es)) + 1) / (nperm + 1)
draws <- data.table(permutation = seq_len(nperm), ES = as.numeric(null_es))
summary <- data.table(
  pathway = pathway_id,
  detected_members = length(members),
  ranked_features = length(stats),
  observed_ES = observed_es,
  permutations = nperm,
  seed = seed,
  empirical_two_sided_P = empirical_p,
  null_mean = mean(null_es),
  null_sd = sd(null_es),
  null_q025 = unname(quantile(null_es, .025)),
  null_q975 = unname(quantile(null_es, .975)),
  analysis_class = "reviewer-requested finite-permutation diagnostic",
  primary_inference = "Frozen fgseaMultilevel result"
)

fwrite(draws, file.path(out_dir, "SourceData_Supplementary_Figure_S14_D5_EMT_finite_permutation.tsv"), sep = "\t")
fwrite(summary, file.path(out_dir, "D5_EMT_finite_permutation_summary.tsv"), sep = "\t")
writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo_D5_EMT_finite_permutation.txt"))
print(summary)
