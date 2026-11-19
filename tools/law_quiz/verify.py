import json,re,importlib.util,sys
from collections import Counter
def norm(s):
    s=re.sub(r'<(개정|신설|전문개정|본조신설|타법개정)[^>]*>','',s)
    return re.sub(r'\s+','',s.replace('\\','').replace('**',''))
def verify(qfile,lawjson,decjson=None):
    sp=importlib.util.spec_from_file_location('m',qfile); m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
    law={a['no']:a for a in json.load(open(lawjson))}; dec={a['no']:a for a in json.load(open(decjson))} if decjson else {}
    bad=0;seen=set()
    for k,q in enumerate(m.Q):
        cat,typ,qs,ans,opts,exp,basis,quote=q
        if qs in seen: print('DUP',k); bad+=1
        seen.add(qs)
        if typ=='OX': ok=ans in('O','X') and opts is None
        else: ok=isinstance(ans,int) and len(opts)==4 and len(set(opts))==4
        if not ok: print('FMT',k,qs); bad+=1
        mm=re.match(r'(법|시행령) (제\d+조(?:의\d+)?)',basis)
        src=dec if mm.group(1)=='시행령' else law
        a=src.get(mm.group(2))
        if not a or norm(quote) not in norm(a['body']): print('NF',k,basis,quote[:30]); bad+=1
    ox=[q for q in m.Q if q[1]=='OX']
    print(qfile,'total',len(m.Q),'bad',bad,'O',sum(q[3]=='O' for q in ox),'X',sum(q[3]=='X' for q in ox),Counter(q[3] for q in m.Q if q[1]=='MC'),Counter(q[0] for q in m.Q))
    return m.Q
if __name__=='__main__': verify(*sys.argv[1:])
