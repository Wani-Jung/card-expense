import 'package:card_expense/expense.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final received = DateTime(2026, 7, 28, 16, 27);

  test('실제 수신 예시', () {
    const sms = '[Web발신]\nNH기업0000승인\n공용카드\n96,000원 체크\n07/28 16:26\n(주)월산주유소';
    final p = parseSms(sms, cardDigits: '0000', receivedAt: received)!;
    expect(p.amount, 96000);
    expect(p.dateTime, DateTime(2026, 7, 28, 16, 26));
    expect(p.merchant, '(주)월산주유소');
    expect(p.isCancel, false);
  });

  test('줄바꿈 없이 한 줄로 와도 파싱', () {
    const sms = '[Web발신] NH기업0000승인 공용카드 96,000원 체크 07/28 16:26 (주)월산주유소';
    final p = parseSms(sms, cardDigits: '0000', receivedAt: received)!;
    expect(p.amount, 96000);
    expect(p.dateTime, DateTime(2026, 7, 28, 16, 26));
    expect(p.merchant, '(주)월산주유소');
  });

  test('승인취소는 isCancel 이고 합계에서 차감', () {
    const sms = '[Web발신]\nNH기업0000승인취소\n공용카드\n96,000원 체크\n07/28 18:01\n(주)월산주유소';
    final p = parseSms(sms, cardDigits: '0000', receivedAt: received.add(const Duration(hours: 2)))!;
    expect(p.isCancel, true);
    expect(p.amount, 96000);
    expect(Expense.fromParsed(p).signedAmount, -96000);
  });

  test('다른 카드 문자는 무시', () {
    const other = '[Web발신]\nNH기업1234승인\n공용카드\n10,000원 체크\n07/28 16:26\n편의점';
    const otherBank = '[Web발신]\n신한카드(0000)승인 10,000원 07/28 16:26 편의점';
    expect(parseSms(other, cardDigits: '0000', receivedAt: received), isNull);
    expect(parseSms(otherBank, cardDigits: '0000', receivedAt: received), isNull);
    expect(parseSms('안녕하세요', cardDigits: '0000', receivedAt: received), isNull);
  });

  test('같은 발신번호의 광고·안내 문자는 무시', () {
    const ad = '[Web발신]\n(광고)NH농협카드 10월 이벤트! 5만원 이상 결제 시 캐시백 10/01 00:00';
    const notice = '[Web발신]\nNH기업0000 결제예정금액 1,234,000원 안내 (11/10 결제)';
    expect(parseSms(ad, cardDigits: '0000', receivedAt: received), isNull);
    expect(parseSms(notice, cardDigits: '0000', receivedAt: received), isNull);
  });

  test('카드명이 달라도 카드번호+승인이면 읽는다', () {
    const sms = 'NH농협0000승인 공용카드 3,000원 체크 07/28 09:00 편의점';
    expect(parseSms(sms, cardDigits: '0000', receivedAt: received)?.amount, 3000);
  });

  group('발신번호 매칭', () {
    test('하이픈 유무 상관없이 숫자로 비교', () {
      expect(senderMatches('15881600', '1588-1600'), isTrue);
      expect(senderMatches('1588-1600', '15881600'), isTrue);
    });
    test('+82, 0 접두어가 붙어도 끝자리 일치', () {
      expect(senderMatches('+8215881600', '1588-1600'), isTrue);
      expect(senderMatches('+82 1588-1600', '1588-1600'), isTrue);
      expect(senderMatches('015881600', '1588-1600'), isTrue);
      expect(senderMatches('+821012345678', '010-1234-5678'), isTrue);
    });
    test('다른 번호·빈 값은 불일치', () {
      expect(senderMatches('15881688', '1588-1600'), isFalse);
      expect(senderMatches('NH농협카드', '1588-1600'), isFalse);
      expect(senderMatches(null, '1588-1600'), isFalse);
      expect(senderMatches('1600', '1588-1600'), isFalse);
    });
  });

  test('12월 문자를 1월에 불러오면 작년으로', () {
    const sms = 'NH기업0000승인\n공용카드\n1,250,000원 체크\n12/30 09:05\n○○상사';
    final p = parseSms(sms, cardDigits: '0000', receivedAt: DateTime(2027, 1, 3))!;
    expect(p.dateTime, DateTime(2026, 12, 30, 9, 5));
    expect(p.amount, 1250000);
  });

  test('누적 금액 꼬리는 가맹점에서 뺀다', () {
    const sms = 'NH기업0000승인 공용카드 5,500원 체크 07/28 16:26 스타벅스 누적1,234,000원';
    final p = parseSms(sms, cardDigits: '0000', receivedAt: received)!;
    expect(p.amount, 5500);
    expect(p.merchant, '스타벅스');
  });

  test('같은 건은 줄바꿈 형식이 달라도 같은 id', () {
    const a = '[Web발신]\nNH기업0000승인\n공용카드\n96,000원 체크\n07/28 16:26\n(주)월산주유소';
    const b = 'NH기업0000승인 공용카드 96,000원 체크 07/28 16:26 (주)월산주';
    expect(parseSms(a, cardDigits: '0000', receivedAt: received)!.id,
        parseSms(b, cardDigits: '0000', receivedAt: received)!.id);
  });

  test('정산 텍스트', () {
    final e1 = Expense.fromParsed(parseSms(
        'NH기업0000승인 96,000원 07/28 16:26 (주)월산주유소', cardDigits: '0000', receivedAt: received)!)
      ..category = kCar;
    final e2 = Expense.fromParsed(parseSms(
        'NH기업0000승인 12,000원 07/20 12:00 김밥천국', cardDigits: '0000', receivedAt: received)!)
      ..category = kOps;
    final t = settlementText([e1, e2], DateTime(2026, 7), '0000');
    expect(t, contains('차량비 1건 / 96,000원'));
    expect(t, contains('운영비 1건 / 12,000원'));
    expect(t, contains('합계 108,000원'));
  });
}
