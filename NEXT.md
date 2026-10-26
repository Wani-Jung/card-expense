# 다음 작업 때 같이 처리할 것

- [ ] 앱 아이콘 교체
  - 프로젝트 폴더의 `wani_card_icon.zip`을 풀어서 `android/app/src/main/res/`에 덮어쓰기
    (mipmap-mdpi~xxxhdpi, mipmap-anydpi-v26, values/ic_launcher_background.xml)
  - AndroidManifest.xml `<application>`에 `android:roundIcon="@mipmap/ic_launcher_round"` 추가
  - pubspec.yaml에 flutter_launcher_icons 설정이 있으면 제거
  - `wani_card_gold_1024.png`는 `assets/icon/`으로 옮겨 원본 보관, zip은 삭제
- [ ] 배포
  - pubspec version 올리고 main push + 새 v 태그 push → release-apk.yml로 Release 생성
  - `gh run watch`로 빌드 확인, 실패하면 고쳐서 재배포
  - 저장소가 private이면 public 전환할지 먼저 물어보기 (keystore·key.properties 커밋 여부 먼저 확인)
  - 끝나면 `releases/latest/download/app-release.apk` 링크가 새 APK를 받는지 확인해서 알려주기
- [ ] 앱 내 업데이트 알림 (다음 배포 때 아이콘이랑 같이)
  - 앱 시작 시(하루 1회 정도) `https://api.github.com/repos/Wani-Jung/card-expense/releases/latest` 조회 →
    `tag_name`(예: v1.4.0)과 현재 앱 버전(package_info_plus) 비교
  - 새 버전이면 다이얼로그 "새 버전 vX.Y.Z가 있어요" + [업데이트] [나중에]
    - [업데이트]: url_launcher로 브라우저에서 `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-release.apk` 열기
    - [나중에]: 그 버전은 다시 안 띄우기
  - 메뉴에 '업데이트 확인' 추가 (수동, 최신이면 "최신 버전이에요")
  - 인터넷 없음·조회 실패는 조용히 넘어가기 (에러 창 금지)
  - dev 프리릴리스는 무시, 정식 v* 릴리스만 기준
  - 릴리스 빌드용 AndroidManifest에 INTERNET 권한 추가
  - 버전 비교 로직 단위 테스트 추가
  - 주의: `releases/latest` API·다운로드 링크는 저장소가 public 이어야 로그인 없이 동작
