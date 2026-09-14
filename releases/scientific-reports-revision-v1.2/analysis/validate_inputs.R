# Read-only validation. Never sources model code or repairs input records.
validate_annotation <- function(x, expected_patients=504L) {
  required<-c('PatientID','SampleName','day_num','sTatus','surv_time','age','SOFA','lac')
  if(!all(required %in% names(x))) stop('clinical: required fields missing')
  if(anyNA(x[,required])) stop('clinical: missing required key/outcome/covariate')
  if(anyDuplicated(x$SampleName)||anyDuplicated(x[,c('PatientID','day_num')])) stop('clinical: duplicate sample or patient/day key')
  for(k in c('day_num','sTatus','surv_time','age','SOFA','lac')) if(!is.numeric(x[[k]])||any(!is.finite(x[[k]]))) stop('clinical: nonnumeric/nonfinite required field')
  if(!all(x$day_num %in% c(1,3,5))||!all(x$sTatus %in% 0:1)||any(x$surv_time<0|x$surv_time>60)||any(x$lac<=0)) stop('clinical: invalid day/event/follow-up/lactate domain')
  base<-x[x$day_num==1,]
  if(nrow(base)!=expected_patients||anyDuplicated(base$PatientID)||!all(x$PatientID %in% base$PatientID)) stop('clinical: baseline cohort/longitudinal membership mismatch')
  m<-match(x$PatientID,base$PatientID)
  if(any(x$sTatus!=base$sTatus[m])||any(x$surv_time!=base$surv_time[m])) stop('clinical: inconsistent longitudinal outcome')
  TRUE
}
validate_qc <- function(q) {
  req<-c('uniprot_id','gene_symbol','clinical_missing_rate','median_within_batch_linear_CV_pct','pass_CV20','pass_missing30','pass_both')
  if(!all(req %in% names(q))) stop('QC: required fields missing')
  if(anyDuplicated(q[,c('uniprot_id','gene_symbol')])) stop('QC: duplicate annotation join key')
  for(k in req[3:7]) if(!is.numeric(q[[k]])||any(!is.finite(q[[k]]))) stop('QC: nonnumeric/nonfinite required field')
  if(any(q$clinical_missing_rate<0|q$clinical_missing_rate>1)||any(q$median_within_batch_linear_CV_pct<0)) stop('QC: invalid rate/CV range')
  if(any(q$pass_CV20 != as.integer(q$median_within_batch_linear_CV_pct<20))||any(q$pass_missing30 != as.integer(q$clinical_missing_rate<.3))||any(q$pass_both != as.integer(q$pass_CV20==1&q$pass_missing30==1))) stop('QC: threshold/combined flags inconsistent')
  TRUE
}
validate_authorised_inputs <- function(data_dir, historical=FALSE) {
  suppressPackageStartupMessages({library(data.table);library(readxl)})
  paths<-expected_input_contract(data_dir)$path
  names(paths)<-expected_input_contract(data_dir)$logical_name
  check_inputs(data_dir,execution=TRUE)
  cl<-fread(paths['clinical'],data.table=FALSE);validate_annotation(cl)
  qc<-fread(paths['protein_qc'],data.table=FALSE);validate_qc(qc)
  header<-names(fread(paths['rna_counts'],nrows=0));rna<-intersect(cl$SampleName,header)
  if(length(rna)!=1246L)stop('RNA: matched sample count differs from source contract')
  # Inspect required RNA sample values only; no filtering or normalization.
  counts<-fread(paths['rna_counts'],select=c(header[1],rna),data.table=FALSE)
  if(anyDuplicated(counts[[1]])||nrow(counts)!=61806L)stop('RNA: feature key/row count mismatch')
  # The historical pipeline uses a double matrix, not an integer-count contract.
  # Fractional non-negative entries are allowed; no rounding is performed.
  if(any(!vapply(counts[-1],function(v)is.numeric(v)&&all(is.na(v)|(is.finite(v)&v>=0)),logical(1))))stop('RNA: nonnumeric/infinite/negative expression input')
  missing_rna<-sum(vapply(counts[-1],function(v)sum(is.na(v)),numeric(1)))
  if(missing_rna>0)warning(sprintf('RNA source contains %d NA cells. Historical gene aggregation uses sum(..., na.rm=TRUE); this check does not aggregate, fill or validate that scientific handling.',missing_rna))
  rm(counts);invisible(gc())
  raw<-as.data.frame(read_excel(paths['protein'],sheet='proteins_annotation'),check.names=FALSE)
  protein<-intersect(grep('_d[135]$',names(raw),value=TRUE),cl$SampleName)
  if(length(protein)!=431L)stop('Protein: matched sample count differs from source contract')
  if(any(!vapply(raw[protein],function(v)is.numeric(v)&&all(is.finite(v)),logical(1))))stop('Protein: nonnumeric/nonfinite analysis matrix')
  ann<-data.frame(uniprot_id=as.character(raw[[1]]),gene_symbol=trimws(sub(';.*$','',as.character(raw[[2]]))))
  if(!all(paste(qc$uniprot_id,qc$gene_symbol,sep='|') %in% paste(ann$uniprot_id,ann$gene_symbol,sep='|')))stop('Protein/QC: unresolved annotation join')
  # Eligibility cardinality check only; no recomputation of CV, deduplication or abundance.
  if(length(unique(qc$gene_symbol[qc$pass_both==1 & !is.na(qc$gene_symbol)&qc$gene_symbol!='']))!=3875L)stop('QC: retained symbol cardinality mismatch')
  result<-list()
  for(om in c('RNA','Protein'))for(day in c(1,3,5)){
    sam<-if(om=='RNA')rna else protein
    md<-cl[cl$day_num==day & cl$SampleName %in% sam,]
    valid<-md$surv_time>(day-1)
    result[[length(result)+1]]<-data.frame(omics=om,day=day,measured=nrow(md),risk_valid=sum(valid),events=sum(md$sTatus[valid]))
  }
  result<-do.call(rbind,result)
  if(!identical(as.integer(result$risk_valid),c(504L,420L,320L,168L,147L,114L))||!identical(as.integer(result$events),c(84L,67L,53L,27L,18L,14L)))stop('Risk-set or outcome count mismatch')
  gmt<-readLines(paths['hallmark'],warn=FALSE)
  if(length(gmt)!=50||anyDuplicated(sub('\t.*','',gmt)))stop('Hallmark: expected 50 unique sets')
  if(historical){
    old<-c(file.path(data_dir,'FINAL_RNA_center_stratified_analysis',paste0('01_',c('D1','D3','D5'),'_center_stratified_cox_zph.csv')),file.path(data_dir,'FINAL_RNA_Figure2_publication','02_RNA_fgsea_FINAL_completed.csv'),file.path(data_dir,'FINAL_center_stratified_protein_analysis',c(paste0('01_',c('D1','D3','D5'),'_center_stratified_primary_cox_zph.csv'),'03_fgseaMultilevel_center_primary_PH_and_intensity_sensitivity.csv')))
    if(any(!file.exists(old)))stop('Optional historical comparison requested but historical files are missing')
  }
  result
}
if(sys.nframe()==0L){
  args<-commandArgs(TRUE)
  if(length(args)<2)stop('Usage: Rscript validate_inputs.R <repository-root> <aggregate-report.tsv> [--historical]')
  source(file.path(args[1],'analysis/check_inputs.R'))
  out<-args[2]
  if(file.exists(out))stop('Refusing to overwrite validation report')
  report<-validate_authorised_inputs(Sys.getenv('CMAISE_DATA_DIR'), '--historical' %in% args)
  write.table(report,out,sep='\t',row.names=FALSE,quote=FALSE)
  cat('Input validation complete; no input changes or statistical estimation.\n')
}
