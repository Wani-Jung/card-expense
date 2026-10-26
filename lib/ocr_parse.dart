import 'sms_parser.dart';

/// 문자 캡처 OCR 텍스트 정리 + 건별 후보 만들기.
///
/// 캡처에는 RCS 화면 글자('알림', '확인된 발신번호', 날짜 구분선, 오전/오후 시간)가 섞여 있고,
/// ML Kit 는 숫자를 O/I/l 로, 쉼표를 마침표로 읽거나 숫자 사이에 공백을 넣기도 한다.
/// 금액·날짜·카드번호 부분만 관대하게 고치고 나머지(가맹점 등)는 건드리지 않는다.

final _webSender = RegExp(r'\[?\s*W\s*e\s*b\s*발\s*신\s*\]?', caseSensitive: false);
final _noiseLines = [
  RegExp(r'^알림$'),
  RegExp(r'확인된\s*발신\s*번호'),
  RegExp(r'^\d{1,2}\s*월\s*\d{1,2}\s*일(\s*[월화수목금토일]\s*요일)?$'), // 8월 4일 화요일
  RegExp(r'^(오전|오후)\s*\d{1,2}\s*[:;.]\s*\d{2}$'), // 오전 10:31
  RegExp(r'^\d{1,2}\s*[:;]\s*\d{2}$'), // 10:31
];
// 숫자처럼 생긴 글자 묶음. 진짜 숫자가 하나라도 섞여 있을 때만 O→0, I/l/|→1 로 바꾼다.
final _digitish = RegExp(r'[0-9OoIl|]{2,}');
final _amount = RegExp(r'(\d[\d .,]*\d|\d)\s*원');
final _dateTime = RegExp(r'(\d{1,2})\s*/\s*(\d{1,2})\s+(\d{1,2})\s*[:;.]\s*(\d{2})');

String _fixDigitish(String line) => line.replaceAllMapped(_digitish, (m) {
      final s = m[0]!;
      if (!s.contains(RegExp(r'\d'))) return s;
      return s.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[Il|]'), '1');
    });

String _formatAmount(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// OCR 텍스트를 parseSms 가 읽을 수 있게 정리한다.
String cleanOcrText(String text) {
  final lines = <String>[];
  for (var line in text.replaceAll(_webSender, '\n[Web발신]\n').split(RegExp(r'\r?\n'))) {
    line = line.trim();
    if (line.isEmpty || _noiseLines.any((r) => r.hasMatch(line))) continue;
    line = _fixDigitish(line);
    // "96.000 원", "96, 000원" → "96,000원"
    line = line.replaceAllMapped(_amount, (m) {
      final digits = m[1]!.replaceAll(RegExp(r'\D'), '');
      return '${_formatAmount(digits)}원';
    });
    // "07 / 28 16 : 26", "07/28 16.26" → "07/28 16:26"
    line = line.replaceAllMapped(_dateTime, (m) => '${m[1]}/${m[2]} ${m[3]}:${m[4]}');
    lines.add(line);
  }
  return lines.join('\n');
}

/// 확인 화면에 보여줄 한 건. 금액·날짜를 못 읽었으면 null 로 두고 사용자가 고치게 한다.
class OcrCandidate {
  final String raw;
  int? amount;
  DateTime? dateTime;
  String merchant;
  bool isCancel;
  bool selected = true;

  OcrCandidate({required this.raw, this.amount, this.dateTime, this.merchant = '', this.isCancel = false});

  bool get valid => amount != null && amount! > 0 && dateTime != null;

  ParsedSms toParsed() =>
      ParsedSms(amount: amount!, dateTime: dateTime!, merchant: merchant, isCancel: isCancel, raw: raw);

  String? get id => valid ? toParsed().id : null;
}

final _amountRe = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\s*원');
final _dateTimeRe = RegExp(r'(\d{1,2})/(\d{1,2})\s*(\d{1,2}):(\d{2})');

/// 한 조각에서 후보를 만든다. 카드번호+승인이 없으면 null (캡처 속 다른 글자).
OcrCandidate? _candidate(String piece, String digits, DateTime now) {
  if (!hasCardApproval(piece, digits)) return null;
  final p = parseSms(piece, cardDigits: digits, receivedAt: now);
  if (p != null) {
    return OcrCandidate(
        raw: p.raw, amount: p.amount, dateTime: p.dateTime, merchant: p.merchant, isCancel: p.isCancel);
  }
  // 일부만 읽힌 경우: 읽힌 것만 채운다.
  final a = _amountRe.firstMatch(piece);
  final d = _dateTimeRe.firstMatch(piece);
  DateTime? dt;
  if (d != null) {
    final mo = int.parse(d[1]!), day = int.parse(d[2]!), h = int.parse(d[3]!), mi = int.parse(d[4]!);
    if (mo >= 1 && mo <= 12 && day >= 1 && day <= 31 && h <= 23 && mi <= 59) {
      dt = DateTime(now.year, mo, day, h, mi);
      if (dt.isAfter(now.add(const Duration(days: 1)))) dt = DateTime(now.year - 1, mo, day, h, mi);
    }
  }
  var merchant = '';
  if (d != null) {
    merchant = piece
        .substring(d.end)
        .split('\n')
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '')
        .split('누적')
        .first
        .trim();
  }
  return OcrCandidate(
    raw: piece.trim(),
    amount: a == null ? null : int.tryParse(a[1]!.replaceAll(',', '')),
    dateTime: dt,
    merchant: merchant,
    isCancel: piece.replaceAll(RegExp(r'\s+'), '').contains('취소'),
  );
}

/// 잘라서 인식한 조각들(위→아래 순서)의 텍스트로 후보 목록을 만든다.
/// 겹치게 잘랐으므로 조각 경계에서 잘린 반쪽짜리 건은 버리고(다음/이전 조각에 온전히 있음),
/// 같은 건은 한 번만 남긴다.
List<OcrCandidate> ocrCandidates(List<String> sliceTexts, String digits, DateTime now) {
  final out = <OcrCandidate>[];
  final ids = <String>{};
  for (var i = 0; i < sliceTexts.length; i++) {
    final pieces = splitMessages(cleanOcrText(sliceTexts[i]));
    final cands = <OcrCandidate>[];
    for (var j = 0; j < pieces.length; j++) {
      final c = _candidate(pieces[j], digits, now);
      if (c == null) continue;
      final atTopEdge = i > 0 && cands.isEmpty;
      final atBottomEdge = i < sliceTexts.length - 1 && j == pieces.length - 1;
      if (!c.valid && (atTopEdge || atBottomEdge)) continue;
      cands.add(c);
    }
    for (final c in cands) {
      final id = c.id;
      if (id != null && !ids.add(id)) continue;
      out.add(c);
    }
  }
  return out;
}
