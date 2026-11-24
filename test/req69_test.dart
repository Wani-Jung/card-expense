import 'dart:io';

import 'package:card_expense/import_screen.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-69: '이번 달'만 골랐는데 1년치 이상이 들어오던 문제.
/// ① 첫 권한 허용 때 자동 1년 불러오기 없음 ② 어느 저장소에서 왔든 기간 밖 문자는 미리보기·불러오기 둘 다 0
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 24, 10);
  final q = importQueryRange(DateTime(2026, 11, 1), DateTime(2026, 11, 24)); // '이번 달'

  String sms(int won, String day, String shop) => '[Web발신] NH기업0000승인 공용카드 $won원 체크 $day 12:00 $shop';

  Map<String, Object> item(String body, DateTime at, {bool bySender = true}) =>
      {'body': body, 'ts': at.millisecondsSinceEpoch, 'bySender': bySender};

  void mockInbox(List<Map<String, Object>> items) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (call) async => call.method == 'readSmsInbox' ? {'items': items, 'addrSamples': <String>[]} : null,
    );
  }

  test('기간 밖 문자(SMS·MMS·RCS 어디서 왔든)는 미리보기에도, 넣는 건수에도 안 들어감', () async {
    mockInbox([
      item(sms(12000, '11/20', 'TT식당'), DateTime(2026, 11, 20, 12)), // 이번 달 (SMS)
      item(sms(9000, '11/03', 'LL분식'), DateTime(2026, 11, 3, 12)), // 이번 달 (MMS)
      item(sms(33000, '05/27', 'YY식당'), DateTime(2026, 5, 27, 12)), // 6개월 전 (RCS)
      item(sms(44000, '10/20', 'ZZ식당'), DateTime(2025, 10, 20, 12)), // 400일 전
      item(sms(55000, '10/31', 'WW주유소'), DateTime(2026, 10, 31, 23, 59)), // 지난달 마지막 순간
      item(sms(61000, '11/25', 'KK주유소'), DateTime(2026, 11, 25)), // 종료일 다음 날 0시 (밖)
    ]);
    final p = await previewImportRange(q.start, q.end, digits: '0000', existing: const {});
    expect(p.approvals, 2);
    expect(p.report.fresh.map((e) => e.merchant), unorderedEquals(['TT식당', 'LL분식']));
    // 미리보기 '새로 넣을 문자' = 실제로 넣는 건수
    final added = addParsedTo([], p.report.fresh, fromStore: true);
    expect(added, p.report.fresh.length);
    expect(resultLines(fresh: p.report.fresh.length, dup: p.duplicates), ['새로 넣을 문자 2건']);
  });

  test('기간 안 문자가 하나도 없으면 0 (불러오기 0건)', () async {
    mockInbox([item(sms(33000, '05/27', 'YY식당'), DateTime(2026, 5, 27, 12))]);
    final p = await previewImportRange(q.start, q.end, digits: '0000', existing: const {});
    expect(p.approvals, 0);
    expect(p.report.fresh, isEmpty);
  });

  test('inRangeOnly: [시작일 0시, 종료일 다음 날 0시)', () {
    final scan = InboxScan([
      RawSms('a', q.start),
      RawSms('b', q.end.subtract(const Duration(milliseconds: 1))),
      RawSms('c', q.end),
      RawSms('d', q.start.subtract(const Duration(milliseconds: 1))),
    ]);
    expect(inRangeOnly(scan, q.start, q.end).items.map((r) => r.body), ['a', 'b']);
    expect(now.isAfter(q.start), isTrue);
  });

  test('자동 1년 불러오기 코드가 없음 (첫 권한 허용 뒤엔 사용자가 고른 기간만)', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('_maybeAutoImport'), isFalse);
    expect(main.contains('defaultImportRange('), isFalse);
    // 메뉴 불러오기: 권한이 없으면 안내 → 권한 → 이어서 기간 고르는 화면
    expect(main.contains('if (!await ensureSmsForImport(context)) return;'), isTrue);
  });

  test('네이티브: 날짜 칸이 없는 저장소는 건너뛰고(지금으로 치지 않음) 단위는 InboxDate 로', () {
    final flavor = File('android/app/src/full/kotlin/com/wani/card_expense/Flavor.kt').readAsStringSync();
    expect(flavor.contains('System.currentTimeMillis()'), isFalse);
    expect(flavor.contains('InboxDate.inRange'), isTrue);
  });
}
