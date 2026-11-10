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
- Dart 는 `lib/flavor.dart` 의 `isFullEdition`(`appFlavor == 'full'`)으로 전용판 메뉴('지난 문자 불러오기')·문자 권한 배너를 나눈다. "일반판/전용판" 표시는 메뉴 > 업데이트 확인(스토어판은 '버전 정보') 설명. 제작자 표시는 메뉴 맨 아래 'Made by wani'.

## 두 채널 (v2.0.0~, REQ-43): 깃허브(APK) / 스토어(AAB)
| 채널 | 빌드 | 파일 | versionCode | 자체 업데이트 |
|---|---|---|---|---|
| 깃허브 | `flutter build apk --flavor public/full` | `app-release.apk` / `app-full-release.apk` (고정 링크) | run_number×10 **+0** | 있음 |
| 스토어 일반 | `flutter build appbundle --flavor public --dart-define=CHANNEL=store` | `app-store-public-release.aab` (비공개 테스트 트랙) | run_number×10 **+1** | 없음 |
| 스토어 전용 | `flutter build appbundle --flavor full --dart-define=CHANNEL=store` | `app-store-full-release.aab` (내부 테스트·문자 권한 심사) | run_number×10 **+2** | 없음 |

- 채널은 flavor 차원이 아니라 `--dart-define=CHANNEL=store` 로 나눈다 (`lib/flavor.dart` `isStoreChannel`, 컴파일 시점 상수). 이유: 두 채널은 매니페스트·네이티브 차이가 없고(설치 권한은 원래 없음), Dart 상수라 스토어 빌드에서 업데이트 코드(`update_check.dart`, `_checkUpdate`)가 트리셰이킹으로 통째로 빠진다. flavor 를 늘리면 변형 4개·APK 파일명·`appFlavor` 값이 모두 바뀐다. define 이 없으면 깃허브판.
- 스토어판: 시작 때 자동 업데이트 확인 안 함, 메뉴 '업데이트 확인' 대신 누를 수 없는 '버전 정보'(`MenuScreen.onUpdate == null`). CI 가 스토어 AAB 의 libapp.so 에 GitHub releases API 주소가 있으면 실패시킨다.
- 같은 태그 빌드에서 APK 2개 + AAB 2개를 만들어 같은 GitHub 릴리스에 첨부. AAB 도 같은 키스토어로 서명(Play App Signing 에 이 키를 앱 서명 키로 등록 → `scripts/export_play_key.md`).
- 어느 판에도 REQUEST_INSTALL_PACKAGES 같은 설치 권한을 넣지 않는다 (CI 검사).
- 권한 안내(Prominent Disclosure, `lib/disclosure.dart`): 문자 권한 시스템 창·알림 접근 설정 화면으로 보내기 전에 매번 전체 화면 안내 → [동의하고 계속]일 때만 요청, [나중에]면 아무것도 안 함. 문자 권한 요청은 `requestSmsWithDisclosure`, 알림 접근은 `openNotificationAccessWithDisclosure` 로만 부른다 (`Native.requestSmsPermission`/`openNotificationAccessSettings` 직접 호출 금지). 문자 안내 문구는 REQ-43 지정 문구 그대로.
- 메뉴 '개인정보처리방침'(모든 판) → 확인 팝업 "개인정보처리방침 페이지(GitHub)를 인터넷 브라우저로 엽니다." [열기]/[취소] → [열기]만 `kPrivacyUrl`(main 의 `PRIVACY.md`) 브라우저로 (스토어 출시 후에도 유지). PRIVACY.md 는 코드와 사실이 맞아야 한다 (기능이 바뀌면 같이 고칠 것).

## 구조
- `lib/sms_parser.dart` — `parseSms()` 문자 파싱 (카드번호+승인 판정, 한 줄 형식, 승인취소, 연도 추정), `splitMessages()` 여러 건 쪼개기([Web발신]·카드번호+승인 단위), `senderMatches()` 발신번호 끝자리 비교
- `lib/expense.dart` — 내역 모델, shared_preferences 저장(`Store`, 권한 '앱에서 사용' 스위치 `use_listener_v1`/`use_sms_v1` 포함). 정산 복사 기능은 v1.14 에서 삭제
- `lib/budget.dart` — 월별 수립(원 단위 저장, 화면은 만원), 운영비 수립 = 합계 − 차량비, 잔여(수립 − 사용, 마이너스면 '초과 X.XX'), 합계·차량비 3단계(여유 <80% / 주의 80~100% / 초과), 운영비 잔여는 빈칸(보조 문구 없음), 보기 기간(1개월·홀짝·짝홀, 저장 안 함). 홀짝·짝홀은 ◀ ▶가 [첫째 달]→[둘째 달]→[두 달 합산] 순서(`PeriodView`, `stepView`), 합산 화면은 두 달 표·내역(달 구분선), 수립 편집 불가, 직전 달 수립 이월
- `lib/update_check.dart` — GitHub `releases/latest` 조회, 버전 비교, 판별 APK 링크
- `lib/paste_screen.dart` — 문자 붙여넣기(클립보드 미리보기, 여러 건, 새/중복 건수 확인)
- 입력 방법: 붙여넣기, 공유하기, 알림 감지, (전용판) 문자 실시간 수신·지난 문자 불러오기. **문자 캡처(OCR)는 v2.0.0(REQ-47)에서 완전히 뺐다** (ML Kit·image_picker·ImageSlicer 없음)
- `lib/ingest.dart` — 들어온 문자 분류: 새 내역 / 진짜 중복(분류·대기 중) / 무시했던 문자(되살리기 가능) / 승인 문자 아님. 붙여넣기·공유·불러오기 공통
- (전용판) 지난 문자 불러오기(`lib/import_screen.dart` `ImportRangeScreen`): 시작일·종료일 달력(미래·시작>종료 막음, 1년보다 이른 시작 허용, 기본 1년 전~오늘) + 빠른 선택 [이번 달][지난달][최근 3개월][최근 1년] → [이 기간 문자 확인] 미리보기 '이 기간 승인 문자 n건 (새 n · 중복 n)' → [불러오기]. 네이티브 `readSmsInbox(from, to)` = [시작일 0시, 종료일 다음 날 0시). SMS/MMS 에 더해 삼성 RCS 후보 저장소(`Flavor.kt` `OTHER_STORES`, `scanOther`)도 같은 기간. 문자 권한을 처음 허용하면 최근 1년을 미리보기 없이 한 번 자동으로(`_maybeAutoImport`). 예전 '문자 저장소 진단' 화면은 v1.7.0 에서 삭제
- 무시한 내역은 지우지 않고 보관 (`lib/ignored_screen.dart`, 메뉴 > 내역 관리 > 무시한 내역). 분류·무시하면 메인에 5초 [되돌리기]
  - 무시 사유 `Expense.ignoreReason`: 직접 무시(`kIgnoreManual`, 필드 없는 예전 데이터 포함) / 중복(`kIgnoreDuplicate`, 원본 id 는 `dupOf`). 무시를 풀면 사유도 지움 (`_setCategory`)
  - 무시한 내역 화면은 사유별 묶음. 중복 건은 '중복이라 무시함 · 원본 MM.dd HH:mm (분류)' + [중복 아님 · 되살리기]만 (되살리면 그 쌍을 check_ok 에 기억)
- 메뉴 > 내역 관리: 미분류 내역(모든 달 대기 건, `UnclassifiedScreen`) / 확인 필요 내역(`CheckScreen`) / 무시한 내역 / 확인한 내역(`ConfirmedScreen`, 분류된 전체·검색·칩·월별 합계, 누르면 메인 편집 시트). 건수 배지: 미분류·확인 필요(와 내역 관리 합계)는 1 이상 빨강, 무시·확인한은 검정, 0 은 회색
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
  - 지운 키워드: 기본은 `removedDefaults`(키), 직접 등록은 `removedCustom`(분류와 함께), [영구 삭제]는 `purged`(목록에서만 숨김, 기본은 계속 안 되살림). `removedKeywords`/`restoreRemoved`/`purgeRemoved`/`addKeyword`
  - 분류 대기에서 차량비/운영비를 고르면 같은 가맹점의 다른 대기 건 일괄 정리를 묻고(무시한 건은 제외. 무시한 내역에서 고를 때는 '직접 무시' 건도 포함, '중복'·'취소로 상쇄'는 제외 — `sameVendorPending(includeIgnored:)`), 그 가맹점을 자동 등록. [되돌리기] 한 번에 일괄 정리·자동 등록까지 전부 복구
  - 추천 버튼은 진하게 + 작은 표시('추천' / '지난번 운영비'), 반대 버튼은 투명도 40%
- `lib/menu_screen.dart` — 우측 상단 톱니 → 메뉴 화면. 섹션 제목 없이 한 목록 9개(접힌 상태 한 화면, 이 순서 고정): 결제내역 입력(펼침: (전용판) 지난 문자 불러오기·문자 붙여넣기) / 내역 관리(펼침, 배지 = 미분류+확인 필요, 확인 필요 있으면 펼친 채 시작) / 등록 업체·추천 키워드 / 카드 문자 설정(카드번호·발신번호 같이 수정, [기본값으로]) / 권한 설정 / 사용법 / 실험실 / 개인정보처리방침(확인 팝업) / 업데이트 확인(현재 버전·판, 스토어판은 '버전 정보') + 맨 아래 크레딧. '설정' 항목은 REQ-44 에서, 메뉴 최상위 '안전 OX Quiz'는 REQ-47 에서 없앰(실험실 안으로)
- `lib/lab_screen.dart` — 메뉴 > 실험실: 안전 OX Quiz(설명 '연속 N일 · 정답률 NN%') / 농어촌정비법 퀴즈. 동작은 예전 그대로
- `lib/onboarding_screen.dart` — 사용법 3단계(넘기기·건너뛰기): ① 이번 달 전체·차량비 수립(만원) ② 카드번호 네자리·발신번호 ③ 지난 결제(전용판 [지난 문자 불러오기], 일반판·스토어판 붙여넣기·공유하기 안내 + [지금 문자 붙여넣기]). 첫 실행(카드 설정 없음)에서만 자동으로 뜨고 예전 첫 실행 카드 문자 설정 화면을 대신한다(두 번 안 물음, ②는 건너뛸 수 없음). 업데이트로 들어온 기존 사용자에겐 안 뜸. 메뉴 > 사용법에서 다시 보기(지금 값이 들어 있고 바꾸면 바로 반영). ③ 버튼은 `OnboardingAction` → 메인이 이어서 실행
- `lib/vendor_screen.dart` — 메뉴 > 업체 관리: 추천 키워드는 차량비/운영비 묶음 안 칩(`KeywordChip`, 직접 등록 = 분류 색 채움, 기본 = 흰 바탕 + 분류 색 테두리). 칩을 누르면 바텀시트(분류 변경 [저장] / [삭제] → 확인 + 5초 되돌리기). 묶음 아래 '지운 키워드 (n)'(0개면 숨김) → `RemovedKeywordsScreen`: 체크한 것만 [다시 넣기], [모두 선택], [영구 삭제](확인). 자동 등록 업체는 한 줄씩. 섹션별 [전체 삭제](+되돌리기)
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
- 스크롤 화면은 edge-to-edge 라 목록 끝 패딩 = `listBottomPad(context)` (`lib/layout.dart`: max(viewPadding.bottom, 48) + 24). 새 스크롤 화면도 반드시 적용
- 긴 한글 설명은 `keepWords()`(`lib/layout.dart`, 글자 사이 WORD JOINER) 로 감싸 단어 중간에서 줄이 안 바뀌게. 테스트에서 찾을 때도 `find.text(keepWords(...))`
- 스낵바는 `appSnackBar()`(`lib/snack.dart`)로만 만든다: 버튼([되돌리기]·[보기])이 있어도 저절로 닫힘(`persist: false`, 최신 Flutter 기본값 대응), 버튼 글자 `kSnackAction`(밝은 노랑, 테마 `snackBarTheme`)
- 백업 (REQ-47, 모든 판): `allowBackup=true` + Android 12+ `res/xml/data_extraction_rules.xml`(`<cloud-backup>` 모든 도메인 제외, `<device-transfer/>` 전부 포함) + Android 11 이하 `res/xml/backup_rules.xml`(전부 제외). 앱을 지웠다 다시 깔면 복원 안 되고, 기기 간 직접 이전(스마트스위치·구글 데이터 복사)만 옮겨진다. 11 이하는 기기 이전도 안 됨
- 리소스 언어: `build.gradle.kts` `androidResources.localeFilters` = ko·en
- 메인 월 이동: 월 진행 표시줄(`_MonthStrip`, 1~12 터치 이동) + ◀ 제목 ▶ (화살표 좌우 끝 고정 48×48, 제목은 FittedBox). 요약표 좌우 스와이프(`_SwipeArea`, 60px 이상 또는 플릭, 가로 > 세로×2) = ◀ ▶, 전환은 `_SlideSwitcher` 200ms 슬라이드
- 메인 틀고정: 월 진행 표시줄·◀ ▶·요약표는 고정, 1px 구분선 아래(권한 배너·분류 대기·확인 필요 줄·내역)만 세로 스크롤. 고정 영역이 화면 절반을 넘으면 전체 스크롤(`_checkFreeze`). 요약표는 가로 드래그 인식기로 먼저 잡아 스와이프 중 세로 흔들림 없음
- 내역 편집 시트에는 [삭제]가 없다 ([무시] 사용). 업체 관리는 섹션별 [전체 삭제](+되돌리기)와 [기본 키워드 다시 넣기]
- `android/.../CardSms.kt` — 알림 리스너·SMS 리시버 공용 처리: 판정, 중복 방지(금액+일시+취소 키), 네이티브 inbox 적재 (알림은 띄우지 않음)
- `CardNotificationListener.kt` — 메시지 앱 알림 감지(두 판 공통). 알림 제목 발신번호 또는 본문 카드번호로 판정
- 지난 문자: 두 판 모두 메시지 앱 공유(ACTION_SEND/SEND_MULTIPLE → `takeShared`)·붙여넣기. 전용판은 추가로 SMS+MMS 기간 조회(MMS date 는 초 단위, 발신번호는 addr type=137, 본문은 part ct=text/plain)

앱이 꺼져 있을 때 들어온 문자는 네이티브 inbox 에 쌓였다가 앱이 켜지면 `drainInbox` 로 Dart 저장소로 옮겨진다.
- `lib/quiz.dart` / `lib/quiz_sheet.dart` — 오늘의 안전 OX (메뉴 > 실험실 > 안전 OX Quiz). 문제 풀 = assets `quiz/questions.json`(내장) vs 기기 캐시(원격 raw.githubusercontent 의 main `quiz/questions.json`, version 이 높을 때만, 하루 1회·3초·실패 무시) 중 높은 버전. 첫 프레임 + 300ms 뒤 하루 1회(`quiz_last_day_v1`) 판정: 안전 OX Quiz 화면 '점수 기록 지우기' 위 '매일 OX 퀴즈' 스위치(`quiz_daily_on_v1`, **기본 꺼짐**, v1.20.1 — 예전 `quiz_enabled_v1` 은 읽지 않음)가 켜져 있을 때만. 첫 실행 설정 직후·다른 팝업(업데이트 창 등)이 먼저 뜬 날은 건너뜀, 활성 문항 0개면 안 뜸. 안전 OX Quiz 메뉴의 연습·챌린지는 스위치와 상관없이 항상 쓸 수 있음.
  오늘 이미 푼 문제(모든 출처)는 오늘 다시 안 냄. 셔플백(`quiz_bag_v1`/`quiz_known_v1`, 새 문항은 남은 순서에 섞음). 기록 `quiz_log_v1`(날짜·id·선택·정답 여부·출처 `s`(없으면 오늘의 문제)/`extra`/`challenge`·회차 `r`, 기기에만), 챌린지 회차 `quiz_runs_v1`. 자동 업데이트 창은 퀴즈 시트가 닫힌 뒤에 뜸
- 실험실 > '안전 OX Quiz'(설명 '연속 N일 · 정답률 NN%' / '오늘의 문제를 풀어보세요') → `lib/quiz_screens.dart` 안전 OX 화면 (REQ-47 순서): 요약 카드(푼 문제·정답률·연속) / 매일 OX 퀴즈 스위치 / 챌린지(10·20·30·50, 설명 '10~50문제, 시간과 정답률로 기록에 도전', 활성 문항보다 크면 비활성, 0.6초 표시 후 자동 다음, 최고 기록 = 정답률 → 시간) / 한 문제 더 풀기(오늘 푼 문제 제외, 소진 안내) / 지난 문제 다시 보기 / 점수 기록 지우기
  - 지난 문제 다시 보기: 날짜 구분 안에서 묶음별 — 챌린지 회차 = 트로피 카드(펼치면 문제들이 카드 안, 왼쪽 남색 세로줄 + 연한 배경), '한 문제 더 풀기 · n문제', '매일 퀴즈 · n문제' 소제목 (묶음 순서 = 가장 최근 기록 순). 출처 꼬리표 없음. 문제마다 '내 답 → 정답' 줄 오른쪽 [해설] 버튼 → 바로 아래 말풍선(위쪽 꼬리)에 해설·분야·근거, 다시 누르면 접힘 (문제 아무 데나 눌러 여는 방식은 없앰)
  - 선택 칩(`QuizSelectChip`, `lib/quiz_category_picker.dart`): 분야 칩·[전체]/[틀린 문제만] 공용. 선택 = 네이비(#1F3A68, O/X 버튼 색) 채움 + 흰 글자, 비선택 = 흰 바탕 + 연회색 테두리 + 회색 글자, 체크 아이콘 없음, 두 상태 크기 같음
  - 결과 화면 위쪽 = 결과 카드(`lib/challenge_card.dart` `ChallengeResultCard`, 세로 2:3, 네이비→연한 남색→네이비 테두리, 등급 배지 `quizGrade`, 최고 기록이면 빨간 사선 띠). [결과 이미지 공유] = 카드를 RepaintBoundary pixelRatio 3 PNG → 앱 캐시 임시 파일 → share_plus 이미지 공유(문구 포함) → 임시 파일 삭제. 카드 이름 `quiz_name_v1`(처음 공유 때 물음, 챌린지 시작 화면에서 바꾸기)
  - 카드 상단 이미지는 상수 `kShareCardLogo`(`assets/icon/gonggam_navy_1024.png`, 투명 배경). 다른 로고로 바꿀 때는 상수·pubspec assets 만 바꾼다. 기관 로고는 아직 넣지 않음
  - [문제 전체 보기]·지난 문제의 챌린지 회차 = `RunAnswersList` ([전체] 기본 / [틀린 문제만])
  - 안전 OX 화면 맨 아래 '점수 기록 지우기'(`QuizStore.clearScores`): 확인 팝업(`kClearScoresMessage`: 지워지는 것 / 남는 것) → 지우기 → 5초 [되돌리기](`snapshotScores`/`restoreScores`). 내 답·정답 여부·챌린지 점수·시간 → null(정답률 '-', 최고 기록 없음). 문제 id·날짜·출처·회차(푼 문제 수·지난 문제 목록)·연속·이름은 남김. 이후 새 기록부터 다시 집계
- 연속 일수 = 오늘의 문제를 푼 날이 이어진 일수 (오늘 아직이면 어제까지)
- 실험실 > 농어촌정비법 퀴즈 (REQ-47, `lib/rural_quiz.dart`·`lib/rural_quiz_screens.dart`): OX + 객관식(4지선다) 섞어 출제. 화면은 요약(푼 문제·정답률) / 한 문제 더 풀기(분야 선택 `QuizCategoryPicker` 재사용, 오늘 푼 문제 제외) / 지난 문제 다시 보기([전체]/[틀린 문제만], [해설] 말풍선 `QuizExplainBubble`·`quizExplainButtonStyle` 재사용). 챌린지·매일 퀴즈 없음
  - 기록은 안전 OX 와 따로: `rural_log_v1`(d·q·p(OX 1/0, 객관식 1~4)·ok·t), `rural_bag_v1`, `rural_cats_v1`. 안전 OX 정답률·연속에 안 섞임
  - 문제 파일 `quiz/rural_questions.json`(앱 내장만, 원격으로 받지 않음 → 문제를 바꾸면 앱을 다시 빌드해야 반영)
- 메뉴 '업데이트 확인'은 메뉴를 닫지 않음(항목 오른쪽 로딩, 결과는 메뉴 위). 메뉴 맨 아래 크레딧 'Made by wani'(가운데, 12, #9AA0A6, 누르는 반응 없음)

테스트: `test/req47_test.dart`(캡처 제거·기간 불러오기·백업 규칙·키워드 정리·칩·지운 키워드·스낵바 자동 닫힘·확인 카드·줄바꿈·첫 실행 사용법·실험실·농어촌정비법 퀴즈), `test/req45_test.dart`(미분류 알림 동기화·스위치·권한·알림 탭, 새 로고), `android/app/src/test/.../ReminderRuleTest.kt`(7일 경계·평일 5시·주말 미룸·재발송 간격), `test/req44_test.dart`(개인정보처리방침 팝업·매일 OX 스위치 위치·점수 기록 지우기 되돌리기·선택 칩 색·지난 문제 묶음·[해설]), `test/req43_test.dart`(스토어 채널 업데이트 없음·권한 안내 화면·개인정보처리방침 메뉴), `test/req39_test.dart`(퀴즈 v2·분야 선택·틀고정·업체 전체 삭제·메뉴 QUIZ 아이콘), `test/quiz_test.dart`(하루 1회·날짜 경계·셔플백·새 문항·active=false·원격 실패/캐시·연속 일수·오늘 푼 문제 제외·챌린지 최고 기록), `test/quiz_screens_test.dart`(챌린지 진행·결과·그만두기, 지난 문제, 한 문제 더), `test/check_test.dart`(확인 필요 규칙 a~e, 중복 쌍 기억), `test/cancel_test.dart`(승인취소 묶음·바로잡기), `test/ignore_vendor_test.dart`(무시 사유·무시한 내역 화면·업체 관리 목록), `test/home_screen_test.dart`(메인 화면 그리기·넘김 위젯 테스트), `test/sms_parser_test.dart`, `test/budget_update_test.dart`, `test/ingest_test.dart`, `test/vendor_test.dart`

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
- 원본(공개 파일, 개인정보 넣지 말 것): `quiz/source_2차_현장안전기준.xlsx`(그룹 '현장 안전기준', id w…), `quiz/source_3차_서류절차.xlsx`(그룹 '서류·절차', id d…).
  '안내'를 뺀 시트 하나 = 분야 하나(시트 순서 = 표시 순서). 열: 번호, 문제, 정답(O/X), 해설(팝업용), 근거, 법령 원문(대조 구절), 채택(O/X), 수정 메모
- 1) xlsx 에서 '채택(O/X)'을 고르고 문제·해설을 고친다 (채택=X 면 출제 제외)
- 2) `python tools/quiz_export.py` → `quiz/questions.json` 재생성 (openpyxl 필요)
  - id 는 기존 json 에서 같은 문제 문장의 id 를 그대로 쓴다(풀이 기록이 id 로 남음). 새 문제·문장이 바뀐 문제만 다음 번호
  - 문항이 바뀌었으면 version 을 자동으로 +1, updated 는 오늘. 안 바뀌었으면 파일 그대로
- 3) xlsx + json 커밋 → main 에 푸시. 앱 재배포 없이 앱이 원격본(버전이 높으면)을 받아 캐시하고 다음 날부터 반영 (확인은 하루 1회라 최대 하루 늦을 수 있음)
- 앱 빌드 때는 그 시점의 `quiz/questions.json` 이 assets 로 들어가 기본값(번들 사본)이 된다
- 정식 출시 전 미리 써보기: v2.0.0 태그·릴리스·고정 링크는 그대로 두고 Actions 수동 실행(workflow_dispatch, main)으로 `dev` 프리릴리스만 갱신한다 (REQ-47)

## 농어촌정비법 퀴즈 문제 관리 (실험실)
- 원본(공개 파일): `quiz/source_농어촌정비법_1차.xlsx` (그룹 '농어촌정비법', id r…). '안내'·'제외 목록'을 뺀 시트 하나 = 분야 하나(시트 순서 = 표시 순서)
  - 열: 번호, 유형(OX/객관식), 문제, 보기1~4, 정답(OX 는 O/X, 객관식은 1~4), 해설, 근거, 법령 원문(대조 구절), 채택(O/X), 수정 메모. 채택=X 면 출제 제외
- `python tools/rural_quiz_export.py` → `quiz/rural_questions.json` (형식 version 1: `{version, updated, groups, questions:[{id, group, category, type:'ox'|'choice', question, choices?, answer(bool 또는 1~4), explain, basis, active}]}`)
  - id 유지·version +1 규칙은 안전 OX 와 같다 (`quiz_export.keep_ids` 재사용)
- **안전 OX 의 `quiz/questions.json` 과 섞지 말 것.** 배포된 옛 앱이 원격으로 받는 파일이라 형식·내용을 바꾸면 안 된다 (객관식 넣지 않음)
- 앱에 내장만 하고 원격으로 받지 않는다 → 문제를 바꾸면 앱을 다시 빌드해야 반영

## 버전 규칙 (고정)
- 1.x 는 v1.20.1 로 끝났다. v2.0.0(REQ-43, 스토어 첫 등록본)부터 아래 2.x 엄격 규칙을 적용한다. 깃허브 APK 도 같은 태그라 같은 versionName 이다.
- **플레이스토어 정식 출시(프로덕션 게시) 전까지 versionName 은 2.0.0 고정** (REQ-44). 이 기간의 수정은 새 커밋에 같은 `v2.0.0` 태그를 다시 달아 재빌드한다: 커밋·푸시 → `gh release delete v2.0.0 --yes`(태그를 먼저 지우면 릴리스가 draft 로 바뀌어 고정 링크가 끊기므로 릴리스부터) → `git tag -d v2.0.0 && git push origin :refs/tags/v2.0.0` → `git tag v2.0.0 && git push origin v2.0.0`. 워크플로도 같은 이름 릴리스가 남아 있으면 지우고 새로 만든다 (`--latest`, 고정 링크가 새 빌드). versionCode 는 run_number×10 + 0/1/2 로 계속 커진다 (절대 낮추지 않음). 정식 출시 이후부터 아래 2.x 엄격 규칙.
- 스토어 등록 최종본은 v2.0.0. 정식 출시 후 2.x 부터 엄격 적용: 새 기능 덩어리(예: OX 퀴즈 처음 추가)는 Y(마이너), 그 밖의 화면 다듬기·버튼·문구·버그 수정·퀴즈 파일 변경은 Z(패치). 어느 쪽인지는 REQ 끝에 명시된다.
- versionCode = GitHub Actions `run_number`×10 + (깃허브 APK 0, 스토어 일반 AAB 1, 스토어 전용 AAB 2) (v2.0.0~. 그 전은 `run_number` 그대로라 값이 커지기만 했다). 절대 줄이지 않는다 (스토어와 기존 설치 앱의 덮어쓰기 업데이트 모두 versionCode 가 더 커야 함). pubspec 의 `+N` 은 로컬 빌드용일 뿐 배포 값이 아니다.
- 버전을 낮추거나 1.0.0 으로 되돌리지 않는다 (앱 안 업데이트 확인이 v 태그를 숫자로 비교하므로 낮은 버전은 업데이트로 인식되지 않음).

## 설치 방식 (고정)
- 폰 설치는 항상 GitHub Release 링크로만 한다 (스토어판은 Play Console 테스트 트랙). adb/USB 설치는 제안하지도 말 것.
- 일반판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-release.apk`
- 전용판: `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-full-release.apk`

## 대기 중인 작업
`NEXT.md`에 다음 요청 때 같이 처리할 일이 쌓여 있다. 새 요청을 받으면 NEXT.md 항목도 함께 처리하고, 끝난 항목은 지운다.
