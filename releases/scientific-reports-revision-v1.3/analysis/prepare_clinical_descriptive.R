# Descriptive preparation using the recorded clinical definitions and existing P values.
# No hypothesis tests, Cox, GSEA, IPW, or normalization are run.
suppressPackageStartupMessages(library(data.table))
args <- commandArgs(TRUE); out <- args[1]; dir.create(out,recursive=TRUE,showWarnings=FALSE)
if(length(args)!=4)stop('Usage: Rscript prepare_clinical_descriptive.R OUTPUT ANNOTATION EXISTING_BASELINE_CSV CLINICAL_CODE')
src <- readLines(args[4],encoding='UTF-8')
# Parse definitions/functions only. Never source the model-fitting script.
ee <- new.env(); ee$tribble <- tibble::tribble
ex <- parse(text=src)
allowed <- c('continuous','binary','fmt_cont','continuous_smd','binary_smd')
for(e in ex) if(is.call(e)&&as.character(e[[1]])=='<-'&&is.symbol(e[[2]])&&as.character(e[[2]])%in%allowed) eval(e,ee)
ann <- fread(args[2])
d <- unique(ann[day_num==1],by='PatientID');stopifnot(nrow(d)==504,sum(d$sTatus)==84)
old <- fread(args[3])
ans <- list(); k <- 0L
add <- function(v,label,level,type,unit,x){
 k <<- k+1L; a<-x[d$sTatus==0];b<-x[d$sTatus==1]
 if(type=='continuous'){
  smd<-ee$continuous_smd(x,d$sTatus);alt<-NA_real_
  display<-vapply(list(x,a,b),ee$fmt_cont,character(1)); n<-rep(NA_real_,3)
 }else{
  p0<-mean(a==1,na.rm=TRUE);p1<-mean(b==1,na.rm=TRUE)
  smd<-ee$binary_smd(x,d$sTatus);alt<-(p1-p0)/sqrt(mean(c(p0,p1))*(1-mean(c(p0,p1))))
  n<-vapply(list(x,a,b),function(z)sum(z==1,na.rm=TRUE),numeric(1))
  display<-vapply(list(x,a,b),function(z)sprintf('%d (%.1f%%)',sum(z==1,na.rm=TRUE),100*mean(z==1,na.rm=TRUE)),character(1))
 }
 ix<-if(type=='infection')which(old$Level==level) else which(old$Variable==label)
 stopifnot(length(ix)==1)
 ans[[k]] <<- data.table(variable=v,label=label,level=level,type=type,unit=unit,Overall=display[1],Survivor=display[2],Death=display[3],N_overall=sum(!is.na(x)),N_survivor=sum(!is.na(a)),N_death=sum(!is.na(b)),Missing_overall=sum(is.na(x)),Missing_survivor=sum(is.na(a)),Missing_death=sum(is.na(b)),count_overall=n[1],count_survivor=n[2],count_death=n[3],mean_survivor=if(type=='continuous')mean(a,na.rm=TRUE) else NA_real_,mean_death=if(type=='continuous')mean(b,na.rm=TRUE) else NA_real_,variance_survivor=if(type=='continuous')var(a,na.rm=TRUE) else NA_real_,variance_death=if(type=='continuous')var(b,na.rm=TRUE) else NA_real_,SMD=smd,SMD_formula2=alt,P_value_existing=old$P_value[ix],historical_SMD=old$SMD[ix],historical_overall=old$Overall[ix],historical_survivor=old[['Survivor/censored']][ix],historical_death=old$Death[ix])
}
for(i in seq_len(nrow(ee$continuous))){z<-ee$continuous[i,];if(z$variable=='procal')next;add(z$variable,z$label,'','continuous',z$unit,as.numeric(d[[z$variable]]))}
for(i in seq_len(nrow(ee$binary))){z<-ee$binary[i,];add(z$variable,z$label,'1 vs 0','binary','n (%)',as.numeric(d[[z$variable]]))}
for(l in levels(factor(d$infectionSite_SD)))add('infectionSite_SD','Infection source',l,'infection','n (%)',as.integer(d$infectionSite_SD==l))
res<-rbindlist(ans);stopifnot(nrow(res)==41)
fwrite(res,file.path(out,'Table1_S9_normalized.tsv'),sep='\t')
writeLines(capture.output(sessionInfo()),file.path(out,'sessionInfo.txt'))
cat('41 descriptive rows; existing P reused; no tests run.\n')
