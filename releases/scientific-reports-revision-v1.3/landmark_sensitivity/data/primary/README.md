# Primary aggregate results

These eight CSV files supply the primary feature-level Cox results and Hallmark enrichment results used for comparison with the common-patient analysis and pathway-score models. Rows represent molecular features or pathways, not individual patients.

- `01_RNA_TMM/01_D*_TMM_center_stratified_cox_zph.csv`: primary transcriptomic Cox results at each landmark.
- `01_RNA_TMM/03_RNA_TMM_Hallmark_primary_PHpass.csv`: transcriptomic Hallmark results, with analysis and time labels.
- `02_Protein/01_D*_center_primary_cox_zph.csv`: primary proteomic Cox results at each landmark.
- `02_Protein/03_Protein_Hallmark_all_models.csv`: proteomic Hallmark results, with analysis labels.

`scripts/summarise.py` selects the primary analysis at each landmark and joins features by `gene_symbol` and pathways by `pathway`. It calculates rank correlations and tabulates the saved estimates and significance categories. It does not fit survival models, rerun enrichment or recalculate adjusted P values.
