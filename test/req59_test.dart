import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/import_screen.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/notice_dialog.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-59: 지난 문자 불러오기 결과 숫자(같은 문자를 여러 저장소에서 읽어도 한 번), 확인 하나짜리 안내 팝업 통일.
void main() {
  final at = DateTime(2026, 11, 20, 9);
  String sms(int won, String day, String shop) => '[Web발신] NH기업0000승인 공용카드 ${groupDigits(won)}원 체크 $day $shop';
  RawSms raw(String body) => RawSms(body, at);

  group('A 불러오기 숫자', () {
    test('SMS·RCS 양쪽에 같은 문자 → 미리보기와 결과 숫자 같음 (겹친 건 중복 아님)', () {
      final bodies = [
        sms(68000, '11/03 08:55', 'OO주유소'),
        sms(9000, '11/05 12:20', 'LL분식'),
        sms(45000, '11/07 09:30', 'EE자동차정비'),
      ];
      // SMS 저장소 3건 + RCS 후보 저장소에서 같은 3건 + 승인 아닌 문자 1건(양쪽에서 두 번)
      final scan = InboxScan(
        [
          for (final b in bodies) raw(b),
          for (final b in bodies) raw(b),
          raw('[Web발신] NH농협카드 연말 이벤트 안내'),
          raw('[Web발신] NH농협카드 연말 이벤트 안내'),
        ],
        4,
        0,
        4,
        3,
      );
      final p = importPreviewOf(scan, digits: '0000', existing: const {});
      expect(p.approvals, 3);
      expect(p.summary, '새 3 · 중복 0');
      // 결과 알림(IngestReport.summary)도 같은 숫자
      expect(p.report.fresh, hasLength(3));
      expect(p.report.dup, 0);
      expect(p.report.rejected, hasLength(1)); // 승인 아닌 문자도 한 번만
      expect(p.report.summary(added: 3), '추가 3건 · 중복 0건 · 승인 문자 아님 1건');
    });

    test('이미 저장된 문자는 중복으로 정확히 센다 (두 저장소에서 읽혀도 1건)', () {
      final old = parseSms(sms(9000, '11/05 12:20', 'LL분식'), cardDigits: '0000', receivedAt: at)!;
      final existing = {old.id: Expense.fromParsed(old)..category = kOps};
      final scan = InboxScan(
        [
          raw(sms(68000, '11/03 08:55', 'OO주유소')),
          raw(sms(9000, '11/05 12:20', 'LL분식')),
          raw(sms(68000, '11/03 08:55', 'OO주유소')),
          raw(sms(9000, '11/05 12:20', 'LL분식')),
        ],
        2,
        0,
        2,
        2,
      );
      final p = importPreviewOf(scan, digits: '0000', existing: existing);
      expect(p.summary, '새 1 · 중복 1');
      expect(p.approvals, 2);
      expect(p.report.summary(added: 1), '추가 1건 · 중복 1건');
    });

    test('무시했던 문자도 한 번만', () {
      final old = parseSms(sms(14000, '11/10 12:15', 'BB식당'), cardDigits: '0000', receivedAt: at)!;
      final existing = {old.id: Expense.fromParsed(old)..category = kIgnored};
      final scan = InboxScan(
        [raw(sms(14000, '11/10 12:15', 'BB식당')), raw(sms(14000, '11/10 12:15', 'BB식당'))],
        1,
        0,
        1,
        1,
      );
      final p = importPreviewOf(scan, digits: '0000', existing: existing);
      expect(p.report.ignoredHits, hasLength(1));
      expect(p.summary, '새 0 · 중복 0 · 무시했던 1');
    });
  });

  group('B 안내 팝업 통일', () {
    Future<void> pump(WidgetTester tester, Widget dialog) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: dialog)),
        ),
      );
    }

    Finder okButton(String label) => find.widgetWithText(FilledButton, label);

    testWidgets('불러오기 0건: 정보 아이콘·제목·검사 숫자 칸·줄 나눈 설명·[확인] 하나', (tester) async {
      await pump(tester, scanResultDialog(const InboxScan([], 30, 2, 5, 0), 0));
      expect(find.byType(NoticeInfoIcon), findsOneWidget);
      expect(find.byType(WarnBadge), findsNothing); // 경고가 아니므로 '!' 아님
      expect(find.text('새로 불러온 문자가 없어요'), findsOneWidget);
      expect(find.text('검사한 문자'), findsOneWidget);
      expect(find.text('37건'), findsOneWidget);
      expect(find.text('카드번호 일치'), findsOneWidget);
      expect(find.text('0건'), findsNWidgets(2)); // 발신번호 일치 0 · 카드번호 일치 0
      expect(find.textContaining(keepWords('문자 저장소에 없을 수 있어요.')), findsOneWidget);
      expect(okButton('확인'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('불러오기 0건이지만 카드 문자는 있음 → 모두 이미 들어와 있어요', (tester) async {
      await pump(tester, scanResultDialog(const InboxScan([], 6, 0), 6));
      expect(find.text(keepWords('이 기간의 카드 승인 문자는\n모두 이미 들어와 있어요.')), findsOneWidget);
    });

    testWidgets('승인 문자 아님만 있는 결과: 숫자 칸 3개·원문 목록 펼침·[닫기] 하나', (tester) async {
      const report = IngestReport(fresh: [], dup: 1, ignoredHits: [], rejected: ['안녕하세요 회의 10시']);
      await pump(tester, ingestResultDialog('붙여넣은 문자', report, 0));
      expect(find.byType(NoticeInfoIcon), findsOneWidget);
      expect(find.text('붙여넣은 문자 결과'), findsOneWidget);
      for (final l in ['추가', '중복', '승인 문자 아님']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text(keepWords('승인 문자가 아닌 문자는\n넣지 않았어요.')), findsOneWidget);
      await tester.tap(find.text('승인 문자 아님 1건 내용 보기'));
      await tester.pumpAndSettle();
      expect(find.text('안녕하세요 회의 10시'), findsOneWidget);
      expect(okButton('닫기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('(반올림) 안내 문구는 줄을 직접 나눔', () {
      expect(kRoundingNote.split('\n'), ['칸마다 반올림해서', '합계와 1 정도 다를 수 있어요.', '', "정확한 금액은 '원' 단위로 보세요."]);
      expect(kRoundingTitle, isNotEmpty);
    });
  });
}
