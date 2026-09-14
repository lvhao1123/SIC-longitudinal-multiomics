# Entry-point safety only. Statistical scripts retain their historical contents.
fresh_output_path <- function(value, protected) {
  if(!nzchar(value))stop('SIC_OUTPUT_DIR is required; use a fresh private directory outside the repository and input directory')
  p<-normalizePath(value,winslash='/',mustWork=FALSE)
  for(q in protected){
    q<-normalizePath(q,winslash='/',mustWork=TRUE)
    if(tolower(p)==tolower(q)||startsWith(tolower(p),paste0(tolower(q),'/')))stop('Output must be outside protected repository/input trees')
  }
  if(file.exists(p)||dir.exists(p))stop('Output already exists; refusing overwrite or resume')
  p
}
historical_inputs <- function(d){
 c(file.path(d,'FINAL_RNA_center_stratified_analysis',paste0('01_',c('D1','D3','D5'),'_center_stratified_cox_zph.csv')),
 file.path(d,'FINAL_RNA_Figure2_publication','02_RNA_fgsea_FINAL_completed.csv'),
 file.path(d,'FINAL_center_stratified_protein_analysis',c(paste0('01_',c('D1','D3','D5'),'_center_stratified_primary_cox_zph.csv'),'03_fgseaMultilevel_center_primary_PH_and_intensity_sensitivity.csv')))
}
main <- function(){
 args<-commandArgs(TRUE)
 if(any(!args %in% c('--preflight-only','--run-historical-pipeline','--include-historical-comparison')))stop('Unknown argument')
 root<-normalizePath(Sys.getenv('SIC_PROJECT_DIR',getwd()),winslash='/',mustWork=TRUE)
 d<-Sys.getenv('CMAISE_DATA_DIR')
 if(!nzchar(d))stop('CMAISE_DATA_DIR is required')
 out<-fresh_output_path(Sys.getenv('SIC_OUTPUT_DIR'),c(root,d))
 hist<-'--include-historical-comparison' %in% args
 if(hist && any(!file.exists(historical_inputs(d))))stop('Optional historical comparison: one or more of 8 declared historical inputs are missing; no model was started')
 source(file.path(root,'analysis/check_inputs.R'))
 source(file.path(root,'analysis/validate_inputs.R'))
 report<-validate_authorised_inputs(d,historical=hist)
 print(report,row.names=FALSE)
 if(!'--run-historical-pipeline' %in% args){message('Preflight finished. No model was run. Read warning messages and REPRODUCIBILITY.md.');return(invisible(NULL))}
 if('--preflight-only' %in% args)stop('Conflicting preflight and execution flags')
 # Explicit future execution reproduces the HISTORICAL primary workflow, not the
 # complete amended revision. In particular, the historical clinical script has
 # 41 contrasts; final 40-contrast tables are assembled from approved summaries.
 dir.create(out,recursive=TRUE)
 Sys.setenv(SIC_PROJECT_DIR=root,CMAISE_DATA_DIR=normalizePath(d,winslash='/'),SIC_OUTPUT_DIR=normalizePath(out,winslash='/'))
 old<-setwd(root);on.exit(setwd(old))
 code<-file.path(root,'outputs/SIC_reanalysis_2026-07-11/code')
 names<-c('00b_build_official_gene_map.R','01_run_RNA_TMM_cox_fgsea.R','01b_finalize_RNA_GSEA.R','02_run_Protein_QC_cox_fgsea.R','02b_finalize_Protein_GSEA.R','03_run_patient_scores_crossomics.R',if(hist)'05_compare_historical_and_summarize.R','06_build_RNA_normalization_robustness.R','09_build_clinical_tables.R')
 stages<-c(file.path(code,names),file.path(root,'analysis/build_clinical_workbook.R'),file.path(code,'10_run_availability_IPW_sensitivity.R'))
 if(any(!file.exists(stages)))stop('A required stage is absent')
 for(s in stages){status<-system2(file.path(R.home('bin'),'Rscript.exe'),shQuote(s));if(status!=0)stop('Stage failed: ',basename(s))}
}
if(sys.nframe()==0L)main()
