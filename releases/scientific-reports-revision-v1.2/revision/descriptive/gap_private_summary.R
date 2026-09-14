args <- commandArgs(trailingOnly=TRUE)
out <- args[1]
annotation <- Sys.getenv('SIC_CLINICAL_ANNOTATION')
weights <- Sys.getenv('SIC_D5_WEIGHTS_FILE')
a <- read.csv(annotation, check.names=FALSE, stringsAsFactors=FALSE)
w <- read.csv(weights, check.names=FALSE, stringsAsFactors=FALSE)
b <- a[a$day_num==1, ]; stopifnot(!anyDuplicated(b$PatientID), nrow(b)==504)
stopifnot(!anyDuplicated(w$PatientID), all(w$PatientID %in% b$PatientID))
b$group <- ifelse(b$surv_time<=4, 'Structural_nonavailability_at_or_before_entry', ifelse(b$PatientID %in% w$PatientID, 'Positivity_supported_survivors', 'Zero_observation_centre_survivors'))
b$centre <- sub('_[^_]+$', '', b$PatientID)
excluded <- b[b$group=='Zero_observation_centre_survivors',]
stopifnot(nrow(excluded)==4, length(unique(excluded$centre))==3, !any(excluded$centre %in% w$center))
stopifnot(sum(b$surv_time<=4)==13, all(b$sTatus[b$surv_time<=4]==1), nrow(w)==487, sum(w$available)==320)
stopifnot(sum(b$sTatus[match(w$PatientID[w$available==1],b$PatientID)])==53)
rows <- list()
for(g in unique(b$group)) {
 d <- b[b$group==g,]
 for(v in c('age','SOFA','lac')) {
  x <- d[[v]]; q <- quantile(x,c(.25,.5,.75),na.rm=TRUE,names=FALSE)
  rows[[length(rows)+1]] <- data.frame(group=g,N=nrow(d),variable=v,nonmissing=sum(!is.na(x)),missing=sum(is.na(x)),median=q[2],q25=q[1],q75=q[3],count=NA)
 }
 rows[[length(rows)+1]] <- data.frame(group=g,N=nrow(d),variable='male_sex_coded_1',nonmissing=sum(!is.na(d$sex)),missing=sum(is.na(d$sex)),median=NA,q25=NA,q75=NA,count=sum(d$sex==1,na.rm=TRUE))
}
write.csv(do.call(rbind,rows),file.path(out,'private','excluded_baseline_PRIVATE_NOT_FOR_RELEASE.csv'),row.names=FALSE,na='')
writeLines(c('LOCAL PRIVATE AGGREGATE ONLY. No patient-level output. Publication permission for the four-person group has not been established.', 'entry=4; structural group surv_time<=4; supported group from existing primary controlled weights; excluded group surviving beyond4 outside that support; 3 distinct centres verified.', 'Summary only; no hypothesis tests, models, weights or FDR recalculated. Continuous quantiles use R type7. sex=1 is male, consistent with existing A3 audit coding.'),file.path(out,'private','DESCRIPTIVE_SUMMARY_README.txt'))
writeLines(capture.output(sessionInfo()),file.path(out,'private','sessionInfo_descriptive.txt'))
cat('Private aggregate saved; denominators verified: 13 structural, 4 excluded, 487 supported, 320 observed, 53 observed subsequent deaths.\n')
