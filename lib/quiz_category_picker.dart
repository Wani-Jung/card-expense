import 'package:flutter/material.dart';

import 'quiz.dart';
import 'quiz_sheet.dart';

/// 문제 카드 위 작은 칩 '그룹 · 분야'
class QuizCategoryChip extends StatelessWidget {
  final QuizQuestion question;
  const QuizCategoryChip(this.question, {super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFE3E9F3), borderRadius: BorderRadius.circular(10)),
      child: Text(
        question.catLabel,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kQuizNavy),
      ),
    ),
  );
}

/// 분야 선택 (챌린지·한 문제 더 풀기). 그룹 제목 아래 분야 칩(다중 선택, 문항 수 표시),
/// 맨 위 [전체 선택] [전체 해제], 그룹 제목 옆 [그룹 전체] 토글. 0개 선택이면 안내.
class QuizCategoryPicker extends StatelessWidget {
  final QuizBank bank;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const QuizCategoryPicker({super.key, required this.bank, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final counts = bank.catCounts;
    final all = bank.allCatKeys;
    final total = bank.only(selected).active.length;
    Widget small(String label, VoidCallback? onPressed) => TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('분야', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected.isEmpty ? '분야를 하나 이상 골라 주세요' : '선택된 문제 $total개',
                style: TextStyle(fontSize: 12, color: selected.isEmpty ? kQuizMiss : const Color(0xFF5F6368)),
              ),
            ),
            small('전체 선택', selected.length == all.length ? null : () => onChanged({...all})),
            small('전체 해제', selected.isEmpty ? null : () => onChanged({})),
          ],
        ),
        for (final g in bank.groups) ...[
          Builder(
            builder: (context) {
              final keys = {for (final c in g.categories) '${g.name}|$c'};
              final allOn = keys.every(selected.contains);
              return Row(
                children: [
                  Text(
                    g.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3C4043)),
                  ),
                  const Spacer(),
                  small(
                    allOn ? '그룹 해제' : '그룹 전체',
                    () => onChanged(allOn ? ({...selected}..removeAll(keys)) : {...selected, ...keys}),
                  ),
                ],
              );
            },
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in g.categories)
                Builder(
                  builder: (_) {
                    final k = '${g.name}|$c';
                    final on = selected.contains(k);
                    return QuizSelectChip(
                      label: '$c ${counts[k] ?? 0}',
                      selected: on,
                      onTap: () => onChanged(on ? ({...selected}..remove(k)) : {...selected, k}),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// 선택 칩 (분야 칩·[전체]/[틀린 문제만] 필터 공용). 체크 표시 없이 색으로만 구분:
/// 선택 = 네이비(O/X 버튼과 같은 색) 채움 + 흰 글자, 비선택 = 흰 바탕 + 연회색 테두리 + 회색 글자.
/// 테두리 두께·글자 굵기·여백이 두 상태에서 같아 눌러도 칩 크기·줄바꿈이 바뀌지 않는다.
class QuizSelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const QuizSelectChip({super.key, required this.label, required this.selected, required this.onTap});

  static const borderOff = Color(0xFFDADCE0);
  static const textOff = Color(0xFF5F6368);

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? kQuizNavy : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? kQuizNavy : borderOff)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : textOff),
          ),
        ),
      ),
    ),
  );
}
