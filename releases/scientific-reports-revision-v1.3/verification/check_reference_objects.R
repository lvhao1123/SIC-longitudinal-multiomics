# Read-only object schema and linkage checks; never prints identifiers or scores.
library(jsonlite)
args<-commandArgs(TRUE);cfg<-fromJSON(args[1]);out<-args[2]
if(file.exists(out))stop('Report exists')
res<-list()
for(k in names(cfg)){
 p<-cfg[[k]]
 if(!is.character(p)||length(p)!=1)next
 if(!file.exists(p))stop('CV reference input missing: ',k)
 if(grepl('\\.rds$',p)){
  obj<-readRDS(p)
  res[[k]]<-list(class=class(obj),names=names(obj),components=lapply(obj,function(x)list(class=class(x),dim=dim(x),missing=if(is.matrix(x)||is.data.frame(x))sum(is.na(x)) else NULL)))
 }
}
root<-dirname(dirname(cfg$reference_objects))
for(sub in c('01_RNA_TMM/RNA_reanalysis_objects.rds','01_RNA_TMM/RNA_TMM_logCPM_gene_by_sample.rds','03_CrossOmics/CrossOmics_reanalysis_objects.rds')){
 p<-file.path(root,sub)
 if(file.exists(p)){
  x<-readRDS(p)
  res[[sub]]<-list(class=class(x),names=if(is.list(x)&&!is.data.frame(x))names(x) else NULL,dim=dim(x),missing=if(is.matrix(x))sum(is.na(x))else NULL)
 }
}
write_json(res,out,pretty=TRUE,auto_unbox=TRUE)
cat('Reference inputs present; object structural audit written locally. No estimation.\n')
