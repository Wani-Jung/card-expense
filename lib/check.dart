import 'cancel_link.dart';
import 'expense.dart';
import 'vendor.dart';

/// '확인 필요 내역' 자동 검사 규칙. 분류된(차량비·운영비) 내역만 본다 — 대기·무시한 건은 대상 아님.
enum CheckRule {
  mixedVendor('같은 업체인데 분류가 다른 건'),
  recommendMismatch('추천·등록 업체와 반대로 분류한 건'),
  duplicate('중복 의심'),
  cancelled('승인 후 취소'),
  cancelPair('승인취소 짝이 안 맞는 건'),
  oddDate('날짜 이상');

  final String title;
  const CheckRule(this.title);
}

class CheckIssue {
  final CheckRule rule;
  final Expense e;
  final String reason;

  /// 중복 의심 묶음 (시간순, 자기 포함). 중복 의심은 묶음 하나가 카드 하나이고 [e] 는 가장 늦은 건.
  /// 승인 후 취소는 [원승인, 취소].
  final List<Expense> group;

  /// 승인 후 취소: 취소 뒤 같은 금액 재결제 (있으면)
  final Expense? rebuy;
  CheckIssue(this.rule, this.e, this.reason, [List<Expense>? group, this.rebuy]) : group = group ?? [e];

  /// '이대로 맞아요'·배너 닫기 기억용 키. 중복 의심·승인 후 취소는 묶음 전체 id.
  String get key => rule == CheckRule.duplicate || rule == CheckRule.cancelled
      ? '${rule.name}|${group.map((g) => g.id).join('+')}'
      : '${rule.name}|${e.id}';
}

/// 중복 의심 쌍 키 (순서 무관). [둘 다 맞아요]·[중복 아님 · 되살리기] 하면 이 쌍은 다시 안 묶는다.
String dupPairKey(String a, String b) {
  final ids = [a, b]..sort();
  return 'dup|${ids[0]}|${ids[1]}';
}

/// [이대로 맞아요]/[둘 다 맞아요] 할 때 check_ok 에 넣을 키
List<String> okKeysFor(CheckIssue i) => i.rule == CheckRule.duplicate
    ? [
        for (var x = 0; x < i.group.length; x++)
          for (var y = x + 1; y < i.group.length; y++) dupPairKey(i.group[x].id, i.group[y].id),
      ]
    : [i.key];

const _dupWindow = Duration(minutes: 10);

bool _classified(Expense e) => e.category == kCar || e.category == kOps;
String _other(String cat) => cat == kCar ? kOps : kCar;

/// 규칙 a~e 를 돌려 걸린 내역을 규칙 순서·최신순으로. [okKeys] 는 '이대로 맞아요' 한 키.
List<CheckIssue> findIssues(
  List<Expense> items,
  VendorBook vendors, {
  required DateTime now,
  Set<String> okKeys = const {},
}) {
  final out = <CheckIssue>[];
  final classified = items.where(_classified).toList();
  final links = linkCancels(items);
  final pairs = pairsById(items);

  // a. 같은 가맹점 다수 분류와 다른 쪽
  final byVendor = <String, List<Expense>>{};
  for (final e in classified) {
    final k = merchantKey(e.merchant);
    if (k.isNotEmpty) byVendor.putIfAbsent(k, () => []).add(e);
  }
  final mixedVendors = <String>{};
  final flaggedA = <String>{};
  for (final MapEntry(key: k, value: list) in byVendor.entries) {
    final car = list.where((e) => e.category == kCar).length;
    final ops = list.length - car;
    if (car == 0 || ops == 0) continue;
    mixedVendors.add(k);
    if (car == ops) continue; // 반반이면 어느 쪽이 실수인지 모름
    final major = car > ops ? kCar : kOps;
    for (final e in list.where((e) => e.category != major)) {
      flaggedA.add(e.id);
      out.add(CheckIssue(CheckRule.mixedVendor, e,
          '평소엔 ${categoryLabel(major)}로 분류한 업체예요 (${list.length}건 중 ${major == kCar ? car : ops}건)'));
    }
  }

  // b. 추천 키워드·등록 업체와 반대 (a 에 걸린 건, 분류가 섞인 업체의 등록 업체 비교는 a 가 맡음)
  for (final e in classified) {
    if (flaggedA.contains(e.id)) continue;
    final rec = vendors.recommend(e.merchant);
    if (rec == null || rec.category == e.category) continue;
    if (rec.source == RecSource.learned) {
      if (mixedVendors.contains(merchantKey(e.merchant))) continue;
      out.add(CheckIssue(CheckRule.recommendMismatch, e, '등록 업체는 ${categoryLabel(rec.category)}인데 ${categoryLabel(e.category!)}로 분류했어요'));
    } else {
      out.add(CheckIssue(
          CheckRule.recommendMismatch, e, '${categoryLabel(rec.category)} 추천 키워드가 들어 있는 가맹점이에요'));
    }
  }

  // c. 같은 가맹점·같은 금액이 10분 이내 2건 이상
  final sameKey = <String, List<Expense>>{};
  // 취소 묶음에 들어간 건(원승인·취소)은 빼고 본다. 결제 → 취소 → 재결제가 중복으로 잡히지 않게
  for (final e in classified.where((e) => !pairs.containsKey(e.id))) {
    sameKey.putIfAbsent('${merchantKey(e.merchant)}|${e.amount}|${e.isCancel}', () => []).add(e);
  }
  for (final list in sameKey.values) {
    if (list.length < 2) continue;
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    // 맞다고 한 쌍(v1.12 까지는 건마다 'duplicate|id')은 빼고, 남은 쌍에 걸린 건만 묶음으로
    bool okPair(Expense a, Expense b) =>
        okKeys.contains(dupPairKey(a.id, b.id)) ||
        (okKeys.contains('duplicate|${a.id}') && okKeys.contains('duplicate|${b.id}'));
    var cluster = <Expense>[list.first];
    void flush() {
      if (cluster.length < 2) return;
      final g = [
        for (final e in cluster)
          if (cluster.any((o) =>
              o != e && (o.dateTime.difference(e.dateTime)).abs() <= _dupWindow && !okPair(e, o)))
            e,
      ];
      if (g.length < 2) return;
      out.add(CheckIssue(CheckRule.duplicate, g.last, '같은 결제가 ${g.length}번 들어온 것 같아요', g));
    }

    for (final e in list.skip(1)) {
      if (e.dateTime.difference(cluster.last.dateTime) <= _dupWindow) {
        cluster.add(e);
      } else {
        flush();
        cluster = [e];
      }
    }
    flush();
  }

  // 승인 후 취소: 원승인·취소가 둘 다 분류된 묶음 하나 = 카드 하나
  for (final p in links.values) {
    if (!_classified(p.origin) || !_classified(p.cancel)) continue;
    out.add(CheckIssue(CheckRule.cancelled, p.cancel, '승인했다가 취소한 결제예요. 합계는 0원이에요',
        [p.origin, p.cancel], rebuyAfter(p, items, pairs)));
  }

  // d. 승인취소 짝: 원승인 없음 / 원승인과 분류가 다름. 원승인은 분류 여부와 상관없이 묶음(linkCancels)으로 찾는다.
  for (final c in classified.where((e) => e.isCancel)) {
    final link = links[c.id];
    if (link == null) {
      out.add(CheckIssue(CheckRule.cancelPair, c, '같은 금액의 원래 승인 내역이 없는 취소예요'));
      continue;
    }
    final o = link.origin;
    if (_classified(o) && o.category != c.category) {
      out.add(CheckIssue(CheckRule.cancelPair, c,
          '원래 승인(${fmtDateTime(o.dateTime)})은 ${categoryLabel(o.category!)}로 분류돼 있어요'));
    }
  }

  // e. 미래 날짜 / 1년보다 오래된 날짜
  for (final e in classified) {
    if (e.dateTime.isAfter(now.add(const Duration(minutes: 10)))) {
      out.add(CheckIssue(CheckRule.oddDate, e, '미래 날짜예요. 붙여넣기·캡처 인식 오류일 수 있어요'));
    } else if (e.dateTime.isBefore(now.subtract(const Duration(days: 365)))) {
      out.add(CheckIssue(CheckRule.oddDate, e, '1년보다 오래된 날짜예요. 붙여넣기·캡처 인식 오류일 수 있어요'));
    }
  }

  return out.where((i) => !okKeys.contains(i.key)).toList()
    ..sort((a, b) {
      final r = a.rule.index.compareTo(b.rule.index);
      return r != 0 ? r : b.e.dateTime.compareTo(a.e.dateTime);
    });
}

/// 카드에 보여줄 '반대쪽으로 변경' 카테고리
String oppositeCategory(Expense e) => _other(e.category ?? kCar);
