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
