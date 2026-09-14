# Display-only typography. The ggplot data and statistical specifications are untouched.
FONT_PT <- as.numeric(Sys.getenv('SIC_FONT_PT', '7.25'))
FONT_MM <- FONT_PT / ggplot2::.pt
size_map <- read.delim(file.path(Sys.getenv('SIC_PLOT_ROOT'),'qa/FIGURE_SIZE_MAP.tsv'),check.names=FALSE)
normalise_plot <- function(p) {
  if(inherits(p,'patchwork')) {
    p$patches$plots <- lapply(p$patches$plots,normalise_plot)
    at <- p$patches$annotation$theme
    if(is.null(at)) at<-theme()
    for(nm in names(at)) if(inherits(at[[nm]],'element_text')) {at[[nm]]$size<-FONT_PT;at[[nm]]$family<-'Arial'}
    p$patches$annotation$theme<-at+theme(plot.title=element_text(size=FONT_PT,family='Arial',face='bold',hjust=.5),plot.subtitle=element_text(size=FONT_PT,family='Arial',hjust=.5))
  }
  for(nm in names(p$theme)) {
    if(inherits(p$theme[[nm]],'element_text')) {p$theme[[nm]]$size<-FONT_PT;p$theme[[nm]]$family<-'Arial'}
    if(inherits(p$theme[[nm]],'element_line') && !is.null(p$theme[[nm]]$linewidth)) p$theme[[nm]]$linewidth<-max(.36,p$theme[[nm]]$linewidth)
  }
  p$theme<-p$theme+theme(text=element_text(size=FONT_PT,family='Arial'),plot.title.position='plot')
  for(i in seq_along(p$layers)) {
    l<-p$layers[[i]]
    if(inherits(l$geom,'GeomText') || inherits(l$geom,'GeomLabel')) {
      l$aes_params$size<-FONT_MM;l$aes_params$family<-'Arial'
    }
    if(!is.null(l$aes_params$linewidth)) l$aes_params$linewidth<-max(.36,l$aes_params$linewidth)
    p$layers[[i]]<-l
  }
  p
}
font_grobs <- function(g) {
  if(inherits(g,'text')) {g$gp$fontsize<-FONT_PT;g$gp$fontfamily<-'Arial'}
  # R's lwd unit is 1/96 inch: 4/3 is one point in the exported vector.
  # Apply after grob construction so explicit grid lines and inherited widths agree.
  if(!inherits(g,'text') && !is.null(g$gp$lwd)) g$gp$lwd<-pmax(4/3,g$gp$lwd)
  if(!is.null(g$grobs)) for(i in seq_along(g$grobs)) g$grobs[[i]]<-font_grobs(g$grobs[[i]])
  if(!is.null(g$children)) for(i in seq_along(g$children)) g$children[[i]]<-font_grobs(g$children[[i]])
  g
}
make_typography_grob <- function(p) {
  p<-normalise_plot(p)
  g<-if(inherits(p,'patchwork')) patchwork::patchworkGrob(p) else ggplot2::ggplotGrob(p)
  # Use native text extents at the selected physical size; historical fixed offsets were sized for smaller text.
  if(exists('patch_centre_labels')) g<-patch_centre_labels(g)
  compact_axis_titles(font_grobs(apply_title_hierarchy(g)))
}
draw_typography <- function(p) {grid::grid.newpage();grid::grid.draw(make_typography_grob(p))}
save_bundle <- function(plot,stem,width_mm,height_mm,dpi=600) {
  row<-size_map[size_map$stem==basename(stem),]
  # The dense all-in-one A3 is not embedded. Only its existing three parts are rebuilt.
  if(!nrow(row)) return(invisible(NULL))
  w<-row$target_width_mm[1];h<-row$target_height_mm[1]
  root<-Sys.getenv('SIC_PLOT_ROOT');stem<-file.path(root,'figures',basename(stem))
  saveRDS(plot,file.path(root,'private',paste0(basename(stem),'_plot_before_typography.rds')))
  svglite::svglite(paste0(stem,'.svg'),width=w/25.4,height=h/25.4,bg='white')
  g<-make_typography_grob(plot);grid::grid.draw(g);dev.off()
  grDevices::cairo_pdf(paste0(stem,'.pdf'),width=w/25.4,height=h/25.4,family='Arial');grid::grid.draw(g);dev.off()
  ragg::agg_tiff(paste0(stem,'.tiff'),width=w,height=h,units='mm',res=600,compression='lzw');grid::grid.draw(g);dev.off()
  ragg::agg_png(paste0(stem,'.png'),width=w,height=h,units='mm',res=180);grid::grid.draw(g);dev.off()
  saveRDS(g,file.path(root,'private',paste0(basename(stem),'_grob.rds')))
  cat('DISPLAY',basename(stem),w,h,'mm; Arial',FONT_PT,'pt at 1:1 embedding\n')
}

# Move a y-axis title next to this panel's own tick labels, not the shared label column.
compact_axis_titles <- function(g) {
  texts <- function(x) {
    a <- if(inherits(x,'text')) list(x) else list()
    if(!is.null(x$grobs)) for(y in x$grobs) a<-c(a,texts(y))
    if(!is.null(x$children)) for(y in x$children) a<-c(a,texts(y))
    a
  }
  if(inherits(g,'gtable')) for(i in seq_along(g$grobs)) {
    nm<-g$layout$name[i]
    if(grepl('^ylab-l',nm) && inherits(g$grobs[[i]],'titleGrob')) {
      ai<-match(sub('^ylab-l','axis-l',nm),g$layout$name)
      tt<-texts(g$grobs[[i]])
      if(!is.na(ai) && length(tt)) {
        at<-texts(g$grobs[[ai]])
        widths<-vapply(at,function(t) grid::convertWidth(grid::grobWidth(t),'mm',valueOnly=TRUE),numeric(1))
        offset<-if(length(widths)) max(widths)+2.5 else 7
        g$layout[i,c('l','r')]<-g$layout[ai,c('l','r')];g$layout$clip[i]<-'off'
        g$grobs[[i]]<-grid::textGrob(tt[[1]]$label,x=grid::unit(1,'npc')-grid::unit(offset,'mm'),y=.5,rot=90,gp=tt[[1]]$gp)
      }
    } else g$grobs[[i]]<-compact_axis_titles(g$grobs[[i]])
  }
  g
}
