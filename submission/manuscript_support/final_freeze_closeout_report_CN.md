# SIC纵向多组学项目：分析冻结收尾报告

生成时间：2026-07-13 19:06:03 CST

## 1. 冻结定位

`07_Freeze_Closeout/`严格作为投稿冻结覆盖层。它引用已通过QA的底层冻结输出，不重新定义estimand、不替代底层统计结果，也不构成第二套分析项目。

## 2. Canonical文件

- `docs/superpowers/specs/2026-07-12-day5-rna-availability-ipw-design.md` — canonical_design; SHA256 `b14d2bbebe28ff62c809d468446b3dde600dc4af917372e24f9bb038ce5c6aad`.
- `outputs/Day5_RNA_availability_IPW_frozen_design.md` — canonical_mirror; SHA256 `b14d2bbebe28ff62c809d468446b3dde600dc4af917372e24f9bb038ce5c6aad`.
- `outputs/SIC_reanalysis_2026-07-11/code/10a_availability_ipw_helpers.R` — helper_code; SHA256 `ee786e2f0ee1c479ebfed7366e8308858f2437b899dbfdd28a31a7854b04c6a9`.
- `outputs/SIC_reanalysis_2026-07-11/code/10_run_availability_IPW_sensitivity.R` — orchestration_code; SHA256 `132c4370b965177b34b375370e407167178abefd28e9ea633f052f37fffb8887`.
- `outputs/SIC_reanalysis_2026-07-11/tests/test_10_availability_ipw.R` — helper_test; SHA256 `065e2000bd108d87efe011a3051c6671f843a5a50b2ba8412e2c916e87a68ffa`.
- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW_final/README_CN.md` — result_readme; SHA256 `1d72d5b28f4dcbd3a251c59465f93ed75372bbd57337c54586d103715be906e4`.
- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW_final/18_final_QA.csv` — module_QA; SHA256 `101916a967fcea9e82467e86f0ef0d68520c4d266d94fcfca6fa09351282389c`.
- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW_final/sessionInfo_Availability_IPW.txt` — session_info; SHA256 `d58eb651c3a6f86ac03f219d6bc54ccdf19c27a198870315fd24f9a91ff10590`.
- `outputs/SIC_reanalysis_2026-07-11/FINAL_QA_SUMMARY.csv` — global_QA; SHA256 `8a30308b5e0ff45a1c40e770d700a4b56f89622d3611d352fb389952f91f7202`.
- `outputs/SIC_reanalysis_2026-07-11/FILE_MANIFEST_SHA256.csv` — existing_manifest; SHA256 `b12ea6d3ae22a0de18cf69146ee862c64e202b331f9fcd5de9a22c1281e213bf`.

唯一canonical design为`docs/superpowers/specs/2026-07-12-day5-rna-availability-ipw-design.md`；其冻结镜像字节一致。`SOFA_D3`仅为内部实现名，含义是基线SOFA加既往D3 RNA availability，不表示同期SOFA测量。

## 3. Superseded文件

- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW/00_availability_counts.csv` — 保留原内容，状态为 **PROHIBITED**；SHA256 `a8f328c2c702bdacbaed92b84075375bae96207ee3300a1e59adf25a09cd7f37`.
- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW/01_availability_SMD_unweighted.csv` — 保留原内容，状态为 **PROHIBITED**；SHA256 `6628536ad5e8fdec05953eb94eef2705fe093845540ba1c01434e25a4a797f84`.
- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW/02_D5_RNA_IPW_weights_controlled.csv` — 保留原内容，状态为 **PROHIBITED**；SHA256 `5643ba8a64b00288595513e58f2e2160e65bd381b736088293ce7d780d9dcf23`.
- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW/03_D5_RNA_IPW_balance.csv` — 保留原内容，状态为 **PROHIBITED**；SHA256 `b5c7c11e306f1a7ff744fdf31cc5bf7d6ee59add98930d2f32f900c17957df85`.
- `outputs/SIC_reanalysis_2026-07-11/06_Availability_IPW/04_D5_RNA_IPW_center_stratified_cox.csv` — 保留原内容，状态为 **PROHIBITED**；SHA256 `e65dce77045cbb6ce9eaf4f7a36d0acb24abc2497305c49919fe761adbab176d`.

旧stabilised numerator设计未覆盖、未删除，集中由`superseded/`索引并明确禁止论文引用或正式结果复现。

## 4. 新增或修改文件

- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/availability_IPW_implementation_addendum.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/canonical/canonical_design_index.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/11_build_canonical_archive_and_truth.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/12_run_sandwich_equivalence_test.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/13_make_submission_figures.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/14_build_manuscript_text.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/15_build_availability_supplement_tables.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/16_run_closeout_QA.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/17_build_manifests_and_closeout_report.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/18_build_manuscript_evidence_matrix.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/19_run_semantic_QA.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/code/20_build_semantic_patch_report.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure1_study_design_risksets_availability.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure1_study_design_risksets_availability.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure1_study_design_risksets_availability.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure1_study_design_risksets_availability.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure2_RNA_core_NES.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure2_RNA_core_NES.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure2_RNA_core_NES.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure2_RNA_core_NES.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure3_Protein_core_NES.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure3_Protein_core_NES.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure3_Protein_core_NES.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure3_Protein_core_NES.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_CrossOmics_integrated_A_to_F.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_CrossOmics_integrated_A_to_F.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_CrossOmics_integrated_A_to_F.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_CrossOmics_integrated_A_to_F.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_review_double_column.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_review_double_column.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_review_full_page.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_review_full_page.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_review_single_column.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Figure4_review_single_column.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A1_centre_positivity.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A1_centre_positivity.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A1_centre_positivity.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A1_centre_positivity.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A2_probability_weight_distributions.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A2_probability_weight_distributions.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A2_probability_weight_distributions.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A2_probability_weight_distributions.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A3_pre_post_weight_SMD.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A3_pre_post_weight_SMD.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A3_pre_post_weight_SMD.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A3_pre_post_weight_SMD.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A4_all_Hallmark_unweighted_vs_IPW.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A4_all_Hallmark_unweighted_vs_IPW.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A4_all_Hallmark_unweighted_vs_IPW.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A4_all_Hallmark_unweighted_vs_IPW.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A5_core_pathway_scenario_heatmap.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A5_core_pathway_scenario_heatmap.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A5_core_pathway_scenario_heatmap.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A5_core_pathway_scenario_heatmap.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A6_six_scenario_robustness_metrics.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A6_six_scenario_robustness_metrics.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A6_six_scenario_robustness_metrics.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A6_six_scenario_robustness_metrics.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A7_entry_boundary_sensitivity.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A7_entry_boundary_sensitivity.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A7_entry_boundary_sensitivity.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A7_entry_boundary_sensitivity.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A8_D5_protein_availability.pdf`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A8_D5_protein_availability.png`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A8_D5_protein_availability.svg`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/figures/Supplementary_Figure_A8_D5_protein_availability.tiff`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/Abstract_numeric_stub.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/Figure_legends_production.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/Limitations_production.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/manuscript_evidence_matrix.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/Methods_production.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/Results_production.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/sessionInfo_evidence_matrix.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/sessionInfo_manuscript_production.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/Supplementary_figure_legends_production.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/Supplementary_table_captions_production.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript/terminology_ledger.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/manuscript_interface_patch_report_CN.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/numeric_truth_dictionary.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/numeric_truth_table.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/sessionInfo_supplement_table_build.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure1_centre_classes.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure1_D5_availability.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure1_exclusions.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure1_samples.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure2_RNA.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure3_Protein.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure4A_same_time.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure4B_forward_D1_D3.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure4C_forward_D3_D5.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure4D_reverse.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure4E_OXPHOS_attenuation.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Figure4F_IFN_effects.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A1.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A2.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A3.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A4.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A5.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A6.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A7.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SourceData_Supplementary_Figure_A8.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/Supplementary_Tables_Availability_IPW.xlsx`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Balance_SMD.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Centre_positivity.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Covariate_missingness.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Cox_PH_audit.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Entry_risksets.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Frozen_internal_QA.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Hallmark_all_models.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Hallmark_comparison.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Hallmark_leading_edges.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Prefit_diagnostics.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Protein_availability.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Scenario_metrics.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Time_origin_audit.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Transform_constants.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/public_source_data/SupplementaryTable_Weight_diagnostics.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/closeout_QA_report.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/closeout_QA_summary.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/figure_axis_boundary_QA.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/figure_rendering_QA.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/Figure4_readability_review.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/privacy_QA.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/semantic_QA_report.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/semantic_QA_summary.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/sessionInfo_closeout_QA.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/qa/sessionInfo_semantic_QA.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/sessionInfo_closeout_figures.txt`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/superseded/README_DO_NOT_USE.md`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/superseded/superseded_files_index.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/tests/test_sandwich_equivalence.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/tests/test_submission_semantics.R`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/validation/formal_result_hash_semantic_comparison.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/validation/formal_result_hash_unchanged.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/validation/formal_result_hashes_post_semantic_patch.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/validation/formal_result_hashes_pre_semantic_patch.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/validation/robust_SE_equivalence_summary.tsv`
- `outputs/SIC_reanalysis_2026-07-11/07_Freeze_Closeout/validation/robust_SE_equivalence_test.csv`
- `outputs/SIC_reanalysis_2026-07-11/FIGURE_LEGENDS_DRAFT.md`
- `outputs/SIC_reanalysis_2026-07-11/README_REPRODUCE_CN.md`

## 5. 是否重新计算正式统计结果

**否。** 未重新拟合主要Cox、IPW或GSEA模型；未修改estimand、协变量、逆观察概率权重、截断规则、显著性标准或核心结果。唯一运行的模型拟合是预设的sandwich等价性验证；它不写回或替代正式结果。投稿图表、source data与生产文本均读取冻结结果和唯一`numeric_truth_table.tsv`。

## 6. QA状态

- helper/sandwich自动测试：PASS；等价性比较基因数=28，最大绝对差≤1e-10。
- 既有65项QA：PASS（65/65）。
- 更新后的closeout QA：PASS（90/90）。
- numeric consistency QA：PASS。
- prohibited-language QA：PASS。
- privacy QA：PASS；公开source data无PatientID、可追溯样本标识或个体概率/权重。
- figure rendering QA：PASS；PDF/SVG可渲染，PDF字体嵌入，TIFF 600 dpi，PNG尺寸及裁切检查通过。
- Figure 4 panel lettering A–F：PASS。
- manifest/hash QA：由本脚本最终生成并复核。

## 7. Figure 4可读性结论

- single-column 89 mm：PASS_EXTENDED_HEIGHT；Readable after a one-column-by-six-panel reflow; the 440-mm height is a review export, not a single-page submission layout.
- double-column 183 mm：PASS；Readable after a two-column-by-three-row reflow; axes and confidence intervals remain visible.
- full-page 183x225 mm：PASS；Preferred submission layout; labels, confidence intervals and legends are readable.

六panel全页版本是正式投稿版。单栏版本不具备充分可读性，双栏版本仅适合快速审阅；没有删减panel、改变模型或选择性隐藏结果。

## 8. IPW结论边界

D5 RNA IPW是一项受到positivity与残余平衡限制、但总体通路结论与未加权主要分析高度一致的敏感性分析。它没有消除选择偏倚、没有恢复死亡后的分子状态，也不取代未加权中心分层主要分析。3个零观察中心不属于IPW estimand；既往D3 RNA availability仍存在明显残余不平衡。

## 9. 未解决问题

- 计算层面无阻断性失败。
- Figure 4单栏和双栏布局受六panel信息密度限制，正式使用全页版本。
- 临床隐私决定完整个体数据只能通过CMEISE受控申请获取；公开source data仅提供非识别性聚合或结果层数据。
- IPW的positivity和残余平衡限制、缺乏精确采样时间及协议资格变量属于研究固有限制，不能由额外计算消除。

## 10. 剩余非计算性作者决策

- 确认最终题目、作者顺序、单位、基金、伦理批件和受控数据访问措辞。
- 依据Critical Care格式完成文献引用、语言润色和最终图注压缩。
- 决定正文Results对各次级通路的篇幅，不得改变冻结主次证据层级。
- 投稿前由全体作者确认数据可用性声明及CMEISE申请流程。

## 11. 是否具备正式撰写Methods和Results的条件

**是。** 统计结果、数字真值、四图结构、availability补充材料、生产文本和QA均已冻结，可正式进入Methods与Results写作。
