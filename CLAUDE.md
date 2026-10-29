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
- Dart 는 `lib/flavor.dart` 의 `isFullEdition`(`appFlavor == 'full'`)으로 전용판 메뉴('지난 문자 1년치 불러오기')·문자 권한 배너를 나눈다. "일반판/전용판" 표시는 메뉴 > 업데이트 확인 설명. 제작자 표시는 메뉴 맨 아래 '제작자 · wani' (설정 화면에는 입력칸 두 개 + [저장]만).

## 구조
- `lib/sms_parser.dart` — `parseSms()` 문자 파싱 (카드번호+승인 판정, 한 줄 형식, 승인취소, 연도 추정), `splitMessages()` 여러 건 쪼개기([Web발신]·카드번호+승인 단위), `senderMatches()` 발신번호 끝자리 비교
- `lib/expense.dart` — 내역 모델, shared_preferences 저장(`Store`, 권한 '앱에서 사용' 스위치 `use_listener_v1`/`use_sms_v1` 포함). 정산 복사 기능은 v1.14 에서 삭제
- `lib/budget.dart` — 월별 수립(원 단위 저장, 화면은 만원), 운영비 수립 = 합계 − 차량비, 잔여(수립 − 사용, 마이너스면 '초과 X.XX'), 합계·차량비 3단계(여유 <80% / 주의 80~100% / 초과), 운영비 잔여는 빈칸(보조 문구 없음), 보기 기간(1개월·홀짝·짝홀, 저장 안 함). 홀짝·짝홀은 ◀ ▶가 [첫째 달]→[둘째 달]→[두 달 합산] 순서(`PeriodView`, `stepView`), 합산 화면은 두 달 표·내역(달 구분선), 수립 편집 불가, 직전 달 수립 이월
- `lib/update_check.dart` — GitHub `releases/latest` 조회, 버전 비교, 판별 APK 링크
- `lib/paste_screen.dart` — 문자 붙여넣기(클립보드 미리보기, 여러 건, 새/중복 건수 확인)
- `lib/ingest.dart` — 들어온 문자 분류: 새 내역 / 진짜 중복(분류·대기 중) / 무시했던 문자(되살리기 가능) / 승인 문자 아님. 붙여넣기·공유·불러오기·캡처 공통
- `lib/ocr_parse.dart`, `lib/ocr_screen.dart` — 문자 캡처 OCR (두 판 공통). 사진 선택기(저장소 권한 없음) → 긴 이미지는 `ImageSlicer.kt` 가 겹치게 잘라서 → ML Kit 한국어 → RCS 화면 글자 제거·숫자 오인식 보정 → 확인 화면. 이미지는 인식 후 바로 삭제
  - ML Kit 한국어 모델은 `android/app/build.gradle.kts` dependencies 에 직접 넣고, 안 쓰는 언어 클래스는 `proguard-rules.pro` 에서 dontwarn
- (전용판) 1년치 불러오기는 SMS/MMS 에 더해 삼성 RCS 후보 저장소(`Flavor.kt` `OTHER_STORES`, `scanOther`)도 열리면 함께 조회. 예전 '문자 저장소 진단' 화면은 v1.7.0 에서 삭제
- 무시한 내역은 지우지 않고 보관 (`lib/ignored_screen.dart`, 메뉴 > 내역 관리 > 무시한 내역). 분류·무시하면 메인에 5초 [되돌리기]
  - 무시 사유 `Expense.ignoreReason`: 직접 무시(`kIgnoreManual`, 필드 없는 예전 데이터 포함) / 중복(`kIgnoreDuplicate`, 원본 id 는 `dupOf`). 무시를 풀면 사유도 지움 (`_setCategory`)
  - 무시한 내역 화면은 사유별 묶음. 중복 건은 '중복이라 무시함 · 원본 MM.dd HH:mm (분류)' + [중복 아님 · 되살리기]만 (되살리면 그 쌍을 check_ok 에 기억)
- 메뉴 > 내역 관리: 미분류 내역(모든 달 대기 건, `UnclassifiedScreen`) / 확인 필요 내역(`CheckScreen`) / 무시한 내역. 각 항목 오른쪽 건수 배지
  - `lib/check.dart` `findIssues` 실수 의심 규칙 (분류된 건만): a 같은 업체 분류 섞임(소수 쪽) / b 추천 키워드·등록 업체와 반대 / c 같은 가맹점·금액 10분 이내 중복 (묶음 하나 = 카드 하나, [둘 다 맞아요]/[하나 무시]=가장 늦은 건을 '중복' 사유로) / 승인 후 취소(취소 묶음 한 카드, [확인했어요] = 두 건 함께 '취소로 상쇄' 무시) / d 승인취소 원승인 없음·분류 다름 / e 미래·1년 넘은 날짜
  - `lib/cancel_link.dart` 승인취소 묶음: 취소마다 같은 가맹점·금액의 이전 승인 중 안 묶인 가장 가까운 1건(같은 분은 이전 승인이 없을 때만). 묶인 건은 중복 검사 제외, 한 건씩 따로 분류·무시 안 됨(`_classify` 가 짝까지), 새 취소는 원승인 분류를 따라감(`followOrigins`). v1.14 1회 `fixCancelRebuys`(`cancel_fix_v1`): 취소 → 재결제가 '중복'으로 무시된 건 되살림
  - 무시 사유 '취소로 상쇄'(`kIgnoreOffset`, 무시 전 분류 `ignoredFrom`) 는 무시한 내역에서 두 건 한 카드, [되살리기] 는 둘 다 원래 분류로
  - [이대로 맞아요] 는 `check_ok_v1`(규칙|id, 중복은 쌍 키 `dupPairKey` = dup|id|id. v1.12 의 duplicate|id 도 인정)에 기억. 메인 표 위 '확인이 필요한 내역 N건 ›' 은 닫으면 `check_banner_closed_v1`, 새 건이 생기면 다시 보임
  - 메뉴에서 연 화면은 HomeScreen `_changes`(setState 마다 증가)를 듣고 다시 그린다. 분류는 메인 `_classify` 를 그대로 써서 일괄 정리 팝업·되돌리기가 같다
- `lib/vendor.dart` — 차량비/운영비 추천. 우선순위: 자동 등록 업체(가맹점 이름 일치) > 직접 등록 키워드 > 기본 키워드(`kDefaultCarKeywords`, 첫 실행 때 목록에 들어가고 지울 수 있음). 키워드는 대소문자·공백·하이픈 무시
  - 분류 대기에서 차량비/운영비를 고르면 같은 가맹점의 다른 대기 건 일괄 정리를 묻고(무시한 건은 제외. 무시한 내역에서 고를 때는 '직접 무시' 건도 포함, '중복'·'취소로 상쇄'는 제외 — `sameVendorPending(includeIgnored:)`), 그 가맹점을 자동 등록. [되돌리기] 한 번에 일괄 정리·자동 등록까지 전부 복구
  - 추천 버튼은 진하게 + 작은 표시('추천' / '지난번 운영비'), 반대 버튼은 투명도 40%
- `lib/menu_screen.dart` — 우측 상단 톱니 → 메뉴 화면. 섹션 제목 없이 한 목록 7개(접힌 상태 한 화면): 결제내역 입력(펼침) / 내역 관리(펼침, 배지 = 미분류+확인 필요, 확인 필요 있으면 펼친 채 시작) / 등록 업체·추천 키워드 / 카드 문자 설정(카드번호·발신번호 같이 수정, [기본값으로]) / 권한 설정 / 업데이트 확인(현재 버전·판) / 제작자
- `lib/permission_screen.dart` — 권한 설정: 알림 감지·문자 읽기(전용판) 각각 '앱에서 사용' 스위치(네이티브 `CardSms.useListener/useSms` 로 전달, 끄면 수신 문자 버림·1년치 불러오기 흐림) + 시스템 권한 상태. 메인 권한 배너는 '사용' 켜짐 + 권한 꺼짐일 때만
- `lib/vendor_screen.dart` — 메뉴 > 업체 관리 (키워드 추가·카테고리 변경·삭제, 자동 등록 업체 관리). 행 = [고정 배지] 이름 … [휴지통], 카테고리는 행을 눌러 바텀시트에서만 변경, 삭제는 "'이름'을/를 목록에서 뺄까요?" 확인. 목록 끝 여백은 + 추가 버튼 높이까지
- `lib/category_badge.dart` — `CategoryBadge` 차량/운영/무시 고정 배지 (메인 내역 목록·업체 관리 공용) + 차량비/운영비 색 상수
- 이 앱은 상태바 알림을 띄우지 않는다 (POST_NOTIFICATIONS 없음). 감지한 문자는 조용히 분류 대기에 쌓이고, 업데이트 안내도 앱 안 다이얼로그로만
- `lib/native.dart` — `card_expense/native` MethodChannel 래퍼
- `lib/main.dart` — 테마(`buildTheme`: 흰 배경 무채색, 포인트 골드 #F0A500, 차량비 초록·운영비 노랑 버튼만 색), 화면 (설정, 분류 대기, 월별 수립/사용/잔여 표, 내역)
- 요약표 색: 행 제목 차량비 초록·운영비 노랑(버튼과 같은 색), 잔여 열 네이비(#1F3A68)/블루그레이 배경, 주의는 잔여 숫자만 빨강(#D93025), 초과는 빨간 칸+흰 글씨, 사용 칸은 초과일 때만 빨간 글씨. 표 안에 골드·주황 쓰지 않음
- 스크롤 화면은 edge-to-edge 라 목록 끝 패딩 = `listBottomPad(context)` (`lib/layout.dart`: max(viewPadding.bottom, 48) + 24). 새 스크롤 화면도 반드시 적용
- 메인 월 이동: 월 진행 표시줄(`_MonthStrip`, 1~12 터치 이동) + ◀ 제목 ▶ (화살표 좌우 끝 고정 48×48, 제목은 FittedBox). 요약표 좌우 스와이프(`_SwipeArea`, 60px 이상 또는 플릭, 가로 > 세로×2) = ◀ ▶, 전환은 `_SlideSwitcher` 200ms 슬라이드
- `android/.../CardSms.kt` — 알림 리스너·SMS 리시버 공용 처리: 판정, 중복 방지(금액+일시+취소 키), 네이티브 inbox 적재 (알림은 띄우지 않음)
- `CardNotificationListener.kt` — 메시지 앱 알림 감지(두 판 공통). 알림 제목 발신번호 또는 본문 카드번호로 판정
- 지난 문자: 두 판 모두 메시지 앱 공유(ACTION_SEND/SEND_MULTIPLE → `takeShared`)·붙여넣기. 전용판은 추가로 SMS+MMS 1년치 조회(MMS date 는 초 단위, 발신번호는 addr type=137, 본문은 part ct=text/plain)

앱이 꺼져 있을 때 들어온 문자는 네이티브 inbox 에 쌓였다가 앱이 켜지면 `drainInbox` 로 Dart 저장소로 옮겨진다.
- `lib/quiz.dart` / `lib/quiz_sheet.dart` — 오늘의 안전 OX. 문제 풀 = assets `quiz/questions.json`(내장) vs 기기 캐시(원격 raw.githubusercontent 의 main `quiz/questions.json`, version 이 높을 때만, 하루 1회·3초·실패 무시) 중 높은 버전. 첫 프레임 + 300ms 뒤 하루 1회(`quiz_last_day_v1`) 판정: 첫 실행 설정 직후·다른 팝업(업데이트 창 등)이 먼저 뜬 날은 건너뜀, 메뉴 스위치(`quiz_enabled_v1`, 기본 켜짐) 꺼짐·활성 문항 0개면 안 뜸. 셔플백(`quiz_bag_v1`/`quiz_known_v1`, 새 문항은 남은 순서에 섞음). 기록 `quiz_log_v1`(날짜·id·선택·정답 여부, 기기에만). 자동 업데이트 창은 퀴즈 시트가 닫힌 뒤에 뜸
- 메뉴 '오늘의 안전 OX'(제작자 위): 스위치 + '지금까지 N문제 · 정답률 NN%', 눌러 펼치면 [지금 한 문제 풀기](하루 1회와 별개)

테스트: `test/quiz_test.dart`(하루 1회·날짜 경계·셔플백·새 문항·active=false·원격 실패/캐시), `test/check_test.dart`(확인 필요 규칙 a~e, 중복 쌍 기억), `test/cancel_test.dart`(승인취소 묶음·바로잡기), `test/ignore_vendor_test.dart`(무시 사유·무시한 내역 화면·업체 관리 목록), `test/home_screen_test.dart`(메인 화면 그리기·넘김 위젯 테스트), `test/sms_parser_test.dart`, `test/budget_update_test.dart`, `test/ingest_ocr_test.dart`, `test/vendor_test.dart`

## 빌드 / 배포
- `flutter test`, `flutter build apk --release --flavor public` / `--flavor full`
- 서명: 로컬은 `android/key.properties`(커밋 금지), CI 는 GitHub Secrets `ANDROID_KEYSTORE_BASE64/PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
- keystore 원본: `C:\Users\EKR\Documents\card_expense_keystore\` (저장소에 넣지 말 것)
- `.github/workflows/release-apk.yml`: 두 판 빌드 → `v*` 태그는 정식 Release, main push 는 `dev` 프리릴리스
- 새 버전 배포: `pubspec.yaml` version 올리고 main push + `git tag vX.Y.Z && git push origin vX.Y.Z`
- 앱이 `releases/latest` 로 업데이트를 확인하므로 저장소는 public 이어야 한다. 실제 카드번호를 코드·문서·커밋에 넣지 말 것 (예시는 0000).

## 퀴즈 문제 관리 (오늘의 안전 OX)
- 원본: `quiz/questions_source.xlsx` '퀴즈' 시트 (번호, 분야, 문제, 정답 O/X, 해설(팝업용), 근거, 신뢰도, 채택(O/X), 수정 메모). 공개 파일이라 개인정보를 넣지 말 것
- 1) xlsx 에서 '채택(O/X)'을 고르고 문제·해설을 고친다
- 2) `python tools/quiz_export.py` → `quiz/questions.json` 재생성 (openpyxl 필요)
  - active: 채택=O → 출제, 채택=X → 제외, 채택이 비어 있으면 신뢰도='확인 권장'만 제외
  - 문항이 바뀌었으면 version 을 자동으로 +1, updated 는 오늘. 안 바뀌었으면 파일 그대로
- 3) xlsx + json 커밋 → main 에 푸시. 앱 재배포 없이 앱이 원격본(버전이 높으면)을 받아 캐시하고 다음 날부터 반영 (확인은 하루 1회라 최대 하루 늦을 수 있음)
- 앱 빌드 때는 그 시점의 `quiz/questions.json` 이 assets 로 들어가 기본값이 된다

## 설치 방식 (고정)
- 폰 설치는 항상 GitHub Release 링크로만 한다. adb/USB 설치는 제안하지도 말 것.
- 일반판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-release.apk`
- 전용판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-full-release.apk`

## 대기 중인 작업
`NEXT.md`에 다음 요청 때 같이 처리할 일이 쌓여 있다. 새 요청을 받으면 NEXT.md 항목도 함께 처리하고, 끝난 항목은 지운다.
