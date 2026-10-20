# Read-only revision input checks. Output contains aggregate counts only.
library(data.table)
args<-commandArgs(TRUE);d<-Sys.getenv('CMAISE_DATA_DIR');f<-Sys.getenv('SIC_FROZEN_PRIVATE_DIR')
a<-Sys.getenv('SIC_AVAILABILITY_MATRIX');if(!nzchar(a))stop('SIC_AVAILABILITY_MATRIX required for revision A3')
cl<-fread(file.path(d,'SIC_504_baseline_carried_forward_annotation.csv'))
av<-fread(a);stopifnot(nrow(av)==504,!anyDuplicated(av$PatientID),sum(av$Protein_D1)==168,all(av$PatientID %in% cl$PatientID))
for(k in c('PatientID','SampleName','Protein_D1','age','SOFA','lac'))if(!k %in% names(av))stop('Availability field missing: ',k)
r<-readRDS(file.path(f,'01_RNA_TMM/RNA_TMM_logCPM_gene_by_sample.rds'))
p<-readRDS(file.path(f,'02_Protein/Protein_QC_gene_by_sample.rds'))
stopifnot(!anyNA(r),!anyNA(p),all(colnames(r)%in%cl$SampleName),all(colnames(p)%in%cl$SampleName))
counts<-list(data.frame(input='availability_A3',rows=nrow(av),keys_unique=TRUE),data.frame(input='RNA_matrix',rows=nrow(r),keys_unique=!anyDuplicated(rownames(r))),data.frame(input='protein_matrix',rows=nrow(p),keys_unique=!anyDuplicated(rownames(p))))
for(n in c('01_RNA_patient_core_pathway_rank_scores.csv','02_Protein_patient_core_pathway_rank_scores.csv')){
 x<-fread(file.path(f,'03_CrossOmics',n),select=c('PatientID','Time','Pathway'))
 stopifnot(!anyDuplicated(x),all(x$PatientID%in%cl$PatientID),all(x$Time%in%c('D1','D3','D5')))
 counts[[length(counts)+1]]<-data.frame(input=sub('_patient.*','_scores',n),rows=nrow(x),keys_unique=TRUE)
}
write.table(do.call(rbind,counts),args[1],sep='\t',row.names=FALSE,quote=FALSE)
capture.output(sessionInfo(),file=args[2])
cat('Revision input joins and unique keys checked; no model/scores calculated.\n')
