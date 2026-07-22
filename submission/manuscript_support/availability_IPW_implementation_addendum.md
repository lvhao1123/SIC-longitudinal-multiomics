# Availability/IPW implementation addendum

The frozen estimand, probability model, inverse-observation weights, truncation and mean-one normalisation remain unchanged.
In the installed survival package, a counting-process delayed-entry Surv response with robust=TRUE requires cluster or id.
Because the frozen formal model contains one row per participant and explicitly does not set id, the same weighted delayed-entry partial likelihood is fitted first.
The observation-level Lin-Wei sandwich variance is then computed as the cross-product of weighted dfbeta residuals.
A prespecified validation compares this implementation with an otherwise identical model using a unique row-level cluster.
The validation compares coefficient, robust standard error, Wald z and two-sided P value and does not replace or regenerate any formal result.

The internal identifier SOFA_D3 means baseline SOFA plus prior D3 RNA availability. It must never be described as Day 3 SOFA in manuscript-facing text.
