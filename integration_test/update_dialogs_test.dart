// '버전 정보' 결과 팝업 세 가지 캡처 (REQ-64 보고용). 실제 앱 테마·글꼴로 팝업만 띄워 찍는다.
//
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/update_dialogs_test.dart \
//     --flavor full --dart-define=CHANNEL=store
//
// 결과: build/store_screenshots/update_*.png (test_driver 가 저장하는 폴더)
import 'package:card_expense/app_update.dart';
import 'package:card_expense/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('update dialogs', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    final cases = {
      'update_available': const UpdateCheck(UpdateStatus.available, '2.0.1'),
      'update_latest': const UpdateCheck(UpdateStatus.latest, '2.0.1'),
      'update_failed': const UpdateCheck(UpdateStatus.failed, '2.0.1'),
    };
    for (final e in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            appBar: AppBar(title: const Text('메뉴')),
            body: Builder(
              builder: (ctx) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => showDialog<void>(context: ctx, builder: (_) => updateResultDialog(e.value, store: true)),
                );
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot(e.key);
    }
  });
}
