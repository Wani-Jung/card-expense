# 법카 정산 (card_expense)

NH기업카드 승인 문자를 읽어 건별로 차량비/운영비를 분류하고 월별 합계를 내는 안드로이드 전용 Flutter 앱. 서버 없음, 저장은 기기 로컬.

## 구조
- `lib/sms_parser.dart` — `parseSms()` 문자 파싱 (카드번호+승인 판정, 한 줄 형식, 승인취소, 연도 추정), `senderMatches()` 발신번호 끝자리 비교. 테스트: `test/sms_parser_test.dart`
- `lib/expense.dart` — 내역 모델, shared_preferences 저장, 정산 텍스트
- `lib/native.dart` — `card_expense/native` MethodChannel 래퍼
- `lib/main.dart` — 화면 (카드번호 입력, 분류 대기, 월별)
- `android/.../CardSms.kt` — 리시버/알림 리스너 공용 처리: 알림 판정, 중복 방지(금액+일시+취소 키), 네이티브 inbox 적재, 알림 표시
- `CardNotificationListener.kt` — 메시지 앱 알림 감지(실시간 유일 통로). 알림 제목 발신번호 또는 본문 카드번호로 판정

앱이 꺼져 있을 때 들어온 문자는 네이티브 inbox 에 쌓였다가 앱이 켜지면 `drainInbox` 로 Dart 저장소로 옮겨진다.

## 빌드 / 배포
- `flutter test`, `flutter build apk --release`
- 서명: 로컬은 `android/key.properties`(커밋 금지), CI 는 GitHub Secrets `ANDROID_KEYSTORE_BASE64/PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
- keystore 원본: `C:\Users\EKR\Documents\card_expense_keystore\` (저장소에 넣지 말 것)
- `.github/workflows/release-apk.yml`: `v*` 태그 → 정식 Release, main push → `dev` 프리릴리스
- 새 버전 배포: `pubspec.yaml` version 올리고 `git tag vX.Y.Z && git push --tags`

## Play Protect
사이드로드 APK 가 RECEIVE_SMS/READ_SMS 를 요청하면 구글 사기 방지 기능이 설치를 막아서 v1.2.0 부터 문자 권한을 쓰지 않는다.
지난 문자는 메시지 앱 공유(ACTION_SEND/SEND_MULTIPLE text/plain → MainActivity `takeShared`) 또는 붙여넣기로 받고, `splitMessages()` 로 [Web발신] 단위로 나눈다.
