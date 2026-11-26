"""PRIVACY.md → 개인정보처리방침 단독 HTML 페이지 (GitHub Pages, gh-pages 브랜치).

Play Console 이 GitHub 파일 보기 화면(blob)을 '간접 링크'로 거부해서(2026-11-26) 본문만 있는 페이지를 따로 만든다.
마크다운 변환은 GitHub 마크다운 API(gh api markdown)를 쓴다.

사용:
  python tools/privacy_page.py request <out.json>         # API 요청 본문 만들기
  gh api markdown --input <out.json> > body.html
  python tools/privacy_page.py wrap body.html <index.html>  # 페이지로 감싸기
"""
import html
import json
import sys

TEMPLATE = """<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  body {{ margin: 0; background: #fff; color: #202124; font: 16px/1.7 -apple-system, "Noto Sans KR", "Malgun Gothic", sans-serif; }}
  main {{ max-width: 760px; margin: 0 auto; padding: 24px 16px 64px; word-break: keep-all; overflow-wrap: anywhere; }}
  h1 {{ font-size: 1.6em; color: #1F3A68; line-height: 1.4; }}
  h2 {{ font-size: 1.2em; margin-top: 2em; color: #1F3A68; }}
  a {{ color: #1F3A68; }}
</style>
</head>
<body><main>
{body}
</main></body>
</html>
"""


def main() -> None:
    cmd = sys.argv[1]
    if cmd == 'request':
        text = open('PRIVACY.md', encoding='utf-8').read()
        with open(sys.argv[2], 'w', encoding='utf-8') as f:
            json.dump({'text': text, 'mode': 'gfm'}, f, ensure_ascii=False)
    elif cmd == 'wrap':
        body = open(sys.argv[2], encoding='utf-8').read()
        if '<h1' not in body:
            raise SystemExit('마크다운 변환 결과에 제목이 없습니다')
        page = TEMPLATE.format(title=html.escape('공감카드 관리 개인정보처리방침'), body=body.strip())
        with open(sys.argv[3], 'w', encoding='utf-8', newline='\n') as f:
            f.write(page)
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
