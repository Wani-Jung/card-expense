import 'dart:convert';
import 'dart:io';

import 'package:card_expense/category_badge.dart';
import 'package:card_expense/check.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/import_screen.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/onboarding_screen.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/quiz_screens.dart';
import 'package:card_expense/review_screens.dart';
import 'package:card_expense/rural_quiz.dart';
import 'package:card_expense/rural_quiz_screens.dart';
import 'package:card_expense/snack.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:card_expense/vendor.dart';
import 'package:card_expense/vendor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-47: 캡처 제거, 날짜 이상 1회 판정(check_test), 기간 불러오기, 백업 규칙, 키워드 정리·칩·지운 키워드,
/// 스낵바 자동 닫힘, 확인 카드 강조, 줄바꿈, 첫 실행 사용법, 실험실·농어촌정비법 퀴즈.
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

  group('A1 캡처(OCR) 제거', () {
    test('파일·의존성이 없다', () {
      for (final f in [
        'lib/ocr_parse.dart',
        'lib/ocr_screen.dart',
        'android/app/src/main/kotlin/com/wani/card_expense/ImageSlicer.kt',
      ]) {
        expect(File(f).existsSync(), isFalse, reason: f);
      }
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('google_mlkit')));
      expect(pubspec, isNot(contains('image_picker')));
      expect(File('android/app/build.gradle.kts').readAsStringSync(), isNot(contains('mlkit')));
      expect(File('PRIVACY.md').readAsStringSync(), isNot(contains('ML Kit')));
    });
  });

  group('A3 지난 문자 불러오기 기간', () {
    final now = DateTime(2026, 11, 10, 15);

    test('빠른 선택', () {
      ({DateTime from, DateTime to}) r(QuickRange q) => q.range(now);
      expect(r(QuickRange.thisMonth), (from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 10)));
      expect(r(QuickRange.lastMonth), (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31)));
      expect(r(QuickRange.months3), (from: DateTime(2026, 8, 10), to: DateTime(2026, 11, 10)));
      expect(r(QuickRange.year1), (from: DateTime(2025, 11, 10), to: DateTime(2026, 11, 10)));
      expect(defaultImportRange(now), r(QuickRange.year1));
      // 1월의 지난달 = 작년 12월
      expect(QuickRange.lastMonth.range(DateTime(2027, 1, 5)), (from: DateTime(2026, 12, 1), to: DateTime(2026, 12, 31)));
    });

    test('기간 경계: 시작>종료·미래 막기, 1년보다 이른 시작 허용, 종료일 그날 끝까지', () {
      expect(importRangeError(DateTime(2026, 11, 5), DateTime(2026, 11, 4), now), contains('시작일이 종료일보다'));
      expect(importRangeError(DateTime(2026, 11, 1), DateTime(2026, 11, 11), now), contains('미래'));
      expect(importRangeError(DateTime(2020, 1, 1), DateTime(2026, 11, 10), now), isNull);
      expect(importRangeError(DateTime(2026, 11, 10), DateTime(2026, 11, 10), now), isNull); // 하루
      final q = importQueryRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(q.start, DateTime(2026, 10, 1));
      expect(q.end, DateTime(2026, 11, 1)); // 미포함
    });

    testWidgets('미리보기 \'이 기간 승인 문자 n건 (새 n · 중복 n)\' → [불러오기] 로 넘김', (tester) async {
      phone(tester);
      final fresh = parseSms('NH기업0000승인 공용카드 10,000원 체크 10/20 12:00 가게', cardDigits: '0000', receivedAt: now)!;
      final fresh2 = parseSms('NH기업0000승인 공용카드 20,000원 체크 10/21 12:00 가게', cardDigits: '0000', receivedAt: now)!;
      DateTime? start, end;
      ImportPreview? popped;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => popped = await Navigator.of(ctx).push<ImportPreview>(MaterialPageRoute(
                builder: (_) => ImportRangeScreen(
                  clock: () => now,
                  preview: (s, e) async {
                    start = s;
                    end = e;
                    return ImportPreview(const InboxScan([], 5, 1), IngestReport(fresh: [fresh, fresh2], dup: 1));
                  },
                ),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('2025.11.10'), findsOneWidget);
      expect(find.text('2026.11.10'), findsOneWidget);
      await tester.tap(find.text('지난달'));
      await tester.pumpAndSettle();
      expect(find.text('2026.10.01'), findsOneWidget);
      expect(find.text('2026.10.31'), findsOneWidget);
      await tester.tap(find.text('이 기간 문자 확인'));
      await tester.pumpAndSettle();
      expect(start, DateTime(2026, 10, 1));
      expect(end, DateTime(2026, 11, 1));
      expect(find.text('이 기간 승인 문자 3건'), findsOneWidget);
      expect(find.text('(새 2 · 중복 1)'), findsOneWidget);
      await tester.tap(find.text('불러오기'));
      await tester.pumpAndSettle();
      expect(popped!.report.fresh, hasLength(2));
    });
  });

  group('A4 백업 규칙', () {
    test('allowBackup + 클라우드 백업 전부 제외 + 기기 이전 전부 포함, 11 이하 전부 제외', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:allowBackup="true"'));
      expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
      final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
      final cloud = RegExp(r'<cloud-backup>([\s\S]*?)</cloud-backup>').firstMatch(rules)!.group(1)!;
      for (final d in [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
        'device_root',
        'device_file',
        'device_database',
        'device_sharedpref',
      ]) {
        expect(cloud, contains('<exclude domain="$d" path="." />'), reason: d);
      }
      expect(cloud, isNot(contains('<include')));
      expect(rules, contains('<device-transfer />')); // 비어 있으면 전부 포함
      final old = File('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync();
      for (final d in ['root', 'file', 'database', 'sharedpref', 'external']) {
        expect(old, contains('<exclude domain="$d" path="." />'), reason: d);
      }
    });
  });

  group('B 키워드', () {
    // v3 에서 기본 목록에서 뺀 키워드의 분류
    const removedOps = ['식육식당', '버거킹', '메가커피', '이마트24', '하나로마트'];
    String catOf(String w) => removedOps.contains(w) ? kOps : kCar;

    test('B1 알파문구·드림디포 운영비 기본 키워드, 버전 3', () {
      expect(kDefaultOpsKeywords, containsAll(['알파문구', '드림디포']));
      expect(kDefaultKeywordsVersion, 3);
      expect(VendorBook.initial().recommend('드림디포 홍성점')!.category, kOps);
    });

    // 차량비·운영비 키워드가 한 이름에 같이 있으면(예: '하나로마트 주유소') 길이 비교가 달라져 바뀔 수 있다 → 보고에 따로 적음
    test('B2 뺀 기본 키워드: 더 짧은 같은 분류 기본 키워드가 덮어서 추천 결과가 같다', () {
      final now = VendorBook.initial();
      final before = VendorBook({}, [
        ...defaultKeywordRules(),
        for (final w in kRemovedDefaultKeywords) KeywordRule(w, catOf(w), isDefault: true),
      ]);
      for (final k in kRemovedDefaultKeywords) {
        final same = [
          ...(catOf(k) == kCar ? kDefaultCarKeywords : kDefaultOpsKeywords),
          ...kRemovedDefaultKeywords.where((w) => catOf(w) == catOf(k)),
        ];
        expect(now.keywords.map((r) => r.key), isNot(contains(keywordKey(k))));
        // 그 키워드만 / 앞뒤에 다른 글자 / 같은 분류 기본 키워드와 같이 있는 가맹점 이름
        final names = [k, '홍성$k점', '(주)$k 본점', for (final o in same) ...['$k $o', '$o $k']];
        for (final n in names) {
          expect(now.recommend(n)?.category, before.recommend(n)?.category, reason: '$k: $n');
        }
        expect(now.recommend(k)!.category, catOf(k));
      }
    });

    test('B2 기존 기기 정리: 덮는 키워드가 남아 있을 때만, 직접 등록은 그대로, 지운 키워드에 안 나옴', () {
      final book = VendorBook(
        {},
        [
          const KeywordRule('주유', kCar, isDefault: true),
          const KeywordRule('주유소', kCar, isDefault: true),
          const KeywordRule('셀프주유', kCar, isDefault: true),
          const KeywordRule('SK에너지', kCar, isDefault: true), // '에너지'를 지운 기기 → 남김
          const KeywordRule('하나로마트', kOps), // 직접 등록 → 그대로
          const KeywordRule('마트', kOps, isDefault: true),
        ],
        defaultsVersion: 2,
        removedDefaults: {keywordKey('에너지'), keywordKey('문구')},
      );
      expect(book.upgradeDefaults(), isTrue);
      final keys = book.keywords.map((k) => k.keyword).toList();
      expect(keys, containsAll(['주유', 'SK에너지', '하나로마트', '마트', '알파문구', '드림디포']));
      expect(keys, isNot(contains('주유소')));
      expect(keys, isNot(contains('셀프주유')));
      expect(book.keywords.firstWhere((k) => k.keyword == '하나로마트').isDefault, isFalse);
      expect(book.removedKeywords.map((k) => k.keyword), isNot(contains('주유소')));
      expect(book.defaultsVersion, 3);
    });

    test('B4 지운 키워드: 직접 등록도 분류와 함께 기억, 골라 다시 넣기, 영구 삭제해도 업데이트로 안 되살아남', () {
      final b = VendorBook.initial()..keywords.insert(0, const KeywordRule('나의가게', kCar));
      b.removeKeyword(b.keywords.firstWhere((k) => k.keyword == '나의가게'));
      b.removeKeyword(b.keywords.firstWhere((k) => k.keyword == '스타벅스'));
      b.removeKeyword(b.keywords.firstWhere((k) => k.keyword == '세차'));
      final r = b.removedKeywords;
      expect(r.map((k) => k.keyword), unorderedEquals(['나의가게', '스타벅스', '세차']));
      expect(r.firstWhere((k) => k.keyword == '나의가게').category, kCar);

      // 저장·읽기
      final back = VendorBook.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(back.removedKeywords.map((k) => k.keyword), unorderedEquals(['나의가게', '스타벅스', '세차']));

      expect(back.restoreRemoved(back.removedKeywords.where((k) => k.keyword == '나의가게')), 1);
      expect(back.recommend('나의가게 본점')!.category, kCar);
      back.purgeRemoved(back.removedKeywords.where((k) => k.keyword == '스타벅스'));
      expect(back.removedKeywords.map((k) => k.keyword), ['세차']);
      back.defaultsVersion = 2;
      back.upgradeDefaults();
      expect(back.keywords.map((k) => k.keyword), isNot(contains('스타벅스')));
      expect(back.keywords.map((k) => k.keyword), isNot(contains('세차')));
    });

    testWidgets('B3·B4 칩 화면: 묶음별 칩, 지운 키워드 (n) → 골라 다시 넣기·영구 삭제', (tester) async {
      phone(tester);
      final b = VendorBook.initial()..addKeyword(const KeywordRule('나의가게', kOps));
      await tester.pumpWidget(MaterialApp(home: VendorScreen(book: b, onChanged: () async {})));
      await tester.pumpAndSettle();
      expect(find.byType(KeywordChip), findsNWidgets(b.keywords.length));
      expect(find.text('지운 키워드 (0)'), findsNothing); // 0개면 숨김
      expect(find.text('기본 키워드 다시 넣기'), findsNothing);

      // 칩 → 바텀시트 [삭제] → 확인 → 지운 키워드 1
      await tester.tap(find.widgetWithText(KeywordChip, '나의가게'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('빼기'));
      await tester.pumpAndSettle();
      expect(b.keywords.map((k) => k.keyword), isNot(contains('나의가게')));
      expect(find.text('되돌리기'), findsOneWidget);
      await tester.tap(find.widgetWithText(KeywordChip, '세차'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('빼기'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('지운 키워드 (2)'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('지운 키워드 (2)'));
      await tester.pumpAndSettle();
      expect(find.text('직접 등록'), findsOneWidget);
      expect(find.text('기본 키워드'), findsOneWidget);
      await tester.tap(find.text('나의가게'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 넣기 (1)'));
      await tester.pumpAndSettle();
      expect(b.keywords.firstWhere((k) => k.keyword == '나의가게').category, kOps);
      expect(find.text('지운 키워드 (1)'), findsOneWidget);

      await tester.tap(find.text('세차'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('영구 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '영구 삭제').last);
      await tester.pumpAndSettle();
      expect(b.removedKeywords, isEmpty);
      expect(b.removedDefaults, contains(keywordKey('세차'))); // 업데이트로 되살리지 않는 기록은 유지
      expect(find.text('지운 키워드가 없어요'), findsOneWidget);
    });
  });

  group('C 화면·문구', () {
    testWidgets('C1 스낵바: [되돌리기]가 있어도 몇 초 뒤 저절로 닫힘, 버튼 글자는 밝은 색', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(
                appSnackBar(content: const Text('지웠어요'), action: SnackBarAction(label: '되돌리기', onPressed: () {})),
              ),
              child: const Text('보이기'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('보이기'));
      await tester.pumpAndSettle();
      expect(find.text('지웠어요'), findsOneWidget);
      final label = tester.widget<Text>(find.descendant(of: find.byType(SnackBarAction), matching: find.byType(Text)));
      expect(label.style?.color ?? DefaultTextStyle.of(tester.element(find.text('되돌리기'))).style.color, kSnackAction);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('지웠어요'), findsNothing);
      // 앱 코드에 persist 를 따로 정하는 SnackBar( 직접 생성이 남아 있지 않다
      for (final f in Directory('lib').listSync().whereType<File>()) {
        if (f.path.endsWith('snack.dart') || f.path.endsWith('onboarding_screen.dart')) continue;
        expect(RegExp(r'(?<![A-Za-z])SnackBar\(').hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    testWidgets('C2 확인 카드: [이대로 맞아요] 지금 분류 색 채움, [X로 변경] 테두리만', (tester) async {
      phone(tester);
      final e = Expense(
        id: 'a',
        amount: 1000,
        dateTime: DateTime(2026, 10, 1),
        merchant: '가게',
        isCancel: false,
        raw: '',
        category: kCar,
      );
      await tester.pumpWidget(MaterialApp(
        home: CheckScreen(
          issues: () => [CheckIssue(CheckRule.oddDate, e, '날짜')],
          changes: ValueNotifier(0),
          onChange: (_, _) async {},
          onOk: (_) async {},
          onIgnoreDuplicate: (_, _) async {},
          onConfirmCancel: (_) async {},
          button: (cat, rec, onPressed, {label}) => const SizedBox(),
        ),
      ));
      final keep = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '이대로 맞아요'));
      expect(keep.style!.backgroundColor!.resolve({}), kCarColor);
      final change = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '운영비로 변경'));
      expect(change.style!.side!.resolve({})!.color, kOpsColor);
      expect(change.style!.backgroundColor, isNull);
    });

    test('C3 카드번호 설명: 괄호부터 다음 줄, 단어 안에서 안 끊김', () {
      expect(kDigitsHelp, '승인 문자에 적힌 카드번호 네자리\n(예: "NH기업0000승인" 이면 0000)');
      final k = keepWords('카드번호 네자리');
      expect(k.replaceAll('⁠', ''), '카드번호 네자리');
      expect(k, '카⁠드⁠번⁠호 네⁠자⁠리');
      expect(keepWords(k), k); // 두 번 해도 같음
    });

    Future<Store> pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({
        'update_checked_at': DateTime.now().millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(DateTime.now()),
        'notif_asked_v1': true,
        ...prefs,
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('C4 첫 실행: 사용법 3단계 (수립 → 카드 설정 → 지난 결제), 카드 설정은 한 번만', (tester) async {
      final store = await pumpApp(tester, {});
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('이번 달 수립 금액'), findsOneWidget);
      // 건너뛰기 해도 카드 설정은 꼭 필요 → 2단계로
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('카드번호 네자리와 발신번호는 꼭 넣어야 시작할 수 있어요'), findsOneWidget);
      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '전체 (합계)'), '30');
      await tester.enterText(find.widgetWithText(TextField, '차량비'), '10');
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      final month = store.loadBudgets().forMonth(DateTime.now());
      expect((month.total, month.car), (300000, 100000));
      expect(find.text(keepWords(kDigitsHelp)), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, '0000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(store.cardDigits, '0000');
      expect(store.senderNumber, kDefaultSender);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('지난 결제 넣기'), findsOneWidget); // 일반판 (테스트는 flavor 없음)
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('메뉴'), findsOneWidget);
      expect(find.text('카드 문자 설정'), findsNothing); // 따로 또 묻지 않음
    });

    testWidgets('C4 기존 사용자(카드 설정 있음)는 자동으로 안 뜸, 메뉴 > 사용법에서 다시 보기', (tester) async {
      await pumpApp(tester, {'card_digits': '1234', 'sender_number': '1588-1600'});
      expect(find.text('1 / 3'), findsNothing);
      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사용법'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('1234'), findsOneWidget);
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(find.text('메뉴'), findsOneWidget); // 메뉴로 돌아옴
    });
  });

  group('D 실험실·농어촌정비법 퀴즈', () {
    test('D3 문제 파일: 198문항(객관식 59), 채점, 옛 questions.json 은 형식·내용 그대로', () {
      final bank = RuralBank.parse(File('quiz/rural_questions.json').readAsStringSync())!;
      expect(bank.questions, hasLength(198));
      expect(bank.questions.where((q) => q.isChoice), hasLength(59));
      expect(bank.groups.single.categories, hasLength(8));
      final c = bank.questions.firstWhere((q) => q.isChoice);
      expect(c.choices, hasLength(4));
      expect(c.isCorrect(c.answer), isTrue);
      expect(c.isCorrect(c.answer % 4 + 1), isFalse);
      expect(c.label(3), '3번');
      final o = bank.questions.firstWhere((q) => !q.isChoice);
      expect(o.label(1), 'O');
      expect(o.label(0), 'X');

      // 안전 OX 파일은 v2 형식 그대로 (옛 앱이 원격으로 받는 파일)
      final ox = jsonDecode(File('quiz/questions.json').readAsStringSync()) as Map<String, dynamic>;
      final qs = ox['questions'] as List;
      expect(qs.every((q) => (q as Map)['answer'] is bool && !q.containsKey('type') && !q.containsKey('choices')), isTrue);
      expect((ox['groups'] as List).map((g) => (g as Map)['name']), ['현장 안전기준', '서류·절차']);
      expect(QuizBank.parse(File('quiz/questions.json').readAsStringSync()), isNotNull);
      expect(File('pubspec.yaml').readAsStringSync(), contains('- quiz/rural_questions.json'));
    });

    test('D3 기록은 안전 OX 와 따로 (키 분리, 정답률 안 섞임)', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final rural = RuralStore(p);
      await rural.record(const RuralRecord('2026-11-10', 'r001', 1, true));
      await rural.record(const RuralRecord('2026-11-10', 'r002', 2, false));
      expect(rural.percent, 50);
      expect(p.getStringList('quiz_log_v1'), isNull);
      final quiz = QuizStore(p);
      expect(quiz.solvedCount, 0);
      expect(quiz.percent, isNull);
      expect(quiz.streak('2026-11-10'), 0);
    });

    const json = '''{"version":1,"updated":"","groups":[{"name":"농어촌정비법","categories":["벌칙"]}],
      "questions":[{"id":"r001","group":"농어촌정비법","category":"벌칙","type":"choice","question":"문제A",
      "choices":["보기가","보기나","보기다","보기라"],"answer":3,"explain":"해설A","basis":"법 제1조","active":true}]}''';

    testWidgets('D3 객관식 풀기: 틀리면 정답 번호·해설, 기록, 지난 문제에서 [해설] 말풍선', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final store = RuralStore(await SharedPreferences.getInstance());
      final bank = RuralBank.parse(json)!;
      await tester.pumpWidget(MaterialApp(home: RuralPracticeScreen(store: store, bank: () async => bank)));
      await tester.pumpAndSettle();
      expect(find.text(keepWords('문제A')), findsOneWidget);
      expect(find.text('객관식'), findsOneWidget);
      await tester.tap(find.text(keepWords('보기나')));
      await tester.pumpAndSettle();
      expect(find.text('아쉬워요. 정답은 3번'), findsOneWidget);
      expect(find.text(keepWords('해설A')), findsOneWidget);
      expect(store.records.single.pick, 2);
      expect(store.records.single.correct, isFalse);

      await tester.pumpWidget(MaterialApp(home: RuralHistoryScreen(store: store, bank: () async => bank)));
      await tester.pumpAndSettle();
      expect(find.text('내 답 2번 → 정답 3번'), findsOneWidget);
      expect(find.text('해설A'), findsNothing);
      await tester.tap(find.text('해설'));
      await tester.pumpAndSettle();
      expect(find.byType(QuizExplainBubble), findsOneWidget);
      expect(find.text('해설A'), findsOneWidget);
    });

    testWidgets('D2 안전 OX 화면 순서: 매일 OX → 챌린지 → 한 문제 더 → 지난 문제 → 점수 기록 지우기', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final store = QuizStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(home: QuizHomeScreen(store: store, bank: () async => const QuizBank(1, '', []))));
      await tester.pumpAndSettle();
      final order = ['푼 문제', '매일 OX 퀴즈', '안전 OX 챌린지', '한 문제 더 풀기', '지난 문제 다시 보기', '점수 기록 지우기'];
      final ys = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]), reason: order[i]);
      }
    });
  });
}
