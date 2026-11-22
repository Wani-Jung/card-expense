import json, random, re, importlib.util, sys
from collections import OrderedDict
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side
from openpyxl.worksheet.datavalidation import DataValidation
from parse import clean
from amend import info as amend_info

def loadq(f):
    sp = importlib.util.spec_from_file_location('m', f); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
    return [list(q) for q in m.Q]

def shuffle_mc(Q, seed):
    rnd = random.Random(seed); out = []
    for i, q in enumerate(Q):
        cat, typ, qs, ans, opts, exp, basis, quote = q
        if typ == 'MC':
            target = i % 4  # 정답 위치 고르게
            right = opts[ans - 1]; others = [o for k, o in enumerate(opts) if k != ans - 1]; rnd.shuffle(others)
            others.insert(target, right); opts = others; ans = target + 1
        out.append([cat, typ, qs, ans, opts, exp, basis, quote])
    return out

def build(Q, lawjson, decjson, title, path, drop=None, note='', fut=None, base=None):
    law = {a['no']: a for a in json.load(open(lawjson))}
    dec = {a['no']: a for a in json.load(open(decjson))} if decjson else {}
    F = Font(name='Arial', size=10); HB = Font(name='Arial', size=10, bold=True, color='FFFFFF')
    HF = PatternFill('solid', fgColor='2F5597'); WR = Alignment(wrap_text=True, vertical='top')
    thin = Side(style='thin', color='BFBFBF'); BD = Border(left=thin, right=thin, top=thin, bottom=thin)
    wb = Workbook(); info = wb.active; info.title = '안내'
    nO = sum(q[1] == 'OX' and q[3] == 'O' for q in Q); nX = sum(q[1] == 'OX' and q[3] == 'X' for q in Q); nM = sum(q[1] == 'MC' for q in Q)
    lines = [title, '', f'총 {len(Q)}문항 (OX {nO+nX}: O {nO} / X {nX}, 객관식 {nM})',
             '근거 조문 원문에 인용 구절이 그대로 들어있는지 자동 대조 + Claude가 문제·보기·해설을 원문 문맥과 하나씩 대조 검토했어요(2026.11.13).',
             '개정 시점: 근거 조항 줄의 <개정·신설> 표시 중 가장 최근 날짜예요. 호에 표시가 없으면 그 호가 속한 항의 날짜를 "(해당 항)"으로 적었어요. 아직 시행 전인 개정은 시행일을 같이 적었어요.',
             '검토 방법: 각 시트의 "채택(O/X)" 칸에 O 또는 X, 고칠 점은 "수정 메모"에 적어주세요.', note]
    for r, t in enumerate(lines, 1):
        c = info.cell(r, 1, t); c.font = Font(name='Arial', size=12 if r == 1 else 10, bold=(r == 1))
    info.column_dimensions['A'].width = 100
    cats = OrderedDict()
    for q in Q: cats.setdefault(q[0], []).append(q)
    hdr = ['번호', '유형', '문제', '보기1', '보기2', '보기3', '보기4', '정답', '해설', '근거', '개정 시점', '조 개정 이력', '법령 원문', '채택(O/X)', '수정 메모']
    widths = [6, 7, 48, 18, 18, 18, 18, 7, 36, 14, 22, 22, 60, 9, 24]
    n = 0
    for cat, qs in cats.items():
        ws = wb.create_sheet(re.sub(r'[\\/*?:\[\]]', '', cat)[:31])
        for j, h in enumerate(hdr, 1):
            c = ws.cell(1, j, h); c.font = HB; c.fill = HF; c.alignment = Alignment(horizontal='center', vertical='center'); c.border = BD
            ws.column_dimensions[c.column_letter].width = widths[j - 1]
        ws.freeze_panes = 'C2'
        dv = DataValidation(type='list', formula1='"O,X"', allow_blank=True); ws.add_data_validation(dv)
        for r, q in enumerate(qs, 2):
            n += 1; _, typ, qq, ans, opts, exp, basis, quote = q
            m = re.match(r'(법|시행령) (제\d+조(?:의\d+)?)', basis)
            art = (dec if m.group(1) == '시행령' else law)[m.group(2)]
            body = f"{basis}({art['title']}) " + clean(art['body'])
            am, hist = amend_info(art['body'], quote, fut)
            # 날짜를 못 찾으면 빈칸 ('이후 개정 없음'은 쓰지 않는다, REQ-67)
            row = [n, 'OX' if typ == 'OX' else '객관식', qq] + ((opts or []) + [''] * 4)[:4] + [ans, exp, basis, am, hist, body[:6000], '', '']
            for j, v in enumerate(row, 1):
                c = ws.cell(r, j, v); c.font = F; c.alignment = WR; c.border = BD
            dv.add(ws.cell(r, 14))
    if drop:
        ws = wb.create_sheet('제외 목록')
        for j, h in enumerate(['근거', '문제', '제외 사유'], 1):
            c = ws.cell(1, j, h); c.font = HB; c.fill = HF
        for r, d in enumerate(drop, 2):
            for j, v in enumerate(d, 1):
                c = ws.cell(r, j, v); c.font = F; c.alignment = WR
        ws.column_dimensions['A'].width = 16; ws.column_dimensions['B'].width = 80; ws.column_dimensions['C'].width = 30
    wb.save(path); print(path, n)

if __name__ == '__main__':
    out = sys.argv[1]
    d = json.load(open('questions/rural_final3.json'))
    drop = [(b, q, '2027.10.28 시행본에서 삭제(빈집·민박은 별도 법으로 이관)') for b, q, _ in d['drop']]
    build(d['q'], 'laws/law_future.json', 'laws/dec_now.json', '농어촌정비법 Quiz (2027 기준, Claude 검토본)', f'{out}/농어촌정비법_Quiz_3차_2027기준.xlsx', drop,
          '법 2027.10.28 시행본 + 시행령(2026.9.11 시행, 최신) 기준. 2027 시행본에서 삭제되는 빈집·민박 문항은 "제외 목록" 시트에 따로 뒀어요. 제90조(행정제재 승계 1년) 2문항 추가.',
          fut={(2026, 10, 27): '2027.10.28'}, base='2009.6.9 전부개정')
    META = {'cta': (None, '2013.5.22 전부개정'), 'con': (None, '1995.1.5 제정'), 'bld': ({(2026, 9, 8): '2027.9.9', (2026, 8, 11): '2027.2.12'}, '2008.3.21 전부개정')}
    for code, name, note in [('cta', '건설기술 진흥법', '법 2025.10.1 시행본 + 시행령 2026.6.9 시행본 기준.'),
                             ('con', '국가계약법', '「국가를 당사자로 하는 계약에 관한 법률」 2026.6.11 시행본 + 시행령 2026.6.3 시행본 기준. 금액·비율 기준은 시행령 문구 그대로예요.'),
                             ('bld', '건축법', '법 2027.9.9 시행본 + 시행령 2026.10.6 시행본(최신) 기준. 2027 개정 조문(일조 높이제한·위반건축물 정기조사·이행강제금 가중·지하주차장 마감재 등) 18문항 포함.')]:
        Q = shuffle_mc(loadq(f'questions/{code}_q.py'), 7)
        build(Q, 'laws/bld_fut.json' if code=='bld' else f'laws/{code}_법률.json', f'laws/{code}_시행령.json', f'{name} Quiz (2027 기준, Claude 검토본)', f'{out}/{name.replace(" ", "")}_Quiz_2차_2027기준.xlsx', None, note, *META[code])
