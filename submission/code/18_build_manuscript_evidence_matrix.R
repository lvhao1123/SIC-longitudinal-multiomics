#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/") else normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
REPO_ROOT <- normalizePath(file.path(CLOSEOUT, ".."), winslash = "/")
source(file.path(REPO_ROOT, "outputs", "SIC_reanalysis_2026-07-11", "code", "00_config.R"))
suppressPackageStartupMessages({library(data.table); library(stringr)})
MAN <- file.path(CLOSEOUT, "manuscript_support")
truth <- fread(file.path(CLOSEOUT, "numeric_truth_table.tsv"))

display_path <- function(x) {
  labels <- c(
    TNFA_SIGNALING_VIA_NFKB = "TNF-α signaling via NF-κB", IL6_JAK_STAT3_SIGNALING = "IL-6/JAK/STAT3 signaling",
    MYC_TARGETS_V1 = "MYC targets V1", MYC_TARGETS_V2 = "MYC targets V2", E2F_TARGETS = "E2F targets",
    DNA_REPAIR = "DNA repair", MTORC1_SIGNALING = "mTORC1 signaling",
    INTERFERON_ALPHA_RESPONSE = "IFN-α response", INTERFERON_GAMMA_RESPONSE = "IFN-γ response",
    REACTIVE_OXYGEN_SPECIES_PATHWAY = "Reactive oxygen species pathway",
    OXIDATIVE_PHOSPHORYLATION = "Oxidative phosphorylation",
    EPITHELIAL_MESENCHYMAL_TRANSITION = "Epithelial–mesenchymal transition"
  )
  z <- unname(labels[x]); miss <- is.na(z)
  z[miss] <- str_to_sentence(str_replace_all(x[miss], "_", " "))
  z
}
tr <- function(k) {
  x <- truth[key == k]
  if (nrow(x) != 1L) stop("Truth key missing or duplicated: ", k)
  x
}
value_string <- function(k, digits = 6) {
  x <- tr(k)
  if (!is.na(x$value_num[1])) formatC(x$value_num[1], format = "fg", digits = digits) else x$value_text[1]
}
rows <- list(); idx <- 0L
add_claim <- function(section, subsection, claim_text, value, unit, effect_direction = "not applicable",
                      confidence_interval = "", FDR_or_P = "", keys, figure_or_table,
                      permitted, prohibited, source_key = keys[1]) {
  idx <<- idx + 1L
  s <- tr(source_key)
  rows[[idx]] <<- data.table(
    claim_id = sprintf("C%04d", idx), section, subsection, claim_text, value = as.character(value), unit,
    effect_direction, confidence_interval, FDR_or_P, numeric_truth_key = paste(keys, collapse = ";"),
    source_file = s$source_file[1], source_row_or_filter = s$filter[1], figure_or_table,
    permitted_interpretation = permitted, prohibited_interpretation = prohibited
  )
}

# Cohort, risk sets and availability hierarchy.
count_specs <- list(
  c("availability.primary.source_N", "Day-1 SIC source cohort", "Figure 1a"),
  c("samples.RNA.D1.risk_valid_n", "Day-1 RNA risk-valid sample count", "Figure 1b"),
  c("samples.RNA.D3.matched_n", "Day-3 raw measured RNA sample count", "Figure 1b"),
  c("samples.RNA.D3.risk_valid_n", "Day-3 delayed-entry risk-valid RNA sample count", "Figure 1b"),
  c("samples.RNA.D5.matched_n", "Day-5 raw measured RNA sample count", "Figure 1b"),
  c("samples.RNA.D5.risk_valid_n", "Day-5 delayed-entry risk-valid RNA sample count", "Figure 1b"),
  c("availability.primary.risk_N", "Day-5 landmark survivors", "Figure 1c"),
  c("availability.primary.support_N", "Day-5 positivity-supported estimand", "Figure 1c"),
  c("availability.primary.observed_N", "Observed day-5 RNA in the estimand", "Figure 1c"),
  c("availability.primary.unobserved_N", "Unobserved day-5 RNA in the estimand", "Figure 1c"),
  c("availability.primary.structural_N", "Deaths at or before the day-5 entry landmark", "Figure 1d"),
  c("availability.primary.centres_zero", "Zero-observation centres", "Figure 1e")
)
for (z in count_specs) add_claim("Results", "Cohort and risk sets", z[2], value_string(z[1], 8), tr(z[1])$unit,
  keys = z[1], figure_or_table = z[3], permitted = "Report the specified patient or centre count using its exact population definition.",
  prohibited = "Do not interchange raw measured, risk-valid, landmark, estimand, patient and centre counts.")
zero_n <- as.numeric(tr("availability.primary.risk_N")$value_num) - as.numeric(tr("availability.primary.support_N")$value_num)
add_claim("Results", "Cohort and risk sets", "Patients from zero-observation centres excluded from the positivity-supported estimand",
  zero_n, "patients", keys = c("availability.primary.risk_N", "availability.primary.support_N", "availability.primary.centres_zero"),
  figure_or_table = "Figure 1d; Figure 1 legend", permitted = "State that four patients from three zero-observation centres were excluded.",
  prohibited = "Do not state that three patients were excluded or that four centres had zero observation.")

# RNA primary and PH-pass sensitivity evidence.
core_rna <- c("TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE", "COMPLEMENT", "COAGULATION",
              "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "EPITHELIAL_MESENCHYMAL_TRANSITION", "APICAL_JUNCTION",
              "HYPOXIA", "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS", "OXIDATIVE_PHOSPHORYLATION", "HEME_METABOLISM",
              "MYC_TARGETS_V1", "MYC_TARGETS_V2", "E2F_TARGETS", "DNA_REPAIR", "MTORC1_SIGNALING", "UNFOLDED_PROTEIN_RESPONSE")
for (tm in c("D1","D3","D5")) for (p in core_rna) {
  nk <- paste("rna", tm, p, "NES_TMM_Primary", sep = "."); fk <- paste("rna", tm, p, "padj_TMM_Primary", sep = ".")
  if (nk %in% truth$key) add_claim("Results", "RNA core pathways", paste(tm, display_path(p), "primary mortality-association enrichment"),
    value_string(nk), "NES", ifelse(as.numeric(tr(nk)$value_num) > 0, "positive", "negative"), "", paste0("BH-FDR=", value_string(fk)),
    c(nk,fk), "Figure 2; SourceData_Figure2_RNA.tsv", "Interpret as pathway-level association with subsequent mortality in the time-specific model.",
    "Do not interpret NES as absolute pathway activation or a causal mechanism.")
  nks <- paste("rna", tm, p, "NES_TMM_PH_pass", sep = "."); fks <- paste("rna", tm, p, "padj_TMM_PH_pass", sep = ".")
  if (nks %in% truth$key) add_claim("Sensitivity", "RNA PH-pass GSEA", paste(tm, display_path(p), "PH-pass sensitivity enrichment"),
    value_string(nks), "NES", ifelse(as.numeric(tr(nks)$value_num) > 0, "positive", "negative"), "", paste0("BH-FDR=", value_string(fks)),
    c(nks,fks), "Supplementary RNA Hallmark table", "Use to assess sensitivity to nominal PH violations.",
    "Do not claim that Figure 2 asterisks encode PH-pass significance.")
}

# Protein primary plus PH/global-intensity sensitivity evidence.
core_protein <- c("HYPOXIA", "GLYCOLYSIS", "FATTY_ACID_METABOLISM", "OXIDATIVE_PHOSPHORYLATION", "MYC_TARGETS_V1",
                  "MTORC1_SIGNALING", "PROTEIN_SECRETION", "COMPLEMENT", "EPITHELIAL_MESENCHYMAL_TRANSITION",
                  "MYOGENESIS", "UNFOLDED_PROTEIN_RESPONSE")
for (tm in c("D1","D3","D5")) for (analysis_suffix in c("center_primary", "center_PHpass", "median_center")) for (p in core_protein) {
  a <- paste0(tm, "_", analysis_suffix); nk <- paste("protein", a, p, "NES", sep = "."); fk <- paste("protein", a, p, "padj", sep = ".")
  if (!nk %in% truth$key) next
  is_primary <- analysis_suffix == "center_primary"
  add_claim(ifelse(is_primary, "Results", "Sensitivity"), ifelse(is_primary, "Protein core pathways", "Protein PH/global-intensity sensitivity"),
    paste(tm, display_path(p), analysis_suffix, "mortality-association enrichment"), value_string(nk), "NES",
    ifelse(as.numeric(tr(nk)$value_num) > 0, "positive", "negative"), "", paste0("BH-FDR=", value_string(fk)), c(nk,fk),
    ifelse(is_primary, "Figure 3; SourceData_Figure3_Protein.tsv", "Supplementary protein Hallmark table"),
    ifelse(is_primary, "Interpret as the displayed primary plasma-protein mortality association.", "Use only as the named sensitivity analysis."),
    ifelse(is_primary, "Do not claim that Figure 3 asterisks encode PH or global-intensity robustness.", "Do not replace the primary analysis or infer absolute protein pathway activity."))
}

# Same-time cross-omics.
same <- truth[domain == "cross_same_time"]
same[, c("x1","x2","Time","Pathway","metric") := tstrsplit(key, "\\.", fixed = FALSE)]
samew <- dcast(same, Time + Pathway ~ metric, value.var = "value_num")
for (i in seq_len(nrow(samew))) {
  r <- samew[i]; rk <- paste("cross.same", r$Time, r$Pathway, "partial_rho", sep="."); fk <- paste("cross.same", r$Time, r$Pathway, "FDR", sep=".")
  add_claim("Results", "Same-time cross-omics", paste(r$Time, display_path(r$Pathway), "same-time RNA–protein association"),
    value_string(rk), "partial Spearman rho", ifelse(r$partial_rho > 0, "positive", "negative"), "", paste0("BH-FDR=", value_string(fk)),
    c(rk,fk), "Figure 4a; SourceData_Figure4A_same_time.tsv", "Interpret as adjusted contemporaneous cross-compartment association.",
    "Do not interpret as mortality association, causality or translation lag.")
}

# Frozen forward and reverse models with CI.
for (kind in c("forward","reverse")) {
  f <- unique(truth[domain == paste0("cross_",kind), source_file])
  d <- fread(f)
  for (i in seq_len(nrow(d))) {
    z <- d[i]; base <- paste("cross", kind, make.names(z$Direction), z$Pathway, sep=".")
    bk <- paste0(base,".beta"); lk <- paste0(base,".lower95"); uk <- paste0(base,".upper95"); fk <- paste0(base,".FDR")
    add_claim("Results", ifelse(kind=="forward", "Forward cross-omics", "Reverse cross-omics"), paste(z$Direction, display_path(z$Pathway)),
      value_string(bk), "standardized coefficient", ifelse(z$beta > 0, "positive", "negative"),
      paste0("[", value_string(lk), ", ", value_string(uk), "]"), paste0("BH-FDR=", value_string(fk)), c(bk,lk,uk,fk),
      ifelse(kind=="forward",
             paste0(ifelse(grepl("D1",z$Direction), "Figure 4b", "Figure 4c"),
                    ifelse(z$Pathway %in% c("INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE"), "; Figure 4f", "")),
             "Figure 4d"),
      ifelse(kind=="forward", "Interpret as adjusted forward temporal cross-compartment association.", "Interpret as the prespecified reverse-direction check."),
      "Do not infer causal transfer, mediation or translation lag.")
  }
}

# OXPHOS attenuation rows are already normalized into the truth layer.
ox <- truth[domain == "cross_oxphos_attenuation"]
for (i in seq_len(nrow(ox))) add_claim("Results", "OXPHOS centre attenuation", ox$key[i], ifelse(is.na(ox$value_num[i]), ox$value_text[i], formatC(ox$value_num[i], format="fg", digits=6)), ox$unit[i],
  effect_direction = ifelse(!is.na(ox$value_num[i]) && ox$value_num[i] > 0, "positive", ifelse(!is.na(ox$value_num[i]) && ox$value_num[i] < 0, "negative", "not applicable")),
  keys = ox$key[i], source_key = ox$key[i], figure_or_table = "Figure 4e; SourceData_Figure4E_OXPHOS_attenuation.tsv",
  permitted = "Use to document attenuation after centre adjustment.", prohibited = "Do not retain the unadjusted OXPHOS result as robust after attenuation.")

# Availability diagnostics and all six Hallmark-comparison scenarios.
avail_keys <- c("availability.weight.primary__SOFA_D3.min_probability", "availability.weight.primary__SOFA_D3.max_raw_weight",
                "availability.weight.primary__SOFA_D3.ESS_ratio", "availability.weight.primary__SOFA_D3.max_abs_SMD_after",
                "availability.cox.entry4_SOFA_D3.genes_entering_GSEA")
for (k in avail_keys) add_claim("Results", "Day-5 availability/IPW", k, value_string(k), tr(k)$unit, keys=k,
  figure_or_table="Supplementary Figures A2–A3; Supplementary availability tables",
  permitted="Report as a diagnostic of the prespecified IPW sensitivity analysis.", prohibited="Do not claim that weighting eliminated selection bias or completely balanced covariates.")
cmp <- truth[domain == "availability_hallmark_comparison"]
for (i in seq_len(nrow(cmp))) add_claim("Sensitivity", "Weighted versus unweighted Hallmark comparison", cmp$key[i],
  formatC(cmp$value_num[i], format="fg", digits=6), cmp$unit[i], keys=cmp$key[i], source_key=cmp$key[i],
  figure_or_table="Supplementary Figures A4 and A6", permitted="Use as complete-Hallmark concordance evidence for the named prespecified scenario.",
  prohibited="Do not choose the numerically best scenario post hoc or replace the unweighted primary analysis.")

evidence <- rbindlist(rows, fill=TRUE)
stopifnot(!anyDuplicated(evidence$claim_id), all(nzchar(evidence$source_file)), all(nzchar(evidence$numeric_truth_key)))
fwrite(evidence, file.path(MAN, "manuscript_evidence_matrix.tsv"), sep="\t", na="")
writeLines(capture.output(sessionInfo()), file.path(MAN, "sessionInfo_evidence_matrix.txt"), useBytes=TRUE)
cat("Manuscript evidence matrix created:", nrow(evidence), "claims.\n")
