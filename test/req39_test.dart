import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:card_expense/expense.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/menu_screen.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/quiz_category_picker.dart';
import 'package:card_expense/quiz_screens.dart';
import 'package:card_expense/vendor.dart';
import 'package:card_expense/vendor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-39: 퀴즈 v2(그룹·분야)·분야 선택·표시, 요약표 틀고정, 편집 시트 삭제 제거, 업체 전체 삭제, 메뉴 순서·QUIZ 아이콘
void main() {
  final bundled = File('quiz/questions.json').readAsStringSync();
  final bank = QuizBank.parse(bundled)!;

  Future<QuizStore> store([Map<String, Object> init = const {}]) async {
    SharedPreferences.setMockInitialValues(init);
    return QuizStore(await SharedPreferences.getInstance());
  }

  void phone(WidgetTester tester, {double height = 2340}) {
    tester.view.physicalSize = Size(1080, height);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
  }

  group('B1 문제 풀 v2', () {
    test('v2 파싱: 452문항, 그룹·분야 순서 그대로, 분야별 수', () {
      expect(bank.version, 2);
      expect(bank.questions, hasLength(452));
      expect(bank.groups.map((g) => g.name), ['현장 안전기준', '서류·절차']);
      expect(bank.groups.first.categories, ['추락·비계', '통로·작업장', '전기작업', '굴착·거푸집', '양중기·장비']);
      expect(bank.groups.last.categories.first, '발주자 의무');
      expect(bank.catCounts['서류·절차|발주자 의무'], 58);
      final q = bank.byId('w001')!;
      expect(q.group, '현장 안전기준');
      expect(q.catLabel, '현장 안전기준 · 추락·비계');
      expect(bank.byId('q001'), isNull); // 예전 id 는 폐기
    });

    test('v1 형식(그룹·분야 없음)도 읽고 기타로, 모르는 필드는 무시', () {
      final v1 = jsonEncode({
        'version': 1,
        'updated': '2026-10-29',
        'questions': [
          {'id': 'q001', 'question': '문제', 'answer': true, 'explain': '', 'basis': '', 'active': true, 'new': 1},
          {'id': 'q002', 'category': '위험성평가', 'question': '문제2', 'answer': false},
        ],
        'somethingNew': {'x': 1},
      });
      final b = QuizBank.parse(v1)!;
      expect(b.byId('q001')!.group, kQuizOther);
      expect(b.byId('q001')!.category, kQuizOther);
      expect(b.byId('q001')!.catLabel, '기타');
      expect(b.byId('q002')!.group, kQuizOther);
      expect(b.byId('q002')!.category, '위험성평가');
      expect(b.groups.single.name, kQuizOther);
    });

    test('깨진 파일·활성 문항 0개는 null, 깨진 문항 하나는 건너뜀', () {
      expect(QuizBank.parse('{깨짐'), isNull);
      expect(QuizBank.parse(jsonEncode({'version': 3, 'questions': []})), isNull);
      expect(
        QuizBank.parse(
          jsonEncode({
            'version': 3,
            'questions': [
              {'id': 'a', 'question': 'x', 'answer': true, 'active': false},
            ],
          }),
        ),
        isNull,
      );
      final b = QuizBank.parse(
        jsonEncode({
          'version': 3,
          'questions': [
            {'id': 'a', 'question': 'x', 'answer': 'yes'}, // 깨진 문항
            {'id': 'b', 'question': 'y', 'answer': true},
          ],
        }),
      )!;
      expect(b.questions.map((q) => q.id), ['b']);
    });

    test('번들 fallback: 원격 실패·깨짐·활성 0개면 캐시하지 않고 번들 사용', () async {
      final s = await store();
      final now = DateTime(2026, 10, 30, 9);
      expect(await s.refresh(2, now: now, fetch: () async => null), isFalse);
      expect(await s.refresh(2, now: now.add(const Duration(days: 1)), fetch: () async => '<html>'), isFalse);
      expect(
        await s.refresh(
          2,
          now: now.add(const Duration(days: 2)),
          fetch: () async => jsonEncode({'version': 9, 'questions': []}),
        ),
        isFalse,
      );
      expect(s.cached, isNull);
      expect((await s.load(readAsset: () async => bundled)).version, 2);
      // 예전 앱이 받아 둔 캐시가 깨져 있어도 번들
      final s2 = await store({'quiz_cache_v1': '{"version": 99, "questions": "망가짐"}'});
      expect((await s2.load(readAsset: () async => bundled)).questions, hasLength(452));
    });

    test('예전 id(q001~) 기록: 오류 없이, 날짜 기록(연속·오늘 제외)은 유지', () async {
      final today = quizDay(DateTime.now());
      final s = await store({
        'quiz_log_v1': [
          jsonEncode({'d': today, 'id': 'q001', 'c': true, 'ok': true}),
        ],
      });
      expect(s.streak(today), 1);
      expect(s.solvedOn(today), {'q001'});
      // 오늘의 문제는 새 풀에서 정상 출제
      final q = await s.next(bank, exclude: s.solvedOn(today));
      expect(q, isNotNull);
      expect(q!.id, isNot('q001'));
    });

    test('active=false 는 어디에도 출제 안 함', () async {
      final b = QuizBank(2, '', [
        const QuizQuestion(id: 'a', group: 'G', category: 'C', question: 'x', answer: true, explain: '', basis: ''),
        const QuizQuestion(
          id: 'b',
          group: 'G',
          category: 'C',
          question: 'y',
          answer: true,
          explain: '',
          basis: '',
          active: false,
        ),
      ]);
      final s = await store();
      for (var i = 0; i < 5; i++) {
        expect((await s.next(b))!.id, 'a');
      }
      expect(QuizStore.challengeSet(b, 10).map((q) => q.id), ['a']);
      expect(b.catCounts['G|C'], 1);
    });
  });

  group('B2·B3 챌린지 문항 수·분야 선택', () {
    test('문항 수 10/20/30/50, 기본 20, 부족하면 가능한 최대값으로', () async {
      expect(kChallengeSizes, [10, 20, 30, 50]);
      final s = await store();
      expect(s.challengeSize, 20);
      await s.setChallengeSize(30);
      expect(s.challengeSize, 30);
      expect(fitChallengeSize(20, 452), 20);
      expect(fitChallengeSize(50, 37), 30);
      expect(fitChallengeSize(20, 14), 10);
      expect(fitChallengeSize(20, 9), isNull);
    });

    test('분야 선택 저장: 챌린지·연습 따로, 없으면 null(전체)', () async {
      final s = await store();
      expect(s.cats(practice: false), isNull);
      await s.setCats({'서류·절차|위험성평가'}, practice: false);
      await s.setCats({'현장 안전기준|전기작업'}, practice: true);
      expect(s.cats(practice: false), {'서류·절차|위험성평가'});
      expect(s.cats(practice: true), {'현장 안전기준|전기작업'});
    });

    test('선택 분야에서만 출제 (챌린지·연습), 오늘의 퀴즈는 전체', () async {
      final keys = {'현장 안전기준|전기작업', '서류·절차|재해보고·서류'};
      final sub = bank.only(keys);
      expect(sub.active, hasLength(15 + 14));
      final set = QuizStore.challengeSet(sub, 20, random: Random(1));
      expect(set.map((q) => q.id).toSet(), hasLength(20));
      expect(set.every((q) => keys.contains(q.catKey)), isTrue);

      final s = await store();
      final got = <String>{};
      for (var i = 0; i < 29; i++) {
        final q = (await s.next(bank, exclude: got, where: (q) => keys.contains(q.catKey)))!;
        expect(keys.contains(q.catKey), isTrue);
        got.add(q.id);
      }
      expect(await s.next(bank, exclude: got, where: (q) => keys.contains(q.catKey)), isNull);
      // 오늘의 퀴즈(조건 없음)는 다른 분야에서도 나온다
      final cats = <String>{};
      for (var i = 0; i < 40; i++) {
        cats.add((await s.next(bank))!.catKey);
      }
      expect(cats.length, greaterThan(2));
    });

    test('분야별 정답률', () {
      final qs = [bank.byId('w001')!, bank.byId('w002')!, bank.byId('d001')!];
      final r = challengeByCategory(qs, [
        const QuizRecord('d', 'w001', true, true),
        const QuizRecord('d', 'w002', true, false),
        const QuizRecord('d', 'd001', true, true),
      ]);
      expect(r.map((c) => '${c.label} ${c.correct}/${c.n}'), [
        '현장 안전기준 · 추락·비계 1/2',
        '${bank.byId('d001')!.catLabel} 1/1',
      ]);
    });

    testWidgets('챌린지 시작: 전체 해제면 시작 불가·안내, 작은 분야면 큰 문항 수 비활성·자동 조정, 선택 저장', (tester) async {
      phone(tester, height: 6000); // 분야 칩이 많아 화면을 길게 (모든 버튼이 한 번에 보이게)
      final s = await store();
      await tester.pumpWidget(
        MaterialApp(
          home: ChallengeStartScreen(store: s, bank: () async => bank),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('선택된 문제 452개'), findsOneWidget);
      expect(find.text('발주자 의무 58'), findsOneWidget);

      ButtonStyleButton size(String n) =>
          tester.widget<ButtonStyleButton>(find.ancestor(of: find.text(n), matching: find.byType(OutlinedButton)));
      ButtonStyleButton startBtn() =>
          tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('시작'), matching: find.byType(FilledButton)));
      expect(size('10').onPressed, isNotNull);
      expect(startBtn().onPressed, isNotNull);

      await tester.tap(find.text('전체 해제'));
      await tester.pumpAndSettle();
      expect(find.text('분야를 하나 이상 골라 주세요'), findsWidgets);
      expect(startBtn().onPressed, isNull);
      expect(s.cats(practice: false), isEmpty);

      // 재해보고·서류(14문항)만 → 20·30·50 비활성, 기본 20 → 10 으로 자동 조정
      await tester.tap(find.text('재해보고·서류 14'));
      await tester.pumpAndSettle();
      expect(find.text('선택된 문제 14개'), findsWidgets);
      expect(size('10').onPressed, isNotNull);
      expect(size('20').onPressed, isNull);
      expect(size('50').onPressed, isNull);
      expect(startBtn().onPressed, isNotNull);
      final sel = tester.widget<OutlinedButton>(
        find.ancestor(of: find.text('10'), matching: find.byType(OutlinedButton)),
      );
      expect(sel.style!.backgroundColor!.resolve({}), isNot(Colors.white)); // 10 이 선택됨
      expect(s.cats(practice: false), {'서류·절차|재해보고·서류'});

      // 그룹 전체 토글
      await tester.tap(find.text('그룹 전체').first);
      await tester.pumpAndSettle();
      expect(s.cats(practice: false)!.where((k) => k.startsWith('현장 안전기준|')), hasLength(5));
      await tester.tap(find.text('전체 선택'));
      await tester.pumpAndSettle();
      expect(find.text('선택된 문제 452개'), findsOneWidget);
      // 연습 선택은 따로 (건드리지 않음)
      expect(s.cats(practice: true), isNull);
    });

    testWidgets('챌린지 진행 화면·한 문제 더 풀기에 분야 칩', (tester) async {
      phone(tester);
      final s = await store();
      await tester.pumpWidget(
        MaterialApp(
          home: ChallengeRunScreen(store: s, bank: bank.only({'현장 안전기준|전기작업'}), n: 10),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuizCategoryChip), findsOneWidget);
      expect(find.text('현장 안전기준 · 전기작업'), findsOneWidget);
      // 정리 (타이머)
      await tester.pumpWidget(const SizedBox());

      await tester.pumpWidget(
        MaterialApp(
          home: QuizPracticeScreen(store: s, bank: () async => bank),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuizCategoryChip), findsOneWidget);
      expect(find.text('분야: 전체'), findsOneWidget);
    });
  });

  group('C 요약표 틀고정', () {
    Future<void> pumpHome(WidgetTester tester, {double height = 2340, int pending = 30}) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('card_expense/native'),
        (_) async => null,
      );
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'card_digits': '0000',
        'sender_number': '1588-1600',
        'update_checked_at': now.millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(now),
        'expenses_v1': jsonEncode([
          for (var i = 0; i < pending; i++)
            {
              'id': 'p$i',
              'amount': 1000 + i,
              'dateTime': DateTime(now.year, now.month, 1, 9, i).toIso8601String(),
              'merchant': '가게$i',
              'isCancel': false,
              'raw': 'NH기업0000승인',
              'category': null,
            },
        ]),
      });
      phone(tester, height: height);
      final st = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: st));
      await tester.pumpAndSettle();
    }

    ScrollPosition lowerScroll(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable).last).position;

    testWidgets('위쪽 고정 + 구분선, 아래만 스크롤, 가로 스와이프 중 세로 이동 없음', (tester) async {
      await pumpHome(tester);
      // 요약표('수립')는 스크롤 영역 밖
      expect(find.ancestor(of: find.text('수립'), matching: find.byType(Scrollable)), findsNothing);
      expect(find.ancestor(of: find.text('분류 대기 30건'), matching: find.byType(Scrollable)), findsOneWidget);
      final top = tester.getTopLeft(find.text('수립'));

      // 아래 영역을 올려도 요약표는 그대로
      await tester.drag(find.text('분류 대기 30건'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(lowerScroll(tester).pixels, greaterThan(0));
      expect(tester.getTopLeft(find.text('수립')), top);
      lowerScroll(tester).jumpTo(0);
      await tester.pumpAndSettle();

      // 요약표 가로 스와이프(살짝 대각선): 다음 달로 넘어가고 아래 스크롤은 0 그대로
      final now = DateTime.now();
      final next = DateTime(now.year, now.month + 1);
      await tester.drag(find.text('수립'), const Offset(-200, 20));
      await tester.pumpAndSettle();
      expect(find.text('${next.year}년 ${next.month}월'), findsOneWidget);
      expect(lowerScroll(tester).pixels, 0);
      expect(tester.getTopLeft(find.text('수립')), top);
    });

    testWidgets('작은 화면(고정 영역이 절반 넘음)은 전체 스크롤', (tester) async {
      await pumpHome(tester, height: 1500); // 500dp
      await tester.pumpAndSettle();
      expect(find.ancestor(of: find.text('수립'), matching: find.byType(Scrollable)), findsOneWidget);
    });
  });

  group('E 편집 시트·업체 관리·메뉴', () {
    testWidgets('편집 시트에 [삭제] 없음 ([무시]·[미분류로 되돌리기]만)', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('card_expense/native'),
        (_) async => null,
      );
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'card_digits': '0000',
        'sender_number': '1588-1600',
        'update_checked_at': now.millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(now),
        'expenses_v1': jsonEncode([
          {
            'id': 'a',
            'amount': 5000,
            'dateTime': DateTime(now.year, now.month, 1, 12).toIso8601String(),
            'merchant': '분류가게',
            'isCancel': false,
            'raw': 'NH기업0000승인',
            'category': 'car',
          },
        ]),
      });
      phone(tester);
      await tester.pumpWidget(CardExpenseApp(store: await Store.open()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('분류가게'));
      await tester.pumpAndSettle();
      expect(find.text('무시'), findsOneWidget);
      expect(find.text('미분류로 되돌리기'), findsOneWidget);
      expect(find.text('삭제'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('업체 관리: 섹션별 전체 삭제(서로 영향 없음)·확인·되돌리기·0개면 비활성, 기본 키워드 다시 넣기', (tester) async {
      phone(tester);
      final b = VendorBook.initial()
        ..learn('고야커피', kOps)
        ..learn('홍성정비', kCar)
        ..keywords.insert(0, const KeywordRule('나의키워드', kOps));
      final total = b.keywords.length;
      await tester.pumpWidget(
        MaterialApp(
          home: VendorScreen(book: b, onChanged: () async {}),
        ),
      );
      await tester.pumpAndSettle();

      Finder delBtn(int i) => find.widgetWithText(TextButton, '전체 삭제').at(i);
      // 1) 자동 등록 업체 전체 삭제 (두 번째 버튼). 화면 아래쪽이라 먼저 스크롤
      await tester.scrollUntilVisible(find.text('자동 등록된 업체'), 500);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '전체 삭제').last);
      await tester.pumpAndSettle();
      expect(find.text('자동 등록 업체 2개를 모두 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(b.learned, isEmpty);
      expect(b.keywords, hasLength(total)); // 키워드는 그대로
      expect(find.text('자동 등록 업체를 모두 삭제했어요'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(b.learned, hasLength(2));

      // 2) 추천 키워드 전체 삭제 → 업체는 그대로, 기본 키워드는 지운 목록에
      await tester.scrollUntilVisible(find.text('추천 키워드'), -500);
      await tester.pumpAndSettle();
      await tester.tap(delBtn(0));
      await tester.pumpAndSettle();
      expect(find.text('추천 키워드 $total개를 모두 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(b.keywords, isEmpty);
      expect(b.learned, hasLength(2));
      expect(b.removedDefaults, contains(keywordKey('스타벅스')));
      // 0개면 버튼 비활성
      expect(tester.widget<TextButton>(delBtn(0)).onPressed, isNull);
      // 지운 기본 키워드는 업데이트(버전 올라감)로 되살아나지 않음
      b.defaultsVersion = 1;
      b.upgradeDefaults();
      expect(b.keywords, isEmpty);

      // 3) 기본 키워드 다시 넣기
      await tester.tap(find.text('기본 키워드 다시 넣기'));
      await tester.pumpAndSettle();
      final n = kDefaultCarKeywords.length + kDefaultOpsKeywords.length;
      expect(b.keywords, hasLength(n));
      expect(b.removedDefaults, isEmpty);
      expect(find.text('$n개를 다시 넣었어요'), findsOneWidget);
      expect(b.restoreDefaults(), 0); // 이미 있으면 건너뜀
    });

    testWidgets('메뉴: 등록 업체가 안전 OX Quiz 위, QUIZ 아이콘', (tester) async {
      phone(tester);
      Future<void> noop() async {}
      await tester.pumpWidget(
        MaterialApp(
          home: MenuScreen(
            onImport: noop,
            onPaste: noop,
            onOcr: noop,
            onVendors: noop,
            onUpdate: noop,
            importEnabled: () => true,
            onSettings: noop,
            cardSummary: () => '카드 0000',
            onPermissions: noop,
            permSummary: () => '',
            onAppSettings: noop,
            appSettingsSummary: () => '매일 OX 퀴즈 꺼짐',
            quizSummary: () => '연속 3일',
            onQuiz: noop,
            counts: () => (pending: 0, check: 0, ignored: 0, confirmed: 0),
            onUnclassified: noop,
            onCheck: noop,
            onIgnored: noop,
            onConfirmed: noop,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final vendorY = tester.getTopLeft(find.text('등록 업체·추천 키워드')).dy;
      final quizY = tester.getTopLeft(find.text('안전 OX Quiz')).dy;
      expect(vendorY, lessThan(quizY));
      expect(find.text('안전 OX'), findsNothing);
      expect(find.text('연속 3일'), findsOneWidget);
      final icon = find.byType(QuizIcon);
      expect(icon, findsOneWidget);
      expect(tester.getSize(icon), const Size(24, 24));
      expect(find.ancestor(of: icon, matching: find.byType(ListTile)), findsOneWidget);
    });
  });
}
