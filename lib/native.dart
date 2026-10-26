import 'package:flutter/services.dart';

class RawSms {
  final String body;
  final DateTime receivedAt;
  RawSms(this.body, this.receivedAt);
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

  static Future<void> setCardDigits(String digits) =>
      _ch.invokeMethod('setCardDigits', {'digits': digits});

  static List<RawSms> _toRaw(List<Map>? list) => (list ?? [])
      .map((m) => RawSms(
            m['body'] as String,
            DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
          ))
      .toList();

  /// 앱이 꺼져 있는 동안 리시버/알림 감지가 쌓아 둔 문자를 가져온다. 가져가면 비워진다.
  static Future<List<RawSms>> drainInbox() async =>
      _toRaw(await _ch.invokeListMethod<Map>('drainInbox'));

  static Future<List<RawSms>> readSmsInbox(int days) async =>
      _toRaw(await _ch.invokeListMethod<Map>('readSmsInbox', {'days': days}));

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
