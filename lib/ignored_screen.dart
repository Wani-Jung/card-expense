import 'package:flutter/material.dart';

import 'expense.dart';
import 'layout.dart';
import 'vendor.dart';

/// 메뉴 > 무시한 내역. 지우지 않고 보관하던 문자를 다시 분류하거나 대기로 되돌린다.
/// 되살린 건은 목록에서 빠지고 메인의 월별 내역/분류 대기로 간다.
class IgnoredScreen extends StatefulWidget {
  final List<Expense> items;
  final Recommendation? Function(String merchant) recommend;

  /// 카테고리 변경 + 저장 (메인 화면 상태를 같이 바꾼다)
  final Future<void> Function(Expense e, String? category) onChange;

  /// 메인과 같은 차량비/운영비 버튼 (추천 강조 포함)
  final Widget Function(Recommendation? rec, VoidCallback onPressed) carButton, opsButton;

  const IgnoredScreen({
    super.key,
    required this.items,
    required this.recommend,
    required this.onChange,
    required this.carButton,
    required this.opsButton,
  });

  @override
  State<IgnoredScreen> createState() => _IgnoredScreenState();
}

class _IgnoredScreenState extends State<IgnoredScreen> {
  Future<void> _set(Expense e, String? cat) async {
    await widget.onChange(e, cat);
    if (!mounted) return;
    setState(() {});
    final what = switch (cat) {
      kCar => '차량비로 분류했어요',
      kOps => '운영비로 분류했어요',
      _ => '분류 대기로 되돌렸어요',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${e.merchant.isEmpty ? won(e.signedAmount) : e.merchant} · $what')));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.where((e) => e.category == kIgnored).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return Scaffold(
      appBar: AppBar(title: Text('무시한 내역 (${items.length}건)')),
      body: items.isEmpty
          ? const Center(child: Text('무시한 내역이 없어요', style: TextStyle(color: Colors.black45)))
          : ListView.separated(
              padding: EdgeInsets.only(top: 4, bottom: listBottomPad(context)),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = items[i];
                final rec = widget.recommend(e.merchant);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          '${fmtDateTime(e.dateTime)} · ${e.merchant.isEmpty ? '(가맹점 미상)' : e.merchant}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(won(e.signedAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 10, children: [
                      widget.carButton(rec, () => _set(e, kCar)),
                      widget.opsButton(rec, () => _set(e, kOps)),
                      SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 30),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _set(e, null),
                          child: const Text('대기로 되돌리기'),
                        ),
                      ),
                    ]),
                  ]),
                );
              },
            ),
    );
  }
}
