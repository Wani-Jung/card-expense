import 'expense.dart';
import 'native.dart';
import 'sms_parser.dart';

/// 붙여넣기·공유·문자 불러오기·캡처로 들어온 문자를 분류한 결과.
class IngestReport {
  /// 처음 보는 승인 문자.
  final List<ParsedSms> fresh;

  /// 진짜 중복: 이미 분류됐거나 대기 중인 것, 또는 같은 묶음 안에서 겹친 것.
  final int dup;

  /// 예전에 '무시'한 내역과 같은 문자. 버리지 않고 따로 세서 되살릴 수 있게 한다.
  final List<ParsedSms> ignoredHits;

  /// 승인 문자로 읽지 못한 조각 (왜 인식 안 됐는지 보여주기용).
  final List<String> rejected;

  const IngestReport({
    this.fresh = const [],
    this.dup = 0,
    this.ignoredHits = const [],
    this.rejected = const [],
  });

  int get total => fresh.length + dup + ignoredHits.length + rejected.length;

  /// "추가 0건 · 중복 0건 · 무시했던 문자 1건(되살리기) · 승인 문자 아님 1건"
  String summary({int? added, bool revived = false}) => [
        '추가 ${added ?? fresh.length}건',
        '중복 $dup건',
        if (ignoredHits.isNotEmpty) '무시했던 문자 ${ignoredHits.length}건(${revived ? '되살림' : '되살리기'})',
        if (rejected.isNotEmpty) '승인 문자 아님 ${rejected.length}건',
      ].join(' · ');
}

/// [raws] 를 파싱해서 새 내역 / 중복 / 무시했던 문자 / 승인 문자 아님으로 나눈다.
/// [existing] 은 지금 저장된 내역 (id → 내역).
IngestReport classifyMessages(
  List<RawSms> raws, {
  required String digits,
  required Map<String, Expense> existing,
  bool requireCard = true,
}) {
  final seen = <String>{};
  final fresh = <ParsedSms>[];
  final ignored = <ParsedSms>[];
  final rejected = <String>[];
  var dup = 0;
  for (final r in raws) {
    final p = parseSms(r.body, cardDigits: digits, receivedAt: r.receivedAt, requireCard: requireCard);
    if (p == null) {
      rejected.add(r.body.trim());
      continue;
    }
    if (!seen.add(p.id)) {
      dup++;
      continue;
    }
    final ex = existing[p.id];
    if (ex == null) {
      fresh.add(p);
    } else if (ex.category == kIgnored) {
      ignored.add(p);
    } else {
      dup++;
    }
  }
  return IngestReport(fresh: fresh, dup: dup, ignoredHits: ignored, rejected: rejected);
}

/// 붙여넣기·공유 텍스트를 한 건씩 나눈다.
List<RawSms> splitToRaw(Iterable<String> texts, DateTime receivedAt) =>
    [for (final t in texts) for (final m in splitMessages(t)) RawSms(m, receivedAt)];
