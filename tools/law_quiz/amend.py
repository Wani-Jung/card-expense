import re, json
from verify import norm
TAG = re.compile(r'<(개정|신설|전문개정)\s*([^>]*)>')
BR = re.compile(r'\[(본조신설|전문개정|본조개정)\s*([^\]]*)\]')
DATE = re.compile(r'(\d{4})\.\s*(\d{1,2})\.\s*(\d{1,2})')
HANG = re.compile(r'^\s*(\*\*)?[①-⑳]')
SUB = re.compile(r'^\s*(\d+(의\d+)?|[가-하])\\?\.')
HO = re.compile(r'^\s*\d+(의\d+)?\\?\.')
MOK = re.compile(r'^\s*[가-하]\\?\.')
def dates(s): return sorted({(int(a),int(b),int(c)) for a,b,c in DATE.findall(s)})
def fmt(d): return f'{d[0]}.{d[1]}.{d[2]}'
def info(body, quote, future=None):
    """future: {(y,m,d): '시행일 문자열'} 아직 시행 전 개정"""
    lines = body.split('\n'); acc = ''; starts = []
    for l in lines: starts.append(len(acc)); acc += norm(l)
    i = acc.find(norm(quote)); assert i >= 0
    li = max(k for k, s in enumerate(starts) if s <= i)
    def tags(l):
        out = []
        for kind, ds in TAG.findall(l):
            for d in dates(ds): out.append((d, kind))
        return out
    own = tags(lines[li]); src = '조항'
    if not own and MOK.match(lines[li]):
        p = next((k for k in range(li, -1, -1) if HO.match(lines[k]) or HANG.match(lines[k])), None)
        if p is not None and HO.match(lines[p]):
            own = tags(lines[p]); src = '해당 호'
            if not own: li = p
    if not own and SUB.match(lines[li]):
        p = next((k for k in range(li, -1, -1) if HANG.match(lines[k])), 0)
        own = tags(lines[p]); src = '해당 항'
    hist_all = sorted({d for d, _ in tags(body)} | set(dates(' '.join(x[1] for x in BR.findall(body)))))
    if not own:
        br = [(d, k) for k, ds in BR.findall(body) for d in dates(ds)]
        own = br; src = '조'
    if not own:
        return '제정(전부개정) 이후 개정 없음', ''
    d, kind = max(own)
    kind = {'본조개정': '개정'}.get(kind, kind)
    s = f'{fmt(d)} {kind}' + ('' if src == '조항' else f'({src})')
    if future and d in future: s += f' · {future[d]} 시행'
    return s, ', '.join(fmt(x) for x in hist_all)
