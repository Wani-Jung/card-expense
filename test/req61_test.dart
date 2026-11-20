import 'package:card_expense/import_screen.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/notice_dialog.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-61: 불러오기 결과 팝업 단순하게 (진단 숫자는 제목 길게 누르기로만), 발신번호 비교 정규화.
void main() {
  group('B 발신번호 비교 (Kotlin SenderMatch 와 같은 규칙)', () {
    const conf = '1588-1600';
    test('저장소마다 다른 형식이 모두 일치', () {
      for (final a in [
        '1588-1600',
        '15881600',
        ' 1588-1600 ',
        '+8215881600',
        '+82 1588-1600',
        '82-1588-1600',
        '0015881600',
        '008215881600',
        '015881600',
        '#15881600',
        'tel:+82-1588-1600',
        'sip:+8215881600@ims.mnc008.mcc450.3gppnetwork.org;user=phone',
        '15881600;phone-context=x1',
      ]) {
        expect(senderMatches(a, conf), isTrue, reason: a);
        expect(senderMatches(conf, a), isTrue, reason: a);
      }
      expect(senderMatches('+821012345678', '010-1234-5678'), isTrue);
    });

    test('다른 번호는 불일치', () {
      for (final a in ['15881688', '1588-1601', 'NH농협카드', '', '1600', 'sip:bot@rcs.mnc008.mcc450.15881600.org']) {
        expect(senderMatches(a, conf), isFalse, reason: a);
      }
      expect(senderMatches(null, conf), isFalse);
    });

    test('네이티브 진단 값(발신번호 일치·주소 형식)을 받는다', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('card_expense/native'),
        (call) async => {
          'items': [
            {'body': 'a', 'ts': 0},
            {'body': 'b', 'ts': 0},
          ],
          'smsScanned': 100,
          'mmsScanned': 20,
          'otherScanned': 5,
          'otherMatched': 2,
          'senderMatched': 0,
          'addrSamples': ['im/chat: sip:+8215881600@ims'],
        },
      );
      final s = await Native.readSmsInbox(DateTime(2026, 11), DateTime(2026, 12));
      expect(s.scanned, 125);
      expect(s.senderMatched, 0);
      expect(s.addrSamples, ['im/chat: sip:+8215881600@ims']);
      // 예전 네이티브(값 없음)는 예전 방식으로 센다
      expect(const InboxScan([], 1, 0, 0, 0).senderMatched, 0);
    });
  });

  group('A 불러오기 결과 문구', () {
    test('새로 넣었을 때: 중복이 있으면 한 줄 더', () {
      expect(importAddedMessage(3, 0), '분류 대기에 3건 넣었어요');
      expect(importAddedMessage(3, 2), '분류 대기에 3건 넣었어요\n이미 있던 2건은 건너뛰었어요');
    });

    Future<void> pump(WidgetTester tester, ImportPreview p, {VoidCallback? onCardSettings}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (dctx) => importResultDialog(dctx, p, onCardSettings: onCardSettings),
                  ),
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

    const scan = InboxScan([], 15000, 500, 12, 5, 0, ['sms: 15881600']);

    testWidgets('이미 다 있음: 제목·두 줄 본문, 진단 숫자 칸 없음', (tester) async {
      await pump(tester, const ImportPreview(scan, IngestReport(fresh: [], dup: 5, ignoredHits: [], rejected: [])));
      expect(find.byType(NoticeInfoIcon), findsOneWidget);
      expect(find.text('새로 불러온 문자가 없어요'), findsOneWidget);
      expect(find.text(keepWords('이 기간 카드 승인 문자 5건은\n모두 이미 들어와 있어요.')), findsOneWidget);
      for (final no in ['검사한 문자', '발신번호 일치', '카드번호 일치']) {
        expect(find.text(no), findsNothing, reason: no);
      }
      expect(find.text('카드 문자 설정'), findsNothing);
      expect(find.widgetWithText(FilledButton, '확인'), findsOneWidget);
    });

    testWidgets('승인 문자 0건: 카드번호 확인 안내 + [카드 문자 설정] 링크', (tester) async {
      var opened = 0;
      await pump(
        tester,
        const ImportPreview(scan, IngestReport(fresh: [], dup: 0, ignoredHits: [], rejected: [])),
        onCardSettings: () => opened++,
      );
      expect(find.text('이 기간엔 카드 승인 문자가 없어요'), findsOneWidget);
      expect(find.text(keepWords('카드 문자 설정의 카드번호 끝 4자리가\n맞는지 확인해 보세요.')), findsOneWidget);
      expect(find.text('검사한 문자'), findsNothing);
      await tester.tap(find.text('카드 문자 설정'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.text('이 기간엔 카드 승인 문자가 없어요'), findsNothing); // 팝업은 닫힘
    });

    testWidgets('제목을 길게 누르면 숨은 진단 (검사 건수·발신번호 일치·주소 형식)', (tester) async {
      await pump(tester, const ImportPreview(scan, IngestReport(fresh: [], dup: 5, ignoredHits: [], rejected: [])));
      await tester.longPress(find.text('새로 불러온 문자가 없어요'));
      await tester.pumpAndSettle();
      expect(find.text('불러오기 진단'), findsOneWidget);
      expect(find.text('검사한 문자'), findsOneWidget);
      expect(find.text('15512건'), findsOneWidget);
      expect(find.text('발신번호 일치'), findsOneWidget);
      expect(find.textContaining('sms: 15881600'), findsOneWidget);
    });
  });
}
