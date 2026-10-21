"""Reaggregate display tables from declared aggregate inputs; no model fitting."""
from pathlib import Path
import csv,json,hashlib,math,sys
base=Path(sys.argv[1]);inp=base/'inputs'
def load(relative):
 p=inp/relative
 with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f,delimiter='\t' if p.suffix=='.tsv' else ','))
def f(v):
 try:return float(v)
 except (ValueError,TypeError):return float('nan')
def yes(v):return str(v).lower() in ('true','1')
def unique(r,k):
 v=set(x[k] for x in r)
 if len(v)!=1:raise ValueError('Nonunique '+k)
 return int(float(v.pop()))
def block(book,sheet,matrix,row=1,col=1):
 stem=Path(book).stem;p=inp/stem/(sheet+'.tsv');p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('w',encoding='utf-8-sig',newline='') as h:csv.writer(h,delimiter='\t').writerows(matrix)
 types=[['blank' if v is None else 'boolean' if isinstance(v,bool) else 'number' if isinstance(v,(float,int)) else 'string' for v in rr]for rr in matrix]
 t='contracts/'+stem+'_'+sheet+'_types.json';(base/t).write_text(json.dumps(types),encoding='utf8')
 cp=base/'contracts'/(stem+'.json');spec=json.loads(cp.read_text(encoding='utf8'))
 b=dict(sheet=sheet,start_row=row,start_col=col,source=str(p.relative_to(base)).replace('\\','/'),rows=len(matrix),cols=len(matrix[0]),source_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),cell_types=t)
 spec['blocks']=[x for x in spec['blocks'] if x['sheet']!=sheet]+[b]
 spec['scope']='Declared aggregate inputs populate cleared numeric blocks; labels and methods are presentation metadata.'
 cp.write_text(json.dumps(spec,indent=2),encoding='utf8')
c=load('Supplementary_Table_S2_Clinical_univariable_Cox/Univariable_Cox.tsv')
assert len(c)==40 and len({(x['Variable'],x['Contrast'])for x in c})==40
diag=[['Metric','Value'],['Patients',unique(c,'N')],['Deaths',unique(c,'Events')],['Survivors/censored',unique(c,'N')-unique(c,'Events')],['Continuous contrasts',sum(x['Type']=='continuous' for x in c)],['Binary contrasts',sum(x['Type']=='binary' for x in c)],['Infection-source contrasts',sum(x['Type']=='categorical' for x in c)],['Clinical association BH family',len(c)],['Nominal Cox P<0.05',sum(f(x['P_value'])<.05 for x in c)],['Cox BH-FDR<0.05',sum(f(x['BH_FDR'])<.05 for x in c)],['Nominal PH P<0.05',sum(f(x['PH_p'])<.05 for x in c)],['Missing PH tests',sum(not math.isfinite(f(x['PH_p'])) for x in c)],['Sparse-event rows',sum(yes(x['Sparse_event_flag'])for x in c)]]
block('Supplementary_Table_S2_Clinical_univariable_Cox.xlsx','Diagnostics',diag)
r=load('Supplementary_Table_S3_RNA_gene_wise_Cox_PH/Gene_Cox_PH.csv');p=load('Supplementary_Table_S5_Protein_wise_Cox_PH/Protein_Cox_PH.csv');g=load('Supplementary_Table_S6_Protein_Hallmark_GSEA/Hallmark_all_models.csv')
audit=[['omic','time','features','fits_successful','nominal_PH_fail_n','nominal_PH_fail_pct','PH_FDR_lt_0.05_n','PH_pass_nominal_definition']]
for om,records in [('Whole-blood RNA-seq',r),('Plasma proteomics',[x for x in p if x['model']=='center_primary'])]:
 for tm in ['D1','D3','D5']:
  rr=[x for x in records if x['Time']==tm];assert len({x['gene_symbol']for x in rr})==len(rr)
  n=sum(f(x['PH_p'])<.05 for x in rr)
  audit.append([om,tm,len(rr),sum(yes(x['fit_ok'])for x in rr),n,100*n/len(rr),sum(f(x['PH_FDR'])<.05 for x in rr),'PH_p >= 0.05'])
combined='Supplementary_Tables_S10-S17_with_S14_baseline.xlsx'
block(combined,'S17_PH_audit',audit)
rr=[x for x in p if x['Time']=='D5' and x['model']=='center_primary'];ee=[x for x in g if x['analysis']=='D5_center_primary' and x['pathway']=='EPITHELIAL_MESENCHYMAL_TRANSITION'];assert len(ee)==1;e=ee[0]
metrics=['risk_valid_N','subsequent_deaths','proteins_fitted','fits_successful','nominal_PH_fail','PH_FDR_lt_0.05','EMT_NES','EMT_BH_FDR','EMT_log2err','leading_edge_proteins']
values=[unique(rr,'N'),unique(rr,'Events'),len(rr),sum(yes(x['fit_ok'])for x in rr),sum(f(x['PH_p'])<.05 for x in rr),sum(f(x['PH_FDR'])<.05 for x in rr),f(e['NES']),f(e['padj']),f(e['log2err']),len(set(e['leadingEdge_text'].split(';')))]
block(combined,'S13_D5_protein_diag',[['metric','value']]+list(map(list,zip(metrics,values))))
norm=load('clinical_normalized.tsv');labels=load('clinical_display_map.tsv');assert len(norm)==len(labels)==41
lookup={(x['variable'],x['level']):x for x in norm};out=[]
for lab in labels:
 x=lookup[(lab['variable'],lab['level'])];out.append([lab['display_label'],x['Overall'],x['Survivor'],x['Death'],f(x['SMD']),int(x['Missing_overall'])])
infection_missing={int(x['Missing_overall']) for x in norm[35:]}
assert len(infection_missing)==1
out.insert(35,['Infection source',None,None,None,None,infection_missing.pop()])
block('Supplementary_Table_S9_Complete_baseline_characteristics.xlsx','S9_baseline',out,row=5)
with (inp/'Table1_display.tsv').open('w',encoding='utf-8-sig',newline='')as h:
 w=csv.writer(h,delimiter='\t');w.writerow(['variable','level','Overall','Survivor','Death','SMD','P_value'])
 for x in norm:w.writerow([x['variable'],x['level'],x['Overall'],x['Survivor'],x['Death'],f(x['SMD']),x['P_value_existing']])
print('S2, S13, S17 reaggregated; Table 1/S9 derived from one clinical summary. No tests or models run.')
