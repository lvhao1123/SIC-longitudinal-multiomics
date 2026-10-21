# Output arithmetic, coverage, privacy-schema and rendering QA. No model fits.
a<-commandArgs(TRUE);stopifnot(length(a)==1L);out<-normalizePath(a[1],winslash='/',mustWork=TRUE)
lib<-Sys.getenv('SIC_R_LIBRARY');if(nzchar(lib)).libPaths(c(lib,.libPaths()))
suppressPackageStartupMessages({library(data.table);library(jsonlite);library(digest)})
read_t<-function(n)fread(file.path(out,'results',n),data.table=FALSE)
qa<-list();add<-function(n,b,d){qa[[length(qa)+1L]]<<-data.frame(check=n,verified=isTRUE(b),detail=d)}
new<-read_t('newly_fitted_proteins.tsv');c<-read_t('control_all_protein_cox_PH.tsv');co<-read_t('all_Hallmark_comparison.tsv');h<-read_t('control_all_Hallmark_VALIDATED.tsv')
relative_error<-function(x,y)max(abs(x-y)/pmax(1,abs(y)),na.rm=TRUE)
add('new_HR_from_beta',relative_error(new$HR,exp(new$logHR))<1e-12,'Arithmetic check, not refitting')
add('new_SE_z_identity',relative_error(new$z,new$logHR/new$SE)<1e-12,'Wald z')
add('new_Wald_P_identity',relative_error(new$pval,2*pnorm(-abs(new$z)))<1e-12,'Two-sided Wald P')
add('new_CI_identity',max(relative_error(new$lower95,exp(new$logHR-qnorm(.975)*new$SE)),relative_error(new$upper95,exp(new$logHR+qnorm(.975)*new$SE)))<1e-12,'95% CI on HR scale')
add('full_status_grid',nrow(h)==150L&&all(table(h$Time)==50L),'50 original Hallmark IDs x three landmarks')
add('precision_flags_match_data',all((h$status=='estimable_precision_uncertain')==(h$eligible & is.finite(h$NES)&is.finite(h$pval)&!is.finite(h$log2err))),'D5 cholesterol precision flag follows raw fgsea log2err NA')
hm<-read_t('figure_heatmap_source.tsv')
for(tm in c('D1','D3','D5'))for(g in c('CV <20%','CV off')) {
  d<-hm[hm$Time==tm & hm$group==g,,drop=FALSE];z<-co[co$Time==tm,,drop=FALSE];i<-match(as.character(d$pathway),z$pathway)
  nn<-if(g=='CV <20%')z$ref_NES[i]else z$control_NES[i];pp<-if(g=='CV <20%')z$ref_FDR[i]else z$control_FDR[i]
  add(paste('heatmap numbers',tm,g),isTRUE(all.equal(d$NES,nn,tolerance=1e-14))&&isTRUE(all.equal(d$FDR,pp,tolerance=1e-14)),'All displayed cells match comparison source')
}
tables<-list.files(file.path(out,'results'),pattern='\\.tsv$',full.names=TRUE)
for(f in tables) {
  cols<-names(fread(f,nrows=0L))
  add(paste('no row-level identifiers',basename(f)),!any(grepl('PatientID|SampleName|BaselineSampleName|SampleLocation|^center$|^centre$',cols,ignore.case=TRUE)),'Column-schema check; feature/gene IDs are not participant IDs')
}
exports<-read_t('figure_export_contract.tsv');render<-list();pdf_text<-list()
for(i in seq_len(nrow(exports))) {
  e<-exports[i,];base<-file.path(out,'figures',e$figure)
  pdf<-paste0(base,'.pdf');sz<-pdftools::pdf_pagesize(pdf);fonts<-pdftools::pdf_fonts(pdf);boxes<-pdftools::pdf_data(pdf)[[1]]
  add(paste(e$figure,'PDF size'),abs(sz$width[1]-floor(e$width_mm/25.4*72))<.01&&abs(sz$height[1]-floor(e$height_mm/25.4*72))<.01,'Cairo integer-point MediaBox; exact floor of requested point dimensions, not 0.1-mm rounding tolerance')
  add(paste(e$figure,'fonts embedded'),all(fonts$embedded),'Arial font embedding verified')
  add(paste(e$figure,'text bounds'),all(boxes$x>=-.2 & boxes$y>=-.2 & boxes$x+boxes$width<=sz$width[1]+.2 & boxes$y+boxes$height<=sz$height[1]+.2),'PDF text bounding boxes inside page')
  bitmap<-pdftools::pdf_render_page(pdf,page=1,dpi=150,numeric=TRUE)
  png::writePNG(bitmap,file.path(out,'qa',paste0(e$figure,'_PDF_150dpi.png')))
  rsvg::rsvg_png(paste0(base,'.svg'),file.path(out,'qa',paste0(e$figure,'_SVG.png')),width=round(e$width_mm/25.4*150))
  ti<-magick::image_info(magick::image_read(paste0(base,'.tiff')))
  add(paste(e$figure,'TIFF pixels'),abs(ti$width-round(e$width_mm/25.4*600))<=1 && abs(ti$height-round(e$height_mm/25.4*600))<=1,'600-dpi physical-size pixel dimensions')
  add(paste(e$figure,'TIFF density'),grepl('600',ti$density),'TIFF density metadata')
  render[[i]]<-data.frame(figure=e$figure,pdf_width_mm=sz$width[1]*25.4/72,pdf_height_mm=sz$height[1]*25.4/72,TIFF_width_px=ti$width,TIFF_height_px=ti$height,TIFF_density=ti$density,PDF_fonts_embedded=all(fonts$embedded),smallest_text_box_height_pt=min(boxes$height[boxes$height>0]))
  pdf_text[[e$figure]]<-pdftools::pdf_text(pdf)
}
fwrite(do.call(rbind,render),file.path(out,'qa/figure_metadata.tsv'),sep='\t')
fwrite(do.call(rbind,qa),file.path(out,'qa/additional_QA.tsv'),sep='\t')
write_json(list(executed_at=format(Sys.time(),'%Y-%m-%d %H:%M:%S %z'),checks=length(qa),failed=vapply(qa,function(x)if(!x$verified)x$check else '',character(1))[!vapply(qa,function(x)x$verified,logical(1))],rendered_PDF_and_SVG=TRUE,visual_review='must be recorded separately after actual image inspection'),file.path(out,'qa/output_verification.json'),auto_unbox=TRUE,pretty=TRUE)
packages<-installed.packages();used<-unique(c(loadedNamespaces(),'survival','fgsea','readxl','dplyr','ggplot2','patchwork','ragg','svglite'))
fwrite(data.frame(package=used,version=packages[used,'Version'],built=packages[used,'Built']),file.path(out,'qa/package_versions.tsv'),sep='\t')
writeLines(capture.output(sessionInfo()),file.path(out,'logs/sessionInfo_final_QA.txt'))
print(do.call(rbind,render));print(do.call(rbind,qa)[!vapply(qa,function(x)x$verified,logical(1)),]);cat('QA checks:',length(qa),'\n')
if(any(!vapply(qa,function(x)x$verified,logical(1))))quit(status=1,save='no')
