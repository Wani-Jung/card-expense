import 'dart:async';

import 'package:flutter/material.dart';

import 'challenge_card.dart';
import 'layout.dart';
import 'quiz.dart';
import 'quiz_category_picker.dart';
import 'quiz_screens.dart';
import 'quiz_sheet.dart';
import 'rural_quiz.dart';

const _grey = Color(0xFF5F6368);

String _today() => quizDay(DateTime.now());

/// 실험실 > 농어촌정비법 퀴즈: 요약(푼 문제·정답률) + 챌린지 / 한 문제 더 풀기 / 지난 문제 다시 보기.
/// 매일 퀴즈는 없다.
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
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kQuizNavy),
          ),
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
          item(
            Icons.emoji_events_outlined,
            '농어촌정비법 챌린지',
            '10~50문제, 시간과 정답률로 기록에 도전',
            RuralChallengeStartScreen(store: s, bank: widget.bank),
          ),
          const Divider(height: 1, thickness: 0.5),
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
            Text(
              '$n',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kQuizNavy),
            ),
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
          Row(children: [_Chip(q.catLabel), const SizedBox(width: 6), _Chip(q.isChoice ? '객관식' : 'OX')]),
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
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kQuizNavy),
    ),
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
    final all = [
      for (final r in widget.store.records)
        if (bank?.byId(r.id) != null) r,
    ];
    final runs = {for (final r in widget.store.runs) r.id: r};
    // 최신순, 날짜 안에서 묶음별: 챌린지 회차마다 카드 하나 / 한 문제 더 풀기 묶음 (묶음 순서 = 가장 최근 기록 순)
    final days = <String, Map<String, List<RuralRecord>>>{};
    for (final r in all.reversed) {
      final key = r.src == kQuizChallenge && r.run != null ? 'run:${r.run}' : 'extra';
      days.putIfAbsent(r.day, () => {}).putIfAbsent(key, () => []).add(r);
    }
    final groups = <({String day, String key, List<RuralRecord> records})>[];
    for (final MapEntry(key: day, value: byKey) in days.entries) {
      for (final MapEntry(:key, :value) in byKey.entries) {
        var list = value;
        if (key.startsWith('run:')) {
          list = list.reversed.toList(); // 푼 순서대로
          if (_wrongOnly && !list.any((r) => !r.correct)) continue;
        } else if (_wrongOnly) {
          list = list.where((r) => !r.correct).toList();
          if (list.isEmpty) continue;
        }
        groups.add((day: day, key: key, records: list));
      }
    }
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
                      QuizSelectChip(
                        label: '전체',
                        selected: !_wrongOnly,
                        onTap: () => setState(() => _wrongOnly = false),
                      ),
                      QuizSelectChip(
                        label: '틀린 문제만',
                        selected: _wrongOnly,
                        onTap: () => setState(() => _wrongOnly = true),
                      ),
                    ],
                  ),
                ),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        _wrongOnly ? '틀린 문제가 없어요' : '아직 푼 문제가 없어요',
                        style: const TextStyle(color: Colors.black45),
                      ),
                    ),
                  ),
                for (final (i, g) in groups.indexed) ...[
                  if (i == 0 || groups[i - 1].day != g.day)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Row(
                        children: [
                          Text(
                            _dayLabel(g.day),
                            style: const TextStyle(fontSize: 12, color: _grey, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Divider(height: 1)),
                        ],
                      ),
                    ),
                  if (g.key.startsWith('run:'))
                    RuralRunTile(run: runs[g.key.substring(4)], answers: g.records, bank: bank!)
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        '한 문제 더 풀기 · ${g.records.length}문제',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kQuizNavy),
                      ),
                    ),
                    for (final r in g.records) RuralRecordTile(record: r, question: bank!.byId(r.id)!),
                  ],
                ],
              ],
            ),
    );
  }
}

/// 챌린지 회차 트로피 카드 (시각·문항 수·정답률·시간). 누르면 카드 안에 그 회차 문제들 (왼쪽 남색 세로줄 + 연한 배경)
class RuralRunTile extends StatefulWidget {
  final ChallengeRun? run;
  final List<RuralRecord> answers;
  final RuralBank bank;
  const RuralRunTile({super.key, required this.run, required this.answers, required this.bank});

  @override
  State<RuralRunTile> createState() => _RuralRunTileState();
}

class _RuralRunTileState extends State<RuralRunTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final n = run?.n ?? widget.answers.length;
    final ok = run?.correct ?? widget.answers.where((a) => a.correct).length;
    final at = run == null ? null : DateTime.fromMillisecondsSinceEpoch(run.at);
    final time = at == null ? '' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined, color: kQuizGold),
            title: Text('챌린지 $n문제 · 정답률 ${n == 0 ? 0 : (ok * 100 / n).round()}%'),
            subtitle: Text(
              [if (time.isNotEmpty) time, '$ok/$n 정답', if (run?.ms != null) quizDuration(run!.ms!)].join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F4F9),
                border: Border(left: BorderSide(color: kQuizNavy, width: 3)),
              ),
              child: RuralAnswersList(answers: widget.answers, bank: widget.bank),
            ),
        ],
      ),
    );
  }
}

/// 챌린지 회차 문제 목록 ([전체] 기본 / [틀린 문제만])
class RuralAnswersList extends StatefulWidget {
  final List<RuralRecord> answers;
  final RuralBank bank;
  const RuralAnswersList({super.key, required this.answers, required this.bank});

  @override
  State<RuralAnswersList> createState() => _RuralAnswersListState();
}

class _RuralAnswersListState extends State<RuralAnswersList> {
  bool _wrongOnly = false;

  @override
  Widget build(BuildContext context) {
    final list = _wrongOnly ? widget.answers.where((a) => !a.correct).toList() : widget.answers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '틀린 문제가 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          ),
        for (final a in list)
          if (widget.bank.byId(a.id) != null) RuralRecordTile(record: a, question: widget.bank.byId(a.id)!),
      ],
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

// ------------------------------------------------------------------
// 농어촌정비법 챌린지 (REQ-48): 안전 OX 챌린지와 같은 구조, 기록·최고 기록은 rural_* 키에 따로
// ------------------------------------------------------------------

const kRuralChallengeTitle = '농어촌정비법 챌린지';
const kRuralCardSubtitle = '농어촌정비법 OX·객관식';

/// 결과 이미지와 함께 보내는 짧은 문구
String ruralShareText(ChallengeRun r) => '$kRuralChallengeTitle ${r.percent}%! 공감카드 관리에서 도전해보세요';

/// 시작: 분야 선택 + 문항 수 [10] [20] [30] [50] (활성 문항보다 크면 비활성) + 내 최고 기록 + 결과 카드 이름 + [시작]
class RuralChallengeStartScreen extends StatefulWidget {
  final RuralStore store;
  final Future<RuralBank?> Function() bank;
  const RuralChallengeStartScreen({super.key, required this.store, required this.bank});

  @override
  State<RuralChallengeStartScreen> createState() => _RuralChallengeStartScreenState();
}

class _RuralChallengeStartScreenState extends State<RuralChallengeStartScreen> {
  RuralBank? _bank;
  bool _loaded = false;
  Set<String> _cats = {};
  late int _want = widget.store.challengeSize;

  @override
  void initState() {
    super.initState();
    widget.bank().then((b) {
      if (!mounted) return;
      setState(() {
        _bank = b;
        _loaded = true;
        if (b != null) {
          final all = b.pickerBank.allCatKeys;
          _cats = (widget.store.challengeCats ?? all).intersection(all);
        }
      });
    });
  }

  int get _count => _bank == null ? 0 : RuralStore.activeCount(_bank!, _cats);
  int? get _n => _cats.isEmpty ? null : fitChallengeSize(_want, _count);

  Future<void> _setCats(Set<String> v) async {
    setState(() => _cats = v);
    await widget.store.setChallengeCats(v);
  }

  Future<void> _start() async {
    final n = _n!;
    await widget.store.setChallengeSize(n);
    final all = _cats.length == _bank!.pickerBank.allCatKeys.length;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RuralChallengeRunScreen(
          store: widget.store,
          bank: _bank!,
          questions: RuralStore.challengeSet(_bank!, n, cats: _cats),
          cats: all ? null : _cats.length,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final count = _count;
    final n = _n;
    return Scaffold(
      appBar: AppBar(title: const Text(kRuralChallengeTitle)),
      body: !_loaded
          ? const SizedBox.shrink()
          : bank == null
          ? const Center(child: Text('문제를 불러오지 못했어요'))
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, listBottomPad(context)),
              children: [
                QuizCategoryPicker(bank: bank.pickerBank, selected: _cats, onChanged: _setCats),
                const SizedBox(height: 12),
                const Text('몇 문제에 도전할까요?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '선택된 문제 $count개 · OX·객관식 섞어서 · 해설은 끝나고 볼 수 있어요',
                  style: const TextStyle(fontSize: 12, color: _grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final sz in kChallengeSizes) ...[
                      if (sz != kChallengeSizes.first) const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: n == sz ? kQuizNavy : Colors.white,
                              foregroundColor: n == sz ? Colors.white : kQuizNavy,
                              side: BorderSide(
                                color: challengeSizeEnabled(sz, count) ? kQuizNavy : const Color(0xFFDADCE0),
                              ),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: challengeSizeEnabled(sz, count) && _cats.isNotEmpty
                                ? () => setState(() => _want = sz)
                                : null,
                            child: Text('$sz'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                const Text('내 최고 기록', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                for (final sz in kChallengeSizes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text('$sz문제', style: const TextStyle(color: _grey)),
                        ),
                        Expanded(
                          child: Text(switch (widget.store.best(sz)) {
                            null => '-',
                            final b => '${b.percent}% (${b.correct}/${b.n}) · ${quizDuration(b.ms!)}',
                          }),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('결과 카드 이름', style: TextStyle(color: _grey)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (widget.store.nameStore.name ?? '').isEmpty ? '(없음 · 날짜만)' : widget.store.nameStore.name!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await askCardName(context, widget.store.nameStore);
                        if (mounted) setState(() {});
                      },
                      child: const Text('바꾸기'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_cats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '분야를 하나 이상 골라 주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kQuizMiss, fontSize: 13),
                    ),
                  ),
                quizGoldButton('시작', n == null ? null : _start),
              ],
            ),
    );
  }
}

/// 진행: 'N / 20', 경과 시간, 진행 막대, [O][X] 또는 보기 1~4. 답하면 0.6초 맞음/틀림 후 자동 다음.
/// ✕(또는 뒤로가기)는 그만둘지 확인 (기록 안 남음).
class RuralChallengeRunScreen extends StatefulWidget {
  final RuralStore store;
  final RuralBank bank;
  final List<RuralQuestion> questions;
  final int? cats;
  const RuralChallengeRunScreen({
    super.key,
    required this.store,
    required this.bank,
    required this.questions,
    this.cats,
  });

  @override
  State<RuralChallengeRunScreen> createState() => _RuralChallengeRunScreenState();
}

class _RuralChallengeRunScreenState extends State<RuralChallengeRunScreen> {
  List<RuralQuestion> get _qs => widget.questions;
  final _picks = <int>[];
  final _watch = Stopwatch()..start();
  late final int _startedAt = DateTime.now().millisecondsSinceEpoch;
  Timer? _tick, _advance;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _advance?.cancel();
    super.dispose();
  }

  void _pick(int v) {
    if (_picked != null) return;
    setState(() => _picked = v);
    _advance = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _picks.add(v);
      if (_picks.length >= _qs.length) {
        _finish();
      } else {
        setState(() => _picked = null);
      }
    });
  }

  Future<void> _finish() async {
    _watch.stop();
    _tick?.cancel();
    final day = _today();
    final id = 'c$_startedAt';
    final answers = [
      for (var i = 0; i < _qs.length; i++)
        RuralRecord(
          day,
          _qs[i].id,
          _picks[i],
          _qs[i].isCorrect(_picks[i]),
          src: kQuizChallenge,
          run: id,
          at: _startedAt,
        ),
    ];
    final run = ChallengeRun(
      id: id,
      at: _startedAt,
      n: _qs.length,
      correct: answers.where((a) => a.correct).length,
      ms: _watch.elapsedMilliseconds,
      cats: widget.cats,
    );
    final prevBest = widget.store.best(run.n);
    await widget.store.saveRun(run, answers);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RuralChallengeResultScreen(
          store: widget.store,
          bank: widget.bank,
          run: run,
          questions: _qs,
          answers: answers,
          newBest: isBetterRun(run, prevBest),
        ),
      ),
    );
  }

  Future<void> _quit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('챌린지를 그만둘까요? 기록은 남지 않아요'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('그만두기')),
        ],
      ),
    );
    if (quit == true && mounted) Navigator.of(context).pop();
  }

  Widget _choice(RuralQuestion q, int n) {
    final picked = _picked;
    final mine = picked == n;
    final answered = picked != null;
    // 답한 순간 0.6초: 내가 고른 보기를 맞음(초록)/틀림(주황)으로
    final bg = mine ? (q.isCorrect(n) ? kQuizOkBg : kQuizMissBg) : Colors.white;
    final border = mine ? (q.isCorrect(n) ? kQuizOk : kQuizMiss) : (answered ? const Color(0xFFDADCE0) : kQuizNavy);
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
        onPressed: answered ? null : () => _pick(n),
        child: Row(
          children: [
            Text(
              '$n',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kQuizNavy),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(keepWords(q.choices[n - 1]), style: const TextStyle(fontSize: 15))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = _picks.length;
    final q = _qs[i.clamp(0, _qs.length - 1)];
    final sec = _watch.elapsed.inSeconds;
    final picked = _picked;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('${i + 1} / ${_qs.length}'),
          actions: [
            Center(
              child: Text(
                '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            IconButton(tooltip: '그만두기', icon: const Icon(Icons.close), onPressed: _quit),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: i / _qs.length,
              minHeight: 4,
              color: kQuizNavy,
              backgroundColor: const Color(0xFFE3E9F3),
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, listBottomPad(context)),
          children: [
            Row(children: [_Chip(q.catLabel), const SizedBox(width: 6), _Chip(q.isChoice ? '객관식' : 'OX')]),
            const SizedBox(height: 8),
            Text(keepWords(q.question), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 24),
            if (q.isChoice)
              for (var n = 1; n <= 4; n++) _choice(q, n)
            else
              Row(
                children: [
                  for (final v in [1, 0]) ...[
                    if (v == 0) const SizedBox(width: 12),
                    Expanded(
                      child: quizOxButton(
                        v == 1,
                        picked: picked == v,
                        answered: picked != null,
                        onPressed: picked == null ? () => _pick(v) : null,
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 28,
              child: picked == null
                  ? null
                  : Text(
                      q.isCorrect(picked) ? '맞아요' : '아쉬워요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: q.isCorrect(picked) ? kQuizOk : kQuizMiss,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 결과: 결과 카드(그대로 공유 이미지) + 분야별 정답률 + [문제 전체 보기] [다시 도전] [결과 이미지 공유]
class RuralChallengeResultScreen extends StatefulWidget {
  final RuralStore store;
  final RuralBank bank;
  final ChallengeRun run;
  final List<RuralQuestion> questions;
  final List<RuralRecord> answers;
  final bool newBest;
  const RuralChallengeResultScreen({
    super.key,
    required this.store,
    required this.bank,
    required this.run,
    required this.questions,
    required this.answers,
    required this.newBest,
  });

  @override
  State<RuralChallengeResultScreen> createState() => _RuralChallengeResultScreenState();
}

class _RuralChallengeResultScreenState extends State<RuralChallengeResultScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    await shareChallengeCard(
      context,
      cardKey: _cardKey,
      nameStore: widget.store.nameStore,
      fileName: 'rural_${widget.run.id}.png',
      text: ruralShareText(widget.run),
      onNameChanged: () => setState(() {}),
    );
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    // 분야별 정답 수 (나온 순서대로)
    final byCat = <String, ({String label, int correct, int n})>{};
    for (var i = 0; i < w.questions.length && i < w.answers.length; i++) {
      final q = w.questions[i];
      final cur = byCat[q.catKey] ?? (label: q.catLabel, correct: 0, n: 0);
      byCat[q.catKey] = (label: cur.label, correct: cur.correct + (w.answers[i].correct ? 1 : 0), n: cur.n + 1);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('챌린지 결과')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, listBottomPad(context)),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: RepaintBoundary(
                key: _cardKey,
                child: ChallengeResultCard(
                  run: w.run,
                  name: w.store.nameStore.name,
                  date: DateTime.fromMillisecondsSinceEpoch(w.run.at),
                  newBest: w.newBest,
                  title: kRuralChallengeTitle,
                  subtitle: kRuralCardSubtitle,
                  gradeTopic: '정비법',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('분야별 정답률', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final c in byCat.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(c.label, style: const TextStyle(fontSize: 13))),
                  Text(
                    '${c.correct}/${c.n}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.correct == c.n ? kQuizOk : kQuizNavy,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text('문제 전체 보기 (${w.answers.length}문제)')),
                  body: ListView(
                    padding: EdgeInsets.only(bottom: listBottomPad(context)),
                    children: [RuralAnswersList(answers: w.answers, bank: w.bank)],
                  ),
                ),
              ),
            ),
            child: const Text('문제 전체 보기'),
          ),
          const SizedBox(height: 8),
          quizGoldButton(
            '다시 도전',
            () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => RuralChallengeRunScreen(
                  store: w.store,
                  bank: w.bank,
                  // 같은 분야·같은 문항 수로 새로 뽑는다
                  questions: RuralStore.challengeSet(
                    w.bank,
                    w.run.n,
                    cats: w.run.cats == null ? null : w.store.challengeCats,
                  ),
                  cats: w.run.cats,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: _sharing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_outlined),
            label: const Text('결과 이미지 공유'),
            onPressed: _sharing ? null : _share,
          ),
        ],
      ),
    );
  }
}
