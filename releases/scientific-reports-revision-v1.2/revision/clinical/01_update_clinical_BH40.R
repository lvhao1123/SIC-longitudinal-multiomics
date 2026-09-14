# Exploratory clinical comparison-family amendment, 2026-09-08.
# Only p.adjust for the 40 retained clinical association P values. No model fits.
args <- commandArgs(trailingOnly = TRUE)
stage <- normalizePath(args[1], mustWork = TRUE)
.libPaths(c(Sys.getenv('SIC_R_LIBRARY'), .libPaths()))
library(data.table)
input <- Sys.getenv('SIC_CLINICAL_40_PRE_BH_FILE')
if(!nzchar(input)) stop('Set SIC_CLINICAL_40_PRE_BH_FILE to the 40-row pre-amendment aggregate table')
dat <- fread(input, colClasses='character', na.strings=NULL)
stopifnot(nrow(dat)==40L, !any(dat$Variable=='procal'))
p <- as.numeric(dat$P_value); old <- as.numeric(dat$BH_FDR)
stopifnot(all(is.finite(p)), all(p>=0 & p<=1))
updated <- p.adjust(p, method='BH', n=40L)
ledger <- data.table(Variable=dat$Variable,Contrast=dat$Contrast,P_value=p,
                    BH_FDR_41=old,BH_FDR_40=updated,difference=updated-old,
                    significant_before=old<.05,significant_after=updated<.05)
fwrite(ledger,file.path(stage,'qa/CLINICAL_BH40_CHANGE_LEDGER.tsv'),sep='\t',na='')
dat$BH_FDR <- sprintf('%.17g',updated)
# Only display labels derived from the authorised new FDR are updated.
dat$FDR_status <- ifelse(updated<.05,'BH-FDR < 0.05','Not FDR-significant')
dat$Direction_status <- ifelse(updated<.05,ifelse(as.numeric(dat$HR)>1,'Higher hazard','Lower hazard'),'Not FDR-significant')
dat$FDR_text <- ifelse(updated<.001,'<0.001*',paste0(formatC(updated,format='f',digits=3),ifelse(updated<.05,'*','')))
fwrite(dat,file.path(stage,'figure_source_data/SourceData_Supplementary_Figure_A9.tsv'),sep='\t',na='')
capture.output(sessionInfo(),file=file.path(stage,'qa/sessionInfo_BH40.txt'))
cat('Contrasts:',nrow(dat),'significant before/after:',sum(old<.05),sum(updated<.05),
    'classification changes:',sum((old<.05)!=(updated<.05)),'\n')
