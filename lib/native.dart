import 'package:flutter/services.dart';

class RawSms {
  final String body;
  final DateTime receivedAt;
  RawSms(this.body, this.receivedAt);
}

/// (전용판) 문자함 불러오기 결과. 0건일 때 원인을 보여주려고 검사 건수도 같이 받는다.
class InboxScan {
  /// SMS/MMS 는 발신번호가 일치한 문자, 그 밖의 저장소(RCS 등)는 카드번호+승인이 들어간 문자.
  final List<RawSms> items;
  final int smsScanned;
  final int mmsScanned;
  final int otherScanned;
  final int otherMatched;
  const InboxScan(this.items, this.smsScanned, this.mmsScanned, [this.otherScanned = 0, this.otherMatched = 0]);

  /// SMS/MMS 에서 발신번호가 일치한 건수.
  int get senderMatched => items.length - otherMatched;
}

/// (전용판) 메뉴 '문자 저장소 진단' 한 줄.
class StoreDiagnosis {
  final String uri;
  final bool ok;
  final int? count;
  final List<String> columns;
  final String? bodyColumn;
  final int? cardMatched;
  final String? error;
  StoreDiagnosis.fromMap(Map m)
      : uri = m['uri'] as String,
        ok = m['ok'] == true,
        count = (m['count'] as num?)?.toInt(),
        columns = ((m['columns'] as List?) ?? []).cast<String>(),
        bodyColumn = m['bodyColumn'] as String?,
        cardMatched = (m['cardMatched'] as num?)?.toInt(),
        error = m['error'] as String?;

  String get summary => ok
      ? '$uri\n  접근 가능 · ${count ?? 0}행 · 본문 컬럼 ${bodyColumn ?? '없음'} · 카드번호 일치 ${cardMatched ?? 0}건\n'
          '  컬럼: ${columns.join(', ')}'
      : '$uri\n  막힘 · $error';
}

class PermStatus {
  /// 알림 접근(메시지 앱 알림 읽기). 이 앱은 상태바 알림을 띄우지 않으므로 알림 표시 권한은 없다.
  final bool listener;

  /// 문자 권한. 일반판은 문자 권한이 아예 없어서 null.
  final bool? sms;
  const PermStatus({this.listener = true, this.sms});
  bool get allOk => listener && (sms ?? true);
}

/// MainActivity.kt 와 주고받는 채널.
class Native {
  static const _ch = MethodChannel('card_expense/native');

  static void setHandler(Future<void> Function(String method) handler) =>
      _ch.setMethodCallHandler((call) => handler(call.method));

  static Future<void> setSettings(String digits, String sender) =>
      _ch.invokeMethod('setSettings', {'digits': digits, 'sender': sender});

  static List<RawSms> _toRaw(List? list) => (list ?? [])
      .cast<Map>()
      .map((m) => RawSms(
            m['body'] as String,
            DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
          ))
      .toList();

  /// 앱이 꺼져 있는 동안 알림 감지·SMS 리시버가 쌓아 둔 문자를 가져온다. 가져가면 비워진다.
  static Future<List<RawSms>> drainInbox() async =>
      _toRaw(await _ch.invokeListMethod<Map>('drainInbox'));

  /// 메시지 앱에서 공유받은 텍스트. 가져가면 비워진다.
  static Future<List<String>> takeShared() async =>
      await _ch.invokeListMethod<String>('takeShared') ?? [];

  /// (전용판) 문자함(SMS + MMS)에서 최근 [days] 일 동안 발신번호가 일치하는 문자를 읽는다.
  static Future<InboxScan> readSmsInbox(int days) async {
    final m = await _ch.invokeMapMethod<String, dynamic>('readSmsInbox', {'days': days}) ?? {};
    return InboxScan(
      _toRaw(m['items'] as List?),
      (m['smsScanned'] as num?)?.toInt() ?? 0,
      (m['mmsScanned'] as num?)?.toInt() ?? 0,
      (m['otherScanned'] as num?)?.toInt() ?? 0,
      (m['otherMatched'] as num?)?.toInt() ?? 0,
    );
  }

  /// (전용판) 문자 저장소 진단. 일반판이거나 실패하면 null.
  static Future<List<StoreDiagnosis>?> diagnoseStores() async {
    final list = await _ch.invokeListMethod<Map>('diagnoseStores');
    return list?.map(StoreDiagnosis.fromMap).toList();
  }

  /// 세로로 긴 캡처를 겹치게 잘라 캐시에 쓴 경로들. 짧으면 원본 경로 하나.
  static Future<List<String>> sliceImage(String path) async =>
      await _ch.invokeListMethod<String>('sliceImage', {'path': path}) ?? [path];

  static Future<PermStatus> permissionStatus() async {
    final m = await _ch.invokeMapMethod<String, bool>('permissionStatus') ?? {};
    return PermStatus(
      listener: m['listener'] ?? false,
      sms: m['sms'],
    );
  }

  static Future<void> requestSmsPermission() => _ch.invokeMethod('requestSmsPermission');
  static Future<void> openNotificationAccessSettings() =>
      _ch.invokeMethod('openNotificationAccessSettings');
  static Future<void> openAppSettings() => _ch.invokeMethod('openAppSettings');
}
