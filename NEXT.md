# 다음 작업 때 같이 처리할 것

- 2.1.0 = REQ-70 일반판·전용판 합치기(flavor 제거, 문자 권한 모든 빌드, '전용판' 표시 삭제, APK 1+옛 링크 사본·AAB app-store-release.aab) + 문자 권한 안내 '처음엔 최근 1년' 삭제·autoImported 정리·문서. dev run 78(780/782) → 782 내부 테스트 출시됨(11/25 15:2x) → 다른 폰 GitHub APK 새 설치 = Play 프로텍트 완전 차단 → GitHub APK 배포 중단(AAB 만, latest 는 v2.0.3 유지). 사용자 폰 782 확인 OK → v2.1.0 태그(792) → 프로덕션 검토 제출 → 11/25 16:37 출시됨. 2.0.3 은 11/25 출시됨
- 남은 일(REQ-71 정리): 법령 Quiz 개정일 연혁 채우기(빈칸 188문항, 국가법령정보센터 연혁) / AAB 자동 업로드(REQ-65 보류) / 매년 target SDK 갱신 / 'Android 개발자 인증' 콘솔 배너 확인 / 화면 최종 점검 때 남은 단어 중간 줄바꿈 / (11/25 Alpha 트랙 일시중지 검토 제출됨 — 반영 확인만)
- (내일 이어서) 개인정보처리방침 '간접 링크' 거부 대응: GitHub Pages(privacy-page.yml, https://wani-jung.github.io/card-expense/) 배포 확인 → 콘솔 앱 콘텐츠 > 개인정보처리방침 URL 교체 → 게시 개요(방침 + Alpha 일시중지) 보여 주고 제출(물어보고) → 다음 앱 업데이트 때 kPrivacyUrl 도 새 주소로. 11/25 밤 GitHub Actions·Pages 장애로 배포 실패 중
- 판매자 상태 선언(콘솔 홈, 2027년 2월까지, 안 하면 앱 삭제) — 사용자가 직접 입력
