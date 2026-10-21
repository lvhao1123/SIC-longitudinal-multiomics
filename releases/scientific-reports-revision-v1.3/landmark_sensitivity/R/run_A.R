args <- commandArgs(TRUE)
if (length(args)!=2L || !args[2] %in% c("RNA", "Protein")) stop("Usage: Rscript run_A.R OUTPUT_DIRECTORY RNA|Protein")
script_arg <- grep("^--file=", commandArgs(FALSE), value=TRUE)
SCRIPT_DIR <- dirname(normalizePath(sub("^--file=", "", script_arg[[1]]), winslash="/", mustWork=TRUE))
source(file.path(SCRIPT_DIR, "common.R"), encoding="UTF-8")
omics<-commandArgs(TRUE)[2];stopifnot(omics %in% c('RNA','Protein'))
con<-start_log(paste0('A_',omics));obj<-load_inputs(omics);x<-obj$x;md<-obj$md;h<-obj$hallmark
ids<-Reduce(intersect,lapply(c('D1','D3','D5'),function(tm)md$PatientID[md$Time==tm&md$stop>4]))
stopifnot(length(ids)>0)
saveRDS(ids,file.path(ROOT,'local_cache',paste0('A_',omics,'_common_patient_ids.rds')))
cover<-vapply(h,function(p)sum(rownames(x)%in%p),integer(1));family<-names(h)[cover>=15&cover<=500]
write_table(data.frame(Omics=omics,pathway=names(h),covered=cover,eligible=names(h)%in%family),paste0('qa/A_',omics,'_coverage.tsv'))
for(tm in c('D1','D3','D5')) {
  meta<-md[md$Time==tm & md$PatientID%in%ids,];meta<-meta[match(sort(ids),meta$PatientID),]
  stopifnot(identical(meta$PatientID,sort(ids)),all(meta$stop>4),!anyDuplicated(meta$PatientID))
  xx<-scale(t(x[,meta$SampleName,drop=FALSE]));xx[!is.finite(xx)]<-NA_real_
  cat(omics,tm,'N',nrow(meta),'Events',sum(meta$event),'features',ncol(xx),'\n')
  fits<-lapply(seq_len(ncol(xx)),function(j){if(j%%500==0)cat('Fitted',j,format(Sys.time()),'\n');fit_score(xx[,j],meta,4)})
  z<-rbindlist(fits,fill=TRUE);z[,`:=`(Omics=omics,Time=tm,gene_symbol=colnames(xx),entry_day=4)]
  z[,padj:=bh_fixed(ifelse(fit_ok,pval,NA_real_),.N)]
  write_table(z,paste0('results/A/',omics,'_',tm,'_feature_cox.tsv'))
  stats<-z$z[z$fit_ok&is.finite(z$z)];names(stats)<-z$gene_symbol[z$fit_ok&is.finite(z$z)];stats<-sort(stats,decreasing=TRUE)
  set.seed(20260711)
  gs<-fgseaMultilevel(h[family],stats,sampleSize=1001,nPermSimple=10000,minSize=15,maxSize=500,eps=0,scoreType='std',nproc=1)
  gs[,precision_retry:=FALSE]
  for(i in which(!is.finite(gs$pval)|!is.finite(gs$NES))) {
    set.seed(20260711);rr<-fgseaMultilevel(h[gs$pathway[i]],stats,sampleSize=5001,nPermSimple=100000,minSize=15,maxSize=500,eps=0,scoreType='std',nproc=1)
    gs$precision_retry[i]<-TRUE
    if(nrow(rr)==1&&is.finite(rr$pval)&&is.finite(rr$NES)){for(nm in c('ES','NES','pval','log2err','size'))set(gs,i,nm,rr[[nm]][1]);gs$leadingEdge[[i]]<-rr$leadingEdge[[1]]}
  }
  gs[,leadingEdge_text:=vapply(leadingEdge,paste,collapse=';',FUN.VALUE=character(1))];gs[,leadingEdge:=NULL]
  gs<-merge(data.table(pathway=names(h),coverage=cover,eligible=names(h)%in%family),gs,by='pathway',all.x=TRUE,sort=FALSE)
  gs[,`:=`(padj=bh_fixed(pval,length(family)),Omics=omics,Time=tm,N=nrow(meta),Events=sum(meta$event),entry_day=4,ranked_features=length(stats),family_n=length(family))]
  write_table(gs,paste0('results/A/',omics,'_',tm,'_Hallmark.tsv'))
  cat('Completed',omics,tm,'estimable',sum(is.finite(gs$pval)),'FDR05',sum(gs$padj<.05,na.rm=TRUE),'\n')
}
writeLines(capture.output(sessionInfo()),file.path(ROOT,'logs',paste0('session_A_',omics,'.txt')))
end_log(con)

