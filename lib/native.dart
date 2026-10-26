import 'package:flutter/services.dart';

class RawSms {
  final String body;
  final DateTime receivedAt;
  RawSms(this.body, this.receivedAt);
}

/// 문자함 불러오기 결과. 0건일 때 원인을 보여주려고 검사 건수도 같이 받는다.
class InboxScan {
  final List<RawSms> items; // 발신번호가 일치한 문자
  final int smsScanned;
  final int mmsScanned;
  const InboxScan(this.items, this.smsScanned, this.mmsScanned);
}

class PermStatus {
  final bool sms;
  final bool notification;
  final bool listener;
  const PermStatus({this.sms = true, this.notification = true, this.listener = true});
  bool get allOk => sms && notification && listener;
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

  /// 앱이 꺼져 있는 동안 리시버/알림 감지가 쌓아 둔 문자를 가져온다. 가져가면 비워진다.
  static Future<List<RawSms>> drainInbox() async =>
      _toRaw(await _ch.invokeListMethod<Map>('drainInbox'));

  /// 문자함(SMS + MMS)에서 최근 [days] 일 동안 발신번호가 일치하는 문자를 읽는다.
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
      sms: m['sms'] ?? false,
      notification: m['notification'] ?? false,
      listener: m['listener'] ?? false,
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
