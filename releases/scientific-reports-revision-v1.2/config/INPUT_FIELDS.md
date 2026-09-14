# Input interface names (no participant records)

The clinical annotation is a longitudinal controlled table. The inspected code uses PatientID, SampleName, day_num, sTatus and surv_time for linkage, landmark and outcome handling; age, SOFA and lac for severity sensitivity. day_num is1/3/5, event is taken from sTatus and entry is0/2/4 days from the Day-1 origin. These names describe required interfaces, not a public data template containing real records. Recruitment centre is derived from the confirmed sample prefix; do not replace it with laboratory batch.

The raw protein workbook sheet is proteins_annotation. The first two columns supply UniProt identifiers and gene symbols; sample columns match authorised clinical SampleName values. The reconstruction code identifies QC columns ending _QC1_[123]. This naming pattern does not establish the experimental meaning of a triplet or the scale of the input values.

The QC feature handoff includes uniprot_id, gene_symbol, pass_missing30, pass_both, median_within_batch_linear_CV_pct. Existing criteria/deduplication are in the protein and CV scripts. Do not substitute a new SD/mean calculation or infer eligibility from this field list alone.

The S14 private observation table uses PatientID, center and available, with supported-landmark definitions checked by the descriptive helper. Probabilities/weights and all row-level inputs must remain private. Public aggregate schemas are the column headers of the supplied figure TSV/CSV and workbook dictionaries. Full metadata semantics and generation of the clinical/QC handoffs are not completely established by this schema document; see CODE_CHAIN.tsv.
