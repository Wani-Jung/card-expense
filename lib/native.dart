import 'package:flutter/services.dart';

class RawSms {
  final String body;
  final DateTime receivedAt;
  RawSms(this.body, this.receivedAt);
}

/// (전용판) 문자함 불러오기 결과. 0건일 때 원인을 보여주려고 검사 건수도 같이 받는다.
class InboxScan {
  final List<RawSms> items; // 발신번호가 일치한 문자
  final int smsScanned;
  final int mmsScanned;
  const InboxScan(this.items, this.smsScanned, this.mmsScanned);
}

class PermStatus {
  final bool notification;
  final bool listener;

  /// 문자 권한. 일반판은 문자 권한이 아예 없어서 null.
  final bool? sms;
  const PermStatus({this.notification = true, this.listener = true, this.sms});
  bool get allOk => notification && listener && (sms ?? true);
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
    );
  }

  static Future<PermStatus> permissionStatus() async {
    final m = await _ch.invokeMapMethod<String, bool>('permissionStatus') ?? {};
    return PermStatus(
      notification: m['notification'] ?? false,
      listener: m['listener'] ?? false,
      sms: m['sms'],
    );
  }

  static Future<void> requestSmsPermission() => _ch.invokeMethod('requestSmsPermission');
  static Future<void> requestNotificationPermission() =>
      _ch.invokeMethod('requestNotificationPermission');
  static Future<void> openNotificationAccessSettings() =>
      _ch.invokeMethod('openNotificationAccessSettings');
  static Future<void> openAppSettings() => _ch.invokeMethod('openAppSettings');
  static Future<void> cancelNotifications() => _ch.invokeMethod('cancelNotifications');
}
