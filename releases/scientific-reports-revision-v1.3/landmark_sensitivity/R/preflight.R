args <- commandArgs(TRUE)
if (length(args)!=1L) stop("Usage: Rscript preflight.R OUTPUT_DIRECTORY")
script_arg <- grep("^--file=", commandArgs(FALSE), value=TRUE)
SCRIPT_DIR <- dirname(normalizePath(sub("^--file=", "", script_arg[[1]]), winslash="/", mustWork=TRUE))
source(file.path(SCRIPT_DIR, "common.R"), encoding="UTF-8")
out<-list()
for(omics in c('RNA','Protein')) {
 o<-load_inputs(omics);md<-o$md
 ids<-Reduce(intersect,lapply(c('D1','D3','D5'),function(t)md$PatientID[md$Time==t&md$stop>4]))
 for(i in 1:3) {
  tm<-c('D1','D3','D5')[i];entry<-c(0,2,4)[i];m<-md[md$Time==tm&md$stop>entry,]
  expectedN<-if(omics=='RNA')c(504,420,320) else c(168,147,114)
  expectedE<-if(omics=='RNA')c(84,67,53) else c(27,18,14)
  stopifnot(nrow(m)==expectedN[i],sum(m$event)==expectedE[i])
  cm<-md[md$Time==tm&md$PatientID%in%ids,]
  out[[length(out)+1]]<-data.frame(Omics=omics,Time=tm,features=nrow(o$x),original_N=nrow(m),original_events=sum(m$event),A_N=nrow(cm),A_events=sum(cm$event))
 }
}
z<-rbindlist(out);write_table(z,'qa/preflight_counts.tsv');print(z)
writeLines(capture.output(sessionInfo()),file.path(ROOT,'logs/session_preflight.txt'))

