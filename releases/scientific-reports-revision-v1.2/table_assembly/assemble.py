"""Aggregate-to-cell assembly; no statistical operations or third-party data access.

Uses OOXML to preserve workbook presentation. Declared numerical blocks in the
templates are empty before assembly. Inputs, data types and hashes are defined
in contracts. Run prepare_final_tables.py first to construct diagnostic summaries.
"""
import csv,json,zipfile,hashlib,sys,io
from pathlib import Path
from xml.etree import ElementTree as E
base,out=map(Path,sys.argv[1:3]);out.mkdir(parents=True,exist_ok=True)
NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main';R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
E.register_namespace('',NS);E.register_namespace('r',R)
def col(n):
 s=''
 while n:n,k=divmod(n-1,26);s=chr(65+k)+s
 return s
for p in sorted((base/'contracts').glob('*.json')):
 spec=json.loads(p.read_text(encoding='utf8'))
 if not isinstance(spec,dict) or 'workbook' not in spec:continue
 target=out/spec['workbook']
 if target.exists():raise RuntimeError('Refusing to overwrite '+str(target))
 z=zipfile.ZipFile(base/'templates'/spec['workbook']);w=E.fromstring(z.read('xl/workbook.xml'));rels=E.fromstring(z.read('xl/_rels/workbook.xml.rels'))
 targets={x.get('Id'):x.get('Target') for x in rels};sheetpaths={x.get('name'):targets[x.get('{'+R+'}id')]for x in w.find('{'+NS+'}sheets')};changes={}
 for b in spec['blocks']:
  raw=(base/b['source']).read_bytes()
  if hashlib.sha256(raw).hexdigest()!=b['source_sha256']:raise RuntimeError('Aggregate source hash mismatch '+b['source'])
  rr=list(csv.reader(io.StringIO(raw.decode('utf-8-sig')),delimiter='\t' if b['source'].endswith('.tsv') else ','));types=json.loads((base/b['cell_types']).read_text())
  if len(rr)!=b['rows'] or any(len(r)!=b['cols'] for r in rr):raise RuntimeError('Aggregate shape mismatch')
  name=sheetpaths[b['sheet']];name=name.lstrip('/') if name.startswith('/') else 'xl/'+name
  tree=E.fromstring(changes.get(name,z.read(name)));sd=tree.find('{'+NS+'}sheetData');rmap={int(x.get('r')):x for x in sd}
  for i,row in enumerate(rr):
   rn=b['start_row']+i;re=rmap.get(rn)
   if re is None:re=E.SubElement(sd,'{'+NS+'}row',r=str(rn));rmap[rn]=re
   cells={x.get('r'):x for x in re}
   for j,value in enumerate(row):
    address=col(b['start_col']+j)+str(rn);ce=cells.get(address)
    if ce is None:ce=E.SubElement(re,'{'+NS+'}c',r=address)
    for child in list(ce):ce.remove(child)
    ce.attrib.pop('t',None);kind=types[i][j]
    if kind=='blank':
     if value!='':raise RuntimeError('Unexpected nonempty value for blank cell '+address)
    elif kind=='number':E.SubElement(ce,'{'+NS+'}v').text=value
    elif kind=='boolean':ce.set('t','b');E.SubElement(ce,'{'+NS+'}v').text='1' if value.upper() in ('TRUE','1') else '0'
    else:
     ce.set('t','inlineStr');ie=E.SubElement(ce,'{'+NS+'}is');te=E.SubElement(ie,'{'+NS+'}t');te.set('{http://www.w3.org/XML/1998/namespace}space','preserve');te.text=value
  changes[name]=E.tostring(tree,encoding='UTF-8',xml_declaration=True)
 with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED) as zz:
  for item in z.infolist():zz.writestr(item,changes.get(item.filename,z.read(item.filename)))
 print(spec['workbook'],len(spec['blocks']))
