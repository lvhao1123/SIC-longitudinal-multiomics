# Display-only labels; plot data, ordering, scales, layers and statistics retained.
a<-commandArgs(TRUE);base<-a[1];out<-a[2]
library(ggplot2);library(grid)
Sys.setenv(SIC_PLOT_ROOT=out,SIC_FONT_PT='7.25')
source(file.path(out,'R/11_title_hierarchy.R'))
source(file.path(out,'R/typography.R'))
map<-c(Chest='infectionSite_SD=Lung/chest',Liver='infectionSite_SD=Biliary/liver',Unknown='infectionSite_SD=Others/unknown')
checks<-list()
for(j in 1:3){
 p<-readRDS(file.path(base,'private',paste0('A3_part_',j,'_plot_before_typography.rds')))
 original<-ggplot_build(p)$data
 p<-p+scale_y_discrete(labels=function(x){hit<-x %in% names(map);x[hit]<-unname(map[x[hit]]);x})
 stopifnot(identical(original,ggplot_build(p)$data))
 save_bundle(p,file.path(out,'figures',paste0('S3_part_',j)),166,232)
 checks[[j]]<-data.frame(part=j,plot_layers_identical=TRUE,rows=nrow(p$data),display_labels_only=TRUE)
}
write.table(do.call(rbind,checks),file.path(out,'qa/S3_layer_equivalence.tsv'),sep='\t',row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,'R/sessionInfo_label_export.txt'))
