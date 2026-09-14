# Local read-only audit. Never source or run the original model-fitting scripts.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=6L) stop('Usage: Rscript verify_qc_and_centres_readonly.R raw_protein.xlsx annotation.csv original_clinical.csv availability.csv qc.csv output_dir')
suppressPackageStartupMessages({library(readxl);library(data.table);library(jsonlite)})
out<-normalizePath(args[6],mustWork=TRUE)
hashes<-tools::md5sum(args[1:5]) # Additional in-run guard; project manifest uses SHA256.
raw<-as.data.frame(read_excel(args[1],sheet='proteins_annotation'),check.names=FALSE)
ann<-fread(args[2],data.table=FALSE);cl<-fread(args[3],data.table=FALSE);av<-fread(args[4],data.table=FALSE);qc<-fread(args[5],data.table=FALSE)
sample_cols<-intersect(names(raw),as.character(ann$SampleName))
qc_cols<-grep('_QC1_[123]$',names(raw),value=TRUE)
groups<-sub('_[123]$','',qc_cols)
mat<-as.matrix(raw[,sample_cols,drop=FALSE]);storage.mode(mat)<-'double'
qm<-as.matrix(raw[,qc_cols,drop=FALSE]);storage.mode(qm)<-'double'
symbol<-trimws(sub(';.*$','',as.character(raw[[2]])))
up<-as.character(raw[[1]])
med<-apply(mat,1,median,na.rm=TRUE)
valid<-!is.na(symbol)&nzchar(symbol)
o<-which(valid)[order(symbol[valid],-med[valid],which(valid))]
selected<-sort(o[!duplicated(symbol[o])])
calc_cv<-vapply(unique(groups),function(g) {
 s<-apply(qm[selected,groups==g,drop=FALSE],1,sd,na.rm=TRUE)
 100*sqrt(exp((log(2)*s)^2)-1)
},numeric(length(selected)))
direct_cv<-vapply(unique(groups),function(g) {
 x<-qm[selected,groups==g,drop=FALSE]
 100*apply(x,1,sd,na.rm=TRUE)/rowMeans(x,na.rm=TRUE)
},numeric(length(selected)))
cv<-apply(calc_cv,1,median,na.rm=TRUE);dcv<-apply(direct_cv,1,median,na.rm=TRUE)
missing<-rowMeans(is.na(mat[selected,,drop=FALSE]))
pcv<-is.finite(cv)&cv<20;pmiss<-is.finite(missing)&missing<.3;both<-pcv&pmiss
key<-paste(up[selected],symbol[selected],sep='|');qkey<-paste(qc$uniprot_id,qc$gene_symbol,sep='|');ix<-match(qkey,key)
if(anyNA(ix)||anyDuplicated(qkey))stop('QC identifier mapping is not one to one; do not proceed.')
delta<-cv[ix]-qc$median_within_batch_linear_CV_pct
audit<-data.frame(gene_symbol=qc$gene_symbol,absolute_cv_difference=abs(delta),cv_flag_equal=as.integer(pcv[ix])==qc$pass_CV20,missing_flag_equal=as.integer(pmiss[ix])==qc$pass_missing30,both_flag_equal=as.integer(both[ix])==qc$pass_both)
write.table(audit,file.path(out,'QC_feature_agreement.tsv'),sep='\t',quote=FALSE,row.names=FALSE)
# Reproduce only the frozen downstream selection rule; no expression export or fit.
k<-which(qc$pass_both==1 & !is.na(qc$gene_symbol)&qc$gene_symbol!='')
candidate<-merge(data.frame(uniprot_id=up,gene_symbol=symbol,row_id=seq_len(nrow(raw)),abundance=med),qc[k,],by=c('uniprot_id','gene_symbol'))
candidate<-candidate[order(candidate$gene_symbol,candidate$median_within_batch_linear_CV_pct,-candidate$abundance,candidate$row_id),]
keep<-candidate[!duplicated(candidate$gene_symbol),]
step<-data.frame(step=c('raw rows','usable gene annotation','deduplicated symbols','missingness pass','CV pass','pass_both'),retained=c(nrow(raw),sum(valid),length(selected),sum(pmiss),sum(pcv),sum(both)))
write.table(step,file.path(out,'QC_step_counts.tsv'),sep='\t',quote=FALSE,row.names=FALSE)
protein<-list(workbook_sheets=excel_sheets(args[1]),raw_rows=nrow(raw),total_columns=ncol(raw),matched_sample_columns=length(sample_cols),qc_columns=length(qc_cols),qc_groups=length(unique(groups)),columns_per_group=unname(as.integer(table(groups))),clinical_missing_cells=sum(is.na(mat)),clinical_other_nonfinite=sum(!is.finite(mat)&!is.na(mat)),qc_missing_or_nonfinite=sum(!is.finite(qm)),empty_gene_rows=sum(!valid),duplicate_rows_removed=sum(valid)-length(selected),dedup_entries=length(selected),uniprot_duplicates_in_raw=sum(duplicated(up)),computed_cv_median=median(cv),direct_input_SD_mean_median=median(dcv),direct_input_SD_mean_pass=sum(is.finite(dcv)&dcv<20),current_formula_pass=sum(both),max_absolute_CV_error=max(abs(delta)),max_missingness_error=max(abs(missing[ix]-qc$clinical_missing_rate)),cv_flags_equal=all(audit$cv_flag_equal),missing_flags_equal=all(audit$missing_flag_equal),pass_both_flags_equal=all(audit$both_flag_equal),pass_both_is_AND=all(qc$pass_both==as.integer(qc$pass_CV20==1&qc$pass_missing30==1)),CV_exact20=sum(cv==20),missingness_exact30=sum(missing==.3),downstream_selected=nrow(keep),downstream_multicandidate_symbols=sum(table(candidate$gene_symbol)>1),reconstruction_selected_same_as_downstream=setequal(symbol[selected][both],keep$gene_symbol),scale_confirmed=FALSE,experimental_QC_groups_confirmed=FALSE,sd_definition='R stats::sd, sample SD with denominator n-1',formula='100*sqrt(exp((ln(2)*SD_input)^2)-1), assuming input is log2-scale',aggregation='Median across ten named three-column groups',dedup_reconstruction='First semicolon-delimited symbol; nonempty; highest median over matched sample columns; original row order for ties',interpretation='Numerical reconstruction, not validation of scale or technical replicate definition')
# Patient/centre identifiers stay only in memory. Export counts, never records or mapping.
if(anyDuplicated(av$SampleName)||anyDuplicated(cl$SampleName))stop('Nonunique linkage keys; no automatic correction.')
j<-match(av$SampleName,cl$SampleName);prefix<-sub('_.*$','',av$SampleName);location<-as.character(cl$SampleLocation[j])
link<-data.frame(prefix,location)
mp<-tapply(link$location,link$prefix,function(z)length(unique(z[!is.na(z)])))
ml<-tapply(link$prefix,link$location,function(z)length(unique(z[!is.na(z)])))
centres<-list(cohort_n=nrow(av),matched_original=sum(!is.na(j)),missing_location=sum(is.na(location)),prefix_codes=length(unique(prefix)),location_codes=length(unique(location)),direct_string_mismatches=sum(prefix!=location,na.rm=TRUE),prefixes_with_multiple_locations=sum(mp>1),locations_with_multiple_prefixes=sum(ml>1),meaning_source='Author confirmation in current instruction; not independent named-hospital validation')
centres$identical_patient_partition<-identical(outer(prefix,prefix,'=='),outer(location,location,'=='))
centres$differently_named_code_pairs<-nrow(unique(link[prefix!=location,,drop=FALSE]))
sets<-list()
for(day in c(1,3,5)) for(layer in c('RNA','Protein')){
 col<-paste0(layer,'_D',day)
 if(!col%in%names(av))stop('Missing availability field: ',col)
 measured<-av[[col]]==1;entry<-day-1;risk<-measured&av$surv_time>entry
 sets[[length(sets)+1]]<-data.frame(layer=layer,day=day,measured_n=sum(measured),measured_centres=length(unique(prefix[measured])),risk_valid_n=sum(risk),risk_valid_centres=length(unique(prefix[risk])),events=sum(av$sTatus[risk]==1))
}
risksets<-do.call(rbind,sets)
write.table(risksets,file.path(out,'CENTRE_COUNTS_BY_ANALYSIS_SET.tsv'),sep='\t',quote=FALSE,row.names=FALSE)
surv<-av$surv_time>4;tab<-aggregate(as.integer(av$RNA_D5[surv]==1),list(prefix=prefix[surv]),function(z)c(N=length(z),observed=sum(z)))
n<-tab$x[,'N'];obs<-tab$x[,'observed'];zero<-obs==0;all<-obs==n
centres$D5_landmark_survivors<-sum(surv);centres$D5_landmark_centres<-nrow(tab);centres$zero_centres<-sum(zero);centres$all_centres<-sum(all);centres$partial_centres<-sum(!zero&!all);centres$zero_centre_patients<-sum(n[zero]);centres$positivity_supported_n<-sum(n[!zero]);centres$positivity_supported_centres<-sum(!zero)
hashes_after<-tools::md5sum(args[1:5])
write_json(list(protein=protein,centre=centres,inputs_unchanged=identical(hashes,hashes_after)),file.path(out,'READ_ONLY_QC_CENTRE_SUMMARY.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
writeLines(capture.output(sessionInfo()),file.path(out,'sessionInfo_read_only_audit.txt'))
cat('Read-only audit completed; see aggregate summary. No models fitted.\n')
