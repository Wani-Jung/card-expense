/// NH기업카드 승인 문자 파서.
///
/// 예)
///   [Web발신]
///   NH기업0000승인
///   공용카드
///   96,000원 체크
///   07/28 16:26
///   (주)월산주유소
///
/// 줄바꿈 없이 한 줄로 와도 같은 결과가 나와야 한다.
class ParsedSms {
  final int amount;
  final DateTime dateTime;
  final String merchant;
  final bool isCancel;
  final String raw;

  const ParsedSms({
    required this.amount,
    required this.dateTime,
    required this.merchant,
    required this.isCancel,
    required this.raw,
  });

  /// 같은 승인 건을 알아보는 키. 알림은 가맹점이 잘려 올 수 있어 가맹점은 넣지 않는다.
  String get id =>
      '${dateTime.toIso8601String()}|$amount|${isCancel ? 'C' : 'A'}';
}

final _amountRe = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\s*원');
final _dateTimeRe = RegExp(r'(\d{1,2})/(\d{1,2})\s*(\d{1,2}):(\d{2})');
final _spaces = RegExp(r'\s+');

/// [cardDigits] 가 들어간 "NH기업xxxx" 문자만 읽는다. 아니면 null.
///
/// 문자에는 연도가 없으므로 [receivedAt](문자 받은 시각) 기준으로 정한다.
/// 받은 시각보다 하루 넘게 미래가 되면 작년 문자로 본다. (12월 문자를 1월에 불러올 때)
ParsedSms? parseSms(String text, {required String cardDigits, DateTime? receivedAt}) {
  final compact = text.replaceAll(_spaces, '');
  if (cardDigits.isEmpty || !compact.contains('NH기업$cardDigits')) return null;

  final amountM = _amountRe.firstMatch(text);
  final dtM = _dateTimeRe.firstMatch(text);
  if (amountM == null || dtM == null) return null;

  final amount = int.parse(amountM.group(1)!.replaceAll(',', ''));
  final mo = int.parse(dtM.group(1)!);
  final d = int.parse(dtM.group(2)!);
  final h = int.parse(dtM.group(3)!);
  final mi = int.parse(dtM.group(4)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;

  final ref = receivedAt ?? DateTime.now();
  var dt = DateTime(ref.year, mo, d, h, mi);
  if (dt.isAfter(ref.add(const Duration(days: 1)))) {
    dt = DateTime(ref.year - 1, mo, d, h, mi);
  }

  final rest = text.substring(dtM.end);
  final line = rest
      .split(RegExp(r'[\r\n]+'))
      .map((s) => s.trim())
      .firstWhere((s) => s.isNotEmpty, orElse: () => '');
  final merchant = line.split('누적').first.trim();

  return ParsedSms(
    amount: amount,
    dateTime: dt,
    merchant: merchant,
    isCancel: compact.contains('취소'),
    raw: text.trim(),
  );
}
