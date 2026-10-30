import 'package:card_expense/disclosure.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/flavor.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/permission_screen.dart';
import 'package:card_expense/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-43: 스토어 채널(자체 업데이트 없음), 권한 안내 화면(Prominent Disclosure), 개인정보처리방침 메뉴.
/// 이 파일은 CI 에서 `--dart-define=CHANNEL=store` 로 한 번 더 돈다 (채널별 기대값이 갈림).
void main() {
  late List<String> calls;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
  }

  group('채널', () {
    testWidgets('${isStoreChannel ? '스토어' : '깃허브'}판: 자동 업데이트 확인 ${isStoreChannel ? '안 함' : '함'}, 메뉴 업데이트 항목',
        (tester) async {
      phone(tester);
      PackageInfo.setMockInitialValues(
        appName: 'card_expense',
        packageName: 'com.wani.card_expense',
        version: '2.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      // update_checked_at 없음 → 깃허브판이면 시작할 때 자동 확인이 돌며 시각을 남긴다
      SharedPreferences.setMockInitialValues({
        'card_digits': '0000',
        'sender_number': '1588-1600',
        'quiz_last_day_v1': quizDay(DateTime.now()),
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      expect(store.updateCheckedAt == null, isStoreChannel);
      expect(find.textContaining('새 버전'), findsNothing);

      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('개인정보처리방침'), findsOneWidget);
      if (isStoreChannel) {
        expect(find.text('업데이트 확인'), findsNothing);
        expect(find.text('버전 정보'), findsOneWidget);
        // 눌러도 아무 일 없음 (메뉴 그대로, 스낵바·창 없음)
        await tester.tap(find.text('버전 정보'));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
      } else {
        expect(find.text('업데이트 확인'), findsOneWidget);
        expect(find.text('버전 정보'), findsNothing);
      }
    });
  });

  group('권한 안내 화면', () {
    Future<Future<bool>> open(WidgetTester tester, Future<bool> Function(BuildContext) f) async {
      phone(tester);
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold();
      })));
      final result = f(ctx);
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('문자: 안내 문구 → [동의하고 계속]이면 시스템 권한 요청', (tester) async {
      final r = await open(tester, requestSmsWithDisclosure);
      expect(find.text('카드 승인 문자 읽기 권한 안내'), findsOneWidget);
      expect(find.textContaining('카드 문자가 아닌 일반 문자는 저장하지 않으며'), findsOneWidget);
      expect(find.textContaining("'지난 문자 불러오기'를 실행하면 최근 1년의 문자에서 카드 문자만 찾아 가져옵니다."), findsOneWidget);
      expect(calls, isNot(contains('requestSmsPermission')));
      await tester.tap(find.text('동의하고 계속'));
      await tester.pumpAndSettle();
      expect(await r, isTrue);
      expect(calls, contains('requestSmsPermission'));
      expect(find.byType(DisclosureScreen), findsNothing);
    });

    testWidgets('문자: [나중에]면 권한 요청 없음, 다시 누르면 안내부터', (tester) async {
      final r = await open(tester, requestSmsWithDisclosure);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(await r, isFalse);
      expect(calls, isNot(contains('requestSmsPermission')));

      final ctx = tester.element(find.byType(Scaffold));
      final again = requestSmsWithDisclosure(ctx);
      await tester.pumpAndSettle();
      expect(find.text('카드 승인 문자 읽기 권한 안내'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(await again, isFalse);
      expect(calls, isNot(contains('requestSmsPermission')));
    });

    testWidgets('알림 접근: 안내 → 동의하면 설정 화면, 나중에면 안 엶', (tester) async {
      var r = await open(tester, openNotificationAccessWithDisclosure);
      expect(find.text('카드 승인 알림 읽기 권한 안내'), findsOneWidget);
      expect(find.textContaining('카드 승인 알림만 저장'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(await r, isFalse);
      expect(calls, isNot(contains('openNotificationAccessSettings')));

      r = openNotificationAccessWithDisclosure(tester.element(find.byType(Scaffold)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('동의하고 계속'));
      await tester.pumpAndSettle();
      expect(await r, isTrue);
      expect(calls, contains('openNotificationAccessSettings'));
    });

    testWidgets('권한 설정: 알림 감지 켜기 → 안내 먼저, [나중에]면 설정 화면 안 열고 다른 기능 그대로', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({'use_listener_v1': false});
      final store = await Store.open();
      final changes = ValueNotifier(0);
      await tester.pumpWidget(MaterialApp(
        home: PermissionScreen(
          store: store,
          perms: () => const PermStatus(listener: false),
          changes: changes,
          refresh: () async {},
          onUsageChanged: () async {},
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('카드 승인 알림 읽기 권한 안내'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('openNotificationAccessSettings')));
      // '앱에서 사용' 스위치는 켜진 채 (권한만 나중에)
      expect(store.useListener, isTrue);
      expect(find.text('권한 설정'), findsOneWidget);

      // [설정 열기] 버튼도 안내부터
      await tester.tap(find.text('설정 열기'));
      await tester.pumpAndSettle();
      expect(find.text('카드 승인 알림 읽기 권한 안내'), findsOneWidget);
      await tester.tap(find.text('동의하고 계속'));
      await tester.pumpAndSettle();
      expect(calls, contains('openNotificationAccessSettings'));
    });
  });
}
