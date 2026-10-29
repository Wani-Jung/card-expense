"""오늘의 안전 OX: quiz/questions_source.xlsx → quiz/questions.json

사용법 (저장소 루트에서):
    python tools/quiz_export.py

- '퀴즈' 시트의 한 줄 = 한 문항. 열: 번호, 분야, 문제, 정답(O/X), 해설(팝업용), 근거, 신뢰도, 채택(O/X), 수정 메모
- active 규칙: 채택=O → 출제, 채택=X → 제외, 채택이 비어 있으면 신뢰도='확인 권장'만 제외
- 문항 내용이 바뀌었으면 version 을 1 올리고 updated 를 오늘 날짜로. 바뀐 게 없으면 파일을 그대로 둔다.
- 필요한 패키지: openpyxl
"""

import datetime
import json
import pathlib
import sys

import openpyxl

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'quiz' / 'questions_source.xlsx'
OUT = ROOT / 'quiz' / 'questions.json'
COLUMNS = ['번호', '분야', '문제', '정답', '해설(팝업용)', '근거', '신뢰도', '채택(O/X)']


def text(v):
    return '' if v is None else str(v).strip()


def ox(v, row, col):
    t = text(v).upper()
    if t not in ('O', 'X'):
        sys.exit(f'{row}행 {col}: O 또는 X 여야 해요 (지금 값: {v!r})')
    return t == 'O'


def read_questions():
    ws = openpyxl.load_workbook(SRC, data_only=True)['퀴즈']
    header = [text(c.value) for c in ws[1]]
    missing = [c for c in COLUMNS if c not in header]
    if missing:
        sys.exit(f"'퀴즈' 시트에 열이 없어요: {missing}")
    col = {name: header.index(name) for name in COLUMNS}
    out, seen = [], set()
    for r, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
        if not text(row[col['문제']]):
            continue  # 빈 줄
        no = row[col['번호']]
        qid = f'q{int(no):03d}'
        if qid in seen:
            sys.exit(f'{r}행: 번호 {no} 가 중복이에요')
        seen.add(qid)
        adopt = text(row[col['채택(O/X)']]).upper()
        if adopt == 'O':
            active = True
        elif adopt == 'X':
            active = False
        else:
            active = text(row[col['신뢰도']]) != '확인 권장'
        out.append({
            'id': qid,
            'category': text(row[col['분야']]),
            'question': text(row[col['문제']]),
            'answer': ox(row[col['정답']], r, '정답'),
            'explain': text(row[col['해설(팝업용)']]),
            'basis': text(row[col['근거']]),
            'active': active,
        })
    return out


def main():
    questions = read_questions()
    old = json.loads(OUT.read_text(encoding='utf-8')) if OUT.exists() else {'version': 0, 'questions': None}
    if old.get('questions') == questions:
        print(f"바뀐 문항이 없어요. version {old['version']} 그대로 둡니다.")
        return
    data = {
        'version': int(old.get('version', 0)) + 1,
        'updated': datetime.date.today().isoformat(),
        'questions': questions,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
    active = sum(q['active'] for q in questions)
    print(f"questions.json 저장: version {data['version']}, 전체 {len(questions)}문항, 출제 {active}문항")


if __name__ == '__main__':
    main()
