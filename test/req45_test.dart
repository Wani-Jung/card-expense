import 'dart:convert';
import 'dart:io';

import 'package:card_expense/challenge_card.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/review_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-45: 미분류 알림 연동(동기화·스위치·권한·알림 탭 이동), 새 로고.
/// 7일 경계·평일 5시·주말 미룸·재발송 간격 판정은 네이티브 쪽이라
/// android/app/src/test/.../ReminderRuleTest.kt 에서 확인한다.
void main() {
  const channel = MethodChannel('card_expense/native');
  late List<MethodCall> calls;
  late bool permissionResult;
  late bool notifEnabled;
  String? openTarget;

  Map<String, Object> basePrefs(List<Expense> items, [Map<String, Object> extra = const {}]) => {
    'card_digits': '0000',
    'sender_number': '1588-1600',
    'update_checked_at': DateTime.now().millisecondsSinceEpoch,
    'quiz_last_day_v1': quizDay(DateTime.now()),
    'expenses_v1': jsonEncode(items.map((e) => e.toJson()).toList()),
    ...extra,
  };

  Expense item(String id, String? cat, DateTime at, {DateTime? since}) => Expense(
    id: id,
    amount: 1000,
    dateTime: at,
    merchant: '가게$id',
    isCancel: false,
    raw: '',
    category: cat,
    pendingSince: since,
  );

  setUp(() {
    calls = [];
    permissionResult = true;
    notifEnabled = true;
    openTarget = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'requestNotificationPermission':
          notifEnabled = permissionResult;
          return permissionResult;
        case 'notificationsEnabled':
          return notifEnabled;
        case 'takeOpenTarget':
          final t = openTarget;
          openTarget = null;
          return t;
      }
      return null;
    });
  });

  List<MethodCall> named(String m) => calls.where((c) => c.method == m).toList();

  Future<Store> pumpHome(WidgetTester tester, Map<String, Object> prefs) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> openManage(WidgetTester tester) async {
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내역 관리'));
    await tester.pumpAndSettle();
  }

  Switch remindSwitch(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(of: find.widgetWithText(ListTile, '미분류 알림 받기'), matching: find.byType(Switch)),
  );

  group('네이티브 동기화', () {
    testWidgets('미분류만 시각을 넘긴다 (실시간 = 승인 일시, 불러온 건 = 넣은 때)', (tester) async {
      final old = DateTime(2026, 1, 5, 9);
      final added = DateTime(2026, 10, 30, 12);
      await pumpHome(tester, basePrefs([
        item('a', null, old),
        item('b', null, DateTime(2025, 12, 1), since: added),
        item('c', kCar, DateTime(2026, 1, 1)),
        item('d', kIgnored, DateTime(2026, 1, 2)),
      ], {'notif_asked_v1': true}));
      final sync = named('syncReminder').last.arguments as Map;
      expect(sync['enabled'], isTrue);
      expect(sync['times'], [old.millisecondsSinceEpoch, added.millisecondsSinceEpoch]);
    });

    test('pendingSince 저장·읽기, 없으면 승인 일시부터', () {
      final at = DateTime(2026, 1, 5, 9);
      final since = DateTime(2026, 10, 30, 12);
      final e = Expense.fromJson(jsonDecode(jsonEncode(item('a', null, at, since: since).toJson())) as Map<String, dynamic>);
      expect(e.pendingFrom, since);
      final old = Expense.fromJson(jsonDecode(jsonEncode(item('b', null, at).toJson())) as Map<String, dynamic>);
      expect(old.pendingSince, isNull);
      expect(old.pendingFrom, at);
    });
  });

  group('미분류 알림 받기 스위치', () {
    testWidgets('기본 ON, 내역 관리 펼침의 4개 목록 아래', (tester) async {
      final store = await pumpHome(tester, basePrefs([], {'notif_asked_v1': true}));
      expect(store.remindOn, isTrue);
      await openManage(tester);
      expect(remindSwitch(tester).value, isTrue);
      expect(find.text('휴대폰 설정에서 알림을 허용해야 받을 수 있어요'), findsNothing);
      final y = tester.getTopLeft(find.text('미분류 알림 받기')).dy;
      for (final t in ['미분류 내역', '확인 필요 내역', '무시한 내역', '확인한 내역']) {
        expect(tester.getTopLeft(find.text(t)).dy, lessThan(y), reason: t);
      }
    });

    testWidgets('OFF 로 바꾸면 저장·네이티브에 enabled=false, 다시 켜면 권한 묻고 ON', (tester) async {
      final store = await pumpHome(tester, basePrefs([], {'notif_asked_v1': true}));
      await openManage(tester);
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, '미분류 알림 받기'), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(store.remindOn, isFalse);
      expect(remindSwitch(tester).value, isFalse);
      expect((named('syncReminder').last.arguments as Map)['enabled'], isFalse);
      // 일부러 끈 것 (권한은 있음) → 안내 없음
      expect(find.text('휴대폰 설정에서 알림을 허용해야 받을 수 있어요'), findsNothing);

      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, '미분류 알림 받기'), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(named('requestNotificationPermission'), hasLength(1));
      expect(store.remindOn, isTrue);
      expect((named('syncReminder').last.arguments as Map)['enabled'], isTrue);
    });

    testWidgets('켤 때 권한 거부 → OFF + 안내 한 줄', (tester) async {
      permissionResult = false;
      final store = await pumpHome(tester, basePrefs([], {'notif_asked_v1': true, 'remind_unclassified_v1': false}));
      await openManage(tester);
      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, '미분류 알림 받기'), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(store.remindOn, isFalse);
      expect(remindSwitch(tester).value, isFalse);
      expect(find.text('휴대폰 설정에서 알림을 허용해야 받을 수 있어요'), findsOneWidget);
      expect((named('syncReminder').last.arguments as Map)['enabled'], isFalse);
    });

    testWidgets('첫 실행 뒤 한 번만 권한 묻기: 거부 → OFF, 다시 열어도 또 묻지 않음', (tester) async {
      permissionResult = false;
      final store = await pumpHome(tester, basePrefs([]));
      expect(named('requestNotificationPermission'), hasLength(1));
      expect(store.notifAsked, isTrue);
      expect(store.remindOn, isFalse);

      calls.clear();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      expect(named('requestNotificationPermission'), isEmpty);
    });

    testWidgets('첫 실행 뒤 허용 → ON 유지', (tester) async {
      final store = await pumpHome(tester, basePrefs([]));
      expect(named('requestNotificationPermission'), hasLength(1));
      expect(store.remindOn, isTrue);
    });

    testWidgets('휴대폰 설정에서 알림을 끄면 돌아왔을 때 스위치 OFF', (tester) async {
      notifEnabled = false;
      final store = await pumpHome(tester, basePrefs([], {'notif_asked_v1': true}));
      expect(store.remindOn, isFalse);
      expect((named('syncReminder').last.arguments as Map)['enabled'], isFalse);
    });
  });

  group('알림 탭', () {
    testWidgets('콜드 스타트: 앱이 켜지면 미분류 내역 화면으로', (tester) async {
      openTarget = 'unclassified';
      await pumpHome(tester, basePrefs([item('a', null, DateTime(2026, 1, 5))], {'notif_asked_v1': true}));
      expect(find.byType(UnclassifiedScreen), findsOneWidget);
      expect(find.textContaining('가게a'), findsOneWidget);
    });

    testWidgets('앱이 떠 있을 때: 메뉴를 닫고 미분류 내역 화면으로 (하나만)', (tester) async {
      await pumpHome(tester, basePrefs([item('a', null, DateTime(2026, 1, 5))], {'notif_asked_v1': true}));
      expect(find.byType(UnclassifiedScreen), findsNothing);
      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();

      openTarget = 'unclassified';
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('openTarget')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(UnclassifiedScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('메뉴'), findsOneWidget); // 메인으로
    });

    testWidgets('알림으로 열지 않았으면 메인 그대로', (tester) async {
      await pumpHome(tester, basePrefs([item('a', null, DateTime(2026, 1, 5))], {'notif_asked_v1': true}));
      expect(find.byType(UnclassifiedScreen), findsNothing);
    });
  });

  group('새 로고', () {
    test('결과 카드 로고 = 네이비 공감, 파일·pubspec 등록, 옛 로고 삭제', () {
      expect(kShareCardLogo, 'assets/icon/gonggam_navy_1024.png');
      expect(File(kShareCardLogo).existsSync(), isTrue);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- $kShareCardLogo'));
      expect(pubspec, isNot(contains('wani_card_gold')));
      expect(File('assets/icon/wani_card_gold_1024.png').existsSync(), isFalse);
    });

    testWidgets('결과 카드가 새 로고 asset 을 그린다, 골드 없음', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: ChallengeResultCard(
                  run: const ChallengeRun(id: 'c1', at: 0, n: 20, correct: 17, ms: 134000),
                  name: '',
                  date: DateTime(2026, 10, 29),
                  newBest: false,
                ),
              ),
            ),
          ),
        ),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).map((i) => i.image);
      final names = [
        for (final p in images)
          switch (p) {
            AssetImage(:final assetName) => assetName,
            ResizeImage(imageProvider: AssetImage(:final assetName)) => assetName,
            _ => '$p',
          },
      ];
      expect(names, contains('assets/icon/gonggam_navy_1024.png'));
      const gold = Color(0xFFF0A500);
      for (final c in tester.widgetList<Container>(find.byType(Container))) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          expect(d.gradient?.colors ?? const <Color>[], isNot(contains(gold)));
          expect((d.border as Border?)?.top.color, isNot(gold));
        }
      }
    });
  });
}
