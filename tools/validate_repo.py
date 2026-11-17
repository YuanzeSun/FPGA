"""Check the maintained project collection without accessing the board."""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def normalized_sha(path):
    return hashlib.sha256(path.read_text(encoding='utf-8-sig').replace('\r\n','\n').encode('utf-8')).hexdigest()

def main():
    output=subprocess.check_output(['git','ls-files','-co','--exclude-standard','-z'],cwd=ROOT)
    paths=sorted({name.decode('utf-8') for name in output.split(b'\0') if name})
    errors=[]
    checked=0
    for relative in paths:
        path=ROOT/relative
        if not path.is_file():continue  # A tracked deletion is checked by Git.
        if any(part in ['build','impl','__pycache__'] for part in path.relative_to(ROOT).parts):
            errors.append('Generated directory included: '+relative)
        if path.name.endswith(('.exe','.dll','.zip','.7z','.fs','.elf','.vvp','.gprj.user')) or path.name in ['local.psd1','toolchain.local.json']:
            errors.append('Local artifact included: '+relative)
        try:
            if path.suffix=='.py':ast.parse(path.read_text(encoding='utf-8-sig'),filename=relative)
            if path.suffix=='.json':json.loads(path.read_text(encoding='utf-8-sig'))
            if path.suffix=='.gprj':
                for source in re.findall(r'<File\s+path="([^"]+)"',path.read_text(encoding='utf-8-sig')):
                    if not (path.parent/source).is_file():errors.append(relative+' missing '+source)
            if path.suffix=='.md':
                text=re.sub(r'```.*?```','',path.read_text(encoding='utf-8-sig'),flags=re.S)
                for target in re.findall(r'\]\(([^)]+)\)',text):
                    if target.startswith(('http:','https:','mailto:','#')):continue
                    target=target.split('#',1)[0]
                    if target and not (path.parent/target).exists():errors.append(relative+' broken link '+target)
            checked+=1
        except (ValueError,SyntaxError,UnicodeError) as error:errors.append(relative+': '+str(error))
    catalog=json.loads((ROOT/'records/projects.json').read_text(encoding='utf-8'))
    assert len(catalog['projects'])==10
    for project in catalog['projects']:
        directory=ROOT/project['path']
        record=json.loads((directory/'reports/validation.json').read_text(encoding='utf-8'))
        for relative,digest in record['source_snapshot_sha256'].items():
            path=directory/relative
            if not path.is_file() or normalized_sha(path)!=digest:errors.append(project['id']+' source snapshot differs: '+relative)
        if not (directory/'README.md').is_file():errors.append('Missing README: '+project['id'])
        if record['validation']['timing']!='PASS' or record['validation']['sram_program_and_readback']!='PASS':
            errors.append('Missing verified baseline: '+project['id'])
    if errors:raise SystemExit('\n'.join(errors))
    print(f'PASS: {len(catalog["projects"])} verified projects; {checked} maintained files; Python/JSON syntax, source hashes, project references and Markdown links')

if __name__=='__main__':main()
