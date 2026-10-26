import 'dart:convert';

/// 카드 승인 문자 파서.
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
/// 발신번호 확인은 [senderMatches] 로 따로 한다. (알림은 번호 대신 연락처 이름이 와서 못 쓰는 경우가 많다)
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

/// 삼성 RCS 저장소(content://im/chat 등)는 본문을 JSON 문자열로 준다.
/// JSON 이면 디코드해서 실제 문자 텍스트만 꺼내고, 리터럴 "\r\n"·"\n" 은 실제 줄바꿈으로 바꾼다.
/// 일반 문자는 그대로 돌려준다.
String normalizeBody(String body) {
  var s = body.trim();
  if (s.startsWith('{') || s.startsWith('[')) {
    try {
      final strings = <String>[];
      void collect(Object? v) {
        if (v is String) {
          strings.add(v);
        } else if (v is Map) {
          v.values.forEach(collect);
        } else if (v is List) {
          v.forEach(collect);
        }
      }

      collect(jsonDecode(s));
      // 승인 문자처럼 보이는 값만 고르고, 없으면 글자가 든 값 전부
      final card = strings.where((t) => t.contains('원') && (t.contains('승인') || t.contains('취소')));
      final picked = card.isNotEmpty ? card : strings.where((t) => t.trim().isNotEmpty);
      if (picked.isNotEmpty) s = picked.join('\n');
    } on FormatException {
      // JSON 이 잘려 있거나 깨진 경우: 아래 리터럴 치환과 가맹점 정리로 버틴다
    }
  }
  return s
      .replaceAll(r'\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\n')
      .replaceAll(r'\"', '"')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
}

/// 가맹점 이름 앞뒤에 붙은 찌꺼기(줄바꿈 리터럴, 따옴표, 중괄호, JSON 꼬리)를 지운다.
String cleanMerchant(String s) {
  var m = s.replaceAll(r'\r', ' ').replaceAll(r'\n', ' ').replaceAll(RegExp(r'[\r\n]+'), ' ');
  m = m.replaceFirst(RegExp(r'^[\s"{}\[\]\\,:]+'), '');
  final quote = m.indexOf('"'); // 가맹점 이름 뒤에 이어 붙은 JSON 꼬리 ("}}}} 등)
  if (quote >= 0) m = m.substring(0, quote);
  return m.replaceFirst(RegExp(r'[\s"{}\[\]\\,:]+$'), '').trim();
}

final _amountRe = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\s*원');
final _dateTimeRe = RegExp(r'(\d{1,2})/(\d{1,2})\s*(\d{1,2}):(\d{2})');
final _spaces = RegExp(r'\s+');
final _nonDigits = RegExp(r'\D');

/// 본문에 "카드번호4자리+승인"(또는 승인취소/취소)이 있는지. 예: NH기업0000승인
bool hasCardApproval(String text, String cardDigits) {
  final c = text.replaceAll(_spaces, '');
  return cardDigits.isNotEmpty && (c.contains('$cardDigits승인') || c.contains('$cardDigits취소'));
}

/// [cardDigits] 승인 문자만 읽는다. 아니면 null. 광고·안내 문자도 여기서 걸러진다.
///
/// [requireCard] 가 false 면 카드번호 대신 "승인"/"취소" 만 본다.
/// 알림 제목의 발신번호로 이미 걸러진 문자를 읽을 때 쓴다.
///
/// 문자에는 연도가 없으므로 [receivedAt](문자 받은 시각) 기준으로 정한다.
/// 받은 시각보다 하루 넘게 미래가 되면 작년 문자로 본다. (12월 문자를 1월에 불러올 때)
ParsedSms? parseSms(
  String body, {
  required String cardDigits,
  DateTime? receivedAt,
  bool requireCard = true,
}) {
  final text = normalizeBody(body);
  if (requireCard) {
    if (!hasCardApproval(text, cardDigits)) return null;
  } else {
    final c = text.replaceAll(_spaces, '');
    if (!c.contains('승인') && !c.contains('취소')) return null;
  }

  final amountM = _amountRe.firstMatch(text);
  final dtM = _dateTimeRe.firstMatch(text);
  if (amountM == null || dtM == null) return null;

  final amount = int.parse(amountM.group(1)!.replaceAll(',', ''));
  final mo = int.parse(dtM.group(1)!);
  final d = int.parse(dtM.group(2)!);
  final h = int.parse(dtM.group(3)!);
  final mi = int.parse(dtM.group(4)!);
  if (amount <= 0 || mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;

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
  final merchant = cleanMerchant(line.split('누적').first);

  return ParsedSms(
    amount: amount,
    dateTime: dt,
    merchant: merchant,
    isCancel: text.replaceAll(_spaces, '').contains('취소'),
    raw: text.trim(),
  );
}

final _cardApprovalRe = RegExp(r'[가-힣A-Za-z]+\d{4}(?:승인|취소)');

/// 여러 문자를 한꺼번에 붙여넣거나 공유받았을 때 한 건씩 나눈다.
/// [Web발신] 단위로 먼저 나누고, 한 조각에 "카드명+네자리+승인"이 여러 번 있으면 그 앞에서 다시 나눈다.
/// (메시지 앱에서 여러 개를 복사하면 [Web발신] 없이 이어 붙는 경우가 있다)
List<String> splitMessages(String text) {
  final out = <String>[];
  for (final chunk in text.split('[Web발신]')) {
    final c = chunk.trim();
    if (c.isEmpty) continue;
    final starts = _cardApprovalRe.allMatches(c).map((m) => m.start).toList();
    if (starts.length < 2) {
      out.add(c);
      continue;
    }
    for (var i = 0; i < starts.length; i++) {
      final from = i == 0 ? 0 : starts[i]; // 첫 승인 앞부분은 첫 건에 붙인다
      final to = i + 1 < starts.length ? starts[i + 1] : c.length;
      final part = c.substring(from, to).trim();
      if (part.isNotEmpty) out.add(part);
    }
  }
  return out;
}

/// 전화번호를 비교용으로 정리한다. 숫자만 남기고 국가번호 82, 앞자리 0 을 뗀다.
String normalizeNumber(String s) {
  var d = s.replaceAll(_nonDigits, '');
  if (d.startsWith('82') && d.length >= 10) d = d.substring(2);
  return d.replaceFirst(RegExp(r'^0+'), '');
}

/// 발신번호 일치 여부. +82·0 같은 접두어가 붙어 있어도 맞도록 끝자리로 비교한다.
bool senderMatches(String? address, String configured) {
  if (address == null) return false;
  final a = normalizeNumber(address);
  final b = normalizeNumber(configured);
  if (a.length < 7 || b.length < 7) return false;
  return a.endsWith(b) || b.endsWith(a);
}
