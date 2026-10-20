# Display-only adaptation of the preceding S15 R script.
# Inputs are already-computed aggregate results; no statistical analysis is run.
a <- commandArgs(TRUE)
stopifnot(length(a)==2L)
input <- normalizePath(a[1],winslash='/',mustWork=TRUE)
out <- normalizePath(a[2],winslash='/',mustWork=TRUE)
suppressPackageStartupMessages({library(ggplot2);library(grid)})
FONT_PT <- as.numeric(Sys.getenv('SIC_FONT_PT','9'))
hh <- read.delim(file.path(input,'figure_heatmap_source.tsv'),check.names=FALSE,na.strings=NULL)
hh$NES[hh$NES=='NA'] <- NA
hh$NES <- as.numeric(hh$NES)
stopifnot(nrow(hh)==300L, length(unique(hh$pathway))==50L,
          !anyDuplicated(hh[c('pathway','Time','group')]))
order_top <- sort(unique(hh$pathway))
parts <- list(a=order_top[1:25],b=order_top[26:50])
limit <- max(abs(hh$NES),na.rm=TRUE)
# One scale and one set of ticks are determined from all 300 cells, before splitting.
shared_breaks <- pretty(c(-limit,limit),n=5)
shared_breaks <- shared_breaks[shared_breaks>=-limit & shared_breaks<=limit]
hh$group <- factor(hh$group,levels=c('CV <20%','CV off'))
hh$Time <- factor(hh$Time,levels=c('D1','D3','D5'))
lab <- function(x) {
 s<-tolower(gsub('_',' ',x));substr(s,1,1)<-toupper(substr(s,1,1))
 special<-c(TNFA_SIGNALING_VIA_NFKB='TNF-α signalling via NF-κB',IL6_JAK_STAT3_SIGNALING='IL-6/JAK/STAT3 signalling',IL2_STAT5_SIGNALING='IL-2/STAT5 signalling',MYC_TARGETS_V1='MYC targets V1',MYC_TARGETS_V2='MYC targets V2',E2F_TARGETS='E2F targets',DNA_REPAIR='DNA repair',MTORC1_SIGNALING='mTORC1 signalling',TGF_BETA_SIGNALING='TGF-β signalling',EPITHELIAL_MESENCHYMAL_TRANSITION='Epithelial–mesenchymal transition',INTERFERON_ALPHA_RESPONSE='IFN-α response',INTERFERON_GAMMA_RESPONSE='IFN-γ response',REACTIVE_OXYGEN_SPECIES_PATHWAY='Reactive oxygen species pathway',G2M_CHECKPOINT='G2M checkpoint',PI3K_AKT_MTOR_SIGNALING='PI3K/AKT/mTOR signalling',UV_RESPONSE_DN='UV response DN',UV_RESPONSE_UP='UV response UP',KRAS_SIGNALING_DN='KRAS signalling DN',KRAS_SIGNALING_UP='KRAS signalling UP',P53_PATHWAY='p53 pathway',WNT_BETA_CATENIN_SIGNALING='WNT/β-catenin signalling')
 ii<-match(x,names(special));s[!is.na(ii)]<-special[ii[!is.na(ii)]];s
}
caption <- NULL
plots <- lapply(names(parts),function(tag) {
 d<-hh[as.character(hh$pathway)%in%parts[[tag]],]
 d$pathway<-factor(d$pathway,levels=rev(parts[[tag]]))
 ggplot(d,aes(group,pathway,fill=NES))+
  geom_tile(colour='white',linewidth=.36)+
  geom_text(aes(label=cell),size=FONT_PT/ggplot2::.pt,family='Arial')+
  facet_grid(~Time)+scale_y_discrete(labels=lab,expand=expansion(add=.5))+
  scale_x_discrete(labels=c('CV <20%'='CV\n<20%','CV off'='Without CV\nfiltering'),expand=expansion(add=.5))+
  scale_fill_gradient2(low='#6F8FB8',mid='white',high='#C56354',
    midpoint=0,limits=c(-limit,limit),breaks=shared_breaks,na.value='#EEEEEE')+
  labs(title='Hallmark enrichment with and without CV filtering',
       tag=tag,x=NULL,y=NULL,fill='NES',caption=caption)+
  theme_classic(base_size=FONT_PT,base_family='Arial')+
  theme(axis.line=element_blank(),axis.ticks=element_blank(),
    axis.text=element_text(colour='#333333',size=FONT_PT),
    axis.text.y=element_text(hjust=1,margin=margin(r=2)),
    axis.text.x=element_text(lineheight=.95),
    strip.text=element_text(size=FONT_PT,face='bold'),
    strip.background=element_blank(),panel.spacing.x=unit(2,'mm'),
    plot.title=element_text(size=FONT_PT,face='bold',hjust=.5),
    plot.title.position='plot',
    plot.tag=element_text(size=FONT_PT,face='bold',hjust=0),
    plot.tag.position=c(0,1),
    legend.position='right',legend.key.height=unit(11,'mm'),
    legend.key.width=unit(3.5,'mm'),legend.margin=margin(0,0,0,3),
    legend.title=element_text(size=FONT_PT),legend.text=element_text(size=FONT_PT),
    plot.caption=element_text(size=FONT_PT,hjust=0,lineheight=1.15),
    plot.caption.position='plot',plot.margin=margin(8,5,5,5))
})
names(plots)<-names(parts)
# Equal gtable geometry fixes left-label width, plot width, columns and row height.
cairo_pdf(file.path(out,'private/S15_layout_metrics.pdf'),width=166/25.4,height=170/25.4,family='Arial')
grobs <- lapply(plots,ggplotGrob)
stopifnot(identical(grobs[[1]]$layout$name,grobs[[2]]$layout$name))
common_widths <- do.call(unit.pmax,lapply(grobs,function(g)g$widths))
common_heights <- do.call(unit.pmax,lapply(grobs,function(g)g$heights))
grobs <- lapply(grobs,function(g){g$widths<-common_widths;g$heights<-common_heights;g})
minimum_lines <- function(g) {
 if(!inherits(g,'text') && !is.null(g$gp$lwd)) g$gp$lwd<-pmax(4/3,g$gp$lwd)
 if(!is.null(g$grobs)) g$grobs<-lapply(g$grobs,minimum_lines)
 if(!is.null(g$children)) for(i in seq_along(g$children)) g$children[[i]]<-minimum_lines(g$children[[i]])
 g
}
grobs<-lapply(grobs,minimum_lines)
dev.off()
w<-166;h<-170
draw <- function(g){grid.newpage();grid.draw(g)}
for(tag in names(grobs)) {
 base<-file.path(out,'figures',paste0('Supplementary_Figure_S15',tag,'_CV_dependence'))
 svglite::svglite(paste0(base,'.svg'),width=w/25.4,height=h/25.4);draw(grobs[[tag]]);dev.off()
 cairo_pdf(paste0(base,'.pdf'),width=w/25.4,height=h/25.4,family='Arial');draw(grobs[[tag]]);dev.off()
 ragg::agg_tiff(paste0(base,'.tiff'),width=w,height=h,units='mm',res=600,compression='lzw');draw(grobs[[tag]]);dev.off()
 ragg::agg_png(paste0(base,'.png'),width=w,height=h,units='mm',res=180);draw(grobs[[tag]]);dev.off()
}
cairo_pdf(file.path(out,'figures/Supplementary_Figure_S15_two_parts.pdf'),width=w/25.4,height=h/25.4,family='Arial',onefile=TRUE)
for(g in grobs) draw(g)
dev.off()
mapped<-hh
mapped$part<-ifelse(as.character(mapped$pathway)%in%parts$a,'a','b')
mapped$row_in_part<-match(as.character(mapped$pathway),order_top)
mapped$row_in_part[mapped$part=='b']<-mapped$row_in_part[mapped$part=='b']-25L
write.table(mapped,file.path(out,'qa/S15_cell_mapping.tsv'),sep='\t',row.names=FALSE,quote=TRUE,na='NA')
record<-list(width_mm=w,height_mm=h,Word_width_mm=166,Word_height_mm=h*166/w,
 font_family='Arial',font_cell_pt=FONT_PT,font_label_pt=FONT_PT,
 font_symbol_caption_pt=NA_real_,embedded_scale=166/w,scale_limits=c(-limit,limit),
 scale_breaks=shared_breaks,low='#6F8FB8',mid='white',high='#C56354',NA_colour='#EEEEEE',
 row_order=parts,shared_gtable_widths=as.character(common_widths),
 shared_gtable_heights=as.character(common_heights),
 note='Font size is a display profile, not a journal-mandated value; full legend accompanies part b.')
jsonlite::write_json(record,file.path(out,'qa/S15_display_contract.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
writeLines(capture.output(sessionInfo()),file.path(out,'R/sessionInfo_plot_only.txt'))
writeLines(capture.output(warnings()),file.path(out,'qa/R_plot_warnings.txt'))
cat('Two consecutive 25-pathway parts exported. All 300 cell labels reused verbatim.\n')
