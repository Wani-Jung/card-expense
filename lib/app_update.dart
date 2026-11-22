import 'package:flutter/material.dart';

import 'flavor.dart';
import 'native.dart';
import 'notice_dialog.dart';

/// '버전 정보'·'업데이트 확인'을 눌렀을 때의 결과 (REQ-64). 스토어판·깃허브판 같은 모양.
/// 깃허브 쪽 조회(update_check.dart)는 여기서 부르지 않는다 — 스토어 빌드에 GitHub 주소가 들어가지 않게(CI 검사).
enum UpdateStatus { available, latest, failed }

class UpdateCheck {
  final UpdateStatus status;

  /// 지금 버전 ('2.0.1')
  final String current;

  /// 깃허브판: 새 버전 태그('v2.0.2'). 스토어판은 Play 가 versionName 을 안 알려 줘서 null
  final String? latest;
  const UpdateCheck(this.status, this.current, [this.latest]);
}

/// 스토어판: Google Play 인앱 업데이트로 확인. Play 에서 설치하지 않았거나 오프라인이면 failed
Future<UpdateCheck> checkPlayUpdate(String current, {Future<Map<String, dynamic>> Function()? check}) async {
  try {
    final m = await (check ?? Native.playUpdateCheck)();
    return UpdateCheck(switch (m['status']) {
      'available' => UpdateStatus.available,
      'latest' => UpdateStatus.latest,
      _ => UpdateStatus.failed,
    }, current);
  } catch (_) {
    return UpdateCheck(UpdateStatus.failed, current);
  }
}

const kUpdateAvailableTitle = '새 버전이 있어요';
const kUpdateLatestTitle = '최신 버전이에요';
const kUpdateFailedTitle = '지금은 확인할 수 없어요';

/// 결과 팝업. [onUpdate]: 업데이트 있음의 [업데이트]/[내려받기]. [onStore]: 스토어판 확인 실패의 [Play 스토어에서 보기]
Widget updateResultDialog(
  UpdateCheck c, {
  required bool store,
  VoidCallback? onUpdate,
  VoidCallback? onStore,
}) => switch (c.status) {
  UpdateStatus.available => NoticeDialog(
    icon: const NoticeInfoIcon(),
    title: kUpdateAvailableTitle,
    body: [
      '지금 v${c.current} 쓰는 중이에요.',
      if (c.latest != null) '새 버전: ${c.latest}',
    ].join('\n'),
    okLabel: store ? '업데이트' : '내려받기',
    onOk: onUpdate,
    cancelLabel: '나중에',
  ),
  UpdateStatus.latest => NoticeDialog(
    icon: const NoticeInfoIcon(),
    title: kUpdateLatestTitle,
    body: 'v${c.current} · $editionLabel',
  ),
  UpdateStatus.failed => NoticeDialog(
    icon: const NoticeInfoIcon(),
    title: kUpdateFailedTitle,
    body: store
        ? 'Play 스토어에서 설치한 앱에서만\n확인할 수 있어요. 인터넷 연결도\n확인해 보세요.'
        : '인터넷 연결을 확인하고\n잠시 뒤 다시 눌러 보세요.',
    okLabel: store ? 'Play 스토어에서 보기' : '확인',
    onOk: store ? onStore : null,
    cancelLabel: store ? '닫기' : null,
  ),
};
