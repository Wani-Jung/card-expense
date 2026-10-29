import 'expense.dart';
import 'vendor.dart';

/// 승인취소 묶음. 원승인 + 취소 한 쌍. 합계에는 둘 다 들어가 0 이 된다.
class CancelPair {
  final Expense origin, cancel;
  const CancelPair(this.origin, this.cancel);

  String get key => '${origin.id}+${cancel.id}';

  /// 묶음 안의 다른 한 건
  Expense partnerOf(Expense e) => identical(e, origin) ? cancel : origin;
}

/// 승인취소마다 같은 가맹점·같은 금액이면서 취소보다 이전인 승인 중 아직 안 묶인 가장 가까운 1건을 원승인으로 묶는다.
/// 시각은 분 단위라 같은 분의 승인은 취소보다 이전인 승인이 없을 때만 고른다
/// (13:23 승인 → 13:24 취소 → 13:24 재승인 이면 13:23 이 원승인).
/// 분류 여부와 상관없이 전체 내역에서 찾는다. 반환: 취소 id → 묶음.
Map<String, CancelPair> linkCancels(Iterable<Expense> items) {
  final cancels = items.where((e) => e.isCancel).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final approvals = items.where((e) => !e.isCancel).toList();
  final used = <String>{};
  final out = <String, CancelPair>{};
  for (final c in cancels) {
    final k = merchantKey(c.merchant);
    final cands = approvals
        .where((o) =>
            !used.contains(o.id) &&
            o.amount == c.amount &&
            merchantKey(o.merchant) == k &&
            !o.dateTime.isAfter(c.dateTime))
        .toList();
    if (cands.isEmpty) continue;
    final before = cands.where((o) => o.dateTime.isBefore(c.dateTime)).toList();
    final pool = before.isNotEmpty ? before : cands;
    pool.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final o = pool.first;
    used.add(o.id);
    out[c.id] = CancelPair(o, c);
  }
  return out;
}

/// 내역 id → 그 내역이 들어간 묶음 (원승인·취소 둘 다)
Map<String, CancelPair> pairsById(Iterable<Expense> items) {
  final out = <String, CancelPair>{};
  for (final p in linkCancels(items).values) {
    out[p.origin.id] = p;
    out[p.cancel.id] = p;
  }
  return out;
}

/// 묶음 취소 뒤 같은 가맹점·같은 금액 재승인 (취소 후 24시간 안, 다른 묶음에 안 든 건). 없으면 null.
Expense? rebuyAfter(CancelPair p, Iterable<Expense> items, Map<String, CancelPair> byId) {
  final c = p.cancel;
  final k = merchantKey(c.merchant);
  final list = items
      .where((e) =>
          !e.isCancel &&
          !byId.containsKey(e.id) &&
          e.category != kIgnored &&
          e.amount == c.amount &&
          merchantKey(e.merchant) == k &&
          !e.dateTime.isBefore(c.dateTime) &&
          e.dateTime.difference(c.dateTime) <= const Duration(hours: 24))
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return list.firstOrNull;
}

bool _classified(String? c) => c == kCar || c == kOps;

/// 묶인 취소 건의 카테고리를 원승인 카테고리에 맞춘다 (원승인이 차량비·운영비일 때만, [only] 가 있으면 그 취소들만).
/// 바꾼 취소 건 목록.
List<Expense> followOrigins(Iterable<Expense> items, {Set<String>? only}) {
  final changed = <Expense>[];
  for (final p in linkCancels(items).values) {
    if (only != null && !only.contains(p.cancel.id)) continue;
    final o = p.origin, c = p.cancel;
    if (!_classified(o.category) || c.category == o.category) continue;
    if (c.category == kIgnored && c.ignoreReason == kIgnoreOffset) continue;
    c
      ..category = o.category
      ..ignoreReason = null
      ..dupOf = null
      ..ignoredFrom = null;
    changed.add(c);
  }
  return changed;
}

/// v1.14 1회 바로잡기. 취소 묶음 때문에 '중복'으로 잘못 무시된 재결제를 원래 분류로 되살리고,
/// 묶인 취소 건 카테고리를 원승인에 맞춘다. 바로잡은 건수.
int fixCancelRebuys(List<Expense> items) {
  final byId = {for (final e in items) e.id: e};
  final pairs = pairsById(items);
  var fixed = 0;
  for (final e in items.where((e) => e.ignoredAsDuplicate && !pairs.containsKey(e.id)).toList()) {
    final orig = byId[e.dupOf];
    if (orig == null || e.isCancel) continue;
    final k = merchantKey(e.merchant);
    // 원본과 이 건 사이에 같은 가맹점·금액 취소가 있으면 취소 → 재결제
    final between = items.any((c) =>
        c.isCancel &&
        c.amount == e.amount &&
        merchantKey(c.merchant) == k &&
        !c.dateTime.isBefore(orig.dateTime) &&
        !c.dateTime.isAfter(e.dateTime));
    if (!between) continue;
    e
      ..category = _classified(orig.category) ? orig.category : null
      ..ignoreReason = null
      ..dupOf = null;
    fixed++;
  }
  return fixed + followOrigins(items).length;
}
