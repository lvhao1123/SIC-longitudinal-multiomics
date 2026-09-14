# Approved revision-stage sensitivity only. No writes outside this run directory.
args <- commandArgs(TRUE)
if (length(args) != 2L || !args[1] %in% c('preflight','analyse')) stop('Use: preflight|analyse <run_directory>')
mode <- args[1]; out <- normalizePath(args[2], winslash='/', mustWork=TRUE)
log_con <- file(file.path(out,'logs',paste0(mode,'_run.log')),open='wt')
sink(log_con,split=TRUE);sink(log_con,type='message')
lib <- Sys.getenv('SIC_R_LIBRARY'); if(nzchar(lib)) .libPaths(c(lib,.libPaths()))
options(stringsAsFactors=FALSE, warn=1)
suppressPackageStartupMessages({library(data.table); library(readxl); library(dplyr); library(survival); library(fgsea); library(jsonlite); library(digest)})
setDTthreads(1L)
cfg <- fromJSON(file.path(out,'private/input_paths.json'))
write_json <- function(x,name) write_json_internal(x,file.path(out,name))
write_json_internal <- function(x,path) jsonlite::write_json(x,path,auto_unbox=TRUE,pretty=TRUE,na='null',digits=16)
save_table <- function(x,name) fwrite(x,file.path(out,'results',name),sep='\t',na='NA')
manifest <- fread(file.path(out,'private/input_manifest.tsv'))
stopifnot(all(vapply(manifest$path,function(p)digest(file=p,algo='sha256'),character(1))==manifest$sha256))
stopifnot(getRversion()=='4.4.2',as.character(packageVersion('survival'))=='3.7.0',as.character(packageVersion('fgsea'))=='1.32.4')
RNGkind('Mersenne-Twister','Inversion','Rejection'); set.seed(20260711)
writeLines(capture.output(sessionInfo()),file.path(out,'logs',paste0('sessionInfo_',mode,'.txt')))
cat('Mode:',mode,'Start:',format(Sys.time()),'RNG:',paste(RNGkind(),collapse='/'),'\n')

raw <- as.data.frame(read_excel(cfg$protein,sheet='proteins_annotation'),check.names=FALSE)
qc <- fread(cfg$qc,data.table=FALSE)
clinical <- fread(cfg$clinical,data.table=FALSE)
sample_cols <- grep('_d[135]$',names(raw),value=TRUE)
samples <- intersect(sample_cols,clinical$SampleName)
md <- clinical[match(samples,clinical$SampleName),,drop=FALSE]
md$day_num <- as.integer(md$day_num)
md$Time <- paste0('D',md$day_num)
md$center <- factor(sub('_.*$','',md$SampleName))
md$event <- as.integer(md$sTatus);md$stop <- as.numeric(md$surv_time)
annot <- data.frame(row_id=seq_len(nrow(raw)),uniprot_id=as.character(raw[[1]]),
                    gene_symbol=trimws(sub(';.*$','',as.character(raw[[2]]))),
                    row_median_abundance=apply(as.matrix(raw[,samples,drop=FALSE]),1,median,na.rm=TRUE))
select_features <- function(use_cv) {
  q <- qc[qc$pass_missing30==1 & !is.na(qc$gene_symbol) & qc$gene_symbol!='',,drop=FALSE]
  if(use_cv) q<-q[q$pass_both==1,,drop=FALSE]
  inner_join(annot,q,by=c('uniprot_id','gene_symbol')) |>
    arrange(gene_symbol,median_within_batch_linear_CV_pct,desc(row_median_abundance),row_id) |>
    distinct(gene_symbol,.keep_all=TRUE)
}
refset <- select_features(TRUE); allset <- select_features(FALSE)
if(nrow(refset)!=3875L || nrow(allset)!=5614L) stop('Candidate count differs from authorized expectation; explain before fitting')
stopifnot(!anyDuplicated(allset$gene_symbol),all(refset$gene_symbol %in% allset$gene_symbol))
expr <- as.matrix(raw[allset$row_id,samples,drop=FALSE]);storage.mode(expr)<-'double';rownames(expr)<-allset$gene_symbol
old <- readRDS(cfg$reference_objects)
refcox <- fread(cfg$reference_cox,data.table=FALSE) |> filter(model=='center_primary')
refgsea <- fread(cfg$reference_gsea,data.table=FALSE) |> filter(grepl('^D[135]_center_primary$',analysis))
refgsea$Time <- sub('_.*$','',refgsea$analysis)
stopifnot(length(samples)==431L,all(is.finite(expr)),all(md$SampleName==samples),identical(colnames(old$expr),samples))
common_expr <- expr[rownames(old$expr),,drop=FALSE]
expression_delta <- max(abs(common_expr-old$expr))
stopifnot(expression_delta==0,identical(as.character(md$SampleName),as.character(old$meta$SampleName)))
meta_ok <- all(vapply(c('day_num','stop','event','center'),function(n)identical(as.character(md[[n]]),as.character(old$meta[[n]])),logical(1)))
stopifnot(meta_ok)
stopifnot(identical(sort(refset$gene_symbol),sort(rownames(old$expr))))

compare_numeric <- function(a,b,keys,fields) {
  ka<-do.call(paste,c(a[keys],sep='|'));kb<-do.call(paste,c(b[keys],sep='|'));idx<-match(ka,kb)
  stopifnot(!anyNA(idx),!anyDuplicated(kb))
  vapply(fields,function(k){x<-as.numeric(a[[k]]);y<-as.numeric(b[[k]][idx]);stopifnot(identical(is.na(x),is.na(y)));max(c(0,abs(x-y)),na.rm=TRUE)},numeric(1))
}
s5<-as.data.frame(read_excel(cfg$s5,sheet='Protein_Cox_PH')) |> filter(model=='center_primary')
numeric_fields<-c('logHR','HR','SE','z','pval','lower95','upper95','PH_chisq','PH_p','N','Events','padj','PH_FDR','entry_day')
s5_delta<-compare_numeric(refcox,s5,c('Time','model','gene_symbol'),numeric_fields)
old_delta<-compare_numeric(refcox,old$cox,c('Time','model','gene_symbol'),numeric_fields)
s6<-as.data.frame(read_excel(cfg$s6,sheet='Hallmark_all_models'))
s6_delta<-compare_numeric(refgsea,s6,c('analysis','pathway'),c('pval','padj','log2err','ES','NES','size','ranked_features'))
fig<-fread(cfg$figure3,data.table=FALSE)
fig_delta<-compare_numeric(fig,refgsea,c('analysis','pathway'),c('NES','padj','size'))
stopifnot(max(s5_delta)<1e-10,max(old_delta)<1e-10,max(s6_delta)<1e-10,max(fig_delta)<1e-10)
entries <- c(D1=0,D3=2,D5=4)
day_objects<-list();risk<-list()
for(tm in names(entries)) {
  m<-md[md$Time==tm & md$stop>entries[tm],,drop=FALSE]
  xx<-scale(t(expr[,m$SampleName,drop=FALSE]));xx[!is.finite(xx)]<-NA_real_
  oo<-scale(t(old$expr[,m$SampleName,drop=FALSE]));oo[!is.finite(oo)]<-NA_real_
  zdelta<-max(abs(xx[,colnames(oo),drop=FALSE]-oo))
  ref<-refcox[refcox$Time==tm,,drop=FALSE]
  stopifnot(zdelta==0,nrow(m)==unique(ref$N),sum(m$event)==unique(ref$Events),unique(ref$entry_day)==entries[tm])
  risk[[tm]]<-data.frame(Time=tm,entry=unname(entries[tm]),N=nrow(m),Events=sum(m$event),centres=nlevels(droplevels(m$center)),reference_features=nrow(refset),control_features=nrow(allset),added_features=nrow(allset)-nrow(refset),common_scaled_input_max_abs_diff=zdelta,model_input_sha256=digest(list(m$SampleName,m$stop,m$event,as.character(m$center),oo),algo='sha256'))
  day_objects[[tm]]<-list(md=m,x=xx,entry=unname(entries[tm]))
}
hallmark<-gmtPathways(cfg$hallmark);names(hallmark)<-sub('^HALLMARK_','',names(hallmark))
stopifnot(length(hallmark)==50L)
preflight<-list(checked_at=format(Sys.time(),'%Y-%m-%d %H:%M:%S %z'),eligible_reference=nrow(refset),eligible_control=nrow(allset),common_expression_max_abs_diff=expression_delta,metadata_exact=meta_ok,S5_max_abs_differences=as.list(s5_delta),archived_object_cox_max_abs_differences=as.list(old_delta),S6_max_abs_differences=as.list(s6_delta),Figure3_max_abs_differences=as.list(fig_delta),reuse_authorized_by_checks=TRUE,reused_models=nrow(refcox),new_models_planned=(nrow(allset)-nrow(refset))*3L,reference_warning_capture='not recorded in original feature table; not assumed zero',PH_filter_applied=FALSE)
if(mode=='preflight') {
  save_table(bind_rows(risk),'risk_sets.tsv')
  save_table(allset |> mutate(in_reference=gene_symbol %in% refset$gene_symbol) |> select(gene_symbol,uniprot_id,median_within_batch_linear_CV_pct,clinical_missing_rate,pass_CV20,pass_missing30,pass_both,in_reference),'feature_sets.tsv')
  write_json(preflight,'qa/preflight.json')
  write_json(list(cox='Efron; iter.max=50; eps=1e-9; x/y/model TRUE',rank='all finite z and original fit_ok',PH='diagnostic only; km; no PH-pass GSEA',GSEA=list(sampleSize=1001,nPermSimple=10000,minSize=15,maxSize=500,eps=0,scoreType='std',nproc=1,gseaParam=1),seed=20260711,RNGkind=RNGkind(),fgsea_defaults=capture.output(formals(fgseaMultilevel))),'qa/execution_parameters.json')
  cat('PREFLIGHT VERIFIED; new fits planned:',preflight$new_models_planned,'No new model fitted.\n')
  quit(save='no',status=0)
}
stopifnot(file.exists(file.path(out,'qa/preflight.json')))
if(file.exists(file.path(out,'results/control_all_protein_cox_PH.tsv'))) stop('Analysis output already exists; do not overwrite')
write_json(list(locked_at=format(Sys.time(),'%Y-%m-%d %H:%M:%S %z'),sha256=digest(file=file.path(out,'R/01_cv_dependence.R'),algo='sha256')),'qa/analysis_code_at_start.json')
lock<-fromJSON(file.path(out,'qa/prerun_lock.json'))$sha256
stopifnot(all(vapply(names(lock),function(n)digest(file=file.path(out,n),algo='sha256'),character(1))==unlist(lock)))

fit_one <- function(v,m,entry) {
  warnings<-character();err<-'';pherr<-''
  d<-data.frame(entry=entry,stop=m$stop,event=m$event,protein_z=as.numeric(v),center=droplevels(m$center))
  d<-d[complete.cases(d),,drop=FALSE]
  ans<-data.frame(logHR=NA_real_,HR=NA_real_,SE=NA_real_,z=NA_real_,pval=NA_real_,lower95=NA_real_,upper95=NA_real_,PH_chisq=NA_real_,PH_p=NA_real_,fit_ok=FALSE,N=nrow(d),Events=sum(d$event),iterations=NA_integer_)
  fit<-tryCatch(withCallingHandlers(coxph(Surv(entry,stop,event)~protein_z+strata(center),data=d,ties='efron',x=TRUE,y=TRUE,model=TRUE,control=coxph.control(iter.max=50,eps=1e-9)),warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e){err<<-conditionMessage(e);NULL})
  if(!is.null(fit)) {
    sm<-summary(fit);cr<-sm$coefficients['protein_z',];ci<-sm$conf.int['protein_z',]
    ans$logHR<-unname(cr['coef']);ans$HR<-unname(ci['exp(coef)']);ans$SE<-unname(cr['se(coef)']);ans$z<-unname(cr['z']);ans$pval<-unname(cr['Pr(>|z|)']);ans$lower95<-unname(ci['lower .95']);ans$upper95<-unname(ci['upper .95']);ans$iterations<-max(fit$iter)
    ans$fit_ok<-is.finite(ans$z)&&is.finite(ans$pval)&&ans$SE>0
    ph<-tryCatch(withCallingHandlers(cox.zph(fit,transform='km',terms=FALSE,global=FALSE),warning=function(w){warnings<<-c(warnings,paste('PH:',conditionMessage(w)));invokeRestart('muffleWarning')}),error=function(e){pherr<<-conditionMessage(e);NULL})
    if(!is.null(ph)){rr<-match('protein_z',rownames(ph$table));if(is.na(rr))rr<-1L;ans$PH_chisq<-ph$table[rr,'chisq'];ans$PH_p<-ph$table[rr,'p']}
  }
  ans$warning<-paste(unique(warnings),collapse=' | ');ans$error<-err;ans$PH_error<-pherr;ans$result_origin<-'new_fit_CV_gate_off_only'
  ans$warning_capture_status<-'captured_this_run'
  ans
}

all_control<-list();new_all<-list();gsea_out<-list();gsea_warn<-list();leading_all<-list();rank_all<-list()
for(tm in names(entries)) {
  cat('Fitting added proteins:',tm,format(Sys.time()),'\n')
  obj<-day_objects[[tm]];added<-setdiff(colnames(obj$x),refset$gene_symbol)
  rr<-lapply(seq_along(added),function(j){if(j%%250L==0L)cat(tm,j,'/',length(added),'\n');cbind(data.frame(Time=tm,model='center_primary_CV_gate_off',gene_symbol=added[j]),fit_one(obj$x[,added[j]],obj$md,obj$entry))})
  new<-bind_rows(rr);new$entry_day<-obj$entry;new_all[[tm]]<-new
  reused<-refcox |> filter(Time==tm)
  reused$model<-'center_primary_CV_gate_off';reused$result_origin<-'reused_frozen_single_feature_estimate';reused$warning<-NA_character_;reused$error<-NA_character_;reused$PH_error<-NA_character_;reused$iterations<-NA_integer_;reused$warning_capture_status<-'not_recorded_in_frozen_feature_table'
  reused$reference_padj_3875<-reused$padj;reused$reference_PH_FDR_3875<-reused$PH_FDR
  combined<-bind_rows(reused,new) |> arrange(gene_symbol)
  combined$padj<-p.adjust(combined$pval,'BH');combined$PH_FDR<-p.adjust(combined$PH_p,'BH');combined$PH_pass_nominal<-is.finite(combined$PH_p)&combined$PH_p>=.05
  combined$BH_feature_family_n<-nrow(combined);combined$PH_BH_family_n<-nrow(combined)
  all_control[[tm]]<-combined
  save_table(combined,paste0(tm,'_control_protein_cox_PH.tsv'))
  tbl<-combined |> filter(fit_ok)
  ranks<-tbl$z;names(ranks)<-tbl$gene_symbol;ranks<-sort(ranks[is.finite(ranks)&tbl$fit_ok],decreasing=TRUE)
  rank_all[[tm]]<-data.frame(Time=tm,rank=seq_along(ranks),gene_symbol=names(ranks),z=as.numeric(ranks),in_reference=names(ranks)%in%refset$gene_symbol)
  cat('GSEA:',tm,'ranked features',length(ranks),format(Sys.time()),'\n')
  warn<-character();gerr<-'';set.seed(20260711)
  g<-tryCatch(withCallingHandlers(fgseaMultilevel(pathways=hallmark,stats=ranks,sampleSize=1001,nPermSimple=10000,minSize=15,maxSize=500,eps=0,scoreType='std',nproc=1),warning=function(w){warn<<-c(warn,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e){gerr<<-conditionMessage(e);NULL})
  gsea_warn[[tm]]<-data.frame(Time=tm,warning=paste(unique(warn),collapse=' | '),error=gerr,ranked_features=length(ranks),tied_nonzero_rank_fraction=sum(duplicated(ranks[ranks!=0]))/sum(ranks!=0))
  cov<-data.frame(pathway=names(hallmark),set_total=vapply(hallmark,length,integer(1)),coverage=vapply(hallmark,function(v)sum(v%in%names(ranks)),integer(1)))
  cov$eligible<-cov$coverage>=15 & cov$coverage<=500
  if(!is.null(g)) {
    g<-as.data.frame(g);g$leadingEdge_text<-vapply(g$leadingEdge,paste,collapse=';',FUN.VALUE=character(1))
    for(i in seq_len(nrow(g))) {
      le<-g$leadingEdge[[i]]
      if(length(le))leading_all[[paste(tm,g$pathway[i])]]<-data.frame(Time=tm,pathway=g$pathway[i],gene_symbol=le,z=unname(ranks[le]),in_reference=le%in%refset$gene_symbol,abs_z_share_within_leading_edge=abs(ranks[le])/sum(abs(ranks[le])))
    }
    g$leadingEdge<-NULL
  } else g<-data.frame(pathway=character(),pval=numeric(),padj=numeric(),log2err=numeric(),ES=numeric(),NES=numeric(),size=integer(),leadingEdge_text=character())
  full<-left_join(cov,g,by='pathway')
  full$Time<-tm;full$analysis<-paste0(tm,'_center_primary_CV_gate_off');full$ranked_features<-length(ranks)
  full$test_family_eligible_n<-sum(full$eligible);full$test_family_returned_n<-nrow(g);full$test_family_finite_p_n<-sum(is.finite(g$pval))
  full$status<-ifelse(!full$eligible,'coverage_outside_original_15_to_500',ifelse(nzchar(gerr),'GSEA_call_failed',ifelse(!is.finite(full$NES)|!is.finite(full$pval),'result_uncertain_nonfinite',ifelse(!is.finite(full$log2err),'estimable_precision_uncertain','estimable'))))
  gsea_out[[tm]]<-full
  save_table(full,paste0(tm,'_control_Hallmark_all_status.tsv'))
}
save_table(bind_rows(new_all),'newly_fitted_proteins.tsv')
save_table(bind_rows(all_control),'control_all_protein_cox_PH.tsv')
save_table(bind_rows(gsea_out),'control_all_Hallmark.tsv')
save_table(bind_rows(leading_all),'control_leading_edge_long.tsv')
save_table(bind_rows(rank_all),'control_full_Wald_rankings.tsv')
save_table(bind_rows(gsea_warn),'GSEA_warnings.tsv')
save_table(refcox,'reference_primary_cox_unchanged.tsv')
save_table(refgsea,'reference_primary_Hallmark_unchanged.tsv')
diag<-bind_rows(all_control) |> group_by(Time,result_origin) |> summarise(features=n(),fit_ok=sum(fit_ok),nonfinite_coefficient=sum(!is.finite(logHR)),nonfinite_SE=sum(!is.finite(SE)),nonfinite_CI=sum(!is.finite(lower95)|!is.finite(upper95)),PH_success=sum(is.finite(PH_p)),PH_nominal_p_lt_05=sum(PH_p<.05,na.rm=TRUE),warning_record_available=sum(!is.na(warning)),features_with_recorded_warning=sum(nzchar(warning)&!is.na(warning)),fit_errors=sum(nzchar(error)&!is.na(error)),PH_errors=sum(nzchar(PH_error)&!is.na(PH_error)),iteration_limit=sum(iterations>=50,na.rm=TRUE),.groups='drop')
save_table(diag,'Cox_PH_diagnostics.tsv')
write_json(list(completed_at=format(Sys.time(),'%Y-%m-%d %H:%M:%S %z'),new_fits=nrow(bind_rows(new_all)),reused_fits=nrow(refcox),new_Hallmark_calls=3L,PH_filter=FALSE,original_results_overwritten=FALSE,scale_confirmed=FALSE,QC_experimental_groups_confirmed=FALSE),'qa/run_completion.json')
writeLines(capture.output(sessionInfo()),file.path(out,'logs/sessionInfo_analysis_complete.txt'))
cat('Analysis completed:',format(Sys.time()),'\n')
