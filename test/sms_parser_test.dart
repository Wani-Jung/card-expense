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
