import 'package:flutter/services.dart';

import 'budget.dart';

/// 금액 입력칸 쉼표 (2.1.1): 치는 대로 세 자리마다 쉼표(350,000). 만원은 소수점 아래는 그대로(1,234.5).
/// 계산은 [parseMoney]/[parseManwon] 이 쉼표를 무시하므로 그대로.
class MoneyCommaFormatter extends TextInputFormatter {
  final MoneyUnit unit;
  const MoneyCommaFormatter(this.unit);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final allowDot = unit == MoneyUnit.man;
    // 커서 앞에 있던 숫자·점 개수를 세어 두고, 다시 쓴 뒤 같은 자리에 둔다
    final cursor = newValue.selection.baseOffset.clamp(0, text.length);
    bool keep(String ch) => RegExp(allowDot ? r'[0-9.]' : r'[0-9]').hasMatch(ch);
    var before = 0;
    for (var i = 0; i < cursor; i++) {
      if (keep(text[i])) before++;
    }
    var raw = text.split('').where(keep).join();
    if (allowDot) {
      // 점은 하나만
      final dot = raw.indexOf('.');
      if (dot >= 0) raw = raw.substring(0, dot + 1) + raw.substring(dot + 1).replaceAll('.', '');
    }
    final out = withCommas(raw);
    var pos = 0, seen = 0;
    while (pos < out.length && seen < before) {
      if (out[pos] != ',') seen++;
      pos++;
    }
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: pos));
  }
}
