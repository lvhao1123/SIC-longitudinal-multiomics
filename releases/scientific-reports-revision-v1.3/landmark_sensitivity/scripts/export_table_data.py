"""Export the six data worksheets of Tables S19 and S20 as TSV files."""
import argparse
import csv
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--data-dir', type=Path, required=True,
                    help='Directory containing results/comparisons and qa')
parser.add_argument('--output-dir', type=Path, required=True,
                    help='New directory for six worksheet TSV files')
args = parser.parse_args()
args.output_dir.mkdir(parents=True, exist_ok=False)
tables = [
    ('S19_Summary', 'results/comparisons/A_summary.tsv', None),
    ('S19_Hallmark_comparison', 'results/comparisons/A_all_Hallmark_vs_original.tsv',
     'Omics Time pathway N Events entry_day coverage eligible ranked_features family_n NES_original padj_original NES_A padj_A pval_original pval_A ES size log2err precision_retry leadingEdge_text'),
    ('S19_Cross_landmark', 'results/comparisons/A_cross_time_correlations.tsv', None),
    ('S19_Diagnostics', 'results/comparisons/A_diagnostics.tsv', None),
    ('S20_Family_summary', 'qa/B_family_summary.tsv', None),
    ('S20_Pathway_Cox', 'results/comparisons/B_all_pathways_with_original_GSEA.tsv',
     'Omics Time pathway N Events Entry HR lower95 upper95 pval FDR PH_p Coverage Coverage_min Eligible Nfamily Riskset_N Riskset_Events Score_mean Score_SD Status Centres Event_centres logHR SE z fit_ok warning error original_GSEA_NES original_GSEA_P original_GSEA_FDR'),
]
for name, source, columns in tables:
    with (args.data_dir / source).open(encoding='utf-8-sig', newline='') as handle:
        reader = csv.DictReader(handle, delimiter='\t')
        fields = columns.split() if columns else reader.fieldnames
        with (args.output_dir / (name + '.tsv')).open('w', encoding='utf-8', newline='') as target:
            writer = csv.DictWriter(target, fieldnames=fields, delimiter='\t', extrasaction='ignore')
            writer.writeheader()
            writer.writerows(reader)
print('Exported six data worksheets. No estimates, P values or FDR values were recalculated.')
