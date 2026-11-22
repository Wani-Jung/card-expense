import 'dart:convert';

import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/import_screen.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/onboarding_screen.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-54: 보기 기간 기억, 사전입력 3단계 '지난 결제 넣기'를 전용판에서 기간 지정 불러오기로.
void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (_) async => null,
    );
  });

  group('A 보기 기간 기억', () {
    test('저장·복원, 저장값 없음 → 1개월', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.open();
      expect(store.periodMode, PeriodMode.single);
      await store.setPeriodMode(PeriodMode.evenOdd);
      expect((await Store.open()).periodMode, PeriodMode.evenOdd);
      SharedPreferences.setMockInitialValues({'period_mode_v1': 'nonsense'});
      expect((await Store.open()).periodMode, PeriodMode.single);
    });

    Future<Store> pumpApp(WidgetTester tester, Map<String, Object> extra) async {
      phone(tester);
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'card_digits': '0000',
        'sender_number': '1588-1600',
        'update_checked_at': now.millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(now),
        'notif_asked_v1': true,
        'budgets_v1': jsonEncode({
          Budgets.keyOf(now): {'total': 1000000, 'car': 400000},
        }),
        ...extra,
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      return store;
    }

    String combinedTitle(PeriodMode m) => PeriodView(periodMonths(DateTime.now(), m).first, combined: true).title(m);

    for (final m in [PeriodMode.oddEven, PeriodMode.evenOdd]) {
      testWidgets('앱 시작: 저장된 ${periodModeShort(m)} → 이번 달 묶음의 두 달 합산', (tester) async {
        await pumpApp(tester, {'period_mode_v1': m.name});
        expect(find.text(combinedTitle(m)), findsOneWidget);
        expect(find.text('${periodModeShort(m)} ▾'), findsOneWidget);
      });
    }

    testWidgets('앱 시작: 저장값 없음·1개월 → 이번 달 월 화면', (tester) async {
      for (final extra in [
        <String, Object>{},
        <String, Object>{'period_mode_v1': 'single'},
      ]) {
        await pumpApp(tester, extra);
        expect(find.text(PeriodView(DateTime.now()).title(PeriodMode.single)), findsOneWidget);
        expect(find.text('1개월 ▾'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('보기를 바꾸면 저장되고, 다시 열면 그 보기로', (tester) async {
      final store = await pumpApp(tester, {});
      await tester.tap(find.text('1개월 ▾'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(periodModeLabel(PeriodMode.evenOdd)).last);
      await tester.pumpAndSettle();
      expect(store.periodMode, PeriodMode.evenOdd);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(CardExpenseApp(store: await Store.open()));
      await tester.pumpAndSettle();
      expect(find.text(combinedTitle(PeriodMode.evenOdd)), findsOneWidget);
    });

    test('연말 짝홀 묶음 (12~1월)', () {
      final dec = DateTime(2026, 12, 10);
      final v = PeriodView(periodMonths(dec, PeriodMode.evenOdd).first, combined: true);
      expect(v.title(PeriodMode.evenOdd), '2026년 12월~2027년 1월 합산');
      final jan = DateTime(2027, 1, 5);
      expect(
        PeriodView(periodMonths(jan, PeriodMode.evenOdd).first, combined: true).title(PeriodMode.evenOdd),
        '2026년 12월~2027년 1월 합산',
      );
    });
  });

  group('B 사전입력 3단계', () {
    final clock = DateTime(2026, 11, 19, 15);
    final parsed = parseSms(
      '[Web발신]\nNH기업0000승인\n공용카드\n96,000원 체크\n11/18 16:26\n(주)월산주유소',
      cardDigits: '0000',
      receivedAt: clock,
    )!;
    ImportPreview preview(int fresh) => ImportPreview(
      const InboxScan([]),
      IngestReport(fresh: [for (var i = 0; i < fresh; i++) parsed], dup: 1, ignoredHits: const [], rejected: const []),
      unique: fresh + 1,
    );

    Future<void> pumpGuide(
      WidgetTester tester, {
      required bool full,
      bool smsOk = true,
      List<(DateTime, DateTime)>? asked,
      List<OnboardingAction>? done,
      int fresh = 2,
    }) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            firstRun: false,
            fullEdition: full,
            clock: () => clock,
            budget: const MonthBudget(),
            digits: '0000',
            sender: '1588-1600',
            onBudget: (_, _) async {},
            onSettings: (_, _) async {},
            onDone: (a) => done?.add(a),
            previewImport: (s, e) async {
              asked?.add((s, e));
              return preview(fresh);
            },
            applyImport: (p) async => p.report.fresh.length,
            ensureSms: (_) async => smsOk,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      expect(find.text('3 / 3'), findsOneWidget);
    }

    testWidgets('일반판: 붙여넣기·공유 안내 그대로', (tester) async {
      await pumpGuide(tester, full: false);
      expect(find.text('지난 결제 넣기'), findsOneWidget);
      expect(find.text('지금 문자 붙여넣기'), findsOneWidget);
      expect(find.text('이 기간 문자 확인'), findsNothing);
    });

    testWidgets('전용판: 기본 이번 달 1일~오늘, 빠른 선택, 미리보기 → 넣기 → 결과 한 줄 → [닫기]', (tester) async {
      final asked = <(DateTime, DateTime)>[];
      final done = <OnboardingAction>[];
      await pumpGuide(tester, full: true, asked: asked, done: done);
      expect(find.text('지난 결제 불러오기'), findsOneWidget);
      expect(find.text('2026.11.01'), findsOneWidget);
      expect(find.text('2026.11.19'), findsOneWidget);
      expect(find.text('지금 문자 붙여넣기'), findsNothing); // 붙여넣기 안내 대신
      expect(find.text('문자 붙여넣기·공유로도 넣을 수 있어요 ›'), findsOneWidget);
      // 빠른 선택
      await tester.tap(find.text('지난달'));
      await tester.pumpAndSettle();
      expect(find.text('2026.10.01'), findsOneWidget);
      expect(find.text('2026.10.31'), findsOneWidget);
      await tester.tap(find.text('이번 달'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 기간 문자 확인'));
      await tester.pumpAndSettle();
      expect(asked.single, (DateTime(2026, 11, 1), DateTime(2026, 11, 20)));
      expect(find.text('이 기간 승인 문자 3건'), findsOneWidget);
      expect(find.text('새로 넣을 문자 2건'), findsOneWidget); // REQ-66 C: 항목별 한 줄
      expect(find.text('이미 있는 문자 1건'), findsOneWidget);
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('분류 대기에 2건 넣었어요\n이미 있던 1건은 건너뛰었어요'), findsOneWidget); // REQ-61 중복 한 줄
      // 결과 아래 [완료] (REQ-67 10, 메뉴에서 연 경우 아래 바도 '완료')
      await tester.tap(find.widgetWithText(FilledButton, '완료').first);
      await tester.pumpAndSettle();
      expect(done, [OnboardingAction.none]);
    });

    testWidgets('전용판: 문자 권한을 못 받으면 미리보기 없이 붙여넣기·공유 안내를 대신', (tester) async {
      final asked = <(DateTime, DateTime)>[];
      final done = <OnboardingAction>[];
      await pumpGuide(tester, full: true, smsOk: false, asked: asked, done: done);
      await tester.tap(find.text('이 기간 문자 확인'));
      await tester.pumpAndSettle();
      expect(asked, isEmpty);
      await tester.scrollUntilVisible(find.text('지금 문자 붙여넣기'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text(keepWords('문자 권한 없이도 이렇게 넣을 수 있어요')), findsOneWidget);
      expect(find.text('지금 문자 붙여넣기'), findsOneWidget);
      await tester.tap(find.text('지금 문자 붙여넣기'));
      await tester.pumpAndSettle();
      expect(done, [OnboardingAction.paste]);
    });

    testWidgets('전용판: 새로 넣을 문자가 없으면 그렇게 알려 줌', (tester) async {
      await pumpGuide(tester, full: true, fresh: 0);
      await tester.tap(find.text('이 기간 문자 확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '닫기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('새로 불러온 문자가 없어요'), findsOneWidget); // REQ-61 문구
    });

    test('기간 규칙: 시작>종료 막기, 미래 날짜 불가', () {
      expect(importRangeError(DateTime(2026, 11, 10), DateTime(2026, 11, 5), clock), '시작일이 종료일보다 늦어요');
      expect(importRangeError(DateTime(2026, 11, 1), DateTime(2026, 11, 20), clock), '미래 날짜는 고를 수 없어요');
      expect(importRangeError(DateTime(2026, 11, 1), DateTime(2026, 11, 19), clock), isNull);
      expect(QuickRange.thisMonth.range(clock), (from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 19)));
    });

    testWidgets('ensureSmsForImport: 허용됨 → true / 영구 거부 → 요청 없이 false / [나중에] → false', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      var requested = 0;
      Future<bool> req(BuildContext _) async {
        requested++;
        return false;
      }

      expect(await ensureSmsForImport(ctx, status: () async => const PermStatus(sms: true), request: req), isTrue);
      expect(
        await ensureSmsForImport(ctx, status: () async => const PermStatus(sms: false, smsBlocked: true), request: req),
        isFalse,
      );
      expect(requested, 0);
      expect(await ensureSmsForImport(ctx, status: () async => const PermStatus(sms: false), request: req), isFalse);
      expect(requested, 1);
    });

    test('넣기 공용 함수: 같은 건은 한 번만, 넣은 때부터 미분류 기간', () {
      final items = <Expense>[];
      expect(addParsedTo(items, [parsed, parsed], fromStore: true, now: clock), 1);
      expect(items.single.pendingSince, clock);
      expect(addParsedTo(items, [parsed], now: clock), 0);
    });
  });
}
