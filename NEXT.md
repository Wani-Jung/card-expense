# 다음 작업 때 같이 처리할 것

- [ ] 무시한 내역에서 [차량비]/[운영비] 고를 때도 같은 업체 일괄 정리 묻기 — `lib/ignored_screen.dart`, `lib/main.dart` `_openIgnored`·`_classify`, `lib/vendor.dart` `sameVendorPending`
  - 같은 업체(merchantKey)의 다른 '직접 무시' 건 + 분류 대기 건이 있으면
    "'고야커피' 무시·대기 내역 N건도 운영비로 정리할까요?" [이번 건만] [모두 정리] (창 밖 누르면 아무것도 안 함)
  - '중복으로 무시'·'취소로 상쇄' 건은 대상에서 뺌
  - 메인과 같은 동작: 등록 업체 기억, 5초 [되돌리기] 한 번에 같이 옮긴 건까지 전부 복구, 승인취소 묶음은 짝까지 같이
  - 테스트: 무시한 내역에서 일괄 정리, 중복·상쇄 건 제외, 되돌리기
- [ ] 위 작업 끝나면 flutter test → 버전 올려 배포 → 두 고정 링크(app-release.apk, app-full-release.apk) 받아지는지 확인
