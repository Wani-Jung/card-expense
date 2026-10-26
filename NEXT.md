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
    - [업데이트]: url_launcher로 브라우저에서 판별 링크 열기
      - public → `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-release.apk`
      - full   → `https://github.com/Wani-Jung/card-expense/releases/latest/download/app-full-release.apk`
    - [나중에]: 그 버전은 다시 안 띄우기
  - 메뉴에 '업데이트 확인' 추가 (수동, 최신이면 "최신 버전이에요")
  - 인터넷 없음·조회 실패는 조용히 넘어가기 (에러 창 금지)
  - dev 프리릴리스는 무시, 정식 v* 릴리스만 기준
  - 릴리스 빌드용 AndroidManifest에 INTERNET 권한 추가
  - 버전 비교 로직 단위 테스트 추가
  - 주의: `releases/latest` API·다운로드 링크는 저장소가 public 이어야 로그인 없이 동작
- [ ] 빌드 2종 분리 (Android product flavor)
  - `public`(일반판, 남들 배포용): 지금 그대로. 문자 권한 없음, 알림 감지 + 붙여넣기/공유만
  - `full`(내 전용판): public 기능 전부 + 문자 권한(RECEIVE_SMS, READ_SMS)
    - 권한·SmsReceiver 는 `android/app/src/full/AndroidManifest.xml` 에만 → public APK 엔 절대 안 들어가게
    - Dart 는 `appFlavor`(services.dart)로 구분해 full 일 때만 관련 메뉴/화면 노출
  - 두 판 모두 같은 applicationId·같은 서명키 → public 위에 full 덮어 설치해도 데이터 유지
  - 설정/정보 화면에 "일반판"/"전용판" 표시
  - 워크플로: 두 APK 모두 빌드해 Release 에 첨부 — public → `app-release.apk`(기존 링크 유지), full → `app-full-release.apk`
  - CLAUDE.md 에 두 판 구조와 "public 에는 문자 권한 절대 금지" 규칙 기록
  - 참고: v1.1.0 코드(git 히스토리, 태그 v1.1.0)에 SmsReceiver·SMS/MMS 조회 구현이 있음
- [ ] (full 전용) 지난 문자 1년치 불러오기
  - 기간 365일. SMS(`content://sms`)와 MMS(`content://mms`) 둘 다 — [Web발신] 장문은 MMS 로 저장됨
    - MMS date 는 초 단위(×1000), 발신번호는 `content://mms/{id}/addr` 의 type=137,
      본문은 `content://mms/part` 의 mid={id}, ct=text/plain (text 가 null 이면 part 스트림 읽기)
  - 판정: 설정된 발신번호 일치(senderMatches) + 카드번호+승인 + 금액 파싱
  - 문자 권한 처음 허용 시 1회 자동 실행, 메뉴 '지난 문자 1년치 불러오기'로 언제든 재실행. 중복 자동 제외
  - 결과 0건이면 진단 표시: "SMS n건·MMS m건 검사 / 발신번호 일치 k건 / 카드번호 일치 j건"
  - 불러온 건은 분류 대기 목록으로
  - full 은 실시간 SMS 수신 리시버도 같이 사용 (알림 감지와 중복 방지)
- [ ] 문자 붙여넣기 개선 (두 판 공통)
  - 화면 열면 입력칸은 항상 빈칸 (힌트만 회색)
  - 위쪽에 클립보드 미리보기: 카드 승인 문자가 있으면 "복사된 문자 N건 발견" + 날짜·가맹점·금액 요약 + [이걸로 넣기].
    화면 열 때·앱 복귀 때마다 재확인. 카드 문자 아니면 안 띄움
  - 여러 문자를 한꺼번에 붙여넣으면 [Web발신]/카드번호+승인 단위로 쪼개서 여러 건 (splitMessages 확장)
  - 추가 전 "N건 중 새 내역 M건, 중복 K건" 확인 → 분류 대기로
  - 안내: "메시지 앱에서 카드 문자를 길게 눌러 여러 개 선택 → 복사 → 여기에 붙여넣으면 한 번에 들어가요"
  - 메뉴 이름 '문자 붙여넣기 (여러 건 가능)'
- [ ] 앱 이름 변경: '법카 정산' → '공감카드 정산'
  - 런처 라벨(AndroidManifest `android:label`), 화면 상단 제목, 알림 제목·채널 이름, 공유 시트 이름, 알림 접근 서비스 라벨 등 사용자에게 보이는 곳 전부
  - applicationId·패키지명·저장소 이름은 그대로 (바꾸면 덮어쓰기 설치·데이터 유지가 깨짐)
  - CLAUDE.md 제목도 '공감카드 정산'으로
- [ ] 월별 합계 요약을 표로 변경 (월 이동 ◀ ▶ 바로 아래, 기존 차량비/운영비 박스 대체)

  |        | 수립 | 사용 |
  |--------|------|------|
  | 합계   |      |      |
  | 차량비 |      |      |
  | 운영비 |      |      |

  - 단위 만원, 소수점 둘째 자리까지 (342,500원 → 34.25). "(단위: 만원)" 표시
  - 사용: 그 달 분류된 내역 합계 (승인취소 차감). 합계 = 차량비 + 운영비
  - 수립:
    - 합계·차량비 칸 터치 → 숫자 입력창(소수점 가능, 만원 단위). 34.25 입력 → 342,500원으로 저장
    - 운영비 수립은 입력 불가, 자동 계산 = 합계 수립 − 차량비 수립. 음수면 빨간색(입력 오류 표시)
    - 월별 저장. 새 달은 직전 달 수립값을 기본으로 채우고, 바꾸면 그 달만 바뀜
    - 미입력은 '-' 표시하고 터치 유도
  - 초과 표시: 합계 사용 > 합계 수립 → 합계 사용 칸 빨간색, 차량비 사용 > 차량비 수립 → 차량비 사용 칸 빨간색.
    운영비는 초과 표시 안 함. 수립이 비어 있으면 판정 안 함
  - 깔끔한 테두리 표, 1행·1열 제목 셀은 연한 배경. 차량비 행 제목은 초록, 운영비 행 제목은 노랑 계열(버튼 색과 맞춤)
  - '이번 달 내역 복사' 정산 텍스트에도 수립/사용 표 포함
  - 만원 변환·운영비 자동계산·초과 판정 단위 테스트 추가
- [ ] 배포 확인
  - 배포 후 두 고정 링크(`app-release.apk`, `app-full-release.apk`) 모두 로그인 없이 받아지는지 확인해서 알려주기
