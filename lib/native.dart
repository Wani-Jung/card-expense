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

class PermStatus {
  /// 알림 접근(메시지 앱 알림 읽기). 이 앱은 상태바 알림을 띄우지 않으므로 알림 표시 권한은 없다.
  final bool listener;

  /// 문자 권한. 일반판은 문자 권한이 아예 없어서 null.
  final bool? sms;

  /// 문자 권한을 영구 거부해서 다시 요청 창이 안 뜨는 상태 (앱 정보 화면에서 켜야 함)
  final bool smsBlocked;
  const PermStatus({this.listener = true, this.sms, this.smsBlocked = false});
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

  /// 세로로 긴 캡처를 겹치게 잘라 캐시에 쓴 경로들. 짧으면 원본 경로 하나.
  static Future<List<String>> sliceImage(String path) async =>
      await _ch.invokeListMethod<String>('sliceImage', {'path': path}) ?? [path];

  static Future<PermStatus> permissionStatus() async {
    final m = await _ch.invokeMapMethod<String, bool>('permissionStatus') ?? {};
    return PermStatus(
      listener: m['listener'] ?? false,
      sms: m['sms'],
      smsBlocked: m['smsBlocked'] ?? false,
    );
  }

  /// 권한 설정 > '앱에서 사용' 스위치를 네이티브(알림 감지·SMS 수신)에 알린다
  static Future<void> setUsage({required bool listener, required bool sms}) =>
      _ch.invokeMethod('setUsage', {'listener': listener, 'sms': sms});

  static Future<void> requestSmsPermission() => _ch.invokeMethod('requestSmsPermission');
  static Future<void> openNotificationAccessSettings() =>
      _ch.invokeMethod('openNotificationAccessSettings');
  static Future<void> openAppSettings() => _ch.invokeMethod('openAppSettings');
}
