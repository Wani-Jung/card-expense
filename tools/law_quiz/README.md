# 법령 Quiz 문제 풀 원본 도구

실험실 '법령 Quiz'(농어촌정비법·건설기술 진흥법·국가계약법·건축법) 문제를 만들고 검증해 검토용 엑셀로 뽑는 도구. 앱이 읽는 `quiz/rural_questions.json` 은 이 엑셀(quiz/source_*.xlsx)을 `tools/rural_quiz_export.py` 로 변환해서 만든다.

흐름: 문제 원본(questions/) + 법령 원문(laws/) → verify.py 로 검증 → xl.py 로 엑셀 4개 → 사용자 검토 → quiz/source_*.xlsx 교체 → rural_quiz_export.py → json.

## 파일
- `questions/rural_final3.json` 농어촌정비법 200문항(`q`) + 2027 시행본에서 삭제된 빈집·민박 34문항(`drop`). 형식: [분야, 'OX'|'MC', 문제, 정답('O'/'X' 또는 1~4), 보기 4개|null, 해설, 근거('법 제N조…'/'시행령 제N조'), 원문 인용 구절]
- `questions/cta_q.py`·`con_q.py`·`bld_q.py` 건설기술 진흥법 92 / 국가계약법 115 / 건축법 127. `Q = [ (같은 8개 항목 튜플), … ]`
- `laws/*.json` 조문 단위로 자른 법령 원문 [{no:'제N조', title, body}]. 출처 github.com/legalize-kr/legalize-kr (kr/<법명>/법률.md, 시행령.md)
  - 농어촌정비법: law_future.json = 2027.10.28 시행본, dec_now.json = 시행령 2026.9.11 시행
  - 건설기술 진흥법: cta_법률 2025.10.1 / cta_시행령 2026.6.9
  - 국가계약법: con_법률 2026.6.11 / con_시행령 2026.6.3
  - 건축법: bld_fut.json = 2027.9.9 시행본 / bld_시행령 2026.10.6
- `parse.py` 법령 마크다운 → 조문 분리(`##### 제N조(제목)`), `clean()`
- `verify.py` `python3 verify.py <문제파일.py> <법률.json> <시행령.json>` — 형식·중복·**인용 구절이 근거 조문 원문에 그대로 있는지** 검사, O/X·객관식 정답 분포 출력. bad 0 이어야 함.
- `amend.py` 근거 줄의 <개정·신설> 표시로 '개정 시점' 계산(호에 표시 없으면 '(해당 항)', 시행 전 개정은 시행일 병기)
- `xl.py` `python3 xl.py <출력폴더>` — 엑셀 4개 생성(분야별 시트, 개정 시점·조 개정 이력·법령 원문 열, 객관식 정답 위치 고르게 섞음). openpyxl 필요.
- `dump.py` 검토용: 문항마다 인용 구절 앞뒤 원문 문맥 출력.

## 문제 원칙 (사용자 지시)
- 틀린 정보가 절대 없어야 한다. 모든 문항은 근거 조문 원문 인용으로 자동 대조(verify bad 0) + 문맥 검토.
- OX 는 O·X 반반 가깝게, 객관식 정답 위치 1~4 고르게.
- 공개 법령만. 회사 내부 규정(여비규정·공사감독업무지침 등)은 앱에 넣지 않는다.
- 법령이 개정되면: legalize-kr 에서 새 원문 받아 laws/ 갱신 → verify 로 깨진 문항 찾기 → 고치거나 빼기 → 엑셀 재생성 → 사용자 검토.
