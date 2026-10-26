import 'package:card_expense/expense.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/ocr_parse.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 10, 12);

Expense _existing(String sms, String? cat) {
  final e = Expense.fromParsed(parseSms(sms, cardDigits: '0000', receivedAt: _now)!);
  e.category = cat;
  return e;
}

void main() {
  group('RCS JSON 본문', () {
    // content://im/chat 의 본문처럼 JSON 문자열에 이스케이프된 \r\n 이 들어 있는 경우
    const rcsJson = r'{"message":{"generalPurposeCard":{"content":{"title":"알림",'
        r'"description":"[Web발신]\r\nNH기업0000승인\r\n공용카드\r\n96,000원 체크\r\n08/04 10:31\r\n(주)월산주유소"}}}}';

    test('JSON 을 디코드해서 문자 텍스트만 꺼낸다', () {
      final t = normalizeBody(rcsJson);
      expect(t, startsWith('[Web발신]\n'));
      expect(t, isNot(contains('{')));
      final p = parseSms(rcsJson, cardDigits: '0000', receivedAt: _now)!;
      expect(p.amount, 96000);
      expect(p.dateTime, DateTime(2026, 8, 4, 10, 31));
      expect(p.merchant, '(주)월산주유소');
      expect(p.raw, isNot(contains('}')));
    });

    test('깨진 JSON·리터럴 \\r\\n 이 그대로 와도 가맹점에 찌꺼기가 안 붙는다', () {
      const broken = r'[Web발신]\r\nNH기업0000승인\r\n공용카드\r\n96,000원 체크\r\n08/04 10:31\r\n(주)월산주유소"}}}}';
      final p = parseSms(broken, cardDigits: '0000', receivedAt: _now)!;
      expect(p.merchant, '(주)월산주유소');
      const oneLine = r'NH기업0000승인 96,000원 08/04 10:31\r\n(주)월산주유소"}}}}';
      expect(parseSms(oneLine, cardDigits: '0000', receivedAt: _now)!.merchant, '(주)월산주유소');
    });

    test('가맹점 정리', () {
      expect(cleanMerchant(r'\r\n(주)월산주유소"}}}}'), '(주)월산주유소');
      expect(cleanMerchant('"김밥천국","foo":1}'), '김밥천국');
      expect(cleanMerchant('스타벅스 강남점'), '스타벅스 강남점');
    });

    test('저장된 내역 1회 정리: 분류 유지, 같은 건은 하나만, 손으로 고친 건 그대로', () {
      Expense raw(String body, String? cat, {String? merchant}) {
        final p = parseSms(body, cardDigits: '0000', receivedAt: _now)!;
        return Expense(
          id: p.id,
          amount: p.amount,
          dateTime: p.dateTime,
          merchant: merchant ?? r'\r\n(주)월산주유소"}}}}', // 예전 버전이 저장한 찌꺼기
          isCancel: p.isCancel,
          raw: body,
          category: cat,
        );
      }

      const plain = '[Web발신]\nNH기업0000승인\n공용카드\n96,000원 체크\n08/04 10:31\n(주)월산주유소';
      const edited = '[Web발신]\nNH기업0000승인\n공용카드\n5,000원 체크\n08/06 09:00\n편의점';
      final items = [
        raw(rcsJson, null), // RCS 에서 들어와 대기 중
        raw(plain, kCar, merchant: '(주)월산주유소'), // 같은 건을 이미 차량비로 분류
        raw(edited, kOps, merchant: '손으로 고친 이름'),
      ];
      final out = cleanupStoredItems(items);
      expect(out, hasLength(2));
      final fuel = out.firstWhere((e) => e.amount == 96000);
      expect(fuel.category, kCar);
      expect(fuel.merchant, '(주)월산주유소');
      expect(out.firstWhere((e) => e.amount == 5000).merchant, '손으로 고친 이름');
      expect(out.every((e) => !e.raw.contains('}')), isTrue);
    });
  });

  group('수집 결과 분류', () {
    const a = 'NH기업0000승인 96,000원 08/04 10:31 (주)월산주유소';
    const b = 'NH기업0000승인 12,000원 08/05 12:01 김밥천국';
    const c = 'NH기업0000승인 5,000원 08/06 09:00 편의점';
    const ad = '(광고) NH농협카드 이벤트 안내';

    test('새 내역 / 진짜 중복 / 무시했던 문자 / 승인 문자 아님', () {
      final existing = {
        for (final e in [_existing(a, kCar), _existing(b, kIgnored)]) e.id: e,
      };
      final r = classifyMessages(
        [for (final s in [a, b, c, ad, c]) RawSms(s, _now)],
        digits: '0000',
        existing: existing,
      );
      expect(r.fresh.map((p) => p.merchant), ['편의점']);
      expect(r.dup, 2); // a(이미 분류) + 같은 묶음 안의 c 두 번째
      expect(r.ignoredHits.map((p) => p.merchant), ['김밥천국']);
      expect(r.rejected, [ad]);
      expect(r.summary(), '추가 1건 · 중복 2건 · 무시했던 문자 1건(되살리기) · 승인 문자 아님 1건');
    });

    test('대기 중인 것도 진짜 중복', () {
      final existing = {for (final e in [_existing(a, null)]) e.id: e};
      final r = classifyMessages([RawSms(a, _now)], digits: '0000', existing: existing);
      expect(r.dup, 1);
      expect(r.ignoredHits, isEmpty);
    });

    test('붙여넣기 텍스트를 한 건씩 나눈다', () {
      final raws = splitToRaw(['[Web발신]\n$a\n[Web발신]\n$b'], _now);
      expect(raws, hasLength(2));
    });
  });

  group('OCR 보정', () {
    test('O·I·l 을 숫자로, 금액 마침표·공백을 쉼표로, 날짜·시간 공백 제거', () {
      const ocr = 'NH기업OO0O승인\n공용카드\n96.000 원 체크\n O7 / 28 l6 : 26\n(주)월산주유소';
      final cleaned = cleanOcrText(ocr);
      expect(cleaned, contains('NH기업0000승인'));
      expect(cleaned, contains('96,000원'));
      expect(cleaned, contains('07/28 16:26'));
      final p = parseSms(cleaned, cardDigits: '0000', receivedAt: _now)!;
      expect(p.amount, 96000);
      expect(p.dateTime, DateTime(2026, 7, 28, 16, 26));
      expect(p.merchant, '(주)월산주유소');
    });

    test('금액 사이 공백·쉼표 혼동', () {
      expect(cleanOcrText('1, 234, 5OO원'), '1,234,500원');
      expect(cleanOcrText('12 000원'), '12,000원');
    });

    test('숫자가 없는 단어는 그대로 (가맹점 이름 보호)', () {
      expect(cleanOcrText('Olive Young'), 'Olive Young');
      expect(cleanOcrText('GS25 편의점'), 'GS25 편의점');
    });

    test('RCS 화면 글자는 버린다', () {
      const ocr = '알림\n확인된 발신번호\n8월 4일 화요일\n[Web발신]\nNH기업0000승인\n공용카드\n'
          '96,000원 체크\n08/04 10:31\n(주)월산주유소\n오전 10:31';
      final cleaned = cleanOcrText(ocr);
      expect(cleaned, isNot(contains('알림')));
      expect(cleaned, isNot(contains('확인된')));
      expect(cleaned, isNot(contains('화요일')));
      expect(cleaned, isNot(contains('오전')));
    });
  });

  group('OCR 캡처 → 후보', () {
    const capture = '''
알림
확인된 발신번호
8월 4일 화요일
[Web 발신]
NH기업0000승인
공용카드
96.000원 체크
08/04 10:31
(주)월산주유소
오전 10:31
8월 5일 수요일
[Web발신]
NH기업0000승인
공용카드
12,0O0원 체크
08/05 12:01
김밥천국
오후 12:01
[Web발신]
NH기업1234승인
공용카드
3,000원 체크
08/05 13:00
다른카드
[Web발신]
NH기업0000승인취소
공용카드
12,000원 체크
08/05 18:20
김밥천국
''';

    test('건별로 쪼개고 다른 카드는 뺀다', () {
      final c = ocrCandidates([capture], '0000', _now);
      expect(c.map((x) => x.merchant), ['(주)월산주유소', '김밥천국', '김밥천국']);
      expect(c.map((x) => x.amount), [96000, 12000, 12000]);
      expect(c.map((x) => x.isCancel), [false, false, true]);
      expect(c.every((x) => x.valid), isTrue);
      expect(c.first.dateTime, DateTime(2026, 8, 4, 10, 31));
    });

    test('금액·날짜를 못 읽은 건은 확인 필요(valid=false)로 남긴다', () {
      const broken = '[Web발신]\nNH기업0000승인\n공용카드\n원 체크\n08/06 09:00\n편의점';
      final c = ocrCandidates([broken], '0000', _now);
      expect(c, hasLength(1));
      expect(c.single.valid, isFalse);
      expect(c.single.amount, isNull);
      expect(c.single.dateTime, DateTime(2026, 8, 6, 9));
      expect(c.single.merchant, '편의점');
    });

    test('겹쳐 자른 스크롤 캡처: 경계에서 잘린 반쪽은 버리고 같은 건은 한 번만', () {
      const slice1 = '[Web발신]\nNH기업0000승인\n공용카드\n96,000원 체크\n08/04 10:31\n(주)월산주유소\n'
          '[Web발신]\nNH기업0000승인\n공용카드\n12,000원'; // 아래가 잘림
      const slice2 = '08/04 10:31\n(주)월산주유소\n' // 위가 잘림 (카드번호 없음 → 무시)
          '[Web발신]\nNH기업0000승인\n공용카드\n12,000원 체크\n08/05 12:01\n김밥천국\n'
          '[Web발신]\nNH기업0000승인\n공용카드\n5,000원 체크\n08/06 09:00\n편의점';
      final c = ocrCandidates([slice1, slice2], '0000', _now);
      expect(c.map((x) => x.merchant), ['(주)월산주유소', '김밥천국', '편의점']);
      expect(c.every((x) => x.valid), isTrue);
    });
  });
}
