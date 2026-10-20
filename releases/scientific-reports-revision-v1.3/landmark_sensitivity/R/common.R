options(stringsAsFactors=FALSE, warn=1)
lib <- Sys.getenv('SIC_R_LIBRARY')
if (nzchar(lib)) .libPaths(c(lib,.libPaths()))
suppressPackageStartupMessages({library(jsonlite);library(data.table);library(survival);library(fgsea)})

is_absolute_path <- function(path) grepl('^([A-Za-z]:[/\\\\]|/|\\\\\\\\)', path)
config_path <- Sys.getenv('SIC_CONFIG', file.path(dirname(SCRIPT_DIR), 'config.json'))
config_path <- normalizePath(config_path, winslash='/', mustWork=TRUE)
cfg <- fromJSON(config_path)
required <- c('source_root', 'clinical', 'hallmark')
stopifnot(all(required %in% names(cfg)),
          all(vapply(cfg[required], function(x) is.character(x) && length(x)==1L && nzchar(x), logical(1))))
for (key in required) {
  path <- cfg[[key]]
  if (!is_absolute_path(path)) path <- file.path(dirname(config_path), path)
  cfg[[key]] <- normalizePath(path, winslash='/', mustWork=TRUE)
}
stopifnot(dir.exists(cfg$source_root), file.exists(cfg$clinical), file.exists(cfg$hallmark))
ROOT <- commandArgs(TRUE)[1]
if (!is_absolute_path(ROOT)) ROOT <- file.path(getwd(), ROOT)
dir.create(ROOT, recursive=TRUE, showWarnings=FALSE)
ROOT <- normalizePath(ROOT, winslash='/', mustWork=TRUE)
path_within <- function(path, parent) {
  if (.Platform$OS.type=='windows') {path <- tolower(path); parent <- tolower(parent)}
  identical(path, parent) || startsWith(path, paste0(sub('/+$', '', parent), '/'))
}
PACKAGE_ROOT <- normalizePath(dirname(SCRIPT_DIR), winslash='/', mustWork=TRUE)
ARCHIVE_ROOT <- dirname(PACKAGE_ROOT)
inside_archive <- file.exists(file.path(ARCHIVE_ROOT, 'CODE_CHAIN.tsv')) && path_within(ROOT, ARCHIVE_ROOT)
if (path_within(ROOT, PACKAGE_ROOT) || path_within(ROOT, cfg$source_root) || inside_archive) {
  stop('Use an output directory outside the code package and the input matrix directory.')
}
for(d in c('results/A','results/B','qa','logs','local_cache')) dir.create(file.path(ROOT,d),recursive=TRUE,showWarnings=FALSE)
write_table <- function(x,path) fwrite(x,file.path(ROOT,path),sep='\t',na='NA')
start_log <- function(label) {
  con <- file(file.path(ROOT,'logs',paste0(label,'.log')),open='wt',encoding='UTF-8')
  sink(con,split=TRUE);sink(con,type='message');cat(label,format(Sys.time()),'\n');con
}
end_log <- function(con) {sink(type='message');sink();close(con)}
load_inputs <- function(omics) {
  p <- if(omics=='RNA') '01_RNA_TMM/RNA_TMM_logCPM_gene_by_sample.rds' else '02_Protein/Protein_QC_gene_by_sample.rds'
  x <- readRDS(file.path(cfg$source_root,p))
  md <- fread(cfg$clinical,data.table=FALSE)
  md$Time <- paste0('D',as.integer(md$day_num));md$event<-as.integer(md$sTatus);md$stop<-as.numeric(md$surv_time)
  md$center<-factor(sub('_.*$','',md$SampleName));md$PatientID<-as.character(md$PatientID)
  stopifnot(!anyDuplicated(md$SampleName),!anyDuplicated(rownames(x)),all(is.finite(x)))
  stopifnot(nrow(x)==if(omics=='RNA')14541L else 3875L)
  md<-md[md$SampleName %in% colnames(x),]
  stopifnot(all(md$event %in% 0:1),all(md$stop>0 & md$stop<=60),all(md$stop[md$event==0]==60))
  byid<-split(md,md$PatientID)
  stopifnot(all(vapply(byid,function(z)length(unique(z$stop))==1&&length(unique(z$event))==1&&length(unique(z$center))==1,logical(1))))
  h<-gmtPathways(cfg$hallmark);names(h)<-sub('^HALLMARK_','',names(h));stopifnot(length(h)==50L)
  list(x=x,md=md,hallmark=h)
}
fit_score <- function(score,md,entry) {
  d<-data.frame(entry=entry,stop=md$stop,event=md$event,score_z=as.numeric(score),center=droplevels(md$center))
  d<-d[complete.cases(d),]; warnings<-character(); err<-''
  out<-data.frame(N=nrow(d),Events=sum(d$event),Centres=length(unique(d$center)),Event_centres=length(unique(d$center[d$event==1])),
    logHR=NA_real_,HR=NA_real_,lower95=NA_real_,upper95=NA_real_,SE=NA_real_,z=NA_real_,pval=NA_real_,PH_p=NA_real_,fit_ok=FALSE,warning='',error='')
  if(nrow(d)<2||sd(d$score_z)==0||sum(d$event)==0) {out$error<-'No score variation or events';return(out)}
  fit<-tryCatch(withCallingHandlers(coxph(Surv(entry,stop,event)~score_z+strata(center),data=d,ties='efron',x=TRUE,y=TRUE,model=TRUE,
    control=coxph.control(iter.max=50,eps=1e-9)),warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e){err<<-conditionMessage(e);NULL})
  if(!is.null(fit)) {
    sm<-summary(fit);v<-sm$coefficients['score_z',];ci<-sm$conf.int['score_z',]
    out$logHR<-unname(v['coef']);out$SE<-unname(v['se(coef)']);out$z<-unname(v['z']);out$pval<-unname(v['Pr(>|z|)'])
    out$HR<-unname(ci['exp(coef)']);out$lower95<-unname(ci['lower .95']);out$upper95<-unname(ci['upper .95'])
    out$fit_ok<-all(is.finite(c(out$logHR,out$SE,out$z,out$pval)))&&out$SE>0&&!any(grepl('infinite|did not converge|Ran out of iterations',warnings,ignore.case=TRUE))
    out$PH_p<-tryCatch(cox.zph(fit,transform='km',terms=FALSE,global=FALSE)$table['score_z','p'],error=function(e)NA_real_)
  }
  out$warning<-paste(unique(warnings),collapse=' | ');out$error<-err;out
}
bh_fixed <- function(p,n) {r<-rep(NA_real_,length(p));ok<-is.finite(p);r[ok]<-p.adjust(p[ok],'BH',n=n);r}
read_original_cox <- function(omics,tm) {
  p<-if(omics=='RNA')paste0('01_RNA_TMM/01_',tm,'_TMM_center_stratified_cox_zph.csv') else paste0('02_Protein/01_',tm,'_center_primary_cox_zph.csv')
  fread(file.path(cfg$source_root,p),data.table=FALSE)
}
read_original_gsea <- function(omics,tm) {
  if(omics=='RNA') {z<-fread(file.path(cfg$source_root,'01_RNA_TMM/03_RNA_TMM_Hallmark_primary_PHpass.csv'),data.table=FALSE);z<-z[z$Time==tm&z$analysis=='Primary',]}
  else {z<-fread(file.path(cfg$source_root,'02_Protein/03_Protein_Hallmark_all_models.csv'),data.table=FALSE);z<-z[z$analysis==paste0(tm,'_center_primary'),]}
  z
}

