// 판은 하나(REQ-70, 2.1.0): 예전 일반판(public)·전용판(full) flavor 를 합쳤다.
// 문자 권한(실시간 수신·지난 문자 불러오기)은 모든 빌드에 있고, 앱 안 안내 → 동의 → 권한 창으로만 켜진다.

/// 배포 채널. `--dart-define=CHANNEL=store` 로 빌드하면 플레이스토어판(AAB), 없으면 깃허브판(APK).
/// 스토어판은 자체 업데이트(업데이트 확인·알림·APK 링크)를 쓰지 않는다.
/// 컴파일 시점 상수라 스토어 빌드에서는 업데이트 코드가 트리셰이킹으로 빠진다.
const isStoreChannel = String.fromEnvironment('CHANNEL') == 'store';

/// 법령 Quiz 4종(농어촌정비법·건설기술 진흥법·국가계약법·건축법)을 스토어판에도 보일지. REQ-49·51 에선 숨겼고
/// REQ-62(2.0.2)부터 보인다 — 출처·'정부와 무관' 고지(`LawSourceNotice`)와 함께. 다시 숨기려면 false 로.
/// 깃허브판에는 이 값과 상관없이 보인다.
const kRuralQuizInStore = true;

/// 실험실에 법령 Quiz 4종을 보일지
const kShowRuralQuiz = !isStoreChannel || kRuralQuizInStore;

const kAppName = '공감카드 관리';

/// 개인정보처리방침 (메뉴 > 개인정보처리방침, 모든 판 공통)
const kPrivacyUrl = 'https://github.com/Wani-Jung/card-expense/blob/main/PRIVACY.md';
