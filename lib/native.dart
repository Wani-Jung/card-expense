import 'package:flutter/services.dart';

class RawSms {
  final String body;
  final DateTime receivedAt;
  RawSms(this.body, this.receivedAt);
}

class PermStatus {
  final bool notification;
  final bool listener;
  const PermStatus({this.notification = true, this.listener = true});
  bool get allOk => notification && listener;
}

/// MainActivity.kt 와 주고받는 채널.
class Native {
  static const _ch = MethodChannel('card_expense/native');

  static void setHandler(Future<void> Function(String method) handler) =>
      _ch.setMethodCallHandler((call) => handler(call.method));

  static Future<void> setSettings(String digits, String sender) =>
      _ch.invokeMethod('setSettings', {'digits': digits, 'sender': sender});

  /// 앱이 꺼져 있는 동안 알림 감지가 쌓아 둔 문자를 가져온다. 가져가면 비워진다.
  static Future<List<RawSms>> drainInbox() async {
    final list = await _ch.invokeListMethod<Map>('drainInbox') ?? [];
    return list
        .map((m) => RawSms(
              m['body'] as String,
              DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
            ))
        .toList();
  }

  /// 메시지 앱에서 공유받은 텍스트. 가져가면 비워진다.
  static Future<List<String>> takeShared() async =>
      await _ch.invokeListMethod<String>('takeShared') ?? [];

  static Future<PermStatus> permissionStatus() async {
    final m = await _ch.invokeMapMethod<String, bool>('permissionStatus') ?? {};
    return PermStatus(
      notification: m['notification'] ?? false,
      listener: m['listener'] ?? false,
    );
  }

  static Future<void> requestNotificationPermission() =>
      _ch.invokeMethod('requestNotificationPermission');
  static Future<void> openNotificationAccessSettings() =>
      _ch.invokeMethod('openNotificationAccessSettings');
  static Future<void> openAppSettings() => _ch.invokeMethod('openAppSettings');
  static Future<void> cancelNotifications() => _ch.invokeMethod('cancelNotifications');
}
