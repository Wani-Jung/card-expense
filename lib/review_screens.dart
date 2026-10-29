import 'package:flutter/material.dart';

import 'check.dart';
import 'expense.dart';
import 'layout.dart';
import 'vendor.dart';

/// 메인과 같은 차량비/운영비 버튼 (추천 강조 포함, 작은 크기)
typedef CategoryButtonBuilder = Widget Function(String category, Recommendation? rec, VoidCallback onPressed,
    {String? label});

/// 날짜·가맹점 / 금액 한 줄
Widget _headline(Expense e) => Row(children: [
      Expanded(
        child: Text(
          '${fmtDateTime(e.dateTime)} · ${e.merchant.isEmpty ? '(가맹점 미상)' : e.merchant}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
      Text(e.isCancel ? '승인취소 ${won(e.signedAmount)}' : won(e.amount),
          style: TextStyle(fontWeight: FontWeight.bold, color: e.isCancel ? Colors.red : null)),
    ]);

Widget _smallOutlined(String label, VoidCallback onPressed) => SizedBox(
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

/// 달 구분선. "2026년 10월 ────"
class MonthDivider extends StatelessWidget {
  final String label;
  const MonthDivider(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368), fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
        ]),
      );
}

/// 메뉴 > 내역 관리 > 미분류 내역. 모든 달의 분류 대기 건을 최신순으로.
/// 버튼은 메인 분류 대기와 같은 동작 (추천 표시, 같은 업체 일괄 정리, 등록 업체 기억, 되돌리기).
class UnclassifiedScreen extends StatelessWidget {
  final List<Expense> items;
  final Listenable changes;
  final Recommendation? Function(String merchant) recommend;
  final Future<void> Function(Expense e, String category) onClassify;
  final CategoryButtonBuilder button;

  const UnclassifiedScreen({
    super.key,
    required this.items,
    required this.changes,
    required this.recommend,
    required this.onClassify,
    required this.button,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: changes,
        builder: (context, _) {
          final list = items.where((e) => e.category == null).toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return Scaffold(
            appBar: AppBar(title: Text('미분류 내역 (${list.length}건)')),
            body: list.isEmpty
                ? const Center(child: Text('미분류 내역이 없어요', style: TextStyle(color: Colors.black45)))
                : ListView(
                    padding: EdgeInsets.only(bottom: listBottomPad(context)),
                    children: [
                      for (final (i, e) in list.indexed) ...[
                        if (i == 0 || !list[i - 1].inMonth(e.dateTime))
                          MonthDivider('${e.dateTime.year}년 ${e.dateTime.month}월'),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _headline(e),
                            const SizedBox(height: 10),
                            Builder(builder: (_) {
                              final rec = recommend(e.merchant);
                              return Wrap(spacing: 6, runSpacing: 10, children: [
                                button(kCar, rec, () => onClassify(e, kCar)),
                                button(kOps, rec, () => onClassify(e, kOps)),
                                _smallOutlined('무시', () => onClassify(e, kIgnored)),
                              ]);
                            }),
                          ]),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
          );
        },
      );
}

/// 메뉴 > 내역 관리 > 확인 필요 내역. 실수 의심 규칙별로 묶어서 이유와 함께.
class CheckScreen extends StatelessWidget {
  final List<CheckIssue> Function() issues;
  final Listenable changes;
  final Future<void> Function(Expense e, String category) onChange;
  final Future<void> Function(CheckIssue issue) onOk;

  /// 중복 의심 [하나 무시]: [e] 를 '중복' 사유로 무시, 원본은 [original]
  final Future<void> Function(Expense e, Expense original) onIgnoreDuplicate;

  /// 승인 후 취소 [확인했어요]: 묶음 두 건을 함께 '취소로 상쇄'로 무시
  final Future<void> Function(CheckIssue issue) onConfirmCancel;
  final CategoryButtonBuilder button;

  const CheckScreen({
    super.key,
    required this.issues,
    required this.changes,
    required this.onChange,
    required this.onOk,
    required this.onIgnoreDuplicate,
    required this.onConfirmCancel,
    required this.button,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: changes,
        builder: (context, _) {
          final all = issues();
          return Scaffold(
            appBar: AppBar(title: Text('확인 필요 내역 (${all.length}건)')),
            body: all.isEmpty
                ? const Center(child: Text('확인이 필요한 내역이 없어요', style: TextStyle(color: Colors.black45)))
                : ListView(
                    padding: EdgeInsets.only(bottom: listBottomPad(context)),
                    children: [
                      for (final rule in CheckRule.values)
                        if (all.any((i) => i.rule == rule)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                            child: Text('${rule.title} (${all.where((i) => i.rule == rule).length}건)',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                          for (final i in all.where((i) => i.rule == rule)) _card(i),
                        ],
                    ],
                  ),
          );
        },
      );

  Widget _card(CheckIssue i) {
    if (i.rule == CheckRule.duplicate) return _duplicateCard(i);
    if (i.rule == CheckRule.cancelled) return _cancelledCard(i);
    final e = i.e;
    final to = oppositeCategory(e);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _headline(e),
          const SizedBox(height: 4),
          Text('현재 ${categoryLabel(e.category!)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(i.reason, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 10, children: [
            _smallOutlined('이대로 맞아요', () => onOk(i)),
            button(to, null, () => onChange(e, to), label: '${categoryLabel(to)}로 변경'),
          ]),
        ]),
      ),
    );
  }

  /// 승인 후 취소: 원승인 + 취소 한 카드. 한 건씩 따로 무시·분류하는 버튼은 없다.
  Widget _cancelledCard(CheckIssue i) {
    final o = i.group.first, c = i.group.last;
    String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                  '${two(o.dateTime.month)}.${two(o.dateTime.day)} · ${o.merchant.isEmpty ? '(가맹점 미상)' : o.merchant}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text(categoryLabel(o.category!), style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          ]),
          const SizedBox(height: 4),
          Text('${hm(o.dateTime)} 승인 ${won(o.amount)} / ${hm(c.dateTime)} 취소 ${won(-c.amount)} → 합계 0원',
              style: const TextStyle(fontSize: 13)),
          if (i.rebuy != null)
            Text('${hm(i.rebuy!.dateTime)} 재결제 ${won(i.rebuy!.amount)} 있음',
                style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          const SizedBox(height: 10),
          _smallOutlined('확인했어요', () => onConfirmCancel(i)),
        ]),
      ),
    );
  }

  /// 중복 의심: 묶음 하나를 카드 하나로 (시간 나란히). 카테고리 변경 버튼 없음.
  Widget _duplicateCard(CheckIssue i) {
    final first = i.group.first;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(first.merchant.isEmpty ? '(가맹점 미상)' : first.merchant,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text(first.isCancel ? '승인취소 ${won(first.signedAmount)}' : won(first.amount),
                style: TextStyle(fontWeight: FontWeight.bold, color: first.isCancel ? Colors.red : null)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final g in i.group)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(6)),
                child: Text('${fmtDateTime(g.dateTime)} · ${categoryLabel(g.category!)}',
                    style: const TextStyle(fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 4),
          Text(i.reason, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 10, children: [
            _smallOutlined('둘 다 맞아요', () => onOk(i)),
            // 가장 늦은 건을 무시, 원본은 가장 이른 건
            _smallOutlined('하나 무시', () => onIgnoreDuplicate(i.group.last, first)),
          ]),
        ]),
      ),
    );
  }
}
