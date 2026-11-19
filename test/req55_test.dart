import 'package:card_expense/budget.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/notice_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-55: 차량비 잔여 경고 팝업 다듬기 (공용 안내 팝업 NoticeDialog, 줄 나눈 문구, 숫자 칸 두 개).
void main() {
  Future<void> pumpWarn(WidgetTester tester, int carRem, int totalRem, MoneyUnit u, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: NoticeDialog(
              icon: const WarnBadge(size: 26),
              title: kCarRemainWarnTitle,
              stats: [
                NoticeStat('차량비 잔여', moneyWithUnit(carRem, u)),
                NoticeStat('전체 잔여', totalRemainWithUnit(totalRem, u), highlight: true),
              ],
              body: carRemainWarnMessage(carRem, totalRem, u),
            ),
          ),
        ),
      ),
    );
  }

  test('문구는 직접 줄을 나눈다 (빈 줄로 두 문단)', () {
    expect(carRemainWarnMessage(101000, 64000, MoneyUnit.won).split('\n'), [
      '차량비는 101,000원 남았지만,',
      '운영비가 초과돼서',
      '전체 남은 돈은 64,000원이에요.',
      '',
      '차량비를 다 쓰면 총액을 넘으니',
      '유의하세요.',
    ]);
    expect(carRemainWarnMessage(101000, -50000, MoneyUnit.won).split('\n'), [
      '차량비는 101,000원 남았지만,',
      '운영비 초과로',
      '전체는 이미 50,000원 초과예요.',
      '',
      '차량비를 더 쓰면 초과 금액이 커지니',
      '유의하세요.',
    ]);
  });

  test('숫자 칸 금액: 선택 단위·반올림 규칙 그대로', () {
    expect(moneyWithUnit(101000, MoneyUnit.won), '101,000원');
    expect(moneyWithUnit(101000, MoneyUnit.thousand), '101천원');
    expect(moneyWithUnit(345000, MoneyUnit.man), '35만원');
    expect(moneyWithUnit(12345000, MoneyUnit.man), '1,235만원');
    expect(totalRemainWithUnit(64000, MoneyUnit.won), '64,000원');
    expect(totalRemainWithUnit(-50000, MoneyUnit.won), '초과 50,000원');
    expect(totalRemainWithUnit(-1500, MoneyUnit.thousand), '초과 2천원');
  });

  for (final (u, car, total) in [
    (MoneyUnit.won, '101,000원', '64,000원'),
    (MoneyUnit.thousand, '101천원', '64천원'),
    (MoneyUnit.man, '10만원', '6만원'),
  ]) {
    testWidgets('팝업: 제목·숫자 칸 두 개·줄 나눈 본문·골드 [확인] (${u.label})', (tester) async {
      await pumpWarn(tester, 101000, 64000, u);
      expect(find.text(kCarRemainWarnTitle), findsOneWidget);
      expect(find.byType(WarnBadge), findsOneWidget);
      expect(find.text('차량비 잔여'), findsOneWidget);
      expect(find.text('전체 잔여'), findsOneWidget);
      expect(find.text(car), findsOneWidget);
      expect(find.text(total), findsOneWidget);
      expect(find.text(keepWords(carRemainWarnMessage(101000, 64000, u))), findsOneWidget);
      // 칸은 가로로 나란히 (차량비 잔여 왼쪽, 전체 잔여 오른쪽)
      expect(tester.getCenter(find.text(car)).dx, lessThan(tester.getCenter(find.text(total)).dx));
      expect((tester.getCenter(find.text(car)).dy - tester.getCenter(find.text(total)).dy).abs(), lessThan(1));
      // 전체 잔여 숫자가 더 진하게
      expect(tester.widget<Text>(find.text(total)).style!.fontWeight, FontWeight.w800);
      // [확인]: 골드 채운 둥근 버튼, 오른쪽 아래
      final ok = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '확인'));
      expect(ok.style!.backgroundColor!.resolve({}), kGold);
      expect(ok.style!.shape!.resolve({}), isA<StadiumBorder>());
      // 팝업 카드(Dialog 안 Material) 기준. Dialog 자체는 바깥 여백까지 포함
      final dialog = tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
      final btn = tester.getRect(find.widgetWithText(FilledButton, '확인'));
      expect(dialog.right - btn.right, lessThan(30));
      expect(dialog.bottom - btn.bottom, lessThan(24)); // 아래 빈 공간 적게
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('경고 표시(요약표)와 팝업 아이콘은 같은 공용 위젯·같은 색', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: WarnBadge(size: 19))));
    final box = tester.widget<Container>(find.descendant(of: find.byType(WarnBadge), matching: find.byType(Container)));
    expect((box.decoration! as BoxDecoration).color, kCarWarn);
    expect((box.decoration! as BoxDecoration).shape, BoxShape.circle);
    expect(tester.widget<Text>(find.text('!')).style!.color, Colors.white);
  });

  testWidgets('다크 모드에서도 읽힘 (글자는 밝게, 바탕은 어둡게)', (tester) async {
    await pumpWarn(tester, 101000, -50000, MoneyUnit.won, theme: ThemeData.dark());
    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.text(kCarRemainWarnTitle));
    expect(title.style!.color!.computeLuminance(), greaterThan(0.6));
    final body = tester.widget<Text>(find.text(keepWords(carRemainWarnMessage(101000, -50000, MoneyUnit.won))));
    expect(body.style!.color!.computeLuminance(), greaterThan(0.4));
    final dialogBg = Theme.of(tester.element(find.byType(Dialog))).colorScheme.surface;
    expect(dialogBg.computeLuminance(), lessThan(0.2));
    expect(find.text('초과 50,000원'), findsOneWidget);
  });
}
