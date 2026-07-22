#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/") else normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
REPO_ROOT <- normalizePath(file.path(CLOSEOUT, ".."), winslash = "/")
source(file.path(REPO_ROOT, "outputs", "SIC_reanalysis_2026-07-11", "code", "00_config.R"))
suppressPackageStartupMessages(library(data.table))
PROJECT <- REPO_ROOT
MAN <- file.path(CLOSEOUT, "manuscript_support")
dir.create(MAN, recursive = TRUE, showWarnings = FALSE)
truth <- fread(file.path(CLOSEOUT, "numeric_truth_table.tsv"))

val <- function(k) {
  x <- truth[truth$key == k]
  if (nrow(x) != 1L) stop("Truth key is missing or duplicated: ", k)
  if (!is.na(x$value_num[1])) return(x$value_num[1])
  x$value_text[1]
}
num <- function(key, digits = NULL) {
  z <- val(key)
  if (is.null(digits)) digits <- truth$precision[match(key, truth$key)]
  formatC(as.numeric(z), format = "f", digits = digits, big.mark = ",")
}
pct <- function(key, digits = 1) paste0(num(key, digits), "%")
pc <- function(key, digits = 1) paste0(formatC(100 * as.numeric(val(key)), format = "f", digits = digits), "%")
write_md <- function(name, lines) writeLines(lines, file.path(MAN, name), useBytes = TRUE)

n0 <- num("availability.primary.source_N", 0)
structural <- num("availability.primary.structural_N", 0)
landmark <- num("availability.primary.risk_N", 0)
estimand <- num("availability.primary.support_N", 0)
observed <- num("availability.primary.observed_N", 0)
unobserved <- num("availability.primary.unobserved_N", 0)
events <- num("availability.primary.observed_events", 0)
czero <- num("availability.primary.centres_zero", 0)
call <- num("availability.primary.centres_all", 0)
cpart <- num("availability.primary.centres_partial", 0)
zero_patients <- formatC(as.numeric(val("availability.primary.risk_N")) - as.numeric(val("availability.primary.support_N")), format = "f", digits = 0)
stopifnot(zero_patients == "4", czero == "3")
entry <- num("analysis.entry.RNA.D5", 0)
horizon <- num("analysis.followup_horizon", 0)
fdr <- num("analysis.fdr_threshold", 2)
ph <- num("analysis.ph_nominal_threshold", 2)
trimlo <- pc("analysis.weight_trim_lower_quantile", 0)
trimhi <- pc("analysis.weight_trim_upper_quantile", 0)
genes <- num("availability.cox.entry4_SOFA_D3.genes_entering_GSEA", 0)
minp <- num("availability.weight.primary__SOFA_D3.min_probability", 5)
maxw <- num("availability.weight.primary__SOFA_D3.max_raw_weight", 2)
essr <- num("availability.weight.primary__SOFA_D3.ESS_ratio", 3)
smd <- num("availability.weight.primary__SOFA_D3.max_abs_SMD_after", 3)
rho <- num("availability.comparison.entry4_SOFA_D3.spearman_NES", 3)
agree <- pc("availability.comparison.entry4_SOFA_D3.direction_agreement", 1)
jacc <- num("availability.comparison.entry4_SOFA_D3.significant_set_jaccard", 2)

methods <- c(
  "# Methods production text — frozen analysis",
  "",
  "## Study population and longitudinal molecular sampling",
  "",
  sprintf("This secondary longitudinal multi-omics analysis included %s patients who met the SIC definition at day 1. Whole-blood RNA and plasma-protein measurements were linked to baseline clinical variables, study centre and %s-day mortality. Day-1, day-3 and day-5 molecular measurements were analysed in separate time-specific prognostic models. Day-3 and day-5 analyses used delayed entry at the corresponding prespecified sampling landmarks.", n0, horizon),
  "",
  "## Time-specific prognostic molecular models",
  "",
  "At each time point, molecular features were standardized to one standard deviation within the analysis set. Gene- and protein-wise Cox models used `Surv(entry, stop, event)` with Efron handling of tied event times and study-centre stratification. Cox Wald statistics provided the complete ranked feature lists for Hallmark gene-set enrichment. Proportional-hazards diagnostics used scaled Schoenfeld residuals with the Kaplan–Meier time transformation. The primary GSEA retained all successfully estimated features; a prespecified sensitivity analysis repeated GSEA using features with nominal PH-test P values at or above the frozen threshold. Hallmark enrichment used the complete ranked lists, prespecified gene-set size limits and BH correction within each time point and analysis family. Mortality-association NES values were interpreted as prognostic enrichment statistics, not as direct measurements of absolute pathway activity.",
  "",
  "## Day-5 RNA availability estimand and inverse-observation-probability weighting",
  "",
  sprintf("The primary availability estimand comprised patients from the day-1 SIC cohort who survived beyond the day-%s landmark and came from centres with empirical support for day-5 RNA observation. Deaths at or before entry were classified as structural non-availability and were reported separately; IPW was not used to reconstruct post-mortem molecular states. Centres with zero observations were excluded from this estimand, centres with complete observation were assigned observation probability and weight equal to one, and probabilities were estimated only in partially observing centres.", entry),
  "",
  "The prespecified primary availability model contained baseline SOFA and prior day-3 RNA availability together with the frozen low-collinearity pre-sampling covariates. The internal implementation label `SOFA_D3` refers to this combination and must not be interpreted as a contemporaneous SOFA measurement. A prespecified model omitting prior day-3 RNA availability, a model replacing baseline SOFA with P/F ratio and platelet count, its corresponding no-day-3-availability variant, and lower- and upper-entry-boundary scenarios were retained as sensitivity analyses; no post hoc model replacement was permitted.",
  "",
  sprintf("Unstabilised inverse observation probabilities were defined as the reciprocal of the estimated observation probability. Weights were truncated at the %s and %s percentiles and then normalized to mean one among observed patients. The weighted delayed-entry Cox model was `Surv(%s, surv_time, event) ~ gene_z + strata(center)`. Because the installed survival implementation required a cluster or id for its delayed-entry robust variance path, the frozen analysis used the same weighted partial-likelihood coefficients with an observation-level Lin–Wei sandwich variance computed from weighted dfbeta residuals. The implementation was separately verified against a model assigning a unique cluster to every row.", trimlo, trimhi, entry),
  "",
  sprintf("The IPW analysis was explicitly treated as a sensitivity analysis. All %s converged gene estimates were ranked by the weighted robust Wald statistic and entered Hallmark GSEA. Weighted and unweighted day-5 results were compared across the complete Hallmark family using NES rank correlation, direction agreement and significant-set Jaccard overlap. The prespecified interpretation was that IPW remained limited by positivity and residual covariate imbalance and therefore did not replace the unweighted centre-stratified primary analysis.", genes),
  "",
  "## Cross-omic analyses",
  "",
  "Patient-level RNA and protein pathway scores were evaluated in contemporaneous and forward cross-time models adjusted according to the frozen analysis specification. Forward models additionally controlled for the preceding protein score, and reverse protein-to-RNA models were retained as directionality checks. OXPHOS estimates before and after centre adjustment were shown to document attenuation. These analyses quantify cross-compartment temporal association and do not establish causal RNA-to-protein transfer.",
  "",
  "## Reproducibility and privacy",
  "",
  "The submission-freeze overlay reads frozen statistical outputs and a single numeric truth table. It does not refit the primary Cox, IPW or GSEA analyses. Public source-data tables contain only aggregate, pathway-level or feature-level results and exclude patient identifiers, traceable sample identifiers, individual observation probabilities and individual weights. Complete clinical and molecular data require controlled access through the CMEISE data-governance process."
)
write_md("Methods_production.md", methods)

results <- c(
  "# Results production text — frozen analysis",
  "",
  "## Longitudinal risk sets and the day-5 availability estimand",
  "",
  sprintf("The source cohort comprised %s patients. At the day-%s landmark, %s patients remained alive; %s deaths at or before entry were structural non-availability. After exclusion of %s zero-observation centres, the positivity-supported estimand comprised %s patients, of whom %s had observed and %s had unobserved day-5 RNA. The observed subset included %s subsequent deaths. The empirical centre distribution comprised %s zero-observation, %s complete-observation and %s partial-observation centres.", n0, entry, landmark, structural, czero, estimand, observed, unobserved, events, czero, call, cpart),
  "",
  "## Day-5 availability/IPW sensitivity analysis",
  "",
  sprintf("In the prespecified primary availability model, the minimum estimated observation probability was %s and the maximum raw inverse-observation weight was %s. After frozen truncation and mean normalization, the effective-sample-size ratio was %s and the maximum weighted absolute standardized mean difference was %s. The latter indicates meaningful residual imbalance, dominated by prior day-3 RNA availability, and the diagnostic classification was caution rather than pass.", minp, maxw, essr, smd),
  "",
  sprintf("All %s gene models converged, yielded finite robust standard errors and entered GSEA. Despite the positivity and residual-balance limitations, weighted and unweighted Hallmark profiles were highly concordant: NES Spearman correlation was %s, pathway-direction agreement was %s and the significant-set Jaccard index was %s. Thus, IPW supported the overall day-5 pathway pattern as a sensitivity analysis but did not eliminate selection bias or supersede the unweighted centre-stratified primary result.", genes, rho, agree, jacc),
  "",
  "## Longitudinal transcriptomic and proteomic prognostic programs",
  "",
  "The frozen RNA results showed time-specific mortality-association programs: early erythroid/heme, hypoxic and thromboinflammatory enrichment; a day-3 inflammatory–oxidative pattern; and day-5 negative enrichment of mitochondrial, proteostatic and reparative programs. Plasma-protein results were complementary rather than globally concordant and showed persistent extracellular-matrix/tissue-remodelling signals across the later course. These are pathway-level mortality associations and should not be interpreted as direct pathway activation measurements or causal transitions.",
  "",
  "## Selective cross-omic coupling",
  "",
  "Same-time and forward models identified interferon-related pathways as the most reproducible cross-compartment signals. Reverse protein-to-RNA models did not show a corresponding FDR-significant pattern, whereas apparent OXPHOS coupling was attenuated after centre adjustment. The integrated Figure 4 therefore presents contemporaneous associations, both prespecified forward intervals, reverse models, OXPHOS attenuation and interferon effect estimates without selecting new models or pathways for display."
)
write_md("Results_production.md", results)

limitations <- c(
  "# Limitations production text — frozen analysis",
  "",
  "This observational secondary analysis identifies prognostic molecular associations and temporal ordering but cannot establish causality. It lacks an independent external cohort, and the later plasma-protein analyses contain relatively few subsequent deaths.",
  "",
  "Day-5 molecular availability remains an important source of selection. IPW could not completely remove this bias: three zero-observation centres were outside the weighted estimand, prior day-3 RNA availability remained materially imbalanced, and unmeasured sampling determinants may still have influenced observation. The weights were therefore classified as caution. IPW cannot reconstruct day-5 molecular states after death and cannot address structural non-availability. Accurate sample-collection timestamps and a reliable protocol-eligibility field were unavailable, so the operational estimand was restricted to landmark survivors in centres with empirical positivity support.",
  "",
  "The primary availability model included baseline SOFA and prior day-3 RNA availability; the latter is not a contemporaneous SOFA measure. The scenario without prior day-3 availability yielded better numerical balance for some covariates but was not allowed to replace the prespecified primary model. All six prespecified scenarios and entry-boundary checks are reported.",
  "",
  "Whole-blood RNA and plasma proteins arise from different cellular and tissue compartments. Discordance may therefore reflect cellular composition, secretion, tissue release, vascular leakage, consumption or clearance rather than analytical failure. Hallmark labels such as epithelial–mesenchymal transition, allograft rejection and heme metabolism require interpretation through their leading-edge members and do not directly prove histological EndMT, transplant rejection, haemolysis or free-heme toxicity.",
  "",
  "The dataset lacks complete longitudinal coagulation phenotype measurements and direct endothelial, glycocalyx, NET, thrombin-generation and fibrinolysis markers. Consequently, the molecular results cannot establish transition between clinical hypercoagulable and hypocoagulable states or validate a specific intervention target. Complete patient-level data are controlled-access because of clinical privacy; public source data are de-identified and exclude individual observation probabilities and weights."
)
write_md("Limitations_production.md", limitations)

legends <- c(
  "# Production figure legends",
  "",
  "## Figure 1 | Study design, longitudinal risk sets and day-5 availability estimand.",
  sprintf("a, Longitudinal design linking the day-1 SIC cohort (n=%s) to subsequent %s-day mortality. b, Raw measured and delayed-entry risk-valid RNA and plasma-protein samples at each time point; values are presented as raw measured/risk-valid. c, Day-5 hierarchy from landmark survivors (n=%s) to the positivity-supported estimand (n=%s), with observed (n=%s) and unobserved (n=%s) RNA. d, Structural deaths at or before the day-%s entry (n=%s) and patients from zero-observation centres (n=%s). Four patients from three zero-observation centres were excluded from the positivity-supported estimand. e, Empirical centre-positivity classes. Raw measured, risk-valid and availability populations are intentionally shown separately.", n0, horizon, landmark, estimand, observed, unobserved, entry, structural, zero_patients),
  "",
  "## Figure 2 | Time-specific whole-blood prognostic programs.",
  sprintf("Centre-stratified, time-specific Cox Wald ranks were analysed by Hallmark GSEA. Tiles show mortality-association NES from the displayed primary analysis. Asterisks encode primary-analysis BH-FDR only: * BH-FDR < %s, ** BH-FDR < 0.01 and *** BH-FDR < 0.001. PH-pass sensitivity results are retained in the source data and supplementary tables but are not encoded by the asterisks. NES values describe prognostic enrichment rather than absolute pathway activity. Source data are provided as a Source Data file.", fdr),
  "",
  "## Figure 3 | Time-specific plasma-protein prognostic programs.",
  sprintf("Tiles show Hallmark mortality-association NES from the displayed primary centre-stratified plasma-protein Cox analysis. Asterisks encode primary-analysis BH-FDR only: * BH-FDR < %s, ** BH-FDR < 0.01 and *** BH-FDR < 0.001. PH-pass and global-intensity sensitivity results remain available in source data and supplementary tables but are not encoded by the asterisks. No patient-level protein abundance is included in public source data. Source data are provided as a Source Data file.", fdr),
  "",
  "## Figure 4 | Pathway-selective contemporaneous and forward cross-omic associations.",
  "a, Same-time adjusted RNA–protein partial correlations. b, Forward RNA day 1 to protein day 3 coefficients with 95% confidence intervals. c, Forward RNA day 3 to protein day 5 coefficients with 95% confidence intervals. d, Reverse protein-to-RNA models. e, OXPHOS association estimates before and after centre adjustment. f, Interferon forward-effect estimates and 95% confidence intervals. Asterisks indicate BH-adjusted significance from the frozen result tables. These associations do not demonstrate causal molecular transfer.",
  "",
  "## Supplementary availability figures",
  "Supplementary Figures A1–A8 display centre positivity, observation-probability and weight distributions, covariate balance before and after weighting, complete-Hallmark weighted versus unweighted NES, core-pathway results across all six prespecified scenarios, scenario-level robustness metrics, entry-boundary sensitivity and descriptive day-5 protein availability. Each figure has a corresponding aggregate source-data table; no patient identifier or individual weight is released."
)
write_md("Figure_legends_production.md", legends)

supp_fig_legends <- c(
  "# Supplementary figure legends",
  "",
  "## Supplementary Figure A1 | Empirical centre positivity for day-5 RNA availability.",
  sprintf("Centre-level counts of observed and unobserved day-5 RNA among day-%s landmark survivors are shown for the prespecified lower, primary and upper entry definitions. Centres were classified as zero observation, complete observation or partial observation. In the primary definition, %s zero-observation, %s complete-observation and %s partial-observation centres were identified. Zero-observation centres were outside the IPW estimand; complete-observation centres received observation probability and weight equal to one. Centre labels describe study sites and do not identify individual patients. Source data are provided as a Source Data file.", entry, czero, call, cpart),
  "",
  "## Supplementary Figure A2 | Observation-probability and inverse-observation-weight distributions.",
  sprintf("Aggregate histograms show estimated day-5 RNA observation probabilities and analysis weights across all six prespecified availability scenarios. The primary model included baseline SOFA and prior day-3 RNA availability; alternative models and entry-boundary scenarios were retained without post hoc replacement. Unstabilised inverse observation weights were truncated at the %s and %s percentiles and normalized to mean one among observed patients. Histograms contain no individual probability or weight. Extreme probabilities and weights indicate potential positivity limitations. Source data are provided as a Source Data file.", trimlo, trimhi),
  "",
  "## Supplementary Figure A3 | Covariate balance before and after inverse-observation weighting.",
  sprintf("Absolute and signed standardized mean differences (SMDs) are shown before and after weighting for all prespecified scenarios. Dashed reference lines mark |SMD|=0.10. The primary model retained a maximum weighted |SMD| of %s, indicating residual imbalance; the plot is therefore a diagnostic rather than evidence that weighting eliminated selection bias. Source data are provided as a Source Data file.", smd),
  "",
  "## Supplementary Figure A4 | Comparison of unweighted and IPW Hallmark enrichment.",
  sprintf("Each point compares day-5 mortality-association NES from the frozen unweighted centre-stratified primary analysis with NES from a prespecified weighted scenario across the complete Hallmark family. Colour denotes the joint FDR classification based on BH-FDR <%s. The primary weighted scenario showed an NES Spearman correlation of %s, direction agreement of %s and significant-set Jaccard index of %s relative to the unweighted analysis. Concordance supports sensitivity of the overall pathway pattern but does not remove availability bias. Source data are provided as a Source Data file.", fdr, rho, agree, jacc),
  "",
  "## Supplementary Figure A5 | Core pathways across prespecified IPW scenarios.",
  "Heat-map cells show weighted day-5 mortality-association NES for the prespecified core Hallmark pathways across all six availability scenarios. Original Hallmark pathway identifiers were retained in source data, whereas display names were standardized for the manuscript. The panel compares robustness across frozen scenarios and must not be used to select a replacement primary model. Source data are provided as a Source Data file.",
  "",
  "## Supplementary Figure A6 | Scenario-level Hallmark robustness metrics.",
  "NES Spearman correlation, pathway-direction agreement and significant-set Jaccard overlap compare each weighted scenario with the frozen unweighted day-5 primary analysis. Metrics cover the complete Hallmark family and all six prespecified scenarios. Better numerical diagnostics in an alternative scenario do not authorize replacement of the prespecified primary availability model. Source data are provided as a Source Data file.",
  "",
  "## Supplementary Figure A7 | Day-5 entry-boundary sensitivity.",
  sprintf("Core-pathway mortality-association NES values are compared across the prespecified lower, primary and upper day-5 entry boundaries. The primary landmark was day %s; boundary scenarios evaluate coding sensitivity only and do not redefine the main estimand. Source data are provided as a Source Data file.", entry),
  "",
  "## Supplementary Figure A8 | Descriptive availability of day-5 plasma proteomics.",
  "Raw measured and delayed-entry risk-valid plasma-protein sample counts are shown across days 1, 3 and 5. This audit is descriptive: no protein availability weights were estimated, and the figure does not imply recovery of unobserved protein states. Source data are provided as a Source Data file."
)
write_md("Supplementary_figure_legends_production.md", supp_fig_legends)

table_specs <- list(
  Entry_risksets = c("Entry-specific risk sets for day-5 RNA availability", "Day-1 SIC cohort under lower, primary and upper day-5 entry definitions.", "N, number of patients; entry, landmark time; observed events, subsequent deaths among observed RNA samples.", "No weighting or FDR is applied.", "Structural deaths are reported but cannot be recovered by IPW."),
  Centre_positivity = c("Centre-level empirical positivity audit", "Landmark survivors classified within each study centre.", "Observed and unobserved are counts of day-5 RNA availability; centre class is zero, complete or partial observation.", "Only partial-observation centres contribute estimated observation probabilities; complete-observation centres receive weight 1.", "Zero-observation centres lie outside the IPW estimand."),
  Time_origin_audit = c("Survival-time origin and 60-day censoring audit", "Patients contributing to the day-5 availability workflow.", "Entry and stop times use the day-1 study origin; boundary events and administrative censoring are tabulated.", "No weighting or FDR is applied.", "The audit cannot replace unavailable exact specimen-collection timestamps."),
  Covariate_missingness = c("Availability-covariate missingness audit", "Positivity-supported landmark population before availability-model fitting.", "Variables are prespecified baseline or prior-availability covariates; missing counts and handling rules are reported.", "No silent complete-case deletion was permitted.", "Unmeasured sampling determinants may remain."),
  Protein_availability = c("Descriptive day-5 protein availability and nesting audit", "Patients with plasma-protein measurements across days 1, 3 and 5.", "Matched N and risk-valid N distinguish raw measurement from delayed-entry eligibility.", "No protein IPW or FDR is applied.", "This descriptive audit does not correct protein-sampling selection."),
  Prefit_diagnostics = c("Availability-model prefit rank and separation diagnostics", "Patients in partial-observation centres used for probability-model estimation.", "The table reports observed/unobserved counts, parameter count, model-matrix rank and separation indicators.", "Diagnostics precede weight estimation.", "Sparse centre/covariate patterns limit positivity even when the model fits."),
  Weight_diagnostics = c("Inverse-observation-weight diagnostics", "Observed day-5 RNA samples in each prespecified scenario.", "Probability, raw weight, truncated normalized weight, effective sample size (ESS) and SMD summaries are reported.", sprintf("Weights are unstabilised, truncated at %s/%s and normalized to mean 1.", trimlo, trimhi), "The primary scenario is classified as caution because positivity and residual balance remain limited."),
  Balance_SMD = c("Covariate balance before and after weighting", "Positivity-supported landmark population under all six scenarios.", "SMD, standardized mean difference; signed and absolute values are reported before and after weighting.", "Weighting follows the frozen scenario-specific inverse-observation procedure.", "SMD improvement does not prove removal of selection bias."),
  Transform_constants = c("Frozen availability-covariate transformations", "Prespecified variables used in availability models.", "The table records centring, scaling, logarithmic transforms and fixed factor levels.", "Transformations were frozen before model fitting.", "Constants are implementation metadata, not clinical cut-points."),
  Cox_PH_audit = c("Weighted Cox convergence and PH audit", "Observed day-5 RNA samples analysed under each weighted scenario.", "PH, proportional hazards; robust SE, Lin–Wei sandwich standard error; genes entering GSEA are counted.", sprintf("PH-pass sensitivity used nominal P≥%s; Hallmark significance used BH-FDR <%s.", ph, fdr), "The audit validates computation but does not establish causal effects."),
  Hallmark_all_models = c("Weighted Hallmark GSEA across all prespecified scenarios", "Complete weighted Cox Wald ranks for day-5 RNA under six scenarios.", "NES, normalized enrichment score; ES, enrichment score; size, mapped gene-set size.", sprintf("P values were BH-adjusted within the complete Hallmark family; significance threshold BH-FDR <%s.", fdr), "NES represents mortality association, not absolute pathway activity."),
  Hallmark_leading_edges = c("Leading-edge genes for weighted Hallmark enrichment", "Scenario- and pathway-specific leading-edge subsets from frozen weighted GSEA.", "Gene symbols and original Hallmark IDs are preserved.", "FDR definitions follow the parent Hallmark analysis.", "Leading-edge membership is exploratory and does not identify causal driver genes."),
  Hallmark_comparison = c("Complete-Hallmark comparison of unweighted and IPW analyses", "Frozen unweighted day-5 primary RNA GSEA compared with each weighted scenario.", "The table includes paired NES, direction and FDR classifications for every pathway.", sprintf("Significance sets use BH-FDR <%s in the corresponding complete Hallmark family.", fdr), "IPW is a sensitivity analysis and does not replace the unweighted primary analysis."),
  Scenario_metrics = c("Summary robustness metrics for six availability scenarios", "All complete-Hallmark pathway pairs comparing weighted and unweighted analyses.", "Spearman NES correlation, direction agreement and significant-set Jaccard overlap are reported.", sprintf("Significant sets use BH-FDR <%s.", fdr), "High concordance does not imply complete covariate balance or absence of selection bias."),
  Frozen_internal_QA = c("Frozen availability/IPW internal QA", "Implementation checks for the final availability workflow.", "Each row records a prespecified check, observed value and pass status.", "QA thresholds follow the frozen design.", "Passing implementation QA does not remove design-level positivity limitations.")
)
table_caption_lines <- c("# Supplementary table captions", "")
for (nm in names(table_specs)) {
  z <- table_specs[[nm]]
  table_caption_lines <- c(table_caption_lines,
    paste0("## Worksheet `", nm, "` | ", z[1], "."), "",
    paste0("**Population/analysis definition:** ", z[2]), "",
    paste0("**Variables and abbreviations:** ", z[3]), "",
    paste0("**Weighting/FDR definition:** ", z[4]), "",
    paste0("**Interpretation limitation:** ", z[5]), "")
}
write_md("Supplementary_table_captions_production.md", table_caption_lines)

terminology <- data.table(
  canonical_term = c("TNF-α signaling via NF-κB", "IL-6/JAK/STAT3 signaling", "MYC targets V1", "E2F targets", "DNA repair", "mTORC1 signaling", "time-specific prognostic models"),
  original_identifier_or_variant = c("TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "MYC_TARGETS_V1", "E2F_TARGETS", "DNA_REPAIR", "MTORC1_SIGNALING", "deprecated longitudinal-exposure wording"),
  decision = c(rep("Standardize display label; retain original Hallmark ID in source data", 6), "Use for separate day-specific Cox analyses; prohibit single-model time-dependent wording")
)
fwrite(terminology, file.path(MAN, "terminology_ledger.tsv"), sep = "\t")

abstract <- c(
  "# Abstract numeric stub — not final prose",
  "",
  sprintf("Among %s day-1 SIC patients, delayed-entry longitudinal RNA and plasma-protein analyses were linked to %s-day mortality.", n0, horizon),
  sprintf("The day-5 RNA sensitivity estimand included %s patients in positivity-supported centres; %s had observed RNA and %s subsequent deaths.", estimand, observed, events),
  sprintf("IPW diagnostics were classified as caution (ESS/observed=%s; maximum weighted |SMD|=%s), but weighted and unweighted Hallmark profiles remained highly concordant (NES Spearman=%s; direction agreement=%s; significant-set Jaccard=%s).", essr, smd, rho, agree, jacc),
  "The frozen biological conclusion is stage-specific RNA prognostic remodelling, persistent plasma extracellular-matrix/tissue-remodelling signals and selective interferon-centred cross-compartment coupling."
)
write_md("Abstract_numeric_stub.md", abstract)

# Project-facing pointers are rewritten as UTF-8 production indexes, not as a
# second results tree.
writeLines(c(
  "# SIC frozen manuscript figure index", "",
  "The submission-ready four-figure architecture is stored in `07_Freeze_Closeout/figures/`.", "",
  "- Figure 1: study design, risk sets and day-5 availability estimand.",
  "- Figure 2 (`Figure2_RNA_core_NES`): frozen RNA Hallmark mortality-association results.",
  "- Figure 3 (`Figure3_Protein_core_NES`): frozen plasma-protein Hallmark mortality-association results.",
  "- Figure 4: integrated A–F cross-omic analysis.", "",
  "No Figure 5 is part of the main manuscript. Numeric labels must be sourced from `07_Freeze_Closeout/numeric_truth_table.tsv`."
), file.path(PROJECT, "FIGURE_LEGENDS_DRAFT.md"), useBytes = TRUE)

writeLines(c(
  "# 冻结结果与投稿生产说明", "",
  "正式统计结果位于既有冻结输出；`07_Freeze_Closeout/`仅为投稿冻结覆盖层，不重新拟合或替代底层统计结果。", "",
  "## 运行顺序", "",
  "1. `11_build_canonical_archive_and_truth.R`：建立canonical索引与唯一数字真值。",
  "2. `12_run_sandwich_equivalence_test.R`：仅验证sandwich实现等价性。",
  "3. `13_make_submission_figures.R`：读取数字真值生成四张主图与八张availability补充图。",
  "4. `14_build_manuscript_text.R`：读取数字真值生成Methods、Results、Limitations及图注生产文本。",
  "5. 后续QA与manifest脚本：验证数字、语言、隐私、图形和哈希一致性。", "",
  "不得将内部模型名`SOFA_D3`写作Day 3 SOFA；其含义是基线SOFA加既往D3 RNA availability。"
), file.path(PROJECT, "README_REPRODUCE_CN.md"), useBytes = TRUE)

writeLines(capture.output(sessionInfo()), file.path(MAN, "sessionInfo_manuscript_production.txt"), useBytes = TRUE)
cat("Manuscript production text created from numeric truth table only.\n")
