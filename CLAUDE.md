# 공감카드 관리 (card_expense)

NH기업카드 승인 문자를 읽어 건별로 차량비/운영비를 분류하고 월별 수립/사용을 관리하는 안드로이드 전용 Flutter 앱. 서버 없음, 저장은 기기 로컬.
사용자에게 보이는 이름은 '공감카드 관리' (`kAppName`, AndroidManifest label). applicationId(`com.wani.card_expense`)·패키지명·저장소 이름은 바꾸지 말 것 (덮어쓰기 설치·데이터 유지가 깨짐).

## 작업 방식 (2026-11-19 인수인계)
- 기획·REQ 작성·Play Console 작업·법령 Quiz 문제 관리까지 이제 Claude Code 가 맡는다 (예전 claude.ai 기획 세션은 끝). 사용자는 Claude Code 에 직접 요청하고, 요청이 쌓이면 묶어서 한 번에 처리하는 걸 좋아한다
- 인수인계 문서·REQ 원문·결정 기록·콘솔 메모는 저장소 밖 `C:\Users\EKR\card_expense_private\`(HANDOVER.md, REQ-52.md, SMS-권한-신고-계획.md, 빌드노트.md)에 둔다. **저장소에 커밋하지 않는다**(공개 저장소). 여기 CLAUDE.md 에도 실명·직장·계정명·앱 ID·트랙 ID·외부 업체 정보는 적지 않는다
- 말투는 격식 없이 편하게, 불릿 최소
- 삭제 기능은 항상 확인 팝업 + 되돌리기
- 회사 내부 규정(여비규정·공사감독업무지침 등)은 앱에 넣지 않는다. 공개 법령만
- 저장소 card-expense 는 공개 유지(앱 업데이트 확인이 익명 조회 + 스토어 개인정보처리방침 링크가 PRIVACY.md). 사용자의 다른 새 저장소는 기본 비공개

## Google Play 현황 (2026-11-23 기준, 바뀌면 여기 고칠 것)
- 패키지 com.wani.card_expense. 콘솔 URL 은 /u/0/ 사용 (계정·앱 ID 는 private 폴더 HANDOVER.md)
- Play 앱 서명: 기존 업로드 키 그대로 (SHA-256 0A:AB:3B…84:15)
- 비공개 테스트 트랙 'Alpha': 631(스토어 일반 AAB) 게시. 테스터 12명 이상 11/3 참여 → 14일 조건 충족. 비공개 테스트 중에는 다른 트랙에 올리지 않는다
- 2026-11-17 프로덕션 액세스 신청 → 11-19 오전 승인. 데이터 보안은 11-19 '앱 정보 및 성능 > 진단' 수집으로 바꿔 통과(ML Kit 통계 때문, 문자는 기기 안에서만 처리라 SMS 항목 불필요 — REQ-60 에서 그대로 둠)
- **2026-11-19 첫 프로덕션 출시 → 검토 통과·출시됨**: 651 (2.0.0, 스토어 일반 AAB) 전체 출시, 국가/지역 대한민국만, 출시 노트 ko-KR(REQ-52 초안), 같은 묶음으로 등록정보 전체 설명·휴대전화 스크린샷 6장(REQ-53) 변경
- **2.0.1 (REQ-60, 2026-11-20): 스토어판 = 전용판(스토어 전용 AAB, 끝 2).** 702 를 내부 테스트로 먼저 출시 → 사용자 폰 확인 → 같은 702 를 프로덕션으로 승급(대한민국·전체 출시), 같은 묶음으로 등록정보 짧은·자세한 설명(문자 자동 읽기 맨 앞)·휴대전화 스크린샷 7장(07 을 2번째) 변경 → 2026-11-20 검토 제출 → **2026-11-22 프로덕션 출시됨**. 스토어 일반 AAB(끝 1)는 이제 스토어에 내지 않는다(빌드·릴리스 첨부는 계속). 깃허브 일반판 APK(고정 링크)는 당분간 유지
- **2.0.2 (REQ-68, 2026-11-23)**: v2.0.2 태그 정식 빌드(750/751/752) → 752 내부 테스트 → 사용자가 폰에서 '버전 정보 → 새 버전이 있어요 → [업데이트]'로 받아 REQ-64 확인 → 같은 752 프로덕션 승격(대한민국·전체) + 등록정보 자세한 설명 '■ 법령 Quiz' 문단(개정 시점은 '확인된 문항만'으로 문구 보정)·휴대전화 스크린샷 8장(순서 01, 07, 02~06, 08) → **2026-11-23 검토 제출**(결과는 사용자가 알려 줌). 데이터 보안은 그대로('앱 정보 및 성능 > 진단' 하나 — ML Kit 을 뺀 지금은 사실상 없어도 되지만 넓게 신고한 상태라 둠). PRIVACY.md 시행일 2026-11-23(스토어판 업데이트 확인 = Google Play 인앱 업데이트)
- 내부 테스트 확인 요령: 사용자 폰은 Play 서명이라 GitHub dev APK 로 덮어 설치가 안 된다 → dev 를 확인할 땐 그 dev 의 스토어 전용 AAB 를 **내부 테스트 트랙**에 올려 본인에게 출시. 프로덕션·등록정보는 따로 요청할 때만
- **문자판(전용판) 준비 (REQ-57, 2026-11-19)**: 내부 테스트 트랙에 682 (2.0.1, 스토어 전용 AAB) 출시, 테스터는 이메일 목록 '내부 테스트 (개발자)'(사용자 계정 1명. 외부 테스터 목록은 내부 테스트에 쓰지 않음). 앱 콘텐츠 > SMS 및 통화 기록 권한 신고서: 핵심 기능 'SMS 기반 자금 관리', 검토 안내 500자(영어, 실제 동작 기준: 발신번호가 맞거나 카드번호가 적힌 승인·취소 문자를 읽고 카드번호 끝 4자리가 맞는 것만 날짜·가맹점·금액·원문으로 저장), 선언 4개 체크, 시연 영상(REQ-58, 에뮬레이터·예시 데이터·영어 자막, YouTube 일부 공개, 사용자 채널) 링크 포함 → **2026-11-20 검토 제출**(결과는 사용자가 알려 줌). 영상은 승인 뒤에도 앱이 스토어에 있는 동안 지우지 않는다(재검토·재신고 때 같은 링크). 영상 원본·녹화 스크립트는 private 폴더 req58_video. 전용판 프로덕션 때 고칠 곳: 스토어 설명(문자 자동 읽기 맨 앞, req53 금지어 풀기), 데이터 보안 SMS 항목 재확인, PRIVACY.md 문자 범위·원문 저장, 문자 불러오기 스크린샷
- AI 애셋 선언(등록정보 검토 단계에 있음): 앱 아이콘·대표 이미지(1024×500)는 AI(Claude)가 코드로 그린 것이라 'AI를 사용하여 생성 또는 수정'으로 라벨, 스크린샷(실제 앱 캡처)은 라벨 안 함. 새 애셋을 올릴 때 같은 기준으로 고른다
- 프로덕션 업데이트도 같은 순서: 프로덕션 > 새 버전 만들기 → AAB 는 사용자가 직접 드래그 → 출시 이름 'versionCode (versionName)' → 출시 노트 → 저장 → 등록정보 변경이 있으면 등록정보 화면 '다음' → '저장'으로 게시 개요에 같이 올림(임시보관함 저장만으로는 개요에 안 잡힘) → 게시 개요에서 사용자 확인 뒤 '검토를 위해 변경사항 N개 제출'
- 콘솔 작업 요령: Chrome 확장 file_upload 는 10MB 제한이라 AAB 업로드는 사용자가 직접 드래그. 스크린샷 업로드는 '애셋 추가' → 오른쪽 애셋 라이브러리 '업로드'(네이티브 파일 창이 열리므로 페이지에서 file input 을 잡아 file_upload 로 넣음). 여러 장을 한 번에 올리면 순서가 섞이니 라이브러리에서 한 장씩 선택 → '추가'. 출시 노트는 form_input 으로 넣고, 제출은 게시 개요 → '검토를 위해 변경사항 N개 제출'
- 문자 권한(전용판) 스토어 반영은 프로덕션 출시 뒤: 스토어 전용 AAB(끝 2)를 **내부 테스트 트랙**에 → 앱 콘텐츠 > 권한 신고서('SMS-based money management') + 시연 영상(YouTube 일부공개, 예시 문자·카드번호 0000) → 승인 시 프로덕션 + 스토어 설명 맨 앞에 문자 자동 읽기 명시 + 데이터 보안·PRIVACY.md 재점검. 가장 큰 거절 위험은 "다른 방법이 없을 때만" 조건(알림 감지·붙여넣기가 있으므로) → 지난 내역·꺼진/묶음 알림을 못 잡고 정산은 한 건만 빠져도 틀린다는 점 강조. 답변 초안·영상 대본은 private 폴더 `SMS-권한-신고-계획.md`
- 다음 할 일 순서는 private 폴더 HANDOVER.md 3장 (2026-11-23 기준 남은 일: 2.0.2 검토 결과·법령 개정일 연혁 채우기·일반/전용 합치기·AAB 자동 업로드(REQ-65 보류)·매년 target SDK 갱신. '지난 결제 넣기' 개편은 REQ-54 로 끝남)

## 스토어 등록정보·스크린샷 (REQ-53)
- 소개글 원본은 `store/listing/ko-KR/`(title.txt 30자·short_description.txt 80자·full_description.txt 4000자 이내). 소개글은 이 파일을 고친 뒤 콘솔에 반영한다(콘솔에서 먼저 고치지 않는다)
- **스토어판에 실제로 있는 기능만 쓴다.** 2.0.1(REQ-60)부터 스토어판 = 전용판(full flavor, CHANNEL=store: 문자 자동 읽기·지난 문자 불러오기 있음). 소개글 맨 앞 핵심 기능은 '카드 승인 문자를 자동으로 읽어 기록', 알림 감지·붙여넣기·공유는 보조. 캡처(OCR)는 스토어판에 없으니 쓰지 않는다(`test/req53_test.dart` 금지어). 법령 Quiz 는 REQ-62(2.0.2)부터 스토어판에도 있어 '■ 법령 Quiz' 문단을 쓰고, 문단 끝에 출처·고지 두 줄('법령 원문 출처: 국가법령정보센터 https://www.law.go.kr' / '이 앱은 정부·공공기관을 대표하지 않는 개인 개발 앱입니다.')을 꼭 둔다(Google Play 정부 정보 앱 정책, 테스트가 검사). 2.0.2 검토 제출 때 콘솔에 반영함
- 스크린샷 08_law_quiz(REQ-62, 2.0.2 부터 콘솔 맨 뒤 8번째): 법령 Quiz 문제 화면(근거·개정 시점 줄이 보이는 짧은 객관식 한 문제 고정), 띠 '법령 Quiz · 근거 조문과 개정 시점까지'. 장면 ⑨ 09_lab(실험실 + 고지)은 보고용이라 저장소에 안 넣음
- 스크린샷 07_import(REQ-60, 콘솔에선 01 다음 2번째): 지난 문자 불러오기 미리보기(데모 기준 이번 달 기록된 11건 + 새 3건), 띠 '지난 승인 문자도 기간 골라 한 번에'
- 스크린샷은 `store/screenshots/ko-KR/NN_name.png`(위쪽 네이비 #1F3A68 문구 띠 버전, 콘솔에 올리는 기본) + `plain/`(띠 없음). 1080×1920 PNG 8장: 01 메인 요약표 / 02 두 달 합산 / 03 분류 대기 추천 / 04 확인 필요 / 05 업체·키워드 / 06 안전 OX / 07 지난 문자 불러오기 / 08 법령 Quiz. 콘솔 순서는 01, 07, 02~06, 08. 대표 이미지 `store/feature_1024x500.png`·아이콘 `store/playstore_icon_512.png` 는 그대로
- 만드는 법: 데모 데이터 모드 `lib/demo.dart`(`--dart-define=DEMO=true` 일 때만, 가짜 가맹점 'OO주유소' 등·카드 0000, 이미 데이터가 있으면 안 덮음. 릴리스 빌드엔 define 이 없어 꺼짐. 규모(REQ-56): 한 달 수립 총액 45만·차량비 30만(`kDemoTotalBudget`·`kDemoCarBudget`, 두 달 합산은 90만·60만), 사용 차량비 약 20만·운영비 약 10만, 주유 5~8만·식사 1~2만 원대. 어느 장면도 수립 초과·차량비 잔여 경고 없게 — `test/req56_test.dart` 가 검사) + `integration_test/store_screenshots_test.dart`(장면마다 데모 데이터로 새로 띄워 찍고, 같은 화면을 문구 띠 아래 줄여 한 번 더 찍음) + `test_driver/integration_test.dart`(build/store_screenshots/ 에 저장)
  - CI: Actions > 'Store screenshots' 수동 실행(`.github/workflows/store-screenshots.yml`, pixel_2 1080×1920·Asia/Seoul) → 아티팩트 store-screenshots. 실행 번호가 release-apk 와 따로라 versionCode 에 영향 없음
  - 로컬: 에뮬레이터를 켜고 `adb shell wm size 1080x1920`, `adb shell wm density 420`, `adb shell service call alarm 3 s16 Asia/Seoul` → `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/store_screenshots_test.dart --flavor public --dart-define=CHANNEL=store --dart-define=DEMO=true` → 끝나면 `wm size reset`·`wm density reset`. PC 가 무거워지니 끝나면 에뮬레이터·Gradle 데몬(`cd android && ./gradlew --stop`)을 끈다
  - 결과 PNG 를 store/screenshots/ko-KR/ 로 옮겨 커밋

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
- Dart 는 `lib/flavor.dart` 의 `isFullEdition`(`appFlavor == 'full'`)으로 전용판 메뉴('지난 문자 불러오기')·문자 권한 배너를 나눈다. "일반판/전용판" 표시는 메뉴 > 업데이트 확인(스토어판은 '버전 정보') 설명. 제작자 표시는 메뉴 맨 아래 'Made by wani'.

## 두 채널 (v2.0.0~, REQ-43): 깃허브(APK) / 스토어(AAB)
| 채널 | 빌드 | 파일 | versionCode | 자체 업데이트 |
|---|---|---|---|---|
| 깃허브 | `flutter build apk --flavor public/full` | `app-release.apk` / `app-full-release.apk` (고정 링크) | run_number×10 **+0** | 있음 |
| 스토어 일반 | `flutter build appbundle --flavor public --dart-define=CHANNEL=store` | `app-store-public-release.aab` (2.0.1~ 스토어에 안 냄) | run_number×10 **+1** | 없음 |
| 스토어 전용 | `flutter build appbundle --flavor full --dart-define=CHANNEL=store` | `app-store-full-release.aab` (2.0.1~ 스토어판: 내부 테스트 → 프로덕션) | run_number×10 **+2** | 없음 |

- 채널은 flavor 차원이 아니라 `--dart-define=CHANNEL=store` 로 나눈다 (`lib/flavor.dart` `isStoreChannel`, 컴파일 시점 상수). 이유: 두 채널은 매니페스트·네이티브 차이가 없고(설치 권한은 원래 없음), Dart 상수라 스토어 빌드에서 업데이트 코드(`update_check.dart`, `_checkUpdate`)가 트리셰이킹으로 통째로 빠진다. flavor 를 늘리면 변형 4개·APK 파일명·`appFlavor` 값이 모두 바뀐다. define 이 없으면 깃허브판.
- 스토어판: 시작 때 자동 업데이트 확인 안 함. 메뉴 맨 아래 '버전 정보'(REQ-64)를 **누를 때만** Google Play 인앱 업데이트로 확인(`PlayUpdate.kt`, 의존성 `com.google.android.play:app-update:2.1.0`, 채널 `playUpdateCheck`/`playUpdateStart`/`openPlayStore`, Dart `lib/app_update.dart` `checkPlayUpdate`). 결과 공용 팝업 `updateResultDialog`(NoticeDialog): 있음 '새 버전이 있어요'/'지금 v… 쓰는 중이에요.' + [업데이트](유연한 업데이트, 다 받으면 바로 설치·재시작, 못 하면 Play 스토어 앱 페이지)·[나중에] / 최신 '최신 버전이에요'/'v… · 전용판' / 실패(Play 설치가 아님·오프라인) '지금은 확인할 수 없어요' + [Play 스토어에서 보기]·[닫기]. 스토어판은 Play 밖에서 내려받아 업데이트하지 않는다(정책). 깃허브판 메뉴 '업데이트 확인'도 같은 팝업(새 버전 태그 + [내려받기] 고정 링크, 실패는 [확인]), 시작 때 자동 확인 창은 예전 AlertDialog 그대로. 팝업은 기다리지 않고 띄운다(`unawaited`, 메뉴 스피너가 팝업 뒤에서 계속 돌지 않게). `NoticeDialog` 에 `onOk`(골드 버튼 뒤 할 일)·`cancelLabel`(왼쪽 글자 버튼) 추가. CI 가 스토어 AAB 의 libapp.so 에 GitHub releases API 주소가 있으면 실패시킨다(app_update.dart 는 update_check.dart 를 부르지 않음).
- 같은 태그 빌드에서 APK 2개 + AAB 2개를 만들어 같은 GitHub 릴리스에 첨부. AAB 도 같은 키스토어로 서명(Play App Signing 에 이 키를 앱 서명 키로 등록 → `scripts/export_play_key.md`).
- 어느 판에도 REQUEST_INSTALL_PACKAGES 같은 설치 권한을 넣지 않는다 (CI 검사).
- 권한 안내(Prominent Disclosure, `lib/disclosure.dart`): 문자 권한 시스템 창·알림 접근 설정 화면으로 보내기 전에 매번 전체 화면 안내 → [동의하고 계속]일 때만 요청, [나중에]면 아무것도 안 함. 문자 권한 요청은 `requestSmsWithDisclosure`, 알림 접근은 `openNotificationAccessWithDisclosure` 로만 부른다 (`Native.requestSmsPermission`/`openNotificationAccessSettings` 직접 호출 금지). 문자 안내 문구는 REQ-43 지정 문구 그대로.
- 메뉴 '개인정보처리방침'(모든 판) → 확인 팝업 "개인정보처리방침 페이지(GitHub)를 인터넷 브라우저로 엽니다." [열기]/[취소] → [열기]만 `kPrivacyUrl`(main 의 `PRIVACY.md`) 브라우저로 (스토어 출시 후에도 유지). PRIVACY.md 는 코드와 사실이 맞아야 한다 (기능이 바뀌면 같이 고칠 것).

## 구조
- `lib/sms_parser.dart` — `parseSms()` 문자 파싱 (카드번호+승인 판정, 한 줄 형식, 승인취소, 연도 추정), `splitMessages()` 여러 건 쪼개기([Web발신]·카드번호+승인 단위), `senderMatches()` 발신번호 끝자리 비교
- `lib/expense.dart` — 내역 모델, shared_preferences 저장(`Store`, 권한 '앱에서 사용' 스위치 `use_listener_v1`/`use_sms_v1` 포함). 정산 복사 기능은 v1.14 에서 삭제
- `lib/budget.dart` — 월별 수립(원 단위 저장, 화면은 만원), 운영비 수립 = 합계 − 차량비, 잔여(수립 − 사용, 마이너스면 '초과 X.XX'), 합계·차량비 3단계(여유 <80% / 주의 80~100% / 초과), 운영비 잔여는 빈칸(보조 문구 없음), 보기 기간(1개월·홀짝·짝홀, **기기에 저장**(REQ-54, `period_mode_v1`, `Store.periodMode`, 없으면 1개월) → 앱을 열면 저장된 보기로 시작: 홀짝·짝홀이면 이번 달이 속한 묶음의 두 달 합산 화면(12~1월 짝홀 포함), 1개월이면 이번 달 월 화면. 보기 선택에서 홀짝·짝홀을 고르면 보던 달이 속한 묶음의 **두 달 합산 화면부터**(REQ-52), 1개월을 고르면 보던 달(합산이면 묶음 첫째 달) 월 화면. 월 숫자를 누르면 그 달 월 화면). 홀짝·짝홀은 ◀ ▶가 [첫째 달]→[둘째 달]→[두 달 합산] 순서(`PeriodView`, `stepView`), 합산 화면은 두 달 표·내역(달 구분선), 수립 편집 불가, 직전 달 수립 이월
- `lib/update_check.dart` — GitHub `releases/latest` 조회, 버전 비교, 판별 APK 링크
- `lib/paste_screen.dart` — 문자 붙여넣기(클립보드 미리보기, 여러 건, 새/중복 건수 확인)
- 입력 방법: 붙여넣기, 공유하기, 알림 감지, (전용판) 문자 실시간 수신·지난 문자 불러오기. **문자 캡처(OCR)는 v2.0.0(REQ-47)에서 완전히 뺐다** (ML Kit·image_picker·ImageSlicer 없음)
- `lib/ingest.dart` — 들어온 문자 분류: 새 내역 / 진짜 중복(분류·대기 중) / 무시했던 문자(되살리기 가능) / 승인 문자 아님. 붙여넣기·공유·불러오기 공통
- (전용판) 지난 문자 불러오기(`lib/import_screen.dart` `ImportRangeScreen`): 시작일·종료일 달력(미래·시작>종료 막음, 1년보다 이른 시작 허용, 기본 1년 전~오늘) + 빠른 선택 [이번 달][지난달][최근 3개월][최근 1년] → [이 기간 문자 확인] 미리보기 '이 기간 승인 문자 n건 (새 n · 중복 n)' → [불러오기]. 네이티브 `readSmsInbox(from, to)` = [시작일 0시, 종료일 다음 날 0시). SMS/MMS 에 더해 삼성 RCS 후보 저장소(`Flavor.kt` `OTHER_STORES`, `scanOther`)도 같은 기간. **첫 권한 허용 때 자동 1년 불러오기는 없앴다**(REQ-69: 사전입력 3단계에서 '이번 달'을 골라 불러온 뒤 메인이 뜨면 `_maybeAutoImport` 가 최근 1년을 미리보기 없이 또 불러왔고, 메뉴에서 권한을 처음 허용해도 기간을 고르기 전에 1년이 들어왔다). 메뉴 불러오기는 권한이 없으면 `ensureSmsForImport`(안내 → 권한 창 → 결과 기다림) 뒤 바로 기간 고르는 화면. 옛 `auto_imported` 키는 읽지 않는다. 네이티브는 SMS·MMS·RCS 후보 저장소를 합쳐 돌려주므로 같은 문자가 두 번 올 수 있다 → `importPreviewOf`(REQ-59)가 승인 id(아니면 본문)로 한 번만 남기고 분류한다. 미리보기 '새 n · 중복 n'과 불러온 뒤 결과 알림 숫자가 같고, 중복은 이미 저장된 내역과 겹친 것만(메뉴·사전입력 3단계·첫 권한 자동 불러오기 모두 `previewImportRange` → `importPreviewOf`) 예전 '문자 저장소 진단' 화면은 v1.7.0 에서 삭제
  - 결과(REQ-61): 새로 넣으면 스낵바 `importAddedMessage`('분류 대기에 n건 넣었어요' + 중복 있으면 '\n이미 있던 n건은 건너뛰었어요', 사전입력 3단계도 같은 문구), 무시했던 문자가 있으면 되살리기 창, 새 건 0 이면 `importResultDialog`. 문자함에서 읽은 '승인 문자 아님'은 보여주지 않음(붙여넣기·공유 결과의 숫자 칸 3개는 그대로)
  - SMS·MMS·RCS 후보 저장소 모두 실시간 수신과 같은 조건('승인'·'취소'가 있고 발신번호 일치 **또는** 본문 카드번호+승인·취소)으로 읽는다(REQ-61·66. 사용자 폰의 1588-1600 카드 문자는 RCS 기업메시지라 im/chat 저장소에만 있었고, 예전엔 그 저장소를 카드번호로만 찾았다). 기간 필터는 네이티브(SMS·MMS 쿼리 + RCS 후보는 `InboxDate.toMillis`·`inRange`, 순수 Kotlin·`InboxDateTest`: 초·밀리초·마이크로초·나노초 정규화, **날짜 칸이 없는 저장소는 통째로 건너뜀** — REQ-69 전엔 '지금'으로 쳐서 기간과 상관없이 전부 읽었고, 본문 날짜로 연도를 추정해 1년 안 날짜로 들어왔다)와 Dart `inRangeOnly`(previewImportRange) 두 번
  - **문자함 전체를 몇 건 봤는지는 앱 어디에도(숨은 진단 포함) 보여 주지 않는다**(REQ-66 B, 다른 문자도 앱에 들어간다고 오해하지 않게). 네이티브 `readSmsInbox` 는 후보 문자(`bySender` 표시)와 주소 형식 샘플만 돌려준다. 진단(미리보기·결과 팝업 제목 길게 누르기 `importDiagDialog`) = 찾은 카드 승인 문자 n건 · 그중 발신번호 일치 n건 · 주소 형식
  - 미리보기·결과 숫자는 항목별 한 줄(`resultLines`: 새로 넣을/넣은 문자 · 이미 있는 문자 · 무시했던 문자 · 승인 문자 아님, 0건 줄은 뺌, REQ-66 C). 미리보기에서 넣을 게 없으면 [닫기](메뉴 화면: 결과 팝업 없이 닫음 — 미리보기에 이미 숫자가 보여서), 있으면 [불러오기]. 무시했던 문자가 있을 때 결과는 공용 팝업 '무시했던 문자가 n건 있어요' + [닫기] [다시 분류 대기로]
- 무시한 내역은 지우지 않고 보관 (`lib/ignored_screen.dart`, 메뉴 > 내역 관리 > 무시한 내역). 분류·무시하면 메인에 5초 [되돌리기]
  - 무시 사유 `Expense.ignoreReason`: 직접 무시(`kIgnoreManual`, 필드 없는 예전 데이터 포함) / 중복(`kIgnoreDuplicate`, 원본 id 는 `dupOf`). 무시를 풀면 사유도 지움 (`_setCategory`)
  - 무시한 내역 화면은 사유별 묶음. 중복 건은 '중복이라 무시함 · 원본 MM.dd HH:mm (분류)' + [중복 아님 · 되살리기]만 (되살리면 그 쌍을 check_ok 에 기억)
- 메뉴 > 내역 관리: 미분류 내역(모든 달 대기 건, `UnclassifiedScreen`. 맨 위 [이번 달 이전 미분류 n건 한꺼번에 무시](REQ-69 C, `pendingBeforeMonth`·`_ignoreOldPending`: 확인창 '모두 무시'/'취소' → '직접 무시'로 무시한 내역에 보관(되살리기 가능) → 5초 [되돌리기], 승인취소 짝도 미분류면 같이, 0건이면 숨김) / 확인 필요 내역(`CheckScreen`) / 무시한 내역 / 확인한 내역(`ConfirmedScreen`, 분류된 전체·검색·칩·월별 합계, 누르면 메인 편집 시트). 건수 배지: 미분류·확인 필요(와 내역 관리 합계)는 1 이상 빨강, 그 밖(무시한·분류한 내역)과 0 은 연회색(REQ-67 17). '확인한 내역'은 REQ-67 18 에서 '분류한 내역'으로 이름 바꿈(화면 제목도)
- 메뉴: 펼침 항목은 한 번에 하나만(`_expanded`). 모든 항목은 메뉴를 닫지 않고 메뉴 위에 push(뒤로가기 → 메뉴, 돌아오면 배지·설명 다시 읽음), 업데이트 확인은 메뉴에 머문 채 로딩(지난 문자 불러오기는 기간 선택 화면)
- 무시한 내역 되살리기 3종(대기로 되돌리기·중복 아님·승인 후 취소)은 전부 미분류로(`_reviveToPending`: 사유 필드 삭제, 스낵바 [보기]→미분류 내역, 5초 [되돌리기]→원래 무시 상태). 재표시 방지 기억(check_ok)은 유지
  - `lib/check.dart` `findIssues` 실수 의심 규칙 (분류된 건만): a 같은 업체 분류 섞임(소수 쪽) / b 추천 키워드·등록 업체와 반대 / c 같은 가맹점·금액 10분 이내 중복 (묶음 하나 = 카드 하나, [둘 다 맞아요]/[하나 무시]=가장 늦은 건을 '중복' 사유로) / 승인 후 취소(취소 묶음 한 카드, [확인했어요] = 두 건 함께 '취소로 상쇄' 무시) / d 승인취소 원승인 없음·분류 다름 / e 미래·1년 넘은 날짜
  - e 날짜 이상은 **들어올 때 한 번만** 판정해 `Expense.dateIssue`('future'/'old')에 저장(`dateIssueAt`, `_addParsed`). 시간이 지났다고 다시 올리지 않는다. 문자 저장소에서 불러온 건·실시간 문자(날짜가 시스템 값)는 판정하지 않는다. 필드가 없는 예전 데이터는 정상으로 본다 → REQ-47 이전에 시간이 지나 올라가 있던 기존 분류 내역은 저장 데이터 변경 없이 자동으로 빠진다
  - 확인 필요 카드(a·b·d·e) 버튼: [이대로 맞아요] = 지금 분류 색 채움·진하게, [X로 변경] = 테두리만 + 바꿀 분류 색 글자 (`CheckScreen.keepButton`/`changeButton`). 중복 의심·승인 후 취소 카드는 그대로
  - `lib/cancel_link.dart` 승인취소 묶음: 취소마다 같은 가맹점·금액의 이전 승인 중 안 묶인 가장 가까운 1건(같은 분은 이전 승인이 없을 때만). 묶인 건은 중복 검사 제외, 한 건씩 따로 분류·무시 안 됨(`_classify` 가 짝까지), 새 취소는 원승인 분류를 따라감(`followOrigins`). v1.14 1회 `fixCancelRebuys`(`cancel_fix_v1`): 취소 → 재결제가 '중복'으로 무시된 건 되살림
  - 무시 사유 '취소로 상쇄'(`kIgnoreOffset`, 무시 전 분류 `ignoredFrom`) 는 무시한 내역에서 두 건 한 카드, [되살리기] 는 둘 다 원래 분류로
  - [이대로 맞아요] 는 `check_ok_v1`(규칙|id, 중복은 쌍 키 `dupPairKey` = dup|id|id. v1.12 의 duplicate|id 도 인정)에 기억. 메인 표 위 '확인이 필요한 내역 N건 ›' 은 닫으면 `check_banner_closed_v1`, 새 건이 생기면 다시 보임
  - 메뉴에서 연 화면은 HomeScreen `_changes`(setState 마다 증가)를 듣고 다시 그린다. 분류는 메인 `_classify` 를 그대로 써서 일괄 정리 팝업·되돌리기가 같다
- `lib/vendor.dart` — 차량비/운영비 추천. 우선순위: 자동 등록 업체(가맹점 이름 일치) > 직접 등록 키워드 > 기본 키워드(`kDefaultCarKeywords`·`kDefaultOpsKeywords`, 첫 실행 때 목록에 들어가고 지울 수 있음). 키워드는 대소문자·공백·하이픈 무시, 영문·숫자 3자 이하(LPG 등)는 가맹점 이름 앞부분 일치만
  - 기본 키워드 세트 버전 `kDefaultKeywordsVersion`(지금 3). 올리면 기존 기기에 새로 생긴 기본 키워드만 1회 추가(`upgradeDefaults`, `loadVendors` 에서). 지운 기본 키워드는 `removedDefaults` 로 기억해 되살리지 않음
  - v3 (REQ-47): 운영비 '알파문구'·'드림디포' 추가. 같은 분류의 더 짧은 기본 키워드에 덮이는 기본 키워드 21개(`kRemovedDefaultKeywords`)를 기본 목록에서 빼고, 기존 기기에서도 덮는 키워드가 남아 있을 때만 정리(`_dropCoveredDefaults`, 직접 등록은 그대로). 단 한 이름에 차량비·운영비 키워드가 같이 있으면(예: '하나로마트 주유소') 추천이 바뀔 수 있다
  - 키워드 켜기/끄기: `KeywordRule.enabled`(기본 true, 꺼졌을 때만 json 에 `enabled:false`, `vendor_book_v1` 안). 업데이트로 기본 키워드가 추가돼도 기존 항목의 꺼짐은 유지. 지운 목록에는 켜진 상태로 남김
  - 지운 키워드: 기본은 `removedDefaults`(키), 직접 등록은 `removedCustom`(분류와 함께), [영구 삭제]는 `purged`(목록에서만 숨김, 기본은 계속 안 되살림). `removedKeywords`/`restoreRemoved`/`purgeRemoved`/`addKeyword`
  - 분류 대기에서 차량비/운영비를 고르면 같은 가맹점의 다른 대기 건 일괄 정리를 묻고(무시한 건은 제외. 무시한 내역에서 고를 때는 '직접 무시' 건도 포함, '중복'·'취소로 상쇄'는 제외 — `sameVendorPending(includeIgnored:)`), 그 가맹점을 자동 등록. [되돌리기] 한 번에 일괄 정리·자동 등록까지 전부 복구
  - 추천 버튼은 진하게 + 작은 표시('추천' / '지난번 운영비'), 반대 버튼은 투명도 40%
- `lib/menu_screen.dart` — 우측 상단 톱니 → 메뉴 화면. 섹션 제목 없이 한 목록 9개(접힌 상태 한 화면, 이 순서 고정): 결제내역 입력(펼침: (전용판) 지난 문자 불러오기·문자 붙여넣기) / 내역 관리(펼침, 배지 = 미분류+확인 필요, 확인 필요 있으면 펼친 채 시작) / 등록 업체·추천 키워드 / 카드 문자 설정(카드번호·발신번호 같이 수정, [기본값으로]) / 권한 설정 / 사전입력사항 / 실험실 / 개인정보처리방침(확인 팝업) / 업데이트 확인(현재 버전·판, 스토어판은 '버전 정보') + 맨 아래 크레딧. '설정' 항목은 REQ-44 에서, 메뉴 최상위 '안전 OX Quiz'는 REQ-47 에서 없앰(실험실 안으로)
- `lib/lab_screen.dart` — 메뉴 > 실험실: 안전 OX Quiz(설명 '연속 N일 · 정답률 NN%') / 법령 Quiz 4종(REQ-51, `kLawQuizzes` 순서: 농어촌정비법 Quiz · 건설기술 진흥법 Quiz · 국가계약법 Quiz · 건축법 Quiz). 메뉴 실험실 설명 '안전 OX Quiz · 법령 Quiz 4종'
  - **법령 Quiz 4종은 REQ-62(2.0.2)부터 스토어판에도 보임**(REQ-49·51 땐 숨김): `lib/flavor.dart` `kRuralQuizInStore = true` → `kShowRuralQuiz = !isStoreChannel || kRuralQuizInStore`. 다시 숨기려면 false 로(그러면 실험실 설명은 '안전 OX Quiz'만)
  - 출처·고지 `lib/law_notice.dart` `LawSourceNotice`(실험실 법령 목록 아래·법령 Quiz 첫 화면 맨 아래, 11pt): '법령 원문 출처: 국가법령정보센터(law.go.kr)'(누르면 https://www.law.go.kr 브라우저) + '이 앱은 정부·공공기관과 관련 없는 개인 앱이며,' / '문제는 학습용으로 법적 효력이 없어요.' / '기준일: yyyy.mm.dd' 세 줄(`lawDisclaimerText`, 줄 직접 나눔 + 줄 안은 keepWords, 2.0.3)(내장 `quiz/rural_questions.json` 의 updated, `lawQuizBaseDate`). Google Play '정부 정보를 전달하는 앱'(Misleading Claims) 정책 대응
  - 앱 이름·아이콘·문구·공유 카드에 특정 기관(공사·부처) 이름을 넣지 않는다. 안전 OX 결과 카드 기본 부제도 '현장 안전 OX'(REQ-62 에서 기관 이름 뺌, `test/req62_test.dart` 가 lib 에 기관 이름이 없는지 검사 — 가맹점 키워드 vendor.dart 제외)
- `lib/onboarding_screen.dart` — 사전입력사항 3단계(화면 제목·메뉴 이름 '사전입력사항', REQ-48. 넘기기·건너뛰기): ① 이번 달 전체·차량비 수립(만원, 설명·예시 줄 없음, 비워 두고 넘어가기 가능) ② 카드번호 네자리·발신번호(제목 아래 설명 없음, 칸 설명은 있음) ③ 지난 결제: 전용판(full flavor, 깃허브·스토어 모두)은 이 화면에서 바로 기간 지정 불러오기(REQ-54, 메뉴와 같은 `ImportRangePanel`, 기본 이번 달 1일~오늘, 빠른 선택 4개) → 미리보기 → [불러오기] → '분류 대기에 n건 넣었어요'(0건이면 '새로 넣을 문자가 없어요') + [닫기]. 미리보기 전에 카드 설정 저장 + 문자 권한(`ensureSmsForImport`: 안내 화면 → 권한 창 → 앱이 앞으로 올 때 결과 확인, 영구 거부면 요청 없이 실패). 권한을 못 받으면 아래에 '문자 권한 없이도 이렇게 넣을 수 있어요' + 붙여넣기·공유 안내. 아래쪽 작은 링크 '문자 붙여넣기·공유로도 넣을 수 있어요'(붙여넣기 화면). 미리보기·넣기는 공용 함수 `previewImportRange`(import_screen)·`addParsedTo`(ingest) — 메뉴 불러오기, 첫 실행(메인 전이라 저장소에 바로), 메뉴 > 사전입력사항이 같이 씀. 일반판·스토어 일반판은 붙여넣기·공유하기 안내 + [지금 문자 붙여넣기] 그대로. 첫 실행(카드 설정 없음)에서만 자동으로 뜨고 예전 첫 실행 카드 문자 설정 화면을 대신한다(두 번 안 물음, ②는 건너뛸 수 없음). 업데이트로 들어온 기존 사용자에겐 안 뜸. 메뉴 > 사전입력사항에서 다시 보기(지금 값이 들어 있고 바꾸면 바로 반영). ③ 버튼은 `OnboardingAction` → 메인이 이어서 실행
- `lib/vendor_screen.dart` — 메뉴 > 등록 업체·추천 키워드(화면 제목도 같음, REQ-67 19. 위 안내 '자주 쓴 가게 → 내가 넣은 키워드 → 기본 키워드 순으로 추천해요', 섹션 [전체 삭제]는 설명 아래 작은 회색 글자): 추천 키워드는 차량비/운영비 묶음 안 칩(`KeywordChip`, REQ-48): 켜짐 = 분류 색 채움(차량비 초록+흰 글자, 운영비 노랑+`kOpsText`, 메인 '차량'/'운영' 배지와 같은 조합), 꺼짐 = 흰 바탕 + 분류 색 테두리·글자(흐리게), 직접 등록은 앞에 작은 사람 아이콘. 위에 안내 '누르면 끄기/켜기 · 길게 누르면 삭제'. 짧게 누르면 끄기/켜기(`toggleKeyword`, 꺼진 키워드는 추천에 안 씀), 길게 누르면 "'키워드'를 목록에서 뺄까요?" → 지운 키워드로(5초 되돌리기). 칩에서 분류 전환 없음(다른 분류로 쓰려면 지우고 새로 추가). 자동 등록 업체는 예전대로(행을 누르면 바텀시트에서 분류 변경·삭제). 묶음 아래 '지운 키워드 (n)'(0개면 숨김) → `RemovedKeywordsScreen`: 체크한 것만 [다시 넣기], [모두 선택], [영구 삭제](확인). 자동 등록 업체는 한 줄씩. 섹션별 [전체 삭제](+되돌리기)
- `lib/permission_screen.dart` — 권한 설정: 알림 감지·문자 읽기(전용판) 각각 '앱에서 사용' 스위치(네이티브 `CardSms.useListener/useSms` 로 전달, 끄면 수신 문자 버림·지난 문자 불러오기 흐림) + 시스템 권한 상태. 메인 권한 배너는 '사용' 켜짐 + 권한 꺼짐일 때만
- `lib/category_badge.dart` — `CategoryBadge` 차량/운영/무시 고정 배지 (메인 내역 목록·업체 관리 공용) + 차량비/운영비 색 상수
- 이 앱은 상태바 알림을 띄우지 않는다. **예외: 미분류 7일 알림만 허용(사용자 결정 2026-11).** 그 밖의 알림·포그라운드 알림은 여전히 금지. 감지한 문자는 조용히 분류 대기에 쌓이고, 업데이트 안내도 앱 안 다이얼로그로만
- 미분류 7일 알림 (REQ-45, 모든 판 동일, 채널 이름 '미분류 알림', 문구 '미분류 내역 n건이 일주일 넘게 남아 있어요')
  - 판정 `ReminderRule.kt`(순수 Kotlin, 테스트 `android/app/src/test/.../ReminderRuleTest.kt`, 실행 `cd android && ./gradlew :app:testPublicDebugUnitTest`, CI 도 돈다): 미분류 7일 초과(딱 7일은 아직) 1건 이상 + 평일 17~21시(기기가 꺼져 늦어져도 밤에 안 울리게 21시 전까지만) + 보낸 뒤 7일 이상. 다음 확인 = 다음 평일 17:00, 보낸 지 7일 안 찼으면 7일 차는 때(몇 초 차이로 한 주 밀리지 않게)
  - 실행 `UnclassifiedReminder.kt`: WorkManager 1회 작업이 자기 뒤에 다음 확인을 잇는다(`APPEND_OR_REPLACE`, 앱에서는 `KEEP`), 재부팅 후에도 유지. 확인은 평일 하루 1번 깨어나는 게 전부. 앱이 꺼져 있어도 판정하도록 Dart `_syncReminder`(`setState` 마다, 바뀌었을 때만)가 미분류 시각·스위치를 `syncReminder` 로 넘기고, 아직 안 옮긴 네이티브 inbox 문자도 센다
  - 미분류 기간 기준 `Expense.pendingFrom` = `pendingSince ?? dateTime`. 지난 문자 불러오기·붙여넣기·공유로 넣은 때·무시에서 되살린 때 `pendingSince` = 그 시각, 실시간 문자·예전 데이터는 승인 일시
  - 스위치: 메뉴 > 내역 관리 펼침 맨 아래 '미분류 알림 받기'(`remind_unclassified_v1`, 기본 ON). 첫 실행 뒤 한 번 권한을 묻고(`notif_asked_v1`), 거부·휴대폰 설정에서 끄면 OFF + 안내 한 줄과 [설정 열기]
  - 탭: 인텐트 extra `open_target` → `takeOpenTarget`/`openTarget` → `_openTarget`(떠 있던 화면 닫고 미분류 내역)
  - R8: `proguard-rules.pro` 의 `-keep class * extends androidx.room.RoomDatabase { <init>(); }` 필수. room-runtime 규칙에는 생성자가 없어 R8 전체 모드에서 지워지고, 빠지면 모든 판이 시작하자마자 죽는다 (REQ-46)
  - 매니페스트: `POST_NOTIFICATIONS` 추가. WorkManager 의 `RECEIVE_BOOT_COMPLETED`·`WAKE_LOCK` 은 그대로, `FOREGROUND_SERVICE`·`SystemForegroundService` 는 `tools:node="remove"` 로 뺌 (CI 검사)
- `lib/native.dart` — `card_expense/native` MethodChannel 래퍼
- `lib/main.dart` — 테마(`buildTheme`: 흰 배경 무채색, 포인트 골드 #F0A500, 차량비 초록·운영비 노랑 버튼만 색), 화면 (설정, 분류 대기, 월별 수립/사용/잔여 표, 내역)
- 요약표 색: 행 제목 차량비 초록·운영비 노랑(버튼과 같은 색), 잔여 열 네이비(#1F3A68)/블루그레이 배경, 주의는 잔여 숫자만 빨강(#D93025), 초과는 빨간 칸+흰 글씨, 사용 칸은 초과일 때만 빨간 글씨. 표 안에 골드·주황 쓰지 않음
- 차량비 잔여는 언제나 차량비 자기 값(수립 − 사용, 초과면 '초과 X'). REQ-48·49 의 '합계 잔여로 보정'은 REQ-50 에서 철회했다(사용자 결정: 두 달 단위로도 관리하므로). 합산 화면도 같음
- 차량비 잔여 경고 (REQ-52, 숫자·색은 안 바꿈): 차량비 잔여 > 0 이고 차량비 잔여 > 합계 잔여(`carRemainWarn`, 같으면 표시 안 함)면 차량비 잔여 칸 오른쪽 위 모서리에 `WarnBadge`(19, 진한 주황 꽉 찬 원 + 흰 '!'). 칸 좌우 여백을 24로 넓혀 숫자와 안 겹침. 칸 전체(아이콘 포함)를 누르면 경고 팝업. 합산 화면도 같은 규칙
  - 팝업 (REQ-55, 공용 `NoticeDialog`): 위 `WarnBadge`(26) + 제목 '차량비 잔여 주의'(`kCarRemainWarnTitle`) / 가로 숫자 칸 두 개 [차량비 잔여 X](회색) [전체 잔여 Y](연한 주황, 숫자 진하게, 마이너스면 '초과 Z' — `moneyWithUnit`·`totalRemainWithUnit`) / 본문 `carRemainWarnMessage`(줄 직접 나눔: '차량비는 {X} 남았지만,\n운영비가 초과돼서\n전체 남은 돈은 {Y}이에요.\n\n차량비를 다 쓰면 총액을 넘으니\n유의하세요.', 합계 < 0 은 '…운영비 초과로\n전체는 이미 {Z} 초과예요.\n\n차량비를 더 쓰면 초과 금액이 커지니\n유의하세요.') / 오른쪽 아래 골드 채운 둥근 [확인]. 금액은 지금 단위 규칙 + 단위 글자
- 공용 안내 팝업 `lib/notice_dialog.dart` (REQ-55): `NoticeDialog`/`showNoticeDialog`(아이콘·제목·숫자 칸 `NoticeStat`·본문·골드 [확인], 모서리 24, 아래 여백 적게, 글자·바탕은 테마에서 가져와 다크 테마에서도 읽힘), `WarnBadge`, 색 상수 `kGold`·`kGoldText`·`kCarWarn`(여기 한 곳에만 정의, main 이 가져다 씀). 확인 하나짜리 안내 팝업은 모두 이걸로(REQ-59): 지난 문자 불러오기 새 건 0 `importResultDialog`(REQ-61, import_screen. 숫자 칸 없음: 승인 문자 있음 '새로 불러온 문자가 없어요'/'이 기간 카드 승인 문자 n건은\n모두 이미 들어와 있어요.', 승인 문자 0 '이 기간엔 카드 승인 문자가 없어요'/'카드 문자 설정의 카드번호 끝 4자리가\n맞는지 확인해 보세요.' + 작은 [카드 문자 설정] 링크. 제목 길게 누르기(`onTitleLongPress`) → 숨은 진단 `importDiagDialog`: 찾은 카드 승인 문자·그중 발신번호 일치·주소 형식, 전체 개수 없음), 단위 옆 '(반올림)'(제목 `kRoundingTitle`, 본문 `kRoundingNote` 줄 나눔), 붙여넣기·공유·불러오기 결과에서 되살릴 게 없고 '승인 문자 아님'만 있을 때 `ingestResultDialog`(REQ-67 14: 제목 '분류 대기에 n건 넣었어요'/'넣을 승인 문자가 없어요' + 항목별 한 줄, `rejectedList` 원문 펼침, [닫기]). 개인정보처리방침 열기 확인도 이걸로('개인정보처리방침을\n브라우저로 열어요.' [취소][열기], REQ-67 15). 경고가 아닌 안내는 `NoticeInfoIcon`(남색 원 i), 경고만 `WarnBadge`. 숫자 칸 라벨은 한 줄(좁으면 줄여서). `child` 로 본문 아래 내용을 덧붙일 수 있음. 되살리기 버튼이 있는 결과 창(버튼 2개)은 AlertDialog 그대로
- 요약표 단위 선택 (REQ-50, `budget.dart` `MoneyUnit`): 표 위 '단위: 원 ▾' 드롭다운 → 만원 / 천원 / 원, **기본 원**(REQ-52, 저장된 선택이 없을 때 — 고른 적 있으면 그 값. 사전입력사항 1단계 입력칸도 같음), 기기에 저장(`money_unit_v1`, `Store.moneyUnit`). 화면 표시만(`money`/`moneyOrDash`/`remainingIn`), 계산·저장은 원 단위 그대로
  - 표 표시 (REQ-51): 만원 = 만원 단위 반올림 정수 + 쉼표(342,500 → 34, 345,000 → 35, 85,000 → 9, 12,345,000 → 1,235), 천원 = 반올림·정수·쉼표(342,500 → 343), 원 = 쉼표(342,500). '초과 X' 도 같은 규칙. 칸마다 원 단위 값을 반올림하고 칸 합과 합계의 1 차이는 보정하지 않음(45,000·45,000·90,000 → 5 / 5 / 9)
  - 단위 드롭다운 옆 작은 회색 '(반올림)'(만원·천원만, `showsRounding`): 누르면 안내 `kRoundingNote` + [확인]. 합산 화면도 같은 표라 같음
  - 편집 시트 미리 채움은 반올림하지 않은 원래 값(`moneyInputText`: 만원은 `manwon` 끝자리 0 생략 34.25)
  - 적용: 메인 요약표(수립·사용·잔여), 합산 화면, 수립 편집 시트, 사전입력사항 1단계. 입력칸 단위 글자도 맞춤. 입력은 만원 = 소수 둘째 자리까지, 천원·원 = 정수만(쉼표 무시, `parseMoney` → 원). 표 칸은 가운데 정렬 + FittedBox 라 7자리(1,234,560)도 칸 안에
- 화면 문구 정리 (REQ-67 2부): 가맹점 이름은 `merchantText`(layout.dart, 띄어쓰기에서만 줄바꿈·최대 2줄·말줄임, 목록·미분류·상세 시트·분류한 내역 공통). 단위 메뉴 순서 원/천원/만원(enum 순서, 저장은 이름). '(반올림)' 글자 대신 단위 옆 ⓘ(툴팁 `kRoundingTooltip`). 수립 입력 안내 두 줄(helperMaxLines 2). 상세 시트 [미분류로 되돌리기] 한 줄(FittedBox)·[무시]와 같은 높이. 미분류 내역 [무시]는 [차량비][운영비]와 같은 높이·모서리. 사전입력 1단계 아래 '운영비는 전체에서 차량비를 뺀 금액이에요 (n원)', 3단계 마지막 버튼 '완료'·붙여넣기 링크 밑줄+›, '카드번호 끝 4자리'(`kDigitsHelp`)·발신번호 설명 `kSenderHelp`(모르면 기본값). 붙여넣기 안내 `kPasteSteps` 3줄. 퀴즈 피드백 '정답이에요 · X' / '아쉬워요 · 정답은 O'. 분야별 정답률 `categoryScoreRows`(큰 분야 소제목 한 번). 챌린지 '결과 카드에 넣을 이름: 없음 (날짜만 표시)', 분야 묶음 '이 묶음 모두 빼기/넣기'. 실험실 법령 Quiz 는 부제 없이 제목만(2.0.3, 예전 `lawQuizSummary` 삭제, 안전 OX Quiz 부제는 그대로). 화면 '푼 문제'는 `scoredCount`(점수 남은 기록, 정답률과 같은 기준 — 점수 기록 지우기 뒤 0). 결과 카드 제목 글자 간격 0.5·카드 안 상자 280×450. 긴 한글 문장은 `keepWords` 로 감싸는 게 원칙(전역 keep-all 은 Flutter 에 없어 화면마다)
- 스크롤 화면은 edge-to-edge 라 목록 끝 패딩 = `listBottomPad(context)` (`lib/layout.dart`: max(viewPadding.bottom, 48) + 24). 새 스크롤 화면도 반드시 적용
- 긴 한글 설명은 `keepWords()`(`lib/layout.dart`, 글자 사이 WORD JOINER) 로 감싸 단어 중간에서 줄이 안 바뀌게. 테스트에서 찾을 때도 `find.text(keepWords(...))`
- 스낵바는 `appSnackBar()`(`lib/snack.dart`)로만 만든다: 버튼([되돌리기]·[보기])이 있어도 저절로 닫힘(`persist: false`, 최신 Flutter 기본값 대응), 버튼 글자 `kSnackAction`(밝은 노랑, 테마 `snackBarTheme`)
- 백업 (REQ-47, 모든 판): `allowBackup=true` + Android 12+ `res/xml/data_extraction_rules.xml`(`<cloud-backup>` 모든 도메인 제외, `<device-transfer/>` 전부 포함) + Android 11 이하 `res/xml/backup_rules.xml`(전부 제외). 앱을 지웠다 다시 깔면 복원 안 되고, 기기 간 직접 이전(스마트스위치·구글 데이터 복사)만 옮겨진다. 11 이하는 기기 이전도 안 됨
- 리소스 언어: `build.gradle.kts` `androidResources.localeFilters` = ko·en
- 메인 월 이동: 월 진행 표시줄(`_MonthStrip`, 1~12 터치 이동) + ◀ 제목 ▶ (화살표 좌우 끝 고정 48×48, 제목은 FittedBox). 요약표 좌우 스와이프(`_SwipeArea`, 60px 이상 또는 플릭, 가로 > 세로×2) = ◀ ▶, 전환은 `_SlideSwitcher` 200ms 슬라이드
- 메인 '분류 대기' 카드 (2.0.3): 보고 있는 기간 것만(1개월 = 그 달, 합산 = 두 달, `pendingInView` in review_screens). 다른 달 미분류가 있으면 카드 아래(그 기간 대기가 없으면 그 자리)에 작게 '다른 달 미분류 n건 ›' → 미분류 내역 화면. 메뉴 '내역 관리' 배지·미분류 7일 알림은 전체 기준 그대로. 테스트 `test/pending_view_test.dart`
- 메인 틀고정: 월 진행 표시줄·◀ ▶·요약표는 고정, 1px 구분선 아래(권한 배너·분류 대기·확인 필요 줄·내역)만 세로 스크롤. 고정 영역이 화면 절반을 넘으면 전체 스크롤(`_checkFreeze`). 요약표는 가로 드래그 인식기로 먼저 잡아 스와이프 중 세로 흔들림 없음
- 내역 편집 시트에는 [삭제]가 없다 ([무시] 사용). 업체 관리는 섹션별 [전체 삭제](+되돌리기)와 '지운 키워드 (n)'(REQ-47, 예전 [기본 키워드 다시 넣기] 대신)
- `android/.../CardSms.kt` — 알림 리스너·SMS 리시버 공용 처리: 판정(발신번호 일치 또는 카드번호+승인), 중복 방지(금액+일시+취소 키), 네이티브 inbox 적재 (알림은 띄우지 않음). SMS 리시버는 발신번호로 막지 않고 카드번호+승인만 본다(REQ-61)
- 발신번호 비교 `SenderMatch.kt`(순수 Kotlin, 테스트 `SenderMatchTest.kt`) = Dart `normalizeNumber`·`senderMatches`(같은 규칙): 앞뒤 공백 제거, '@'·';' 뒤(RCS sip 도메인·옵션) 잘라냄, 숫자만, 00·82 국가번호와 앞 0 떼고 끝자리 비교(7자리 이상). 실시간 수신·지난 문자 불러오기 공용
- `CardNotificationListener.kt` — 메시지 앱 알림 감지(두 판 공통). 알림 제목 발신번호 또는 본문 카드번호로 판정
- 지난 문자: 두 판 모두 메시지 앱 공유(ACTION_SEND/SEND_MULTIPLE → `takeShared`)·붙여넣기. 전용판은 추가로 SMS+MMS 기간 조회(MMS date 는 초 단위, 발신번호는 addr type=137, 본문은 part ct=text/plain)

앱이 꺼져 있을 때 들어온 문자는 네이티브 inbox 에 쌓였다가 앱이 켜지면 `drainInbox` 로 Dart 저장소로 옮겨진다.
- `lib/quiz.dart` / `lib/quiz_sheet.dart` — 오늘의 안전 OX (메뉴 > 실험실 > 안전 OX Quiz). 문제 풀 = assets `quiz/questions.json`(내장) vs 기기 캐시(원격 raw.githubusercontent 의 main `quiz/questions.json`, version 이 높을 때만, 하루 1회·3초·실패 무시) 중 높은 버전. 첫 프레임 + 300ms 뒤 하루 1회(`quiz_last_day_v1`) 판정: 안전 OX Quiz 화면 '점수 기록 지우기' 위 '매일 OX 퀴즈' 스위치(`quiz_daily_on_v1`, **기본 꺼짐**, v1.20.1 — 예전 `quiz_enabled_v1` 은 읽지 않음)가 켜져 있을 때만. 첫 실행 설정 직후·다른 팝업(업데이트 창 등)이 먼저 뜬 날은 건너뜀, 활성 문항 0개면 안 뜸. 안전 OX Quiz 메뉴의 연습·챌린지는 스위치와 상관없이 항상 쓸 수 있음.
  오늘 이미 푼 문제(모든 출처)는 오늘 다시 안 냄. 셔플백(`quiz_bag_v1`/`quiz_known_v1`, 새 문항은 남은 순서에 섞음). 기록 `quiz_log_v1`(날짜·id·선택·정답 여부·출처 `s`(없으면 오늘의 문제)/`extra`/`challenge`·회차 `r`, 기기에만), 챌린지 회차 `quiz_runs_v1`. 자동 업데이트 창은 퀴즈 시트가 닫힌 뒤에 뜸
- 실험실 > '안전 OX Quiz'(설명 '연속 N일 · 정답률 NN%' / '오늘의 문제를 풀어보세요') → `lib/quiz_screens.dart` 안전 OX 화면 (REQ-47 순서): 요약 카드(푼 문제·정답률·연속) / 매일 OX 퀴즈 스위치 / 챌린지(10·20·30·50, 설명 '10~50문제, 시간과 정답률로 기록에 도전', 활성 문항보다 크면 비활성, 0.6초 표시 후 자동 다음, 최고 기록 = 정답률 → 시간) / 한 문제 더 풀기(오늘 푼 문제 제외, 소진 안내) / 지난 문제 다시 보기 / 점수 기록 지우기
  - 지난 문제 다시 보기: 날짜 구분 안에서 묶음별 — 챌린지 회차 = 트로피 카드(펼치면 문제들이 카드 안, 왼쪽 남색 세로줄 + 연한 배경), '한 문제 더 풀기 · n문제', '매일 퀴즈 · n문제' 소제목 (묶음 순서 = 가장 최근 기록 순). 출처 꼬리표 없음. 문제마다 '내 답 → 정답' 줄 오른쪽 [해설] 버튼 → 바로 아래 말풍선(위쪽 꼬리)에 해설·분야·근거, 다시 누르면 접힘 (문제 아무 데나 눌러 여는 방식은 없앰)
  - 선택 칩(`QuizSelectChip`, `lib/quiz_category_picker.dart`): 분야 칩·[전체]/[틀린 문제만] 공용. 선택 = 네이비(#1F3A68, O/X 버튼 색) 채움 + 흰 글자, 비선택 = 흰 바탕 + 연회색 테두리 + 회색 글자, 체크 아이콘 없음, 두 상태 크기 같음
  - 결과 화면 위쪽 = 결과 카드(`lib/challenge_card.dart` `ChallengeResultCard`, 세로 2:3, 네이비→연한 남색→네이비 테두리, 등급 배지 `quizGrade(topic:)`, 최고 기록이면 빨간 사선 띠, 맨 아래 크레딧 없음. `title`·`subtitle`·`gradeTopic` 으로 안전 OX / 농어촌정비법 챌린지 공용). 공유는 `shareChallengeCard`(두 퀴즈 공용). [결과 이미지 공유] = 카드를 RepaintBoundary pixelRatio 3 PNG → 앱 캐시 임시 파일 → share_plus 이미지 공유(문구 포함) → 임시 파일 삭제. 카드 이름 `quiz_name_v1`(처음 공유 때 물음, 챌린지 시작 화면에서 바꾸기)
  - 카드 상단 이미지는 상수 `kShareCardLogo`(`assets/icon/gonggam_navy_1024.png`, 투명 배경). 다른 로고로 바꿀 때는 상수·pubspec assets 만 바꾼다. 기관 로고는 아직 넣지 않음
  - [문제 전체 보기]·지난 문제의 챌린지 회차 = `RunAnswersList` ([전체] 기본 / [틀린 문제만])
  - 안전 OX 화면 맨 아래 '점수 기록 지우기'(`QuizStore.clearScores`): 확인 팝업(`kClearScoresMessage`: 지워지는 것 / 남는 것) → 지우기 → 5초 [되돌리기](`snapshotScores`/`restoreScores`). 내 답·정답 여부·챌린지 점수·시간 → null(정답률 '-', 최고 기록 없음). 문제 id·날짜·출처·회차(푼 문제 수·지난 문제 목록)·연속·이름은 남김. 이후 새 기록부터 다시 집계
- 연속 일수 = 오늘의 문제를 푼 날이 이어진 일수 (오늘 아직이면 어제까지)
- 실험실 > 법령 Quiz (REQ-47 농어촌정비법, REQ-51 건설기술 진흥법·국가계약법·건축법 추가, `lib/rural_quiz.dart`·`lib/rural_quiz_screens.dart`). 법령 하나 = `LawQuiz(group, keyPrefix, short, icon)`, 화면은 하나를 같이 쓰고 `RuralStore(prefs, law)` 로 나뉨(복붙 없음). 문제는 `RuralBank.load()` 한 파일에서 `only(group)`. 이름은 모두 '<그룹> Quiz'(앱바·실험실), 챌린지 '<그룹> 챌린지', 결과 카드 제목 '<그룹> Quiz'·설명 '<그룹> OX·객관식'·등급 앞말 `short`(정비법/건진법/국계법/건축법).
  - 기록은 법령마다 따로: 키 = '{keyPrefix}_log_v1' 등. 농어촌정비법 keyPrefix 는 'rural' 이라 예전 rural_* 기록이 그대로 읽힘. 나머지 law_ctech / law_contract / law_building. 점수 기록 지우기도 그 법령만
  - 문제 화면 한 줄 (REQ-51, `RuralBasisLine`): 문제 문장 바로 아래·O/X(또는 보기) 위에 event_note 아이콘(14) + '근거 · 개정 시점'(`basisLine`, 13, 보통 굵기, 푸른 회색 #5F6B7A, keepWords, 위 6·아래 16). amended 가 비면 근거만, 둘 다 비면 숨김. 문제 카드·챌린지 진행 화면·지난 문제 다시 보기 각 문항 모두. 해설 아래 '근거:' 줄은 그대로. 안전 OX Quiz 화면은 해당 없음
  - (아래는 REQ-47~50 때 정비법 기준 설명, 네 법령 모두 같다) OX + 객관식(4지선다) 섞어 출제. 화면은 요약(푼 문제·정답률) / 농어촌정비법 챌린지(REQ-48) / 한 문제 더 풀기(분야 선택 `QuizCategoryPicker` 재사용, 오늘 푼 문제 제외) / 지난 문제 다시 보기(날짜 안에서 챌린지 회차 트로피 카드 `RuralRunTile` + '한 문제 더 풀기 · n문제', [전체]/[틀린 문제만], [해설] 말풍선 `QuizExplainBubble`·`quizExplainButtonStyle` 재사용). 매일 퀴즈 없음
  - 챌린지: 안전 OX 챌린지와 같은 구조(분야 선택·10·20·30·50(활성 문항보다 크면 비활성)·0.6초 표시 후 자동 다음·시간·정답률·최고 기록 정답률→시간·결과 카드·[문제 전체 보기]·[다시 도전]·공유). OX·객관식 섞어 출제(`RuralStore.challengeSet`). 결과 카드 제목 '농어촌정비법 챌린지', 위 설명 '농어촌정비법 OX·객관식', 등급 '정비법 …'. 카드 이름은 안전 OX 와 같이 씀(`quiz_name_v1`)
  - 정비법 화면 맨 아래 '점수 기록 지우기'(REQ-50, `RuralStore.clearScores`, 안전 OX 와 같은 동작): 확인 팝업(`kRuralClearScoresMessage`: 지워지는 것 / 남는 것) → 지우기 → 5초 [되돌리기](`snapshotScores`/`restoreScores`). 내 답·정답 여부·챌린지 점수·시간 → null(정답률 '-', 최고 기록 없음). 푼 문제 수·지난 문제 목록은 남김. 정비법 기록만(안전 OX 는 그대로)
  - 기록은 안전 OX 와 따로: `rural_log_v1`(d·q·p(OX 1/0, 객관식 1~4)·ok·t, 챌린지는 s='challenge'·r=회차, 점수를 지우면 p·ok 없음), `rural_runs_v1`(회차), `rural_bag_v1`, `rural_cats_v1`(한 문제 더), `rural_cats_challenge_v1`, `rural_challenge_size_v1`. 안전 OX 정답률·연속·최고 기록에 안 섞임
  - 문제 파일 `quiz/rural_questions.json`(앱 내장만, 원격으로 받지 않음 → 문제를 바꾸면 앱을 다시 빌드해야 반영)
- 메뉴 '업데이트 확인'은 메뉴를 닫지 않음(항목 오른쪽 로딩, 결과는 메뉴 위). 메뉴 맨 아래 크레딧 'Made by wani'(가운데, 12, 검은색(REQ-48), 누르는 반응 없음). 챌린지 결과 카드(공유 이미지)에는 크레딧을 넣지 않는다(REQ-48)

테스트: `test/req69_test.dart`(기간 밖 문자 미리보기·넣기 0, 미리보기=넣는 건수, 자동 1년 불러오기 없음, 네이티브 날짜 없는 저장소 건너뜀), `test/menu_manage_test.dart` 마지막(이번 달 이전 미분류 한꺼번에 무시·취소·되돌리기), `android/app/src/test/.../InboxDateTest.kt`, `test/req67_test.dart`(법령 '개정 없음' 없음·22조의3 해설·도구 규칙, 줄 나열·미리보기 [닫기]·진단, 단위 순서·반올림 문구·가맹점 줄바꿈·법령 부제·분야별 정답률 묶음), `test/req64_test.dart`(Play 응답 → 결과 세 가지·팝업 버튼·깃허브 [내려받기]), `integration_test/update_dialogs_test.dart`(결과 팝업 캡처용, 로컬 flutter drive), `test/req62_test.dart`(두 채널 법령 Quiz 보임·고지 문구·출처 링크·기준일·실험실 고지 위치·기관 이름 없음), `test/req61_test.dart`(발신번호 형식 일치·불일치·네이티브 진단 값, 결과 문구·카드 문자 설정 링크·제목 길게 눌러 진단), `android/app/src/test/.../SenderMatchTest.kt`, `test/req59_test.dart`(여러 저장소에서 겹친 문자 한 번만·미리보기=결과 숫자·이미 있는 건만 중복·무시했던 건, 안내 팝업 3종), `test/req56_test.dart`(데모 데이터 규모·초과 없음·경고 없음), `test/req55_test.dart`(경고 팝업 줄바꿈·단위별 숫자 칸·골드 [확인] 위치·공용 경고 표시 색·다크 테마), `test/req54_test.dart`(보기 기간 저장·복원·앱 시작 화면·연말 짝홀, 3단계 판별 화면·기간 기본값·빠른 선택·미래/역순 막기·권한 거부 대체 안내·미리보기→넣기·0건, 권한 확인 함수, 넣기 공용 함수), `test/req53_test.dart`(데모 데이터 모드·스토어 등록정보 길이·금지어), `test/req52_test.dart`(단위 기본 원·저장값 유지, 차량비 잔여 경고 조건 경계·문구·아이콘 위치·7자리 숫자 안 겹침·칸 탭, 홀짝·짝홀 합산 먼저·연말 묶음·합산 화면 경고), `test/req51_test.dart`(만원 정수·경계·'(반올림)' 안내·편집 시트 원래 값, 법령 4종 문항 수·amended·근거 한 줄 위치·그룹별 기록 분리·정비법 키 호환·실험실 4개(스토어 숨김)), `test/req50_test.dart`(잔여 보정 철회·단위 선택(만원·천원·원 표기·입력 변환·저장)·정비법 점수 기록 지우기), `test/req49_test.dart`(잔여 보정 조건·팝업·숫자 끝자리 0 생략·스토어판 정비법 숨김, 채널별 기대값), `test/req48_test.dart`(사전입력사항 문구·정비법 챌린지·결과 카드 크레딧 없음·키워드 칩 켜기/끄기·길게 눌러 삭제·차량비 잔여 보정), `test/req47_test.dart`(캡처 제거·기간 불러오기·백업 규칙·키워드 정리·칩·지운 키워드·스낵바 자동 닫힘·확인 카드·줄바꿈·첫 실행 사용법·실험실·농어촌정비법 퀴즈), `test/req45_test.dart`(미분류 알림 동기화·스위치·권한·알림 탭, 새 로고), `android/app/src/test/.../ReminderRuleTest.kt`(7일 경계·평일 5시·주말 미룸·재발송 간격), `test/req44_test.dart`(개인정보처리방침 팝업·매일 OX 스위치 위치·점수 기록 지우기 되돌리기·선택 칩 색·지난 문제 묶음·[해설]), `test/req43_test.dart`(스토어 채널 업데이트 없음·권한 안내 화면·개인정보처리방침 메뉴), `test/req39_test.dart`(퀴즈 v2·분야 선택·틀고정·업체 전체 삭제·메뉴 QUIZ 아이콘), `test/quiz_test.dart`(하루 1회·날짜 경계·셔플백·새 문항·active=false·원격 실패/캐시·연속 일수·오늘 푼 문제 제외·챌린지 최고 기록), `test/quiz_screens_test.dart`(챌린지 진행·결과·그만두기, 지난 문제, 한 문제 더), `test/check_test.dart`(확인 필요 규칙 a~e, 중복 쌍 기억), `test/cancel_test.dart`(승인취소 묶음·바로잡기), `test/ignore_vendor_test.dart`(무시 사유·무시한 내역 화면·업체 관리 목록), `test/home_screen_test.dart`(메인 화면 그리기·넘김 위젯 테스트), `test/sms_parser_test.dart`, `test/budget_update_test.dart`, `test/ingest_test.dart`, `test/vendor_test.dart`

## 빌드 / 배포
- `flutter test`, `flutter build apk --release --flavor public` / `--flavor full`, 스토어판은 `flutter build appbundle --release --flavor public|full --dart-define=CHANNEL=store`
- 전체 테스트는 CI 에서 `flutter test --dart-define=CHANNEL=store` 로 한 번 더 돈다 (채널별로 갈리는 테스트는 `isStoreChannel` 로 기대값을 나누거나 skip)
- 서명: 로컬은 `android/key.properties`(커밋 금지), CI 는 GitHub Secrets `ANDROID_KEYSTORE_BASE64/PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
- keystore 원본: `C:\Users\EKR\Documents\card_expense_keystore\` (저장소에 넣지 말 것)
- `.github/workflows/release-apk.yml` (v1.20.1~): **`v*` 태그 push 에서만** 정식 빌드·Release. main push(문서 커밋 포함)로는 CI 가 돌지 않는다. `dev` 프리릴리스는 Actions 탭 수동 실행(workflow_dispatch)일 때만
  - 캐시: Flutter SDK·pub(`flutter-action` cache), Gradle(`gradle/actions/setup-gradle@v4`, `cache-read-only: false`), NDK 28.2(`actions/cache`, `$ANDROID_HOME/ndk/28.2.13676358`). `android/gradle.properties` 에 `org.gradle.caching=true`·`org.gradle.parallel=true`
  - 캐시 범위 주의: GitHub 캐시는 만든 ref 범위다. 태그 실행이 저장한 캐시는 **다른 태그에서는 못 쓰고**, 기본 브랜치(main) 캐시는 모든 태그가 쓴다. Gradle·NDK 캐시를 다음 태그에서 hit 시키려면 main 에서 수동 실행(workflow_dispatch)을 한 번 돌려 main 범위에 저장해야 한다 (dev 프리릴리스도 같이 갱신됨)
  - ABI 는 arm64-v8a·armeabi-v7a 2개(x86_64 없음): CI 의 `--target-platform android-arm,android-arm64`(Flutter 라이브러리) + `android/app/build.gradle.kts` 의 release 변형 `packaging.jniLibs.excludes += lib/x86_64/**`(ML Kit 등 플러그인 .so — `--target-platform` 만으로는 안 빠짐, 빌드타입 `ndk.abiFilters` 도 효과 없었음). debug 는 그대로. fat APK 하나씩, 파일 이름·고정 링크 그대로. split-per-abi 안 함
  - `flutter test`(+스토어 채널 전체) → APK 2개 + AAB 2개 빌드 → 권한 검사(aapt + bundletool 1.17.2: 일반판 APK·AAB 문자 권한 없음, 전용판 있음, 전부 설치 권한 없음, AAB versionCode·targetSdk 로그) → Kotlin 단위 테스트(Kotlin·Gradle 원본 해시가 지난번 통과와 같으면 건너뜀, `actions/cache` 통과 표시) → 업데이트 코드 검사(깃허브 APK 에는 있고 스토어 AAB 에는 없어야 함) → 스모크 테스트(`tools/smoke_test.sh`, API 36 에뮬레이터에 4개 산출물 설치·실행, AAB 는 bundletool 분할 설치, 크래시 없이 30초 생존해야 릴리스). flavor 병렬(matrix)·ML Kit 변경은 하지 않음
  - AAB 도 x86_64 없음(같은 release 변형 설정). targetSdk 는 `flutter.targetSdkVersion`(Flutter 3.44.9 = 36, Play 요구치 충족)
- 새 버전 배포: `pubspec.yaml` version 올리고 main push + `git tag vX.Y.Z && git push origin vX.Y.Z` (태그 push 만 CI 를 돌린다)
- **로컬 작업 루틴 (규칙)**
  - 수정 중에는 바뀐 파일만 `flutter analyze <파일>`, 관련 테스트 파일만 `flutter test <파일>`
  - 전체 analyze·전체 test 는 커밋 직전 1회
  - 흔들림 확인용 반복 실행은 새 위젯 테스트를 추가했을 때만
  - 로컬 APK 빌드는 Kotlin·Gradle·네이티브 플러그인이 바뀐 REQ 에서만. 이때는 빌드만 하지 말고 에뮬레이터에서 **실제로 실행**까지 확인한다 (`ADB=<adb 경로> bash tools/smoke_test.sh <bundletool.jar> <폴더>`. R8 문제는 빌드·권한 검사·단위 테스트로 안 잡힌다)
  - APP_STATUS versionCode 기록은 가능하면 릴리스 커밋에 같이 넣는다 (태그 실행의 run_number = 직전 실행 번호 + 1). 따로 커밋해도 이제 CI 는 돌지 않는다
- 앱이 `releases/latest` 로 업데이트를 확인하므로 저장소는 public 이어야 한다. 실제 카드번호를 코드·문서·커밋에 넣지 말 것 (예시는 0000).

## 퀴즈 문제 관리 (안전 OX Quiz)
- 파일 형식 version 2: `{version, updated, note, groups:[{name, categories}], questions:[{id, group, category, question, answer, explain, basis, active}]}`.
  앱은 version 1(그룹·분야 없음 → '기타')도 읽고 모르는 필드는 무시한다. 원격본이 깨졌거나 활성 문항이 0개면 번들 사본을 쓴다
- 분야 태그 정리(REQ-67 27, version 3): w062→추락·비계, w064→굴착·거푸집, w065→전기작업, w097→양중기·장비, d028·d029→산안관리비, d190~d195→계획서·작업계획서(문제·정답·해설은 그대로). 애매해서 둔 것: w066(교량 작업계획서, 통로·작업장), w089~w091(철골작업, 굴착·거푸집)
- 원본(공개 파일, 개인정보 넣지 말 것): `quiz/source_2차_현장안전기준.xlsx`(그룹 '현장 안전기준', id w…), `quiz/source_3차_서류절차.xlsx`(그룹 '서류·절차', id d…).
  '안내'를 뺀 시트 하나 = 분야 하나(시트 순서 = 표시 순서). 열: 번호, 문제, 정답(O/X), 해설(팝업용), 근거, 법령 원문(대조 구절), 채택(O/X), 수정 메모
- 1) xlsx 에서 '채택(O/X)'을 고르고 문제·해설을 고친다 (채택=X 면 출제 제외)
- 2) `python tools/quiz_export.py` → `quiz/questions.json` 재생성 (openpyxl 필요)
  - id 는 기존 json 에서 같은 문제 문장의 id 를 그대로 쓴다(풀이 기록이 id 로 남음). 새 문제·문장이 바뀐 문제만 다음 번호
  - 문항이 바뀌었으면 version 을 자동으로 +1, updated 는 오늘. 안 바뀌었으면 파일 그대로
- 3) xlsx + json 커밋 → main 에 푸시. 앱 재배포 없이 앱이 원격본(버전이 높으면)을 받아 캐시하고 다음 날부터 반영 (확인은 하루 1회라 최대 하루 늦을 수 있음)
- 앱 빌드 때는 그 시점의 `quiz/questions.json` 이 assets 로 들어가 기본값(번들 사본)이 된다
- 정식 출시 전 미리 써보기: v2.0.0 태그·릴리스·고정 링크는 그대로 두고 Actions 수동 실행(workflow_dispatch, main)으로 `dev` 프리릴리스만 갱신한다 (REQ-47)

## 법령 Quiz 문제 관리 (실험실)
- 문제 원본·법령 원문·검증 도구는 `tools/law_quiz/` (README 참고): questions/(문제 원본) + laws/(조문 단위 법령 원문, 출처 legalize-kr) → `verify.py`(인용 구절이 근거 조문 원문에 그대로 있는지, bad 0 이어야 함) → `amend.py`(개정 시점) → `xl.py`(검토용 엑셀 4개) → 사용자 검토 → quiz/source_*.xlsx 교체 → `tools/rural_quiz_export.py`
- 원칙: 틀린 정보 절대 금지(자동 대조 + 문맥 검토), OX 는 O·X 반반 가깝게, 객관식 정답 위치 1~4 고르게, 공개 법령만
- **'…이후 개정 없음'은 쓰지 않는다**(REQ-67): 원본(legalize-kr)엔 [본조신설]·[전문개정] 같은 조 단위 표시가 빠져 있어, 줄에 개정·신설 날짜가 없으면 '개정 시점'은 빈칸 → 앱은 근거 조문만('법 제22조의3'). amend.py·xl.py·rural_quiz_export.py(원본에 남아 있어도 빈칸) 모두 같은 규칙, `test/req67_test.dart` 가 검사. 정확한 신설·개정일을 국가법령정보센터 연혁으로 채우는 건 별도 과제(private 메모)
- 법령이 개정되면 새 원문으로 laws/ 갱신 → verify 로 깨진 문항 찾기 → 고치거나 빼기 → 엑셀 재생성 → 사용자 검토. 시행령 2027 개정본은 아직 미반영(나오면 시행령 근거 문항 재검토)
- 안전 OX(quiz/questions.json)는 별도 풀, 사용자가 관리
- 원본(공개 파일, 2027 기준, REQ-51): `quiz/source_농어촌정비법_3차_2027.xlsx`(그룹 '농어촌정비법', id r…, 200문항) / `quiz/source_건설기술진흥법_2027.xlsx`('건설기술 진흥법', c…, 92) / `quiz/source_국가계약법_2027.xlsx`('국가계약법', k…, 115) / `quiz/source_건축법_2027.xlsx`('건축법', b…, 127). 예전 `source_농어촌정비법_1차.xlsx` 는 지움. '안내'·'제외 목록'을 뺀 시트 하나 = 분야 하나(시트 순서 = 표시 순서)
  - 열: 번호, 유형(OX/객관식), 문제, 보기1~4, 정답(OX 는 O/X, 객관식은 1~4), 해설, 근거, 개정 시점, 조 개정 이력, 법령 원문(대조 구절), 채택(O/X), 수정 메모. 채택=X 면 출제 제외. '개정 시점' → json `amended`(비면 생략), '조 개정 이력'·법령 원문은 앱에 안 넣음
- `python tools/rural_quiz_export.py` → `quiz/rural_questions.json` (형식 version 1: `{version, updated, groups, questions:[{id, group, category, type:'ox'|'choice', question, choices?, answer(bool 또는 1~4), explain, basis, amended?, active}]}`). 네 법령이 한 파일
  - id 유지·version +1 규칙은 안전 OX 와 같다 (`quiz_export.keep_ids` 재사용)
- **안전 OX 의 `quiz/questions.json` 과 섞지 말 것.** 배포된 옛 앱이 원격으로 받는 파일이라 형식·내용을 바꾸면 안 된다 (객관식 넣지 않음)
- 앱에 내장만 하고 원격으로 받지 않는다 → 문제를 바꾸면 앱을 다시 빌드해야 반영

## 버전 규칙 (고정)
- 1.x 는 v1.20.1 로 끝났다. v2.0.0(REQ-43, 스토어 첫 등록본)부터 아래 2.x 엄격 규칙을 적용한다. 깃허브 APK 도 같은 태그라 같은 versionName 이다.
- **플레이스토어 정식 출시(프로덕션 게시) 전까지 versionName 은 2.0.0 고정** (REQ-44). 이 기간의 수정은 새 커밋에 같은 `v2.0.0` 태그를 다시 달아 재빌드한다: 커밋·푸시 → `gh release delete v2.0.0 --yes`(태그를 먼저 지우면 릴리스가 draft 로 바뀌어 고정 링크가 끊기므로 릴리스부터) → `git tag -d v2.0.0 && git push origin :refs/tags/v2.0.0` → `git tag v2.0.0 && git push origin v2.0.0`. 워크플로도 같은 이름 릴리스가 남아 있으면 지우고 새로 만든다 (`--latest`, 고정 링크가 새 빌드). versionCode 는 run_number×10 + 0/1/2 로 계속 커진다 (절대 낮추지 않음). 정식 출시 이후부터 아래 2.x 엄격 규칙.
- **2.0.0 은 2026-11-19 스토어 정식 출시됐다. 이제 versionName 을 올린다: 정식 출시 후 패치는 2.0.x(다음은 2.0.1)**, 같은 태그를 다시 다는 재빌드는 더 하지 않는다(v2.0.0 태그·릴리스는 그대로 둠). 새 버전 = pubspec version 올리고 새 태그.
- 스토어 등록 최종본은 v2.0.0. 정식 출시 후 2.x 부터 엄격 적용: 새 기능 덩어리(예: OX 퀴즈 처음 추가)는 Y(마이너), 그 밖의 화면 다듬기·버튼·문구·버그 수정·퀴즈 파일 변경은 Z(패치). 어느 쪽인지는 REQ 끝에 명시된다.
- versionCode = GitHub Actions `run_number`×10 + (깃허브 APK 0, 스토어 일반 AAB 1, 스토어 전용 AAB 2) (v2.0.0~. 그 전은 `run_number` 그대로라 값이 커지기만 했다). 절대 줄이지 않는다 (스토어와 기존 설치 앱의 덮어쓰기 업데이트 모두 versionCode 가 더 커야 함). pubspec 의 `+N` 은 로컬 빌드용일 뿐 배포 값이 아니다.
- 버전을 낮추거나 1.0.0 으로 되돌리지 않는다 (앱 안 업데이트 확인이 v 태그를 숫자로 비교하므로 낮은 버전은 업데이트로 인식되지 않음).

## 설치 방식 (고정)
- 폰 설치는 항상 GitHub Release 링크로만 한다 (스토어판은 Play Console 테스트 트랙). adb/USB 설치는 제안하지도 말 것.
- 일반판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-release.apk`
- 전용판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-full-release.apk`

## 대기 중인 작업
`NEXT.md`에 다음 요청 때 같이 처리할 일이 쌓여 있다. 새 요청을 받으면 NEXT.md 항목도 함께 처리하고, 끝난 항목은 지운다.
