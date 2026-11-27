// REQ-66·67 보고용 화면 캡처 (실제 폰 크기 에뮬레이터, 데모 데이터). 저장소 스크린샷이 아니라 확인용.
//
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/req67_screens_test.dart \
//     --dart-define=CHANNEL=store --dart-define=DEMO=true
//
// 결과: build/store_screenshots/r67_*.png
import 'package:card_expense/demo.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/import_screen.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('req67 screens', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    final prefs = await SharedPreferences.getInstance();

    Future<void> settle() async {
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> shot(String name) async {
      await settle();
      await binding.takeScreenshot('r67_$name');
    }

    Future<void> tap(Finder f) async {
      await tester.tap(f.first);
      await settle();
    }

    /// 데모 + 긴 가맹점 이름 한 건 (줄바꿈 확인용)
    Future<void> start({bool pending = false}) async {
      await prefs.clear();
      await seedDemo(prefs, pending: pending, issues: false);
      final store = await Store.open();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final p = parseSms(
        '[Web발신] NH기업0000승인 공용카드 8,500원 체크 ${two(now.month)}/${two(now.day)} 08:10 좋은아침페스츄리베이커리카페 홍성내포신도시점',
        cardDigits: '0000',
        receivedAt: now,
      )!;
      final items = store.loadItems()..add(Expense.fromParsed(p)..category = kOps);
      await store.saveItems(items);
      await tester.pumpWidget(CardExpenseApp(key: UniqueKey(), store: await Store.open()));
      await settle();
    }

    // 메인 (긴 가맹점 이름 2줄) → 상세 시트 버튼
    await start();
    await shot('01_main_merchant');
    await tap(find.textContaining('좋'));
    await shot('02_edit_sheet');
    await tester.tapAt(const Offset(20, 80));
    await settle();

    // 단위 메뉴 (원/천원/만원), ⓘ
    await tap(find.text('단위: 원 ▾'));
    await shot('03_unit_menu');
    await tap(find.text('만원').last);
    await shot('04_unit_info_icon');
    // 수립 입력 안내 두 줄
    await tap(find.byIcon(Icons.edit));
    await shot('05_budget_edit');
    await tap(find.text('취소'));

    // 미분류 내역 버튼 정렬
    await start(pending: true);
    await tap(find.byTooltip('메뉴'));
    if (find.text('미분류 내역').evaluate().isEmpty) await tap(find.text('결제내역'));
    await shot('06_menu_badges');
    await tap(find.text('미분류 내역'));
    await shot('07_unclassified');
    await tester.pageBack();
    await settle();

    // 개인정보처리방침 확인창
    await tap(find.text('개인정보처리방침'));
    await shot('08_privacy');
    await tap(find.text('취소'));

    // 등록 업체·추천 키워드
    await tap(find.text('등록 업체·추천 키워드'));
    await shot('09_vendors');
    await tester.pageBack();
    await settle();

    // 문자 붙여넣기 (결제내역은 위에서 펼친 채)
    if (find.text('문자 붙여넣기').evaluate().isEmpty) await tap(find.text('결제내역'));
    await tap(find.text('문자 붙여넣기'));
    await shot('10_paste');
    await tester.pageBack();
    await settle();

    // 사전입력사항은 2.1.1 에서 메뉴에서 뺌 (첫 실행에만)
    await settle();

    // 실험실 (법령 Quiz 부제)
    await tap(find.text('실험실'));
    await shot('13_lab');
    await tester.pageBack();
    await settle();

    // 지난 문자 불러오기 미리보기 (줄 나열, 넣을 게 없으면 [닫기])
    final preview = ImportPreview(
      const InboxScan([], ['im/chat: 15881600']),
      const IngestReport(fresh: [], dup: 115, ignoredHits: [], rejected: []),
      unique: 115,
      bySender: 115,
    );
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(builder: (_) => ImportRangeScreen(preview: (_, _) async => preview)),
    );
    await settle();
    await tap(find.text('이번 달'));
    await tap(find.text('이 기간 문자 확인'));
    await shot('14_import_preview');
    await tester.longPress(find.text('이 기간 승인 문자 115건'));
    await shot('15_import_diag');
  });
}
