# Descriptive comparisons and author-review figures; no statistical model fits.
a<-commandArgs(TRUE);stopifnot(length(a)==1L);out<-normalizePath(a[1],winslash='/',mustWork=TRUE)
lib<-Sys.getenv('SIC_R_LIBRARY');if(nzchar(lib)).libPaths(c(lib,.libPaths()))
suppressPackageStartupMessages({library(data.table);library(dplyr);library(tidyr);library(ggplot2);library(patchwork);library(jsonlite);library(fgsea)})
lc<-file(file.path(out,'logs/comparison_plot_run.log'),'wt');sink(lc,split=TRUE);sink(lc,type='message')
read_t<-function(n)fread(file.path(out,'results',n),data.table=FALSE)
save_t<-function(x,n)fwrite(x,file.path(out,'results',n),sep='\t',na='NA')
cfg<-fromJSON(file.path(out,'private/input_paths.json'))
ref<-read_t('reference_primary_Hallmark_unchanged.tsv');ctl<-read_t('control_all_Hallmark.tsv')
# Independently validate numerical status. The computation-stage scalar error
# branch recycled the first eligible status; correct only derived labels here.
raw_status<-ctl$status
ctl$status<-ifelse(!ctl$eligible,'coverage_outside_original_15_to_500',ifelse(!is.finite(ctl$NES)|!is.finite(ctl$pval),'result_uncertain_nonfinite',ifelse(!is.finite(ctl$log2err),'estimable_precision_uncertain','estimable')))
save_t(data.frame(Time=ctl$Time,pathway=ctl$pathway,initial_status=raw_status,validated_status=ctl$status,changed=raw_status!=ctl$status),'numerical_status_validation.tsv')
save_t(ctl,'control_all_Hallmark_VALIDATED.tsv')
rc<-read_t('reference_primary_cox_unchanged.tsv');cc<-read_t('control_all_protein_cox_PH.tsv')
features<-read_t('feature_sets.tsv');risk<-read_t('risk_sets.tsv');ranks<-read_t('control_full_Wald_rankings.tsv')
hall<-gmtPathways(cfg$hallmark);names(hall)<-sub('^HALLMARK_','',names(hall))
split_le<-function(s)if(length(s)==0L||is.na(s)||!nzchar(s))character()else strsplit(s,';',fixed=TRUE)[[1]]
jaccard<-function(x,y)if(length(union(x,y)))length(intersect(x,y))/length(union(x,y))else NA_real_
rf<-list();cmp<-list();members<-list()
for(tm in c('D1','D3','D5')) {
  r<-ref[ref$Time==tm,,drop=FALSE]
  valid<-rc$gene_symbol[rc$Time==tm & rc$fit_ok & is.finite(rc$z)]
  cover<-data.frame(pathway=names(hall),ref_coverage=vapply(hall,function(x)sum(x%in%valid),integer(1)))
  r<-left_join(cover,r,by='pathway');r$Time<-tm
  r$ref_status<-ifelse(r$ref_coverage<15|r$ref_coverage>500,'coverage_outside_original_15_to_500',ifelse(!is.finite(r$NES)|!is.finite(r$pval),'result_uncertain_nonfinite',ifelse(!is.finite(r$log2err),'estimable_precision_uncertain','estimable')))
  r$ref_family_eligible_n<-sum(r$ref_coverage>=15&r$ref_coverage<=500)
  r$ref_family_finite_p_n<-sum(is.finite(r$pval));rf[[tm]]<-r
  c<-ctl[ctl$Time==tm,,drop=FALSE]
  x<-left_join(r |> select(pathway,Time,ref_NES=NES,ref_ES=ES,ref_pval=pval,ref_FDR=padj,ref_log2err=log2err,ref_coverage,ref_status,ref_family_eligible_n,ref_family_finite_p_n,ref_LE=leadingEdge_text),c |> select(pathway,Time,control_NES=NES,control_ES=ES,control_pval=pval,control_FDR=padj,control_log2err=log2err,control_coverage=coverage,control_status=status,control_family_eligible_n=test_family_eligible_n,control_family_finite_p_n=test_family_finite_p_n,control_LE=leadingEdge_text),by=c('pathway','Time'))
  x$delta_NES<-x$control_NES-x$ref_NES
  x$ref_signed_NES_rank<-rank(-x$ref_NES,ties.method='min',na.last='keep')
  x$control_signed_NES_rank<-rank(-x$control_NES,ties.method='min',na.last='keep')
  x$rank_shift<-x$control_signed_NES_rank-x$ref_signed_NES_rank
  x$direction_same<-sign(x$ref_NES)==sign(x$control_NES)
  x$FDR_status<-ifelse(is.na(x$ref_FDR)|is.na(x$control_FDR),'not_comparable',ifelse(x$ref_FDR<.05 & x$control_FDR<.05,'both_FDR_lt_05',ifelse(x$ref_FDR<.05,'reference_only',ifelse(x$control_FDR<.05,'control_only','neither'))))
  z<-ranks[ranks$Time==tm,,drop=FALSE];zz<-setNames(z$z,z$gene_symbol)
  for(i in seq_len(nrow(x))) {
    old<-split_le(x$ref_LE[i]);new<-split_le(x$control_LE[i]);added<-setdiff(new,features$gene_symbol[features$in_reference])
    x$ref_LE_n[i]<-length(old);x$control_LE_n[i]<-length(new);x$shared_LE_n[i]<-length(intersect(old,new));x$LE_Jaccard[i]<-jaccard(old,new)
    x$shared_universe_LE_Jaccard[i]<-jaccard(old,intersect(new,features$gene_symbol[features$in_reference]))
    x$added_in_control_LE_n[i]<-length(added);x$added_fraction_control_LE[i]<-if(length(new))length(added)/length(new)else NA_real_
    x$added_abs_z_share_control_LE[i]<-if(length(new))sum(abs(zz[added]))/sum(abs(zz[new]))else NA_real_
    h<-intersect(hall[[x$pathway[i]]],names(zz))
    if(length(h))members[[paste(tm,x$pathway[i])]]<-data.frame(Time=tm,pathway=x$pathway[i],gene_symbol=h,control_z=unname(zz[h]),in_reference=h%in%features$gene_symbol[features$in_reference],in_reference_LE=h%in%old,in_control_LE=h%in%new)
  }
  cmp[[tm]]<-x
}
comp<-bind_rows(cmp);save_t(bind_rows(rf),'reference_all_Hallmark_status.tsv');save_t(comp,'all_Hallmark_comparison.tsv');save_t(bind_rows(members),'pathway_member_contribution_long.tsv')
metrics<-lapply(c('D1','D3','D5'),function(tm){x<-comp[comp$Time==tm,,drop=FALSE];ok<-is.finite(x$ref_NES)&is.finite(x$control_NES);s1<-x$pathway[!is.na(x$ref_FDR)&x$ref_FDR<.05];s2<-x$pathway[!is.na(x$control_FDR)&x$control_FDR<.05];data.frame(Time=tm,all_Hallmark=nrow(x),paired_estimable=sum(ok),ref_FDR05=length(s1),control_FDR05=length(s2),NES_Spearman=cor(x$ref_NES[ok],x$control_NES[ok],method='spearman'),direction_agreement=mean(x$direction_same[ok]),significant_set_Jaccard=jaccard(s1,s2),median_abs_NES_change=median(abs(x$delta_NES[ok])),max_abs_NES_change=max(abs(x$delta_NES[ok])),median_LE_Jaccard=median(x$LE_Jaccard[ok],na.rm=TRUE),control_precision_uncertain=sum(x$control_status=='estimable_precision_uncertain'))})
metrics<-bind_rows(metrics);save_t(metrics,'global_comparison_metrics.tsv')
claims<-fread(file.path(out,'claims_before_results.tsv'),data.table=FALSE)
claims<-left_join(claims,comp,by=c('Time','pathway'));save_t(claims,'locked_claims_comparison.tsv')
grid<-fread(file.path(out,'Figure3_grid_before_results.tsv'),data.table=FALSE) |> select(Time,pathway,pathway_label)
save_t(left_join(grid,comp,by=c('Time','pathway')),'Figure3_complete_grid_comparison.tsv')
shared<-left_join(rc |> select(Time,gene_symbol,ref_logHR=logHR,ref_HR=HR,ref_SE=SE,ref_z=z,ref_pval=pval,ref_lower95=lower95,ref_upper95=upper95,ref_FDR=padj),cc |> select(Time,gene_symbol,control_logHR=logHR,control_HR=HR,control_SE=SE,control_z=z,control_pval=pval,control_lower95=lower95,control_upper95=upper95,control_FDR=padj,result_origin),by=c('Time','gene_symbol'))
for(k in c('logHR','HR','SE','z','pval','lower95','upper95'))shared[[paste0('difference_',k)]]<-shared[[paste0('control_',k)]]-shared[[paste0('ref_',k)]]
save_t(shared,'common_feature_estimate_and_FDR_comparison.tsv')

# QA checks compare outputs with input evidence, not only process exit status.
checks<-list()
add<-function(name,value,detail){checks[[length(checks)+1L]]<<-data.frame(check=name,verified=isTRUE(value),detail=detail)}
add('shared_effects_exact',all(as.matrix(shared[,grep('^difference_',names(shared))])==0),'Reused estimates: equality is not independent stability evidence')
initial<-read_t('control_all_Hallmark.tsv')
add('status_validation_no_numeric_changes',identical(initial[,vapply(initial,is.numeric,logical(1))],ctl[,vapply(ctl,is.numeric,logical(1))]),'Only one derived precision-status label corrected; no statistical rerun')
for(tm in c('D1','D3','D5')) {
 d<-cc[cc$Time==tm,,drop=FALSE];g<-ctl[ctl$Time==tm,,drop=FALSE];rk<-ranks[ranks$Time==tm,,drop=FALSE]
 add(paste(tm,'BH_feature_family'),isTRUE(all.equal(d$padj,p.adjust(d$pval,'BH'),tolerance=1e-13)),paste('family',nrow(d)))
 add(paste(tm,'BH_PH_family'),isTRUE(all.equal(d$PH_FDR,p.adjust(d$PH_p,'BH'),tolerance=1e-13)),paste('family',nrow(d)))
 ge<-g[g$eligible,,drop=FALSE]
 add(paste(tm,'BH_GSEA_family'),isTRUE(all.equal(ge$padj,p.adjust(ge$pval,'BH'),tolerance=1e-12)),paste('eligible',nrow(ge),'finite',sum(is.finite(ge$pval))))
 add(paste(tm,'full_Hallmark_status'),nrow(g)==length(hall)&&setequal(g$pathway,names(hall)),'All original Hallmark IDs retained')
 add(paste(tm,'complete_Wald_rank'),nrow(rk)==sum(d$fit_ok&is.finite(d$z))&&all(diff(rk$z)<=0),'No protein P/FDR or PH threshold filter')
 add(paste(tm,'fixed_risk_set'),all(d$N==risk$N[risk$Time==tm])&&all(d$Events==risk$Events[risk$Time==tm]),'Original N/events preserved')
}
code_lock<-fromJSON(file.path(out,'qa/analysis_code_at_start.json'))
executed_path<-file.path(out,'private/01_cv_dependence_executed_20260908.R')
if(!file.exists(executed_path))executed_path<-file.path(out,'R/01_cv_dependence.R')
add('executed_analysis_code_hash',digest::digest(file=executed_path,algo='sha256')==code_lock$sha256,'Exact executed source preserved before post-run derived-status correction')
old_code<-readLines(executed_path,warn=FALSE);new_code<-readLines(file.path(out,'R/01_cv_dependence.R'),warn=FALSE)
add('postrun_code_change_limited_to_status',identical(old_code[!grepl('full$status<-',old_code,fixed=TRUE)],new_code[!grepl('full$status<-',new_code,fixed=TRUE)]),'Only vectorized status-label branch corrected; fitting/ranking/GSEA code unchanged; not rerun')
save_t(bind_rows(checks),'statistical_output_QA.tsv')
if(!all(bind_rows(checks)$verified))stop('Output QA failed: inspect before delivery')

# R-only figures: all values are read from the comparison tables above.
lab<-function(x){s<-tolower(gsub('_',' ',x));substr(s,1,1)<-toupper(substr(s,1,1));special<-c(TNFA_SIGNALING_VIA_NFKB='TNF-α signalling via NF-κB',IL6_JAK_STAT3_SIGNALING='IL-6/JAK/STAT3 signalling',IL2_STAT5_SIGNALING='IL-2/STAT5 signalling',MYC_TARGETS_V1='MYC targets V1',MYC_TARGETS_V2='MYC targets V2',E2F_TARGETS='E2F targets',DNA_REPAIR='DNA repair',MTORC1_SIGNALING='mTORC1 signalling',TGF_BETA_SIGNALING='TGF-β signalling',EPITHELIAL_MESENCHYMAL_TRANSITION='Epithelial–mesenchymal transition',INTERFERON_ALPHA_RESPONSE='IFN-α response',INTERFERON_GAMMA_RESPONSE='IFN-γ response',REACTIVE_OXYGEN_SPECIES_PATHWAY='Reactive oxygen species pathway',G2M_CHECKPOINT='G2M checkpoint',PI3K_AKT_MTOR_SIGNALING='PI3K/AKT/mTOR signalling',UV_RESPONSE_DN='UV response DN',UV_RESPONSE_UP='UV response UP',KRAS_SIGNALING_DN='KRAS signalling DN',KRAS_SIGNALING_UP='KRAS signalling UP',P53_PATHWAY='p53 pathway',WNT_BETA_CATENIN_SIGNALING='WNT/β-catenin signalling');ii<-match(x,names(special));s[!is.na(ii)]<-special[ii[!is.na(ii)]];s}
theme_set(theme_classic(base_size=8,base_family='Arial')+theme(axis.line=element_line(linewidth=.35),axis.ticks=element_line(linewidth=.3),axis.text=element_text(colour='#333333'),plot.title=element_text(size=9,face='bold',hjust=.5),strip.text=element_text(size=8,face='bold'),legend.title=element_text(size=7.5),legend.text=element_text(size=7.5),plot.tag=element_text(size=9,face='bold'),plot.caption=element_text(size=7,hjust=0),plot.margin=margin(5,6,5,6)))
save_plot<-function(p,name,w,h){base<-file.path(out,'figures',name);svglite::svglite(paste0(base,'.svg'),width=w/25.4,height=h/25.4);print(p);dev.off();cairo_pdf(paste0(base,'.pdf'),width=w/25.4,height=h/25.4,family='Arial');print(p);dev.off();ragg::agg_tiff(paste0(base,'.tiff'),width=w,height=h,units='mm',res=600,compression='lzw');print(p);dev.off();ragg::agg_png(paste0(base,'.png'),width=w,height=h,units='mm',res=180);print(p);dev.off();data.frame(figure=name,width_mm=w,height_mm=h,font_base_pt=8,TIFF_dpi=600)}
lim<-range(c(comp$ref_NES,comp$control_NES),na.rm=TRUE)+c(-.15,.15)
d<-comp[is.finite(comp$ref_NES)&is.finite(comp$control_NES),,drop=FALSE]
facet_names<-setNames(paste0(risk$Time,' | n=',risk$N,', deaths=',risk$Events),risk$Time)
tags<-data.frame(Time=risk$Time,letter=letters[1:nrow(risk)])
p<-ggplot(d,aes(ref_NES,control_NES))+geom_hline(yintercept=0,colour='#CCCCCC',linewidth=.3)+geom_vline(xintercept=0,colour='#CCCCCC',linewidth=.3)+geom_abline(slope=1,intercept=0,linetype=2,colour='#777777',linewidth=.35)+
  geom_point(aes(colour=FDR_status,shape=control_status=='estimable_precision_uncertain'),size=1.8)+
  geom_text(data=tags,aes(x=-Inf,y=Inf,label=letter),inherit.aes=FALSE,hjust=-.4,vjust=1.2,fontface='bold',family='Arial',size=3)+
  scale_colour_manual(values=c(both_FDR_lt_05='#B94E48',reference_only='#8064A2',control_only='#3B76A4',neither='#999999'),limits=c('both_FDR_lt_05','reference_only','control_only','neither'),drop=FALSE,labels=c('Both FDR <0.05','Reference only','CV off only','Neither'))+
  scale_shape_manual(values=c('FALSE'=16,'TRUE'=1),limits=c(FALSE,TRUE),drop=FALSE,labels=c('Finite precision estimate','Precision uncertain'))+
  facet_wrap(~Time,nrow=1,labeller=as_labeller(facet_names))+coord_equal(xlim=lim,ylim=lim)+
  labs(title='Dependence of Hallmark enrichment on CV filtering',x='Reference NES (CV <20%)',y='CV-gate-off NES',colour='BH-FDR status',shape='GSEA precision',caption=paste0(unique(metrics$paired_estimable),' paired estimable Hallmark sets per landmark; newly testable sets appear in the full heatmap.\nDashed line: equal NES. Positive NES: higher subsequent mortality-associated ranking, not activation.\nOpen points flag uncertain Monte Carlo precision. FDR crossings alone are not direction reversals.'))+
  theme(legend.position='bottom',legend.box='vertical',strip.background=element_blank(),plot.title=element_text(hjust=.5),panel.spacing.x=unit(4,'mm'))
exports<-list(save_plot(p,'CV_dependence_all_Hallmark_NES_scatter',183,116))
hh<-bind_rows(comp |> transmute(Time,pathway,group='CV <20%',NES=ref_NES,FDR=ref_FDR,status=ref_status),comp |> transmute(Time,pathway,group='CV off',NES=control_NES,FDR=control_FDR,status=control_status))
hh$pathway<-factor(hh$pathway,levels=rev(sort(names(hall))));hh$group<-factor(hh$group,levels=c('CV <20%','CV off'))
hh$cell<-ifelse(is.finite(hh$NES),paste0(sprintf('%.2f',hh$NES),ifelse(is.na(hh$FDR),'',ifelse(hh$FDR<.001,'***',ifelse(hh$FDR<.01,'**',ifelse(hh$FDR<.05,'*',''))))), 'NA')
hh$cell<-paste0(hh$cell,ifelse(hh$status=='estimable_precision_uncertain','†',''))
save_t(hh,'figure_heatmap_source.tsv');save_t(comp,'figure_scatter_source.tsv')
heat<-ggplot(hh,aes(group,pathway,fill=NES))+geom_tile(colour='white',linewidth=.3)+geom_text(aes(label=cell),size=2.45,family='Arial')+facet_grid(~Time)+scale_y_discrete(labels=lab)+scale_fill_gradient2(low='#6F8FB8',mid='white',high='#C56354',midpoint=0,limits=c(-max(abs(hh$NES),na.rm=TRUE),max(abs(hh$NES),na.rm=TRUE)),na.value='#EEEEEE')+labs(title='All-Hallmark comparison: CV-filtered versus CV-gate-off',x=NULL,y=NULL,fill='NES',caption=paste0('Stars: displayed-analysis BH-FDR, * <0.05; ** <0.01; *** <0.001. † Uncertain numerical precision.\nPositive NES: higher subsequent mortality-associated ranking; negative NES: converse.\nNA: insufficient coverage. Full numerical status is retained in the comparison table.\nDay 5 has only ',risk$Events[risk$Time=='D5'],' deaths; this sensitivity does not validate QC experimental assumptions.'))+theme(axis.line=element_blank(),axis.ticks=element_blank(),axis.text.y=element_text(size=7.4,hjust=1,margin=margin(r=2)),panel.spacing.x=unit(2,'mm'),legend.position='right',legend.key.height=unit(13,'mm'),plot.caption=element_text(size=7),strip.background=element_blank())
exports[[2]]<-save_plot(heat,'CV_dependence_complete_Hallmark_heatmap',183,262)
save_t(bind_rows(exports),'figure_export_contract.tsv')
fonts<-lapply(bind_rows(exports)$figure,function(n){f<-pdftools::pdf_fonts(file.path(out,'figures',paste0(n,'.pdf')));f$figure<-n;f})
save_t(bind_rows(fonts),'PDF_fonts.tsv')
writeLines(capture.output(sessionInfo()),file.path(out,'logs/sessionInfo_comparison_plots.txt'))
print(metrics)
print(claims[,c('Time','pathway','ref_NES','control_NES','ref_FDR','control_FDR','control_status','added_in_control_LE_n','added_abs_z_share_control_LE')])
cat('Comparison / plot generation complete:',format(Sys.time()),'\n')
