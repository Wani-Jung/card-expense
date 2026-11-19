import json,re,sys,importlib.util
from parse import clean
def norm(s): return re.sub(r'\s+','',re.sub(r'<(개정|신설|전문개정|본조신설|타법개정)[^>]*>','',s).replace('\\','').replace('**',''))
qf,lj,dj=sys.argv[1:4]; W=int(sys.argv[4]) if len(sys.argv)>4 else 110
sp=importlib.util.spec_from_file_location('m',qf); m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
law={a['no']:a for a in json.load(open(lj))}; dec={a['no']:a for a in json.load(open(dj))}
for k,q in enumerate(m.Q):
    cat,typ,qs,ans,opts,exp,basis,quote=q
    mm=re.match(r'(법|시행령) (제\d+조(?:의\d+)?)',basis); a=(dec if mm.group(1)=='시행령' else law)[mm.group(2)]
    b=norm(a['body']); i=b.find(norm(quote)); ctx=b[max(0,i-W):i+len(norm(quote))+W]
    o=' / '.join(f'{j+1}){x}' for j,x in enumerate(opts)) if opts else ''
    print(f'{k}|{typ}|{qs}|{o}|정답{ans}|해설:{exp}|{basis}|…{ctx}…')
