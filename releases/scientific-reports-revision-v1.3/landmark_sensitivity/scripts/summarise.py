"""Rebuild aggregate comparison tables; no Cox fitting or FDR recalculation."""
import itertools,pathlib
import numpy as np
import pandas as pd
import argparse
parser = argparse.ArgumentParser(description="Compare saved common-patient and pathway-score results with primary aggregate results.")
parser.add_argument("--results-root", type=pathlib.Path, required=True, help="Directory containing results/A and results/B")
parser.add_argument("--primary-results", type=pathlib.Path, required=True, help="Directory containing 01_RNA_TMM and 02_Protein aggregate results")
parser.add_argument("--output-dir", type=pathlib.Path, required=True, help="New directory for comparison tables")
args = parser.parse_args()
root = args.results_root.resolve()
src = args.primary_results.resolve()
out = args.output_dir.resolve()
out.mkdir(parents=True, exist_ok=False)
def write(df,name):df.to_csv(out/name,sep='\t',index=False,na_rep='NA')
def rho(a,b):
    z=pd.DataFrame({'a':a,'b':b}).replace([np.inf,-np.inf],np.nan).dropna()
    return z.a.rank().corr(z.b.rank()) if len(z)>1 else np.nan
def original(omics,tm):
    if omics=='RNA':
        g=pd.read_csv(src/'01_RNA_TMM/03_RNA_TMM_Hallmark_primary_PHpass.csv');g=g[(g.Time==tm)&(g.analysis=='Primary')]
        c=pd.read_csv(src/f'01_RNA_TMM/01_{tm}_TMM_center_stratified_cox_zph.csv')
    else:
        g=pd.read_csv(src/'02_Protein/03_Protein_Hallmark_all_models.csv');g=g[g.analysis==f'{tm}_center_primary']
        c=pd.read_csv(src/f'02_Protein/01_{tm}_center_primary_cox_zph.csv')
    return g,c
allg=[];s=[];pairs=[];cache={};diagnostics=[]
for omics in ['RNA','Protein']:
 for tm in ['D1','D3','D5']:
    g=pd.read_csv(root/f'results/A/{omics}_{tm}_Hallmark.tsv',sep='\t');c=pd.read_csv(root/f'results/A/{omics}_{tm}_feature_cox.tsv',sep='\t');og,oc=original(omics,tm)
    comp=g.merge(og[['pathway','NES','pval','padj']],on='pathway',how='left',suffixes=('_A','_original'));allg.append(comp)
    zz=c[['gene_symbol','z','fit_ok']].merge(oc[['gene_symbol','z','fit_ok']],on='gene_symbol',suffixes=('_A','_original'));zz=zz[zz.fit_ok_A&zz.fit_ok_original]
    valid=comp.NES_A.notna()&comp.NES_original.notna();sig=comp.padj_original<.05
    s.append(dict(Omics=omics,Time=tm,N=int(c.N.max()),Events=int(c.Events.max()),feature_rank_rho=rho(zz.z_A,zz.z_original),NES_rho=rho(comp.NES_A,comp.NES_original),NES_direction_agree=int((np.sign(comp.loc[valid,'NES_A'])==np.sign(comp.loc[valid,'NES_original'])).sum()),NES_pairs=int(valid.sum()),Original_FDR05=int(sig.sum()),A_FDR05=int((comp.padj_A<.05).sum()),Original_sig_same_direction=int((sig&valid&(np.sign(comp.NES_A)==np.sign(comp.NES_original))).sum()),Original_sig_retained_FDR05=int((sig&(comp.padj_A<.05)).sum())))
    diagnostics.append(dict(Omics=omics,Time=tm,N=int(c.N.max()),Events=int(c.Events.max()),features=len(c),fits_ok=int(c.fit_ok.sum()),warnings=int(c.warning.notna().sum()),PH_nominal_below_05=int((c.PH_p<.05).sum()),GSEA_eligible=int(g.eligible.sum()),GSEA_estimable=int(g.pval.notna().sum()),GSEA_precision_retries=int(g.precision_retry.fillna(False).sum())))
    cache[(omics,tm,'A')]=(g,c);cache[(omics,tm,'Original')]=(og,oc)
 for t1,t2 in itertools.combinations(['D1','D3','D5'],2):
  for analysis in ['Original','A']:
    g1,c1=cache[(omics,t1,analysis)];g2,c2=cache[(omics,t2,analysis)]
    gg=g1[['pathway','NES']].merge(g2[['pathway','NES']],on='pathway',suffixes=('_1','_2'));cc=c1[['gene_symbol','z','fit_ok']].merge(c2[['gene_symbol','z','fit_ok']],on='gene_symbol',suffixes=('_1','_2'));cc=cc[cc.fit_ok_1&cc.fit_ok_2]
    pairs.append(dict(Omics=omics,Comparison=t1+'_'+t2,Analysis=analysis,feature_rank_rho=rho(cc.z_1,cc.z_2),NES_rho=rho(gg.NES_1,gg.NES_2)))
full=pd.concat(allg,ignore_index=True);write(full,'A_all_Hallmark_vs_original.tsv');write(pd.DataFrame(s),'A_summary.tsv');write(pd.DataFrame(pairs),'A_cross_time_correlations.tsv');write(pd.DataFrame(diagnostics),'A_diagnostics.tsv')
b=pd.read_csv(root/'results/B/all_pathway_cox.tsv',sep='\t').rename(columns={'Pathway':'pathway'})
allb=[]
for (omics,tm),bb in b.groupby(['Omics','Time'],sort=False):
 og,_=original(omics,tm);allb.append(bb.merge(og[['pathway','NES','pval','padj']].rename(columns={'NES':'original_GSEA_NES','pval':'original_GSEA_P','padj':'original_GSEA_FDR'}),on='pathway',how='left'))
bfull=pd.concat(allb,ignore_index=True);write(bfull,'B_all_pathways_with_original_GSEA.tsv')
print(pd.DataFrame(s).to_string(index=False));print('\nB FDR<0.05:');print(bfull.loc[bfull.FDR<.05,['Omics','Time','pathway','HR','lower95','upper95','pval','FDR','PH_p']].to_string(index=False))
