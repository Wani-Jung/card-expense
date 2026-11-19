// 플레이스토어 스크린샷 (REQ-53). 스토어판 + 데모 데이터로 에뮬레이터에서 찍는다.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart \
//     --flavor public --dart-define=CHANNEL=store --dart-define=DEMO=true
//
// 화면 크기는 1080×1920 (CI: pixel_2 프로필, 로컬: adb shell wm size 1080x1920 · wm density 420).
// 결과: build/store_screenshots/NN_name.png (위쪽 문구 띠 버전) + plain/NN_name.png (띠 없음).
import 'dart:convert';

import 'package:card_expense/budget.dart';
import 'package:card_expense/demo.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/flavor.dart';
import 'package:card_expense/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _navy = Color(0xFF1F3A68);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    expect(isStoreChannel, isTrue, reason: '--dart-define=CHANNEL=store 로 돌려야 함');
    expect(kDemo, isTrue, reason: '--dart-define=DEMO=true 로 돌려야 함');
    await binding.convertFlutterSurfaceToImage();
    final prefs = await SharedPreferences.getInstance();

    Future<void> settle() async {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    /// 데모 데이터로 앱을 새로 띄운다
    Future<void> start({bool pending = false, bool issues = false}) async {
      await prefs.clear();
      await seedDemo(prefs, pending: pending, issues: issues);
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(key: UniqueKey(), store: store));
      await settle();
    }

    Future<void> tap(Finder f) async {
      await tester.tap(f.first);
      await settle();
    }

    /// 지금 화면을 찍고(띠 없음), 같은 화면을 문구 띠 아래에 줄여 놓고 한 번 더 찍는다 (띠 버전)
    Future<void> shot(String name, String caption) async {
      await settle();
      final raw = Uint8List.fromList(await binding.takeScreenshot('plain/$name'));
      final image = MemoryImage(raw);
      final ctx = tester.element(find.byType(Navigator).first);
      await tester.runAsync(() => precacheImage(image, ctx));
      final entry = OverlayEntry(
        builder: (_) => _CaptionFrame(caption: caption, image: image),
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).overlay!.insert(entry);
      await settle();
      // 첫 장에서 띠가 그려지기 전 화면이 찍힌 적이 있어서, 띠 없는 화면과 같으면 다시 찍는다
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump();
        final framed = await binding.takeScreenshot(name);
        if (!_sameBytes(framed, raw)) break;
      }
      entry.remove();
      await settle();
    }

    // ① 메인 요약표 + 내역
    await start();
    await shot('01_main', '한눈에 보는 월별 예산');

    // ② 두 달 합산 (이번 달이 묶음의 둘째 달이 되는 쪽을 골라 두 달 모두 내역이 있게)
    final mode = periodMonths(DateTime.now(), PeriodMode.oddEven).last.month == DateTime.now().month
        ? PeriodMode.oddEven
        : PeriodMode.evenOdd;
    await tap(find.text('1개월 ▾'));
    await tap(find.text(periodModeLabel(mode)));
    await shot('02_combined', '두 달 단위 합산');

    // ③ 분류 대기 카드 (추천 배지)
    // 요약표는 틀고정이라 스크롤하지 않는다 (아래 목록만 밀리면 첫 카드 머리가 가려짐)
    await start(pending: true);
    await shot('03_pending', '승인 문자 자동 분류');

    // ④ 확인 필요 내역
    await start(issues: true);
    await tap(find.byTooltip('메뉴'));
    // 확인 필요 건이 있으면 '내역 관리'는 펼친 채로 열린다
    if (find.text('확인 필요 내역').evaluate().isEmpty) await tap(find.text('내역 관리'));
    await tap(find.text('확인 필요 내역'));
    await shot('04_check', '실수 의심 건은 따로 모아서');

    // ⑤ 등록 업체·추천 키워드
    await start();
    await tap(find.byTooltip('메뉴'));
    await tap(find.text('등록 업체·추천 키워드'));
    await shot('05_vendors', '업체·키워드 추천');

    // ⑥ 안전 OX Quiz (한 문제 풀고 해설까지)
    await start();
    await tap(find.byTooltip('메뉴'));
    await tap(find.text('실험실'));
    await tap(find.text('안전 OX Quiz'));
    await tap(find.text('한 문제 더 풀기'));
    // 보기 좋게 정답을 고른다 (내장 문제 파일에서 화면의 문제를 찾아서)
    final bank = jsonDecode(await rootBundle.loadString('quiz/questions.json')) as Map<String, dynamic>;
    final shown = {for (final t in tester.widgetList<Text>(find.byType(Text))) (t.data ?? '').replaceAll('⁠', '')};
    final q = (bank['questions'] as List).cast<Map<String, dynamic>>().firstWhere((q) => shown.contains(q['question']));
    await tap(find.text(q['answer'] == true ? 'O' : 'X'));
    await shot('06_quiz', '현장 안전 OX Quiz');
  });
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 스토어용 한 장: 네이비 바탕, 위쪽 흰 글씨 문구, 아래에 앱 화면을 줄여서
class _CaptionFrame extends StatelessWidget {
  final String caption;
  final ImageProvider image;
  const _CaptionFrame({required this.caption, required this.image});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: _navy,
      child: Column(
        children: [
          SizedBox(
            height: size.height * 0.17,
            width: double.infinity,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Image(
                    image: image,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
