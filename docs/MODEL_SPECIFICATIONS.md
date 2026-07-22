# Frozen model specifications

## Molecular prognosis models

For omics feature \(x\) at each sampling time:

```text
Surv(entry, stop, event) ~ x_z + strata(center)
```

Entries are 0, 2 and 4 days for D1, D3 and D5, respectively. Ties use the Efron approximation. Effect estimates are reported per one standard-deviation increase. Proportional-hazards diagnostics use `cox.zph(..., transform = "km")`.

The protein global-intensity sensitivity model is:

```text
Surv(entry, stop, event) ~ protein_z + sample_median_z + strata(center)
```

## GSEA

The full Cox Wald-z vector is ranked in decreasing order and analysed against Hallmark sets using `fgseaMultilevel`, `minSize = 15`, `maxSize = 500`, `eps = 0` and standard scoring. BH-FDR is calculated across the complete Hallmark family within each time-specific analysis.

## Cross-omics models

Forward models estimate later protein pathway score from earlier RNA score while adjusting for the earlier protein score, age, sex, baseline SOFA, centre and target-time protein median. HC3 robust standard errors are used. Reverse protein-to-RNA models are prespecified specificity analyses.

## Availability/IPW

The Day-5 RNA sensitivity uses delayed entry at day 4, centre positivity rules, frozen main and alternative availability covariates, non-stabilized inverse observation-probability weights, frozen trimming and observation-level Lin-Wei sandwich variance. No post hoc model substitution is permitted.
