import 'dart:io';

import 'package:card_expense/check.dart';
import 'package:card_expense/demo.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-53: 스토어 스크린샷용 데모 데이터 모드, 등록정보 원본 파일.
void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (_) async => null,
    );
  });

  test('데모 모드는 define 이 있을 때만 (기본 꺼짐)', () {
    expect(kDemo, const bool.fromEnvironment('DEMO'));
  });

  test('데모 데이터: 가짜 카드번호·가맹점, 이번 달 날짜, 미래 없음, 대기·확인 필요 선택', () async {
    final now = DateTime(2026, 11, 19, 15);
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await seedDemo(p, now: now);
    final store = await Store.open();
    expect(store.cardDigits, '0000');
    final items = store.loadItems();
    expect(items.every((e) => !e.dateTime.isAfter(now)), isTrue);
    expect(items.where((e) => e.dateTime.month == 11), isNotEmpty);
    expect(items.where((e) => e.dateTime.month == 10), isNotEmpty);
    expect(items.every((e) => RegExp(r'^[A-Z]{2}').hasMatch(e.merchant)), isTrue); // 'OO주유소' 같은 가짜 이름
    expect(items.where((e) => e.category == null), hasLength(3));
    final vendors = store.loadVendors();
    expect(vendors.recommend('KK주유소')?.category, kCar);
    final issues = findIssues(items, vendors, now: now, okKeys: const {});
    expect(issues, isNotEmpty);

    // 대기·확인 필요 없이
    SharedPreferences.setMockInitialValues({});
    final q = await SharedPreferences.getInstance();
    await seedDemo(q, now: now, pending: false, issues: false);
    final s2 = await Store.open();
    expect(s2.loadItems().where((e) => e.category == null), isEmpty);
    expect(findIssues(s2.loadItems(), s2.loadVendors(), now: now, okKeys: const {}), isEmpty);

    // 월초(1일)에도 미래 날짜가 안 생김
    SharedPreferences.setMockInitialValues({});
    await seedDemo(await SharedPreferences.getInstance(), now: DateTime(2026, 12, 1, 9, 30));
    final s3 = await Store.open();
    expect(s3.loadItems().every((e) => !e.dateTime.isAfter(DateTime(2026, 12, 1, 9, 30))), isTrue);
  });

  test('실제 데이터가 있으면 데모로 덮지 않음 (define 이 없으면 아무것도 안 함)', () async {
    SharedPreferences.setMockInitialValues({'card_digits': '1234'});
    await seedDemoIfEmpty();
    final p = await SharedPreferences.getInstance();
    expect(p.getString('card_digits'), '1234');
    expect(p.containsKey('expenses_v1'), isFalse);
  });

  testWidgets('데모 데이터로 메인이 그려짐 (권한 배너 없음, 원 단위)', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 420 / 160;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await seedDemo(await SharedPreferences.getInstance(), pending: false, issues: false);
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('단위: 원 ▾'), findsOneWidget);
    expect(find.text('알림 감지 권한 필요'), findsNothing);
    expect(find.textContaining('분류 대기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('스토어 등록정보 원본: 길이 제한, 스토어판에 없는 기능 안 씀', () {
    String read(String f) => File('store/listing/ko-KR/$f').readAsStringSync().trim();
    expect(read('title.txt'), '공감카드 관리');
    expect(read('title.txt').length, lessThanOrEqualTo(30));
    expect(read('short_description.txt').length, lessThanOrEqualTo(80));
    final full = read('full_description.txt');
    expect(full.length, lessThanOrEqualTo(4000));
    for (final no in ['지난 문자', '문자 읽기', '문자 권한', '캡처', '법령 Quiz', '농어촌정비법', '건축법', '국가계약법']) {
      expect(full.contains(no), isFalse, reason: no);
      expect(read('short_description.txt').contains(no), isFalse, reason: no);
    }
  });
}
