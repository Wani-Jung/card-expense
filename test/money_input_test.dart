import 'package:card_expense/budget.dart';
import 'package:card_expense/money_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2.1.1: 금액 입력칸은 치는 대로 세 자리마다 쉼표
void main() {
  TextEditingValue type(MoneyUnit u, String text, [int? cursor]) => MoneyCommaFormatter(u).formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length)),
      );

  test('원·천원: 쉼표 넣기, 숫자 아닌 글자 버림, 커서는 끝', () {
    expect(type(MoneyUnit.won, '350000').text, '350,000');
    expect(type(MoneyUnit.won, '350000').selection.baseOffset, 7);
    expect(type(MoneyUnit.won, '1234567').text, '1,234,567');
    expect(type(MoneyUnit.won, '12,3456').text, '123,456');
    expect(type(MoneyUnit.thousand, '999').text, '999');
    expect(type(MoneyUnit.won, '35.0').text, '350');
    expect(type(MoneyUnit.won, '').text, '');
  });

  test('중간에 지우거나 넣어도 커서가 같은 숫자 뒤에', () {
    // '350,000' 에서 '5' 뒤(3번째 글자)에 커서, 0 하나 더 → '3,500,000', 커서는 '5' 다음 '0' 뒤
    final r = type(MoneyUnit.won, '3500,000', 3);
    expect(r.text, '3,500,000');
    expect(r.selection.baseOffset, 4);
  });

  test('만원: 정수 부분만 쉼표, 점은 하나', () {
    expect(type(MoneyUnit.man, '1234.5').text, '1,234.5');
    expect(type(MoneyUnit.man, '35').text, '35');
    expect(type(MoneyUnit.man, '1.2.3').text, '1.23');
  });

  test('쉼표가 있어도 계산은 그대로, 미리 채움도 쉼표', () {
    expect(parseMoney('350,000', MoneyUnit.won), 350000);
    expect(parseMoney('1,234.5', MoneyUnit.man), 12345000);
    expect(moneyInputText(350000, MoneyUnit.won), '350,000');
    expect(moneyInputText(342500, MoneyUnit.man), '34.25');
  });
}
