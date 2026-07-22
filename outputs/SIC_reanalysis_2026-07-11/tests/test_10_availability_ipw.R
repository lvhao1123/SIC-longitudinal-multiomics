source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
source("outputs/SIC_reanalysis_2026-07-11/code/10a_availability_ipw_helpers.R")
assert_avail_packages()

suppressPackageStartupMessages({library(data.table); library(dplyr)})
logcpm <- readRDS(file.path(RNA_OUT, "RNA_TMM_logCPM_gene_by_sample.rds"))
clinical <- fread(INPUT$clinical, data.table = FALSE)
base <- prepare_availability_base(clinical, colnames(logcpm))
d5_ids <- base$PatientID[base$RNA_D5_available == 1L]

expected <- list(
  lower = c(structural_N = 11, risk_N = 493, support_N = 489, observed_N = 321, unobserved_N = 168, observed_events = 54),
  primary = c(structural_N = 13, risk_N = 491, support_N = 487, observed_N = 320, unobserved_N = 167, observed_events = 53),
  upper = c(structural_N = 13, risk_N = 491, support_N = 487, observed_N = 320, unobserved_N = 167, observed_events = 53)
)
audits <- Map(function(e, nm) {
  a <- build_entry_cohort(e, base, d5_ids)
  got <- unlist(a$counts[names(expected[[nm]])], use.names = TRUE)
  stopifnot(identical(as.numeric(got), as.numeric(expected[[nm]])))
  a
}, AVAIL_ENTRY, names(AVAIL_ENTRY))

a4 <- audits$primary
stopifnot(nrow(base) == 504, sum(base$event) == 84)
stopifnot(sum(a4$centres$class == "zero") == 3)
stopifnot(sum(a4$centres$class == "all") == 13)
stopifnot(sum(a4$centres$class == "partial") == 14)
miss <- audit_missingness(a4$supported, "primary")
stopifnot(sum(miss$missing_N) == 0)

protein_qc <- fread(file.path(PROTEIN_OUT, "00_Protein_sample_QC.csv"), data.table = FALSE)
pn <- audit_protein_nesting(protein_qc, base)
stopifnot(pn$D1_N == 168, pn$D3_N == 148, pn$D5_N == 115)
stopifnot(pn$D3_not_D1 == 0, pn$D5_not_D1 == 0, pn$D5_not_D3 == 0)
stopifnot(pn$D5_risk_valid_N == 114, pn$D5_post_entry_events == 14)

z <- transform_availability_covariates(a4$supported)
partial <- z[z$centre_class == "partial", ]
stopifnot(abs(mean(partial$age_z)) < 1e-10, abs(sd(partial$age_z) - 1) < 1e-10)
stopifnot(all(is.finite(partial$log2_lac_z)), all(is.finite(partial$log2_plt_z)))

dims <- c(SOFA_D3 = 26, SOFA_noD3 = 25, PF_PLT_D3 = 27, PF_PLT_noD3 = 26)
for (spec in names(dims)) {
  pre <- prefit_availability_audit(z, spec)
  stopifnot(pre$summary$N == 427, pre$summary$observed == 260, pre$summary$unobserved == 167)
  stopifnot(pre$summary$parameters == dims[[spec]], pre$summary$rank == dims[[spec]])
  stopifnot(!pre$summary$rank_deficient, !pre$summary$separation)
  w <- fit_observation_weights(a4$supported, spec)
  stopifnot(all(w$data$raw_probability[w$data$centre_class == "all"] == 1))
  stopifnot(all(w$data$raw_weight[w$data$centre_class == "all" & w$data$available == 1] == 1))
  stopifnot(abs(mean(w$data$analysis_weight[w$data$available == 1]) - 1) < 1e-10)
  stopifnot(all(is.finite(w$data$analysis_weight[w$data$available == 1])))
}

w <- fit_observation_weights(a4$supported, "SOFA_D3")
md <- w$data |>
  filter(available == 1L) |>
  select(-SampleName) |>
  left_join(clinical |> filter(day_num == 5) |> select(PatientID, SampleName), by = "PatientID") |>
  mutate(entry = 4, center = droplevels(factor(center)))
smoke <- run_weighted_cox_matrix(logcpm[seq_len(20), , drop = FALSE], md, run_ph = TRUE, workers = 1L)
needed <- c("gene_symbol", "beta", "HR", "robust_SE", "z", "pval", "converged",
            "finite_beta", "finite_robust_SE", "fit_valid", "warning_text", "PH_success", "PH_p")
stopifnot(nrow(smoke) == 20, all(needed %in% names(smoke)))
stopifnot(all(smoke$fit_valid), all(is.finite(smoke$z)))
cat("All Day-5 availability/IPW helper tests passed.\n")
