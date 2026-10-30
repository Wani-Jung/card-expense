"""안전 OX Quiz: quiz/source_*.xlsx → quiz/questions.json (형식 version 2: groups + 문항별 group·category)

사용법 (저장소 루트에서):
    python tools/quiz_export.py

- 원본 2개, 파일 하나 = 그룹 하나:
    quiz/source_2차_현장안전기준.xlsx → 그룹 '현장 안전기준', id w001~
    quiz/source_3차_서류절차.xlsx     → 그룹 '서류·절차',     id d001~
- 각 파일의 '안내' 시트를 뺀 시트 하나 = 분야 하나 (시트 순서 = 화면 표시 순서).
- id 는 지금 questions.json 의 id 를 문제 문장으로 찾아 그대로 쓴다 (풀이 기록이 id 로 남으므로 바꾸지 않는다).
  새 문제(문장이 바뀐 문제 포함)만 그룹별 다음 번호를 받고, 순서는 기존 문항 순서 뒤에 붙는다.
- 열: 번호, 문제, 정답(O/X), 해설(팝업용), 근거, 법령 원문(대조 구절), 채택(O/X), 수정 메모
- active 규칙: 채택=X 면 제외, 그 밖(O·빈칸)은 출제. (신뢰도 열이 있으면 채택이 빈칸일 때 '확인 권장'만 제외)
- 문항이 바뀌었으면 version 을 1 올리고 updated 를 오늘 날짜로. 바뀐 게 없으면 파일을 그대로 둔다. note 는 기존 값 유지.
- 필요한 패키지: openpyxl
"""

import datetime
import json
import pathlib
import sys

import openpyxl

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'quiz' / 'questions.json'
SOURCES = [
    ('source_2차_현장안전기준.xlsx', '현장 안전기준', 'w'),
    ('source_3차_서류절차.xlsx', '서류·절차', 'd'),
]
NEEDED = ['문제', '정답', '해설(팝업용)', '근거']


def text(v):
    return '' if v is None else str(v).strip()


def ox(v, where):
    t = text(v).upper()
    if t not in ('O', 'X'):
        sys.exit(f'{where} 정답: O 또는 X 여야 해요 (지금 값: {v!r})')
    return t == 'O'


def read_group(path, group, prefix):
    wb = openpyxl.load_workbook(path, data_only=True)
    categories, questions = [], []
    n = 0
    for ws in wb.worksheets:
        if ws.title == '안내':
            continue
        header = [text(c.value) for c in ws[1]]
        missing = [c for c in NEEDED if c not in header]
        if missing:
            sys.exit(f"{path.name} '{ws.title}' 시트에 열이 없어요: {missing}")
        col = {name: i for i, name in enumerate(header)}
        categories.append(ws.title)
        for r, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not text(row[col['문제']]):
                continue  # 빈 줄
            n += 1
            adopt = text(row[col['채택(O/X)']]).upper() if '채택(O/X)' in col else ''
            if adopt == 'X':
                active = False
            elif adopt == 'O':
                active = True
            else:
                active = '신뢰도' not in col or text(row[col['신뢰도']]) != '확인 권장'
            questions.append({
                'id': f'{prefix}{n:03d}',
                'group': group,
                'category': ws.title,
                'question': text(row[col['문제']]),
                'answer': ox(row[col['정답']], f"{path.name} '{ws.title}' {r}행"),
                'explain': text(row[col['해설(팝업용)']]),
                'basis': text(row[col['근거']]),
                'active': active,
            })
    return {'name': group, 'categories': categories}, questions


def keep_ids(questions, old_questions):
    """기존 id 유지: 같은 문제 문장이면 예전 id, 새 문제는 접두어별 다음 번호. 기존 순서 → 새 문제 순."""
    by_text = {q['question']: q['id'] for q in old_questions}
    order = {q['id']: i for i, q in enumerate(old_questions)}
    used = set(by_text.values())
    next_no = {}
    for q in old_questions:
        p, n = q['id'][0], int(q['id'][1:]) if q['id'][1:].isdigit() else 0
        next_no[p] = max(next_no.get(p, 0), n)
    kept, fresh = [], []
    for q in questions:
        prefix = q['id'][0]
        if q['question'] in by_text:
            q['id'] = by_text[q['question']]
            kept.append(q)
        else:
            next_no[prefix] = next_no.get(prefix, 0) + 1
            while f'{prefix}{next_no[prefix]:03d}' in used:
                next_no[prefix] += 1
            q['id'] = f'{prefix}{next_no[prefix]:03d}'
            used.add(q['id'])
            fresh.append(q)
    kept.sort(key=lambda q: order[q['id']])
    return kept + fresh


def main():
    groups, questions = [], []
    for name, group, prefix in SOURCES:
        path = ROOT / 'quiz' / name
        if not path.exists():
            sys.exit(f'원본이 없어요: {path}')
        g, qs = read_group(path, group, prefix)
        groups.append(g)
        questions.extend(qs)
    old = json.loads(OUT.read_text(encoding='utf-8')) if OUT.exists() else {'version': 0}
    questions = keep_ids(questions, old.get('questions') or [])
    if old.get('questions') == questions and old.get('groups') == groups:
        print(f"바뀐 문항이 없어요. version {old['version']} 그대로 둡니다.")
        return
    data = {
        'version': int(old.get('version', 0)) + 1,
        'updated': datetime.date.today().isoformat(),
    }
    if old.get('note'):
        data['note'] = old['note']
    data['groups'] = groups
    data['questions'] = questions
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
    active = sum(q['active'] for q in questions)
    print(f"questions.json 저장: version {data['version']}, 전체 {len(questions)}문항, 출제 {active}문항")


if __name__ == '__main__':
    main()
