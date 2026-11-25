import 'package:flutter/services.dart';

class RawSms {
  final String body;
  final DateTime receivedAt;

  /// (지난 문자 불러오기) 발신번호가 맞아서 찾은 문자인지. 진단에만 쓴다
  final bool bySender;
  RawSms(this.body, this.receivedAt, {this.bySender = false});
}

/// 문자함 불러오기 결과: 카드 승인·취소 후보 문자와 진단용 주소 형식.
/// 문자함 전체를 몇 건 봤는지는 받지도, 어디에 보여 주지도 않는다 (REQ-66 B).
class InboxScan {
  /// SMS·MMS·RCS 후보 저장소 모두 같은 조건: '승인'·'취소'가 있고 (발신번호 일치 또는 카드번호+승인·취소)
  final List<RawSms> items;

  /// 진단용: 찾은 문자의 저장소별 주소 형식 몇 개 ('sms: 15881600' 처럼)
  final List<String> addrSamples;
  const InboxScan(this.items, [this.addrSamples = const []]);
}

class PermStatus {
  /// 알림 접근(메시지 앱 알림 읽기). 이 앱은 상태바 알림을 띄우지 않으므로 알림 표시 권한은 없다.
  final bool listener;

  /// 문자 권한 (상태를 못 읽었으면 null).
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
            bySender: m['bySender'] == true,
          ))
      .toList();

  /// 앱이 꺼져 있는 동안 알림 감지·SMS 리시버가 쌓아 둔 문자를 가져온다. 가져가면 비워진다.
  static Future<List<RawSms>> drainInbox() async =>
      _toRaw(await _ch.invokeListMethod<Map>('drainInbox'));

  /// 메시지 앱에서 공유받은 텍스트. 가져가면 비워진다.
  static Future<List<String>> takeShared() async =>
      await _ch.invokeListMethod<String>('takeShared') ?? [];

  /// 문자함(SMS + MMS + RCS 후보)에서 [from] 이상 [to] 미만 기간의 카드 승인·취소 후보 문자를 읽는다.
  static Future<InboxScan> readSmsInbox(DateTime from, DateTime to) async {
    final m = await _ch.invokeMapMethod<String, dynamic>(
          'readSmsInbox',
          {'from': from.millisecondsSinceEpoch, 'to': to.millisecondsSinceEpoch},
        ) ??
        {};
    return InboxScan(
      _toRaw(m['items'] as List?),
      ((m['addrSamples'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }

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

  /// (스토어판 '버전 정보', REQ-64) Play 인앱 업데이트 확인: {status: available|latest|error, versionCode?}
  static Future<Map<String, dynamic>> playUpdateCheck() async =>
      await _ch.invokeMapMethod<String, dynamic>('playUpdateCheck') ?? const {'status': 'error'};

  /// Play 유연한 업데이트 시작. 못 하면 false
  static Future<bool> playUpdateStart() async => await _ch.invokeMethod<bool>('playUpdateStart') ?? false;

  /// Play 스토어 앱의 이 앱 페이지
  static Future<void> openPlayStore() => _ch.invokeMethod('openPlayStore');

  /// 미분류 알림: 미분류 내역의 미분류 시작 시각([times])·승인 일시([dates], 같은 순서, 이번 달·지난달 판정용)와
  /// 스위치를 네이티브에 넘긴다 (앱이 꺼져 있어도 판정하도록)
  static Future<void> syncReminder(List<int> times, {required List<int> dates, required bool enabled}) =>
      _ch.invokeMethod('syncReminder', {'times': times, 'dates': dates, 'enabled': enabled});

  /// 알림을 눌러 앱이 열렸으면 열 화면 ('unclassified'). 가져가면 비워진다.
  static Future<String?> takeOpenTarget() => _ch.invokeMethod<String>('takeOpenTarget');

  /// 시스템 알림 허용 여부
  static Future<bool> notificationsEnabled() async => await _ch.invokeMethod<bool>('notificationsEnabled') ?? true;

  /// 알림 권한 요청 (안드로이드 13 이상만 창이 뜬다). 결과 = 허용 여부
  static Future<bool> requestNotificationPermission() async =>
      await _ch.invokeMethod<bool>('requestNotificationPermission') ?? true;

  /// 앱 전용 캐시 폴더 (공유 이미지 임시 파일용, 저장소 권한 필요 없음). 못 받으면 null
  static Future<String?> cacheDir() async {
    try {
      return await _ch.invokeMethod<String>('cacheDir');
    } catch (_) {
      return null;
    }
  }
}
