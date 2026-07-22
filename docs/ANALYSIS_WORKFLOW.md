# Frozen analysis workflow

## Cohort and time-specific risk sets

The source cohort contains patients meeting the prespecified SIC criterion at day 1. Day-1, day-3 and day-5 molecular measurements are analysed in separate time-specific prognostic models. Day-3 and day-5 analyses use delayed entry at their prespecified sampling landmarks, so patients who died before the relevant landmark do not enter that risk set.

## Clinical analysis

Clinical processing verifies outcome coding, units, missingness, sparse categorical levels and the prespecified six-category infection-source grouping. The clinical baseline table excludes arterial pH and calcium because of missingness. Univariate clinical Cox models describe associations and do not automatically define a multivariable causal model.

## RNA analysis

RNA counts undergo the frozen low-expression filter, TMM normalization and joint log-CPM transformation. Within each time-specific risk set, each gene is standardized and fitted using delayed-entry, centre-stratified Cox regression. The Cox Wald z statistic ranks the full gene universe for Hallmark GSEA. A PH-pass ranking is retained as a sensitivity analysis, not as a replacement for the primary ranking.

## Protein analysis

Protein features follow the frozen replicate-QC and duplicate-symbol rules recorded by the canonical scripts. Each protein is standardized within the time-specific risk set and fitted with centre-stratified Cox regression. Models additionally adjusting for the sample-wide median protein intensity assess sensitivity to the global abundance axis.

## Pathway and cross-omics analyses

Hallmark enrichment uses the full Cox Wald-z ranking and `fgseaMultilevel`, with BH correction within the complete Hallmark family for each time point and analysis. Patient-level prespecified pathway scores support same-time and lagged RNA-protein coupling models. These are associations across molecular compartments and are not interpreted as causal translation delays.

## Day-5 availability/IPW sensitivity

The frozen Day-5 RNA sensitivity analysis restricts the estimand to landmark survivors with empirical centre-level positivity support. Structural deaths before the landmark are reported separately. Non-stabilized inverse observation-probability weights are trimmed and mean-normalized according to the frozen rules. Limitations from positivity and residual imbalance remain explicit; IPW does not recreate molecular states after death and does not replace the unweighted primary analysis.
