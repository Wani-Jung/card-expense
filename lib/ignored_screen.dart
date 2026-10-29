import 'package:flutter/material.dart';

import 'cancel_link.dart';
import 'expense.dart';
import 'layout.dart';
import 'vendor.dart';

/// 메뉴 > 무시한 내역. 지우지 않고 보관하던 문자를 사유별로 보여 주고 다시 분류하거나 대기로 되돌린다.
/// 되살린 건은 목록에서 빠지고 메인의 월별 내역/분류 대기로 간다.
class IgnoredScreen extends StatefulWidget {
  final List<Expense> items;
  final Recommendation? Function(String merchant) recommend;

  /// 메인 상태가 바뀔 때 올라간다 ([되돌리기] 등으로 바뀌면 다시 그린다)
  final Listenable changes;

  /// 카테고리 변경 + 저장 (메인 화면 상태를 같이 바꾼다, 알림·[되돌리기]도 메인이 띄운다)
  final Future<void> Function(Expense e, String? category) onChange;

  /// 되살리기 3종은 모두 미분류(분류 대기)로 보낸다. 알림·[보기]·[되돌리기]는 메인이 띄운다.
  /// [대기로 되돌리기] (승인취소 묶음이면 짝도)
  final Future<void> Function(Expense e) onRevive;

  /// '취소로 상쇄' 묶음 [되살리기]: 두 건 함께 미분류로 ([원승인, 취소])
  final Future<void> Function(List<Expense> group) onReviveOffset;

  /// 중복으로 무시한 건 [중복 아님 · 되살리기]: 분류 대기로, 그 쌍은 다시 중복 의심에 안 뜨게
  final Future<void> Function(Expense e) onReviveDuplicate;

  /// 메인과 같은 차량비/운영비 버튼 (추천 강조 포함)
  final Widget Function(Recommendation? rec, VoidCallback onPressed) carButton, opsButton;

  const IgnoredScreen({
    super.key,
    required this.items,
    required this.recommend,
    required this.changes,
    required this.onChange,
    required this.onReviveDuplicate,
    required this.onReviveOffset,
    required this.onRevive,
    required this.carButton,
    required this.opsButton,
  });

  @override
  State<IgnoredScreen> createState() => _IgnoredScreenState();
}

class _IgnoredScreenState extends State<IgnoredScreen> {
  Future<void> _set(Expense e, String? cat) async {
    await widget.onChange(e, cat);
    if (mounted) setState(() {});
  }

  Future<void> _revive(Expense e) async {
    await widget.onReviveDuplicate(e);
    if (mounted) setState(() {});
  }

  Future<void> _toPending(Expense e) async {
    await widget.onRevive(e);
    if (mounted) setState(() {});
  }

  Widget _outlined(String label, VoidCallback onPressed) => SizedBox(
    height: 30,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 30),
        textStyle: const TextStyle(fontSize: 12),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );

  Future<void> _reviveOffset(List<Expense> group) async {
    await widget.onReviveOffset(group);
    if (mounted) setState(() {});
  }

  /// '취소로 상쇄' 묶음 한 카드: 승인 + 취소, 합계 0원. 차량비/운영비 버튼 없음
  Widget _offsetTile(List<Expense> group) {
    final head = group.first;
    String line(Expense e) => '${fmtDateTime(e.dateTime)} ${e.isCancel ? '취소' : '승인'} ${won(e.signedAmount)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  head.merchant.isEmpty ? '(가맹점 미상)' : head.merchant,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                won(group.fold(0, (s, e) => s + e.signedAmount)),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final e in group) Text(line(e), style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          const Text('취소로 상쇄 · 합계 0원', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          const SizedBox(height: 10),
          _outlined('되살리기', () => _reviveOffset(group)),
        ],
      ),
    );
  }

  /// "원본 12.08 13:23 (차량비)"
  String _originalText(Expense e) {
    final o = widget.items.where((x) => x.id == e.dupOf).firstOrNull;
    if (o == null) return '원본 없음';
    final d = o.dateTime;
    final cat = o.category == kCar || o.category == kOps ? categoryLabel(o.category!) : '분류 대기';
    return '원본 ${two(d.month)}.${two(d.day)} ${two(d.hour)}:${two(d.minute)} ($cat)';
  }

  Widget _tile(Expense e) {
    final dup = e.ignoredAsDuplicate;
    final rec = dup ? null : widget.recommend(e.merchant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${fmtDateTime(e.dateTime)} · ${e.merchant.isEmpty ? '(가맹점 미상)' : e.merchant}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(won(e.signedAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          if (dup)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '중복이라 무시함 · ${_originalText(e)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (dup)
                _outlined('중복 아님 · 되살리기', () => _revive(e))
              else ...[
                widget.carButton(rec, () => _set(e, kCar)),
                widget.opsButton(rec, () => _set(e, kOps)),
                _outlined('대기로 되돌리기', () => _toPending(e)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: widget.changes, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final items = widget.items.where((e) => e.category == kIgnored).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final manual = items.where((e) => !e.ignoredAsDuplicate && !e.ignoredAsOffset).toList();
    final dups = items.where((e) => e.ignoredAsDuplicate).toList();
    // 취소로 상쇄: 묶음 [원승인, 취소] 하나가 카드 하나 (짝을 못 찾으면 혼자)
    final pairs = pairsById(widget.items);
    final offsets = <List<Expense>>[];
    final seen = <String>{};
    for (final e in items.where((e) => e.ignoredAsOffset)) {
      if (seen.contains(e.id)) continue;
      final p = pairs[e.id];
      final g = p != null && p.partnerOf(e).ignoredAsOffset ? [p.origin, p.cancel] : [e];
      seen.addAll(g.map((x) => x.id));
      offsets.add(g);
    }
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
      child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
    return Scaffold(
      appBar: AppBar(title: Text('무시한 내역 (${items.length}건)')),
      body: items.isEmpty
          ? const Center(
              child: Text('무시한 내역이 없어요', style: TextStyle(color: Colors.black45)),
            )
          : ListView(
              padding: EdgeInsets.only(bottom: listBottomPad(context)),
              children: [
                for (final (title, list) in [('직접 무시', manual), ('중복으로 무시', dups)])
                  if (list.isNotEmpty) ...[
                    header('$title (${list.length}건)'),
                    for (final (i, e) in list.indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      _tile(e),
                    ],
                  ],
                if (offsets.isNotEmpty) ...[
                  header('취소로 상쇄 (${offsets.fold(0, (s, g) => s + g.length)}건)'),
                  for (final (i, g) in offsets.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    _offsetTile(g),
                  ],
                ],
              ],
            ),
    );
  }
}
