"""농어촌정비법 퀴즈: quiz/source_농어촌정비법_*.xlsx → quiz/rural_questions.json

사용법 (저장소 루트에서):
    python tools/rural_quiz_export.py

- 안전 OX(quiz/questions.json)와 따로 관리한다. 지금 배포된 앱이 원격으로 받는 questions.json 은 건드리지 않는다.
- 원본: quiz/source_농어촌정비법_1차.xlsx → 그룹 '농어촌정비법', id r001~
- '안내'·'제외 목록' 시트를 뺀 시트 하나 = 분야 하나 (시트 순서 = 화면 표시 순서)
- 열: 번호, 유형(OX/객관식), 문제, 보기1~4, 정답(OX 는 O/X, 객관식은 1~4), 해설, 근거, 법령 원문(대조 구절), 채택(O/X), 수정 메모
- 채택=X 면 active=false (출제 제외), 그 밖은 출제
- id 는 지금 rural_questions.json 의 id 를 문제 문장으로 찾아 그대로 쓴다 (풀이 기록이 id 로 남음). 새 문제만 다음 번호.
- 문항이 바뀌었으면 version +1, updated 는 오늘. 안 바뀌었으면 파일을 그대로 둔다.
- json 형식 (version 1):
    {version, updated, groups:[{name, categories}],
     questions:[{id, group, category, type:'ox'|'choice', question, choices?:[4], answer, explain, basis, active}]}
    answer: OX 는 true(O)/false(X), 객관식은 정답 보기 번호 1~4
- 필요한 패키지: openpyxl
"""

import datetime
import json
import pathlib
import sys

import openpyxl

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from quiz_export import keep_ids, text  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'quiz' / 'rural_questions.json'
SOURCES = [('source_농어촌정비법_1차.xlsx', '농어촌정비법', 'r')]
SKIP_SHEETS = ('안내', '제외 목록')
NEEDED = ['유형', '문제', '보기1', '보기2', '보기3', '보기4', '정답', '해설', '근거']


def read_group(path, group, prefix):
    wb = openpyxl.load_workbook(path, data_only=True)
    categories, questions = [], []
    n = 0
    for ws in wb.worksheets:
        if ws.title in SKIP_SHEETS:
            continue
        header = [text(c.value) for c in ws[1]]
        missing = [c for c in NEEDED if c not in header]
        if missing:
            sys.exit(f"{path.name} '{ws.title}' 시트에 열이 없어요: {missing}")
        col = {name: i for i, name in enumerate(header)}
        categories.append(ws.title)
        for r, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
            if not text(row[col['문제']]):
                continue
            n += 1
            where = f"{path.name} '{ws.title}' {r}행"
            kind = text(row[col['유형']])
            answer_raw = text(row[col['정답']]).upper()
            q = {'id': f'{prefix}{n:03d}', 'group': group, 'category': ws.title}
            if kind == 'OX':
                if answer_raw not in ('O', 'X'):
                    sys.exit(f'{where} 정답: O 또는 X 여야 해요 (지금 값: {answer_raw!r})')
                q.update(type='ox', question=text(row[col['문제']]), answer=answer_raw == 'O')
            elif kind == '객관식':
                choices = [text(row[col[f'보기{i}']]) for i in range(1, 5)]
                if not all(choices):
                    sys.exit(f'{where} 보기1~4 가 다 있어야 해요')
                if answer_raw not in ('1', '2', '3', '4'):
                    sys.exit(f'{where} 정답: 1~4 여야 해요 (지금 값: {answer_raw!r})')
                q.update(type='choice', question=text(row[col['문제']]), choices=choices, answer=int(answer_raw))
            else:
                sys.exit(f"{where} 유형: 'OX' 또는 '객관식' 이어야 해요 (지금 값: {kind!r})")
            adopt = text(row[col['채택(O/X)']]).upper() if '채택(O/X)' in col else ''
            q.update(
                explain=text(row[col['해설']]),
                basis=text(row[col['근거']]),
                active=adopt != 'X',
            )
            questions.append(q)
    return {'name': group, 'categories': categories}, questions


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
        'groups': groups,
        'questions': questions,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
    active = sum(q['active'] for q in questions)
    kinds = sum(q['type'] == 'choice' for q in questions)
    print(f'rural_questions.json 저장: version {data["version"]}, 전체 {len(questions)}문항'
          f' (객관식 {kinds}), 출제 {active}문항')


if __name__ == '__main__':
    main()
