# Supplementary table captions

## Supplementary Table S1 | Clinical variable definitions, transformations and prespecified data handling.

**Population/analysis definition:** Day-1 SIC cohort and clinical-data audit supporting Table 1 and the exploratory clinical Cox analysis.

**Variables and abbreviations:** The workbook contains the clinical variable dictionary, infection-source mapping, variables excluded for incomplete baseline observations and the aggregate sparse-event audit. SIC, sepsis-induced coagulopathy.

**Weighting/FDR definition:** Definitions and audit outputs only; no weighting, multiplicity correction or new inferential model is introduced.

**Interpretation limitation:** The workbook documents prespecified processing and does not provide time-updated Day-3 or Day-5 clinical physiology.

## Supplementary Table S2 | Exploratory clinical univariable Cox regression results.

**Population/analysis definition:** 504 patients meeting the Day-1 SIC definition, including 84 deaths within 60 days.

**Variables and abbreviations:** All 41 displayed contrasts are reported with HR, 95% CI, nominal P value, BH-FDR, PH diagnostic, nonlinearity diagnostic and sparse-event flags. HR, hazard ratio; CI, confidence interval; PH, proportional hazards.

**Weighting/FDR definition:** Separate univariable Cox models used Efron handling of ties; BH correction was applied across all displayed contrasts. Infection source was also assessed using an overall likelihood-ratio test.

**Interpretation limitation:** Associations provide descriptive clinical context and are not independent predictors, causal effects or covariate-selection criteria for molecular models.

## Supplementary Table S3 | Time-specific RNA gene-wise Cox and proportional-hazards results.

**Population/analysis definition:** Risk-valid whole-blood RNA-seq samples at Days 1, 3 and 5, analysed in separate landmark-specific survival models.

**Variables and abbreviations:** All gene-wise centre-stratified Cox estimates, Wald-z statistics, BH-FDR values and exact PH diagnostics are provided together with model diagnostics.

**Weighting/FDR definition:** Models used Surv(entry, stop, event) ~ gene_z + strata(centre), Efron ties and delayed entry at the prespecified Day-3 and Day-5 sampling landmarks. BH-FDR was applied across gene-wise estimates within each time point.

**Interpretation limitation:** Gene-wise associations are exploratory prognostic rankings and do not establish independent biomarkers or causal mechanisms.

## Supplementary Table S4 | RNA Hallmark GSEA and leading-edge results.

**Population/analysis definition:** Complete time-specific RNA Cox Wald-z rankings at Days 1, 3 and 5.

**Variables and abbreviations:** Primary and PH-pass Hallmark results, complete leading-edge genes and GSEA diagnostics are supplied. NES, normalised enrichment score; GSEA, gene-set enrichment analysis.

**Weighting/FDR definition:** fgseaMultilevel was applied against the complete Hallmark family; BH-FDR was calculated within each time point and analysis family.

**Interpretation limitation:** NES encodes enrichment along mortality-associated rankings, not absolute pathway activation or longitudinal change in expression.

## Supplementary Table S5 | Time-specific plasma protein Cox and proportional-hazards results.

**Population/analysis definition:** Risk-valid plasma proteomic samples at Days 1, 3 and 5.

**Variables and abbreviations:** All centre-stratified primary and sample-median-adjusted sensitivity models, PH diagnostics and model diagnostics are reported.

**Weighting/FDR definition:** Separate landmark-specific Cox models used centre stratification; protein abundance was standardised within each time point. BH-FDR was applied across protein-wise estimates within each model family.

**Interpretation limitation:** Later protein analyses have limited subsequent events, especially Day 5, and are interpreted at pathway level as hypothesis-generating evidence.

## Supplementary Table S6 | Plasma protein Hallmark GSEA and leading-edge results.

**Population/analysis definition:** Complete protein-wise Cox Wald-z rankings from primary and prespecified sensitivity models.

**Variables and abbreviations:** All Hallmark model results, complete leading-edge proteins and GSEA diagnostics are supplied.

**Weighting/FDR definition:** fgseaMultilevel was used with BH-FDR correction within each time point and model family.

**Interpretation limitation:** The Hallmark epithelial–mesenchymal transition label is interpreted as extracellular-matrix/tissue-remodelling enrichment when supported by its protein leading edge, not as proof of a cellular transition.

## Supplementary Table S7 | Contemporaneous, forward and reverse-order cross-omic pathway models.

**Population/analysis definition:** Patients with matched whole-blood RNA and plasma protein pathway scores for the relevant time point or interval.

**Variables and abbreviations:** Adjusted contemporaneous partial Spearman correlations, forward RNA-to-later-protein models, reverse-order protein-to-later-RNA models and feature coverage are reported.

**Weighting/FDR definition:** Prespecified clinical and technical adjustment was used with BH-FDR correction within each model family; forward models condition on the prior protein score.

**Interpretation limitation:** Temporal asymmetry is an observational cross-compartment association and does not establish causal transfer, translation lag or mediation.

## Supplementary Table S8 | Day-5 RNA availability/IPW diagnostics and Hallmark comparisons.

**Population/analysis definition:** Day-5 landmark survivors from centres with empirical positivity support; structural pre-landmark deaths are reported separately.

**Variables and abbreviations:** The workbook contains all six prespecified scenarios, centre positivity, weight diagnostics, covariate balance, Cox/PH audit, complete Hallmark results, leading edges, entry-boundary sensitivity and descriptive Day-5 protein availability. IPW, inverse-probability weighting; SMD, standardised mean difference.

**Weighting/FDR definition:** Non-stabilised inverse observation probability weights used prespecified truncation and mean normalisation; delayed-entry weighted Cox inference used an observation-level Lin–Wei sandwich variance. Hallmark BH-FDR was calculated within each prespecified analysis family.

**Interpretation limitation:** The sensitivity analysis is constrained by positivity and residual imbalance, excludes zero-observation centres from its estimand and cannot reconstruct molecular states after death.

## Worksheet `Entry_risksets` | Entry-specific risk sets for day-5 RNA availability.

**Population/analysis definition:** Day-1 SIC cohort under lower, primary and upper day-5 entry definitions.

**Variables and abbreviations:** N, number of patients; entry, landmark time; observed events, subsequent deaths among observed RNA samples.

**Weighting/FDR definition:** No weighting or FDR is applied.

**Interpretation limitation:** Structural deaths are reported but cannot be recovered by IPW.

## Worksheet `Centre_positivity` | Centre-level empirical positivity audit.

**Population/analysis definition:** Landmark survivors classified within each study centre.

**Variables and abbreviations:** Observed and unobserved are counts of day-5 RNA availability; centre class is zero, complete or partial observation.

**Weighting/FDR definition:** Only partial-observation centres contribute estimated observation probabilities; complete-observation centres receive weight 1.

**Interpretation limitation:** Zero-observation centres lie outside the IPW estimand.

## Worksheet `Time_origin_audit` | Survival-time origin and 60-day censoring audit.

**Population/analysis definition:** Patients contributing to the day-5 availability workflow.

**Variables and abbreviations:** Entry and stop times use the day-1 study origin; boundary events and administrative censoring are tabulated.

**Weighting/FDR definition:** No weighting or FDR is applied.

**Interpretation limitation:** The audit cannot replace unavailable exact specimen-collection timestamps.

## Worksheet `Covariate_missingness` | Availability-covariate missingness audit.

**Population/analysis definition:** Positivity-supported landmark population before availability-model fitting.

**Variables and abbreviations:** Variables are prespecified baseline or prior-availability covariates; missing counts and handling rules are reported.

**Weighting/FDR definition:** No silent complete-case deletion was permitted.

**Interpretation limitation:** Unmeasured sampling determinants may remain.

## Worksheet `Protein_availability` | Descriptive day-5 protein availability and nesting audit.

**Population/analysis definition:** Patients with plasma-protein measurements across days 1, 3 and 5.

**Variables and abbreviations:** Matched N and risk-valid N distinguish raw measurement from delayed-entry eligibility.

**Weighting/FDR definition:** No protein IPW or FDR is applied.

**Interpretation limitation:** This descriptive audit does not correct protein-sampling selection.

## Worksheet `Prefit_diagnostics` | Availability-model prefit rank and separation diagnostics.

**Population/analysis definition:** Patients in partial-observation centres used for probability-model estimation.

**Variables and abbreviations:** The table reports observed/unobserved counts, parameter count, model-matrix rank and separation indicators.

**Weighting/FDR definition:** Diagnostics precede weight estimation.

**Interpretation limitation:** Sparse centre/covariate patterns limit positivity even when the model fits.

## Worksheet `Weight_diagnostics` | Inverse-observation-weight diagnostics.

**Population/analysis definition:** Observed day-5 RNA samples in each prespecified scenario.

**Variables and abbreviations:** Probability, raw weight, truncated normalized weight, effective sample size (ESS) and SMD summaries are reported.

**Weighting/FDR definition:** Weights are unstabilised, truncated at 1%/99% and normalized to mean 1.

**Interpretation limitation:** The primary scenario is classified as caution because positivity and residual balance remain limited.

## Worksheet `Balance_SMD` | Covariate balance before and after weighting.

**Population/analysis definition:** Positivity-supported landmark population under all six scenarios.

**Variables and abbreviations:** SMD, standardized mean difference; signed and absolute values are reported before and after weighting.

**Weighting/FDR definition:** Weighting follows the frozen scenario-specific inverse-observation procedure.

**Interpretation limitation:** SMD improvement does not prove removal of selection bias.

## Worksheet `Transform_constants` | Frozen availability-covariate transformations.

**Population/analysis definition:** Prespecified variables used in availability models.

**Variables and abbreviations:** The table records centring, scaling, logarithmic transforms and fixed factor levels.

**Weighting/FDR definition:** Transformations were frozen before model fitting.

**Interpretation limitation:** Constants are implementation metadata, not clinical cut-points.

## Worksheet `Cox_PH_audit` | Weighted Cox convergence and PH audit.

**Population/analysis definition:** Observed day-5 RNA samples analysed under each weighted scenario.

**Variables and abbreviations:** PH, proportional hazards; robust SE, Lin–Wei sandwich standard error; genes entering GSEA are counted.

**Weighting/FDR definition:** PH-pass sensitivity used nominal P≥0.05; Hallmark significance used BH-FDR <0.05.

**Interpretation limitation:** The audit validates computation but does not establish causal effects.

## Worksheet `Hallmark_all_models` | Weighted Hallmark GSEA across all prespecified scenarios.

**Population/analysis definition:** Complete weighted Cox Wald ranks for day-5 RNA under six scenarios.

**Variables and abbreviations:** NES, normalized enrichment score; ES, enrichment score; size, mapped gene-set size.

**Weighting/FDR definition:** P values were BH-adjusted within the complete Hallmark family; significance threshold BH-FDR <0.05.

**Interpretation limitation:** NES represents mortality association, not absolute pathway activity.

## Worksheet `Hallmark_leading_edges` | Leading-edge genes for weighted Hallmark enrichment.

**Population/analysis definition:** Scenario- and pathway-specific leading-edge subsets from frozen weighted GSEA.

**Variables and abbreviations:** Gene symbols and original Hallmark IDs are preserved.

**Weighting/FDR definition:** FDR definitions follow the parent Hallmark analysis.

**Interpretation limitation:** Leading-edge membership is exploratory and does not identify causal driver genes.

## Worksheet `Hallmark_comparison` | Complete-Hallmark comparison of unweighted and IPW analyses.

**Population/analysis definition:** Frozen unweighted day-5 primary RNA GSEA compared with each weighted scenario.

**Variables and abbreviations:** The table includes paired NES, direction and FDR classifications for every pathway.

**Weighting/FDR definition:** Significance sets use BH-FDR <0.05 in the corresponding complete Hallmark family.

**Interpretation limitation:** IPW is a sensitivity analysis and does not replace the unweighted primary analysis.

## Worksheet `Scenario_metrics` | Summary robustness metrics for six availability scenarios.

**Population/analysis definition:** All complete-Hallmark pathway pairs comparing weighted and unweighted analyses.

**Variables and abbreviations:** Spearman NES correlation, direction agreement and significant-set Jaccard overlap are reported.

**Weighting/FDR definition:** Significant sets use BH-FDR <0.05.

**Interpretation limitation:** High concordance does not imply complete covariate balance or absence of selection bias.

## Worksheet `Frozen_internal_QA` | Frozen availability/IPW internal QA.

**Population/analysis definition:** Implementation checks for the final availability workflow.

**Variables and abbreviations:** Each row records a prespecified check, observed value and pass status.

**Weighting/FDR definition:** QA thresholds follow the frozen design.

**Interpretation limitation:** Passing implementation QA does not remove design-level positivity limitations.

