import re,json,sys
def parse(t):
    t=t.split('\n## 부칙')[0]
    arts=[];chap='';cur=None
    for line in t.split('\n'):
        if line.startswith('## '): chap=line[3:].strip(); continue
        if line.startswith('### '): continue
        m=re.match(r'#####\s+(제\d+조(?:의\d+)?)\s*\((.*?)\)',line)
        if m: cur={'no':m.group(1),'title':m.group(2),'chap':chap,'body':[]};arts.append(cur);continue
        if cur and line.strip(): cur['body'].append(line.strip())
    for a in arts: a['body']='\n'.join(a['body'])
    return arts
def clean(s):
    s=re.sub(r'<(개정|신설|전문개정|본조신설|타법개정)[^>]*>','',s)
    return re.sub(r'[ \t]+',' ',s.replace('\\.','.').replace('**',''))
