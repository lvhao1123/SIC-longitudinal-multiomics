# Methods production text — frozen analysis

## Study population and longitudinal molecular sampling

This secondary longitudinal multi-omics analysis included 504 patients who met the SIC definition at day 1. Whole-blood RNA and plasma-protein measurements were linked to baseline clinical variables, study centre and 60-day mortality. Day-1, day-3 and day-5 molecular measurements were analysed in separate time-specific prognostic models. Day-3 and day-5 analyses used delayed entry at the corresponding prespecified sampling landmarks.

## Time-specific prognostic molecular models

At each time point, molecular features were standardized to one standard deviation within the analysis set. Gene- and protein-wise Cox models used `Surv(entry, stop, event)` with Efron handling of tied event times and study-centre stratification. Cox Wald statistics provided the complete ranked feature lists for Hallmark gene-set enrichment. Proportional-hazards diagnostics used scaled Schoenfeld residuals with the Kaplan–Meier time transformation. The primary GSEA retained all successfully estimated features; a prespecified sensitivity analysis repeated GSEA using features with nominal PH-test P values at or above the frozen threshold. Hallmark enrichment used the complete ranked lists, prespecified gene-set size limits and BH correction within each time point and analysis family. Mortality-association NES values were interpreted as prognostic enrichment statistics, not as direct measurements of absolute pathway activity.

## Day-5 RNA availability estimand and inverse-observation-probability weighting

The primary availability estimand comprised patients from the day-1 SIC cohort who survived beyond the day-4 landmark and came from centres with empirical support for day-5 RNA observation. Deaths at or before entry were classified as structural non-availability and were reported separately; IPW was not used to reconstruct post-mortem molecular states. Centres with zero observations were excluded from this estimand, centres with complete observation were assigned observation probability and weight equal to one, and probabilities were estimated only in partially observing centres.

The prespecified primary availability model contained baseline SOFA and prior day-3 RNA availability together with the frozen low-collinearity pre-sampling covariates. The internal implementation label `SOFA_D3` refers to this combination and must not be interpreted as a contemporaneous SOFA measurement. A prespecified model omitting prior day-3 RNA availability, a model replacing baseline SOFA with P/F ratio and platelet count, its corresponding no-day-3-availability variant, and lower- and upper-entry-boundary scenarios were retained as sensitivity analyses; no post hoc model replacement was permitted.

Unstabilised inverse observation probabilities were defined as the reciprocal of the estimated observation probability. Weights were truncated at the 1% and 99% percentiles and then normalized to mean one among observed patients. The weighted delayed-entry Cox model was `Surv(4, surv_time, event) ~ gene_z + strata(center)`. Because the installed survival implementation required a cluster or id for its delayed-entry robust variance path, the frozen analysis used the same weighted partial-likelihood coefficients with an observation-level Lin–Wei sandwich variance computed from weighted dfbeta residuals. The implementation was separately verified against a model assigning a unique cluster to every row.

The IPW analysis was explicitly treated as a sensitivity analysis. All 14,541 converged gene estimates were ranked by the weighted robust Wald statistic and entered Hallmark GSEA. Weighted and unweighted day-5 results were compared across the complete Hallmark family using NES rank correlation, direction agreement and significant-set Jaccard overlap. The prespecified interpretation was that IPW remained limited by positivity and residual covariate imbalance and therefore did not replace the unweighted centre-stratified primary analysis.

## Cross-omic analyses

Patient-level RNA and protein pathway scores were evaluated in contemporaneous and forward cross-time models adjusted according to the frozen analysis specification. Forward models additionally controlled for the preceding protein score, and reverse protein-to-RNA models were retained as directionality checks. OXPHOS estimates before and after centre adjustment were shown to document attenuation. These analyses quantify cross-compartment temporal association and do not establish causal RNA-to-protein transfer.

## Reproducibility and privacy

The submission-freeze overlay reads frozen statistical outputs and a single numeric truth table. It does not refit the primary Cox, IPW or GSEA analyses. Public source-data tables contain only aggregate, pathway-level or feature-level results and exclude patient identifiers, traceable sample identifiers, individual observation probabilities and individual weights. Complete clinical and molecular data require controlled access through the CMEISE data-governance process.
