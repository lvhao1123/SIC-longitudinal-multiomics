"""Current aggregate-to-table entry. Does not run the historical model pipeline."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
if len(sys.argv)!=2:raise SystemExit('Usage: python analysis/run_current_tables.py NEW_OUTPUT_DIRECTORY')
out=Path(sys.argv[1])
if out.exists():raise SystemExit('Output directory must not exist')
base=root/'table_assembly'
subprocess.run([sys.executable,str(base/'prepare_final_tables.py'),str(base)],check=True)
subprocess.run([sys.executable,str(base/'assemble.py'),str(base),str(out)],check=True)
