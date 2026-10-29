import 'package:flutter/material.dart';

import 'quiz.dart';

const _gold = Color(0xFFF0A500);
const _navy = Color(0xFF1F3A68);
const _grey = Color(0xFF5F6368);

/// 안전 OX 공용 색 (O/X 버튼 네이비, 맞음 초록, 틀림 차분한 주황 — 혼나는 느낌 없게)
const kQuizNavy = _navy;
const kQuizGold = _gold;
const kQuizOk = Color(0xFF1E7B34);
const kQuizOkBg = Color(0xFFE8F5EC);
const kQuizMiss = Color(0xFF9A5B00);
const kQuizMissBg = Color(0xFFFFF4E5);

/// 큰 [O] [X] 버튼 (높이 64, 네이비 외곽선). [picked] 는 채워지고, [onPressed] 가 null 이면 고를 수 없음.
Widget quizOxButton(bool value, {required bool picked, required bool answered, VoidCallback? onPressed}) => SizedBox(
  height: 64,
  child: OutlinedButton(
    style: OutlinedButton.styleFrom(
      backgroundColor: picked ? _navy : Colors.white,
      foregroundColor: picked ? Colors.white : _navy,
      disabledForegroundColor: picked ? Colors.white : _navy.withValues(alpha: 0.45),
      side: BorderSide(color: answered && !picked ? _navy.withValues(alpha: 0.3) : _navy, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      splashFactory: NoSplash.splashFactory,
    ),
    onPressed: onPressed,
    child: Text(value ? 'O' : 'X'),
  ),
);

/// 골드 큰 버튼 ([확인], [다음 문제] 등)
Widget quizGoldButton(String label, VoidCallback onPressed) => FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: _gold,
    foregroundColor: const Color(0xFF3E2700),
    minimumSize: const Size.fromHeight(48),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),
  onPressed: onPressed,
  child: Text(label),
);

/// 정답·해설·근거 박스
Widget quizResultBox(QuizQuestion q, bool choice) {
  final ok = choice == q.answer;
  final mark = q.answer ? 'O' : 'X';
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(color: ok ? kQuizOkBg : kQuizMissBg, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ok ? '정답이에요! 정답은 $mark' : '아쉬워요. 정답은 $mark',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ok ? kQuizOk : kQuizMiss),
        ),
        if (q.explain.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(q.explain, style: const TextStyle(fontSize: 14, color: Color(0xFF1F1F1F))),
        ],
        if (q.basis.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('근거: ${q.basis}', style: const TextStyle(fontSize: 12, color: _grey)),
        ],
      ],
    ),
  );
}

/// 오늘의 안전 OX 바텀시트. 배경은 살짝만 어둡게, ✕·아래로 밀기·바깥 터치·뒤로가기 모두 바로 닫힌다(확인 없음).
/// 진동·소리·효과 없음. [onAnswer] 는 O/X 를 고른 순간 한 번 (기록 저장).
Future<void> showQuizSheet(
  BuildContext context,
  QuizQuestion q, {
  required Future<void> Function(bool choice) onAnswer,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  barrierColor: Colors.black.withValues(alpha: 0.28),
  sheetAnimationStyle: const AnimationStyle(
    duration: Duration(milliseconds: 220),
    reverseDuration: Duration(milliseconds: 150),
  ),
  builder: (_) => QuizSheet(question: q, onAnswer: onAnswer),
);

/// 문제 한 장. 오늘의 팝업(바텀시트)과 '한 문제 더 풀기' 화면이 같이 쓴다.
/// [sheet] 면 ✕ 버튼·닫기 안내·[확인] 이 있고, 아니면 답한 뒤 [actions] 를 보여준다.
class QuizSheet extends StatefulWidget {
  final QuizQuestion question;
  final Future<void> Function(bool choice) onAnswer;
  final bool sheet;
  final String label;
  final List<Widget> Function(BuildContext context)? actions;
  const QuizSheet({
    super.key,
    required this.question,
    required this.onAnswer,
    this.sheet = true,
    this.label = '오늘의 안전 OX',
    this.actions,
  });

  @override
  State<QuizSheet> createState() => _QuizSheetState();
}

class _QuizSheetState extends State<QuizSheet> {
  /// 고른 답. 고른 뒤엔 다시 못 바꾼다.
  bool? _choice;

  void _pick(bool v) {
    if (_choice != null) return;
    setState(() => _choice = v);
    widget.onAnswer(v);
  }

  Widget _button(bool value) => Expanded(
    child: quizOxButton(
      value,
      picked: _choice == value,
      answered: _choice != null,
      onPressed: _choice == null ? () => _pick(value) : null,
    ),
  );

  Widget _result() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        quizResultBox(widget.question, _choice!),
        const SizedBox(height: 12),
        ...widget.actions?.call(context) ?? [quizGoldButton('확인', () => Navigator.of(context).pop())],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 12, 16 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.label}${q.category.isEmpty ? '' : ' · ${q.category}'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _gold),
                ),
              ),
              if (widget.sheet)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: '닫기',
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F3F4)),
                    icon: const Icon(Icons.close, size: 20, color: _grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(q.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4)),
                const SizedBox(height: 20),
                Row(children: [_button(true), const SizedBox(width: 12), _button(false)]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _choice == null
                      ? !widget.sheet
                            ? const SizedBox(width: double.infinity)
                            : const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: Text(
                                  '아래로 내리거나 ✕를 누르면 바로 닫혀요',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Color(0xFF9AA0A6)),
                                ),
                              )
                      : _result(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
