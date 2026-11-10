import 'package:flutter/material.dart';

import 'layout.dart';
import 'quiz.dart';
import 'quiz_category_picker.dart';
import 'quiz_screens.dart';
import 'quiz_sheet.dart';
import 'rural_quiz.dart';

const _grey = Color(0xFF5F6368);

String _today() => quizDay(DateTime.now());

/// 실험실 > 농어촌정비법 퀴즈: 요약(푼 문제·정답률) + 한 문제 더 풀기 / 지난 문제 다시 보기.
/// 챌린지·매일 퀴즈는 없다.
class RuralQuizHomeScreen extends StatefulWidget {
  final RuralStore store;
  final Future<RuralBank?> Function() bank;
  const RuralQuizHomeScreen({super.key, required this.store, required this.bank});

  @override
  State<RuralQuizHomeScreen> createState() => _RuralQuizHomeScreenState();
}

class _RuralQuizHomeScreenState extends State<RuralQuizHomeScreen> {
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final p = s.percent;
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kQuizNavy)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: _grey)),
        ],
      ),
    );
    Widget item(IconData icon, String title, String sub, Widget screen) => ListTile(
      leading: Icon(icon, color: kQuizNavy),
      title: Text(title),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(screen),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('농어촌정비법 퀴즈')),
      body: ListView(
        padding: EdgeInsets.only(bottom: listBottomPad(context)),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: const Color(0xFFF1F4F9), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [stat('${s.solvedCount}', '푼 문제'), stat(p == null ? '-' : '$p%', '정답률')]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              keepWords('농어촌정비법·시행령에서 낸 OX·객관식 문제예요. 분야를 골라 풀 수 있어요.'),
              style: const TextStyle(fontSize: 12, color: _grey),
            ),
          ),
          item(Icons.add_task, '한 문제 더 풀기', '분야를 골라 원하는 만큼 풀어요', RuralPracticeScreen(store: s, bank: widget.bank)),
          const Divider(height: 1, thickness: 0.5),
          item(Icons.history_edu, '지난 문제 다시 보기', '푼 문제를 날짜별로 다시 봐요', RuralHistoryScreen(store: s, bank: widget.bank)),
        ],
      ),
    );
  }
}

/// 한 문제 더 풀기: 분야 선택(접힘) + 문제 카드 (OX 또는 4지선다). 오늘 푼 문제는 오늘 다시 안 나온다.
class RuralPracticeScreen extends StatefulWidget {
  final RuralStore store;
  final Future<RuralBank?> Function() bank;
  const RuralPracticeScreen({super.key, required this.store, required this.bank});

  @override
  State<RuralPracticeScreen> createState() => _RuralPracticeScreenState();
}

class _RuralPracticeScreenState extends State<RuralPracticeScreen> {
  RuralBank? _bank;
  RuralQuestion? _q;
  Set<String> _cats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.bank().then((b) {
      if (!mounted) return;
      if (b == null) {
        setState(() => _loading = false);
        return;
      }
      _bank = b;
      final all = b.pickerBank.allCatKeys;
      _cats = (widget.store.cats ?? all).intersection(all);
      _next();
    });
  }

  Future<void> _next() async {
    final cats = _cats;
    final q = cats.isEmpty
        ? null
        : await widget.store.next(_bank!, exclude: widget.store.solvedOn(_today()), cats: cats);
    if (!mounted) return;
    setState(() {
      _q = q;
      _loading = false;
    });
  }

  Future<void> _setCats(Set<String> v) async {
    setState(() => _cats = v);
    await widget.store.setCats(v);
    if (_q == null || !v.contains(_q!.catKey)) await _next();
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final q = _q;
    final picker = bank == null
        ? const SizedBox.shrink()
        : ExpansionTile(
            title: Text(
              _cats.length == bank.pickerBank.allCatKeys.length ? '분야: 전체' : '분야: ${_cats.length}개 선택',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [QuizCategoryPicker(bank: bank.pickerBank, selected: _cats, onChanged: _setCats)],
          );
    return Scaffold(
      appBar: AppBar(title: const Text('농어촌정비법 퀴즈')),
      body: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.only(bottom: listBottomPad(context)),
              children: [
                picker,
                if (q == null)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      bank == null
                          ? '문제를 불러오지 못했어요'
                          : _cats.isEmpty
                          ? '분야를 하나 이상 골라 주세요'
                          : '고른 분야의 문제를 오늘 모두 풀었어요!\n내일 다시 만나요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: _grey, height: 1.5),
                    ),
                  )
                else
                  RuralQuestionCard(
                    key: ValueKey(q.id),
                    question: q,
                    onAnswer: (pick) => widget.store.record(
                      RuralRecord(_today(), q.id, pick, q.isCorrect(pick), at: DateTime.now().millisecondsSinceEpoch),
                    ),
                    onNext: _next,
                    onStop: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
    );
  }
}

/// 문제 카드: 분야 칩 + 문제 + [O][X] 또는 보기 1~4. 고르면 정답·해설·근거, [다음 문제] [그만하기].
class RuralQuestionCard extends StatefulWidget {
  final RuralQuestion question;
  final Future<void> Function(int pick) onAnswer;
  final VoidCallback onNext, onStop;
  const RuralQuestionCard({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.onNext,
    required this.onStop,
  });

  @override
  State<RuralQuestionCard> createState() => _RuralQuestionCardState();
}

class _RuralQuestionCardState extends State<RuralQuestionCard> {
  int? _pick;

  Future<void> _choose(int pick) async {
    if (_pick != null) return;
    setState(() => _pick = pick);
    await widget.onAnswer(pick);
  }

  Widget _choiceButton(int n, String text) {
    final q = widget.question;
    final answered = _pick != null;
    final isAnswer = n == q.answer;
    final picked = n == _pick;
    // 답한 뒤: 정답은 초록, 내가 고른 오답은 주황
    final bg = !answered
        ? Colors.white
        : isAnswer
        ? kQuizOkBg
        : picked
        ? kQuizMissBg
        : Colors.white;
    final border = !answered
        ? kQuizNavy
        : isAnswer
        ? kQuizOk
        : picked
        ? kQuizMiss
        : const Color(0xFFDADCE0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledForegroundColor: const Color(0xFF1F1F1F),
          side: BorderSide(color: border, width: 1.4),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: answered ? null : () => _choose(n),
        child: Row(
          children: [
            Text('$n', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kQuizNavy)),
            const SizedBox(width: 12),
            Expanded(child: Text(keepWords(text), style: const TextStyle(fontSize: 15))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final pick = _pick;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Chip(q.catLabel),
              const SizedBox(width: 6),
              _Chip(q.isChoice ? '객관식' : 'OX'),
            ],
          ),
          const SizedBox(height: 10),
          Text(keepWords(q.question), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4)),
          const SizedBox(height: 16),
          if (q.isChoice)
            for (var i = 0; i < 4; i++) _choiceButton(i + 1, q.choices[i])
          else
            Row(
              children: [
                for (final v in [1, 0]) ...[
                  if (v == 0) const SizedBox(width: 12),
                  Expanded(
                    child: quizOxButton(
                      v == 1,
                      picked: pick == v,
                      answered: pick != null,
                      onPressed: pick == null ? () => _choose(v) : null,
                    ),
                  ),
                ],
              ],
            ),
          if (pick != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: q.isCorrect(pick) ? kQuizOkBg : kQuizMissBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.isCorrect(pick) ? '정답이에요! 정답은 ${q.label(q.answer)}' : '아쉬워요. 정답은 ${q.label(q.answer)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: q.isCorrect(pick) ? kQuizOk : kQuizMiss,
                    ),
                  ),
                  if (q.explain.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(keepWords(q.explain), style: const TextStyle(fontSize: 14, height: 1.45)),
                  ],
                  if (q.basis.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('근거: ${q.basis}', style: const TextStyle(fontSize: 12, color: _grey)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            quizGoldButton('다음 문제', widget.onNext),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: widget.onStop,
              child: const Text('그만하기'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFFE3E9F3), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kQuizNavy)),
  );
}

/// 지난 문제 다시 보기: 최신순, 날짜 구분, [전체] [틀린 문제만]. 문제마다 '내 답 → 정답' 줄 오른쪽 [해설] 말풍선.
class RuralHistoryScreen extends StatefulWidget {
  final RuralStore store;
  final Future<RuralBank?> Function() bank;
  const RuralHistoryScreen({super.key, required this.store, required this.bank});

  @override
  State<RuralHistoryScreen> createState() => _RuralHistoryScreenState();
}

class _RuralHistoryScreenState extends State<RuralHistoryScreen> {
  RuralBank? _bank;
  bool _loaded = false;
  bool _wrongOnly = false;

  @override
  void initState() {
    super.initState();
    widget.bank().then((b) {
      if (mounted) {
        setState(() {
          _bank = b;
          _loaded = true;
        });
      }
    });
  }

  static String _dayLabel(String day) {
    final p = day.split('-');
    return '${p[0]}년 ${int.parse(p[1])}월 ${int.parse(p[2])}일';
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final records = [
      for (final r in widget.store.records.reversed)
        if (bank?.byId(r.id) != null && (!_wrongOnly || !r.correct)) r,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('지난 문제 다시 보기')),
      body: !_loaded
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.only(bottom: listBottomPad(context)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      QuizSelectChip(label: '전체', selected: !_wrongOnly, onTap: () => setState(() => _wrongOnly = false)),
                      QuizSelectChip(label: '틀린 문제만', selected: _wrongOnly, onTap: () => setState(() => _wrongOnly = true)),
                    ],
                  ),
                ),
                if (records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        _wrongOnly ? '틀린 문제가 없어요' : '아직 푼 문제가 없어요',
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ),
                  ),
                for (final (i, r) in records.indexed) ...[
                  if (i == 0 || records[i - 1].day != r.day)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Row(
                        children: [
                          Text(
                            _dayLabel(r.day),
                            style: const TextStyle(fontSize: 12, color: _grey, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Divider(height: 1)),
                        ],
                      ),
                    ),
                  RuralRecordTile(record: r, question: bank!.byId(r.id)!),
                ],
              ],
            ),
    );
  }
}

/// 문제 한 줄: 문제(객관식이면 보기 목록), '내 답 → 정답' + [해설] 버튼 → 말풍선
class RuralRecordTile extends StatefulWidget {
  final RuralRecord record;
  final RuralQuestion question;
  const RuralRecordTile({super.key, required this.record, required this.question});

  @override
  State<RuralRecordTile> createState() => _RuralRecordTileState();
}

class _RuralRecordTileState extends State<RuralRecordTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final q = widget.question;
    final color = r.correct ? kQuizOk : kQuizMiss;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [_Chip(q.catLabel), const SizedBox(width: 6), _Chip(q.isChoice ? '객관식' : 'OX')]),
          const SizedBox(height: 4),
          Text(keepWords(q.question), style: const TextStyle(fontSize: 14)),
          if (q.isChoice)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 4; i++)
                    Text(
                      '${i + 1}. ${q.choices[i]}',
                      style: TextStyle(
                        fontSize: 13,
                        color: i + 1 == q.answer ? kQuizOk : _grey,
                        fontWeight: i + 1 == q.answer ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(r.correct ? Icons.check_circle : Icons.info_outline, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '내 답 ${q.label(r.pick)} → 정답 ${q.label(q.answer)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              SizedBox(
                height: 30,
                child: _open
                    ? FilledButton(
                        style: quizExplainButtonStyle(filled: true),
                        onPressed: () => setState(() => _open = false),
                        child: const Text('해설'),
                      )
                    : OutlinedButton(
                        style: quizExplainButtonStyle(filled: false),
                        onPressed: () => setState(() => _open = true),
                        child: const Text('해설'),
                      ),
              ),
            ],
          ),
          if (_open) QuizExplainBubble(explain: q.explain, catLabel: q.catLabel, basis: q.basis),
        ],
      ),
    );
  }
}
