import 'package:flutter/services.dart';

/// 빌드 판. `flutter build apk --flavor public|full` 로 정해진다. 테스트 등 flavor 없이 돌면 일반판.
///
/// - 일반판(public): 문자 권한 없음. 알림 감지 + 붙여넣기/공유.
/// - 전용판(full): 일반판 + 문자 권한(실시간 SMS 수신, 지난 문자 1년치 불러오기).
bool get isFullEdition => appFlavor == 'full';

String get editionLabel => isFullEdition ? '전용판' : '일반판';

const kAppName = '공감카드 정산';
