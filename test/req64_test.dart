import 'package:card_expense/app_update.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/notice_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-64: '버전 정보'(스토어)·'업데이트 확인'(깃허브)을 누르면 같은 모양 결과 팝업 세 가지
void main() {
  group('Play 인앱 업데이트 응답 → 결과', () {
    Future<UpdateStatus> of(Map<String, dynamic> m) async =>
        (await checkPlayUpdate('2.0.1', check: () async => m)).status;
    test('available / latest / error·모름·예외', () async {
      expect(await of({'status': 'available', 'versionCode': 742}), UpdateStatus.available);
      expect(await of({'status': 'latest'}), UpdateStatus.latest);
      expect(await of({'status': 'error', 'message': 'Install Error(-10)'}), UpdateStatus.failed);
      expect(await of({}), UpdateStatus.failed);
      final c = await checkPlayUpdate('2.0.1', check: () async => throw PlatformException(code: 'x'));
      expect(c.status, UpdateStatus.failed);
      expect(c.current, '2.0.1');
    });
  });

  group('결과 팝업', () {
    Future<void> open(WidgetTester tester, Widget dialog) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(context: ctx, builder: (_) => dialog),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    testWidgets('스토어 업데이트 있음: [업데이트] 누르면 닫고 업데이트, [나중에]는 닫기만', (tester) async {
      var updated = 0;
      await open(
        tester,
        updateResultDialog(
          const UpdateCheck(UpdateStatus.available, '2.0.1'),
          store: true,
          onUpdate: () => updated++,
        ),
      );
      expect(find.byType(NoticeInfoIcon), findsOneWidget);
      expect(find.text('새 버전이 있어요'), findsOneWidget);
      expect(find.text(keepWords('지금 v2.0.1 쓰는 중이에요.')), findsOneWidget);
      expect(find.text('나중에'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '업데이트'));
      await tester.pumpAndSettle();
      expect(updated, 1);
      expect(find.text('새 버전이 있어요'), findsNothing);
    });

    testWidgets('최신: 버전·판, [확인] 하나', (tester) async {
      await open(tester, updateResultDialog(const UpdateCheck(UpdateStatus.latest, '2.0.1'), store: true));
      expect(find.text('최신 버전이에요'), findsOneWidget);
      expect(find.text(keepWords('v2.0.1')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '확인'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget); // '열기' 버튼만 (팝업엔 보조 버튼 없음)
    });

    testWidgets('스토어 확인 실패: [Play 스토어에서 보기] + [닫기]', (tester) async {
      var store = 0;
      await open(
        tester,
        updateResultDialog(const UpdateCheck(UpdateStatus.failed, '2.0.1'), store: true, onStore: () => store++),
      );
      expect(find.text('지금은 확인할 수 없어요'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
      await tester.tap(find.text('Play 스토어에서 보기'));
      await tester.pumpAndSettle();
      expect(store, 1);
    });

    testWidgets('깃허브: 업데이트 있음은 새 버전 태그 + [내려받기], 실패는 [확인]만', (tester) async {
      var down = 0;
      await open(
        tester,
        updateResultDialog(
          const UpdateCheck(UpdateStatus.available, '2.0.1', 'v2.0.2'),
          store: false,
          onUpdate: () => down++,
        ),
      );
      expect(find.text(keepWords('지금 v2.0.1 쓰는 중이에요.\n새 버전: v2.0.2')), findsOneWidget);
      await tester.tap(find.text('내려받기'));
      await tester.pumpAndSettle();
      expect(down, 1);

      await open(tester, updateResultDialog(const UpdateCheck(UpdateStatus.failed, '2.0.1'), store: false));
      expect(find.text('지금은 확인할 수 없어요'), findsOneWidget);
      expect(find.text('Play 스토어에서 보기'), findsNothing);
      expect(find.widgetWithText(FilledButton, '확인'), findsOneWidget);
    });
  });
}
