import 'dart:io';

import 'package:card_expense/flavor.dart';
import 'package:card_expense/lab_screen.dart';
import 'package:card_expense/law_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-62: 스토어판에도 법령 Quiz + 출처·'정부와 무관' 고지 (Google Play 정부 정보 앱 정책)
void main() {
  test('법령 Quiz 는 두 채널 모두 보임', () {
    expect(kRuralQuizInStore, isTrue);
    expect(kShowRuralQuiz, isTrue, reason: isStoreChannel ? '스토어' : '깃허브');
  });

  test('기준일은 내장 문제 파일의 updated', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await lawQuizBaseDate(), matches(RegExp(r'^\d{4}\.\d{2}\.\d{2}$')));
    expect(lawBaseDateText('2026-11-16'), '2026.11.16');
  });

  testWidgets('고지: 출처(누르면 law.go.kr)·정부와 무관·기준일', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LawSourceNotice(baseDate: Future.value('2026.11.16'), open: (u) async => opened.add(u)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('법령 원문 출처: 국가법령정보센터(law.go.kr)'), findsOneWidget);
    expect(
      find.text(lawDisclaimerText('2026.11.16')),
      findsOneWidget,
    );
    await tester.tap(find.text('법령 원문 출처: 국가법령정보센터(law.go.kr)'));
    expect(opened, [Uri.parse('https://www.law.go.kr')]);
  });

  testWidgets('실험실: 법령 Quiz 4종 아래에 고지', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Future<void> noop() async {}
    await tester.pumpWidget(
      MaterialApp(
        home: LabScreen(quizSummary: () => '', onQuiz: noop, onLaw: (_) => noop()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('건축법 Quiz'), findsOneWidget);
    final notice = find.text('법령 원문 출처: 국가법령정보센터(law.go.kr)');
    expect(notice, findsOneWidget);
    expect(tester.getTopLeft(notice).dy, greaterThan(tester.getTopLeft(find.text('건축법 Quiz')).dy));
  });

  test('특정 기관 공식 앱처럼 보이는 표현 없음 (공유 카드 기본 부제·앱 이름)', () {
    expect(File('lib/challenge_card.dart').readAsStringSync(), contains("this.subtitle = '현장 안전 OX'"));
    expect(kAppName.contains('공사'), isFalse);
    // 화면 문구에 기관 이름이 없어야 한다 (가맹점 추천 키워드 vendor.dart 는 제외)
    for (final f in Directory('lib').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('vendor.dart')) continue;
      expect(f.readAsStringSync().contains('한국농어촌공사'), isFalse, reason: f.path);
    }
  });
}
