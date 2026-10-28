# 공감카드 관리 (card_expense)

NH기업카드 승인 문자를 읽어 건별로 차량비/운영비를 분류하고 월별 수립/사용을 관리하는 안드로이드 전용 Flutter 앱. 서버 없음, 저장은 기기 로컬.
사용자에게 보이는 이름은 '공감카드 관리' (`kAppName`, AndroidManifest label). applicationId(`com.wani.card_expense`)·패키지명·저장소 이름은 바꾸지 말 것 (덮어쓰기 설치·데이터 유지가 깨짐).

## 두 판 (Android product flavor `edition`)
| 판 | flavor | Release 파일 | 문자 권한 |
|---|---|---|---|
| 일반판 (남들 배포용) | `public` | `app-release.apk` | **없음** |
| 전용판 (내 전용) | `full` | `app-full-release.apk` | RECEIVE_SMS, READ_SMS |

- **public 에는 문자 권한 절대 금지.** 사이드로드 APK 가 문자 권한을 요청하면 구글 사기 방지(Play Protect)가 설치를 막는다.
  - 문자 권한·`SmsReceiver`·SMS/MMS 조회는 `android/app/src/full/` 에만 둔다 (`AndroidManifest.xml`, `kotlin/.../SmsReceiver.kt`, `Flavor.kt`).
  - `src/public/kotlin/.../Flavor.kt` 는 빈 구현. main 코드는 `Flavor` 객체로만 판 차이를 부른다.
  - CI 가 public APK 에 문자 권한이 있으면 실패시킨다.
- 두 판은 같은 applicationId·서명키 → 서로 덮어 설치해도 데이터 유지.
- Dart 는 `lib/flavor.dart` 의 `isFullEdition`(`appFlavor == 'full'`)으로 전용판 메뉴('지난 문자 1년치 불러오기')·문자 권한 배너를 나눈다. "일반판/전용판" 표시는 메뉴 > 앱 정보 > 현재 버전. 설정 화면 맨 아래는 '제작자: wani' + 버전.

## 구조
- `lib/sms_parser.dart` — `parseSms()` 문자 파싱 (카드번호+승인 판정, 한 줄 형식, 승인취소, 연도 추정), `splitMessages()` 여러 건 쪼개기([Web발신]·카드번호+승인 단위), `senderMatches()` 발신번호 끝자리 비교
- `lib/expense.dart` — 내역 모델, shared_preferences 저장(`Store`), 정산 텍스트
- `lib/budget.dart` — 월별 수립(원 단위 저장, 화면은 만원), 운영비 수립 = 합계 − 차량비, 잔여(수립 − 사용, 마이너스면 '초과 X.XX'), 합계·차량비 3단계(여유 <80% / 주의 80~100% 주황 / 초과 빨강), 운영비는 잔여 대신 '계획 +X.XX'만, 보기 기간(1개월·홀짝·짝홀 두 달 합산, `periodMonths`, 저장 안 함), 직전 달 수립 이월
- `lib/update_check.dart` — GitHub `releases/latest` 조회, 버전 비교, 판별 APK 링크
- `lib/paste_screen.dart` — 문자 붙여넣기(클립보드 미리보기, 여러 건, 새/중복 건수 확인)
- `lib/ingest.dart` — 들어온 문자 분류: 새 내역 / 진짜 중복(분류·대기 중) / 무시했던 문자(되살리기 가능) / 승인 문자 아님. 붙여넣기·공유·불러오기·캡처 공통
- `lib/ocr_parse.dart`, `lib/ocr_screen.dart` — 문자 캡처 OCR (두 판 공통). 사진 선택기(저장소 권한 없음) → 긴 이미지는 `ImageSlicer.kt` 가 겹치게 잘라서 → ML Kit 한국어 → RCS 화면 글자 제거·숫자 오인식 보정 → 확인 화면. 이미지는 인식 후 바로 삭제
  - ML Kit 한국어 모델은 `android/app/build.gradle.kts` dependencies 에 직접 넣고, 안 쓰는 언어 클래스는 `proguard-rules.pro` 에서 dontwarn
- (전용판) 1년치 불러오기는 SMS/MMS 에 더해 삼성 RCS 후보 저장소(`Flavor.kt` `OTHER_STORES`, `scanOther`)도 열리면 함께 조회. 예전 '문자 저장소 진단' 화면은 v1.7.0 에서 삭제
- 무시한 내역은 지우지 않고 보관 (`lib/ignored_screen.dart`, 메뉴 > 내역 관리 > 무시한 내역). 분류·무시하면 메인에 5초 [되돌리기]
- `lib/vendor.dart` — 차량비/운영비 추천. 우선순위: 자동 등록 업체(가맹점 이름 일치) > 직접 등록 키워드 > 기본 키워드(`kDefaultCarKeywords`, 첫 실행 때 목록에 들어가고 지울 수 있음). 키워드는 대소문자·공백·하이픈 무시
  - 분류 대기에서 차량비/운영비를 고르면 같은 가맹점의 다른 대기 건 일괄 정리를 묻고(무시한 건은 제외), 그 가맹점을 자동 등록. [되돌리기] 한 번에 일괄 정리·자동 등록까지 전부 복구
  - 추천 버튼은 진하게 + 작은 표시('추천' / '지난번 운영비'), 반대 버튼은 투명도 40%
- `lib/menu_screen.dart` — 우측 상단 톱니 → 메뉴 화면 (내역 넣기 / 내역 관리 / 정산 / 업체 관리 / 설정 / 앱 정보)
- `lib/vendor_screen.dart` — 메뉴 > 업체 관리 (키워드 추가·카테고리 변경·삭제, 자동 등록 업체 관리)
- 이 앱은 상태바 알림을 띄우지 않는다 (POST_NOTIFICATIONS 없음). 감지한 문자는 조용히 분류 대기에 쌓이고, 업데이트 안내도 앱 안 다이얼로그로만
- `lib/native.dart` — `card_expense/native` MethodChannel 래퍼
- `lib/main.dart` — 테마(`buildTheme`: 흰 배경 무채색, 포인트 골드 #F0A500, 차량비 초록·운영비 노랑 버튼만 색), 화면 (설정, 분류 대기, 월별 수립/사용/잔여 표, 내역)
- 스크롤 화면은 edge-to-edge 라 목록 끝 패딩 = `MediaQuery.viewPaddingOf(context).bottom + 24`
- `android/.../CardSms.kt` — 알림 리스너·SMS 리시버 공용 처리: 판정, 중복 방지(금액+일시+취소 키), 네이티브 inbox 적재 (알림은 띄우지 않음)
- `CardNotificationListener.kt` — 메시지 앱 알림 감지(두 판 공통). 알림 제목 발신번호 또는 본문 카드번호로 판정
- 지난 문자: 두 판 모두 메시지 앱 공유(ACTION_SEND/SEND_MULTIPLE → `takeShared`)·붙여넣기. 전용판은 추가로 SMS+MMS 1년치 조회(MMS date 는 초 단위, 발신번호는 addr type=137, 본문은 part ct=text/plain)

앱이 꺼져 있을 때 들어온 문자는 네이티브 inbox 에 쌓였다가 앱이 켜지면 `drainInbox` 로 Dart 저장소로 옮겨진다.
테스트: `test/sms_parser_test.dart`, `test/budget_update_test.dart`, `test/ingest_ocr_test.dart`, `test/vendor_test.dart`

## 빌드 / 배포
- `flutter test`, `flutter build apk --release --flavor public` / `--flavor full`
- 서명: 로컬은 `android/key.properties`(커밋 금지), CI 는 GitHub Secrets `ANDROID_KEYSTORE_BASE64/PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
- keystore 원본: `C:\Users\EKR\Documents\card_expense_keystore\` (저장소에 넣지 말 것)
- `.github/workflows/release-apk.yml`: 두 판 빌드 → `v*` 태그는 정식 Release, main push 는 `dev` 프리릴리스
- 새 버전 배포: `pubspec.yaml` version 올리고 main push + `git tag vX.Y.Z && git push origin vX.Y.Z`
- 앱이 `releases/latest` 로 업데이트를 확인하므로 저장소는 public 이어야 한다. 실제 카드번호를 코드·문서·커밋에 넣지 말 것 (예시는 0000).

## 설치 방식 (고정)
- 폰 설치는 항상 GitHub Release 링크로만 한다. adb/USB 설치는 제안하지도 말 것.
- 일반판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-release.apk`
- 전용판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-full-release.apk`

## 대기 중인 작업
`NEXT.md`에 다음 요청 때 같이 처리할 일이 쌓여 있다. 새 요청을 받으면 NEXT.md 항목도 함께 처리하고, 끝난 항목은 지운다.
