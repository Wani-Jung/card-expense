import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'challenge_card.dart';
import 'layout.dart';
import 'native.dart';
import 'quiz.dart';
import 'quiz_category_picker.dart';
import 'quiz_sheet.dart';

const _grey = Color(0xFF5F6368);

String _today() => quizDay(DateTime.now());

/// 점수 기록 지우기 확인 문구 (지워지는 것 / 남는 것. QuizStore.clearScores 동작 그대로)
const kClearScoresMessage =
    '지워지는 것\n'
    "· 정답률 (지운 뒤 다음에 푸는 문제부터 새로 계산, 그 전까지 '-')\n"
    '· 문제마다 내 답·맞음/틀림\n'
    '· 챌린지 정답률·걸린 시간·최고 기록\n\n'
    '남는 것\n'
    '· 푼 문제 수\n'
    '· 연속 일수\n'
    '· 지난 문제 다시 보기 목록 (문제·정답·해설, 챌린지 회차)\n\n'
    '지운 직후 [되돌리기]로 되살릴 수 있어요.';

/// 메뉴 > 안전 OX. 요약 카드 + 지난 문제 다시 보기 / 한 문제 더 풀기 / 안전 OX 챌린지
class QuizHomeScreen extends StatefulWidget {
  final QuizStore store;
  final Future<QuizBank> Function() bank;
  const QuizHomeScreen({super.key, required this.store, required this.bank});

  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {}); // 돌아오면 요약 다시
  }

  /// 점수 기록 지우기: 확인 → 지우기 → 5초 [되돌리기]. 푼 문제·날짜·출처·연속 일수·이름은 남는다.
  Future<void> _clearScores() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('점수 기록을 지울까요?'),
        content: const Text(kClearScoresMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD93025)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final snap = widget.store.snapshotScores();
    await widget.store.clearScores();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('점수 기록을 지웠어요'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () async {
              await widget.store.restoreScores(snap);
              if (mounted) setState(() {});
            },
          ),
        ),
      );
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
      appBar: AppBar(title: const Text('안전 OX Quiz')),
      body: ListView(
        padding: EdgeInsets.only(bottom: listBottomPad(context)),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: const Color(0xFFF1F4F9), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                stat('${s.solvedCount}', '푼 문제'),
                stat(p == null ? '-' : '$p%', '정답률'),
                stat('${s.streak(_today())}일', '연속'),
              ],
            ),
          ),
          item(Icons.history_edu, '지난 문제 다시 보기', '푼 문제를 날짜별로 다시 봐요', QuizHistoryScreen(store: s, bank: widget.bank)),
          const Divider(height: 1, thickness: 0.5),
          item(Icons.add_task, '한 문제 더 풀기', '원하는 만큼 계속 풀어요', QuizPracticeScreen(store: s, bank: widget.bank)),
          const Divider(height: 1, thickness: 0.5),
          item(
            Icons.emoji_events_outlined,
            '안전 OX 챌린지',
            '10~50문제, 시간과 정답률로 기록에 도전',
            ChallengeStartScreen(store: s, bank: widget.bank),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 0.5),
          SwitchListTile(
            title: const Text('매일 OX 퀴즈'),
            subtitle: const Text('켜면 앱을 열 때 하루 한 번 안전 OX 퀴즈가 나옵니다.', style: TextStyle(fontSize: 12)),
            value: s.dailyOn,
            onChanged: (v) async {
              await s.setDailyOn(v);
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9AA0A6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: _clearScores,
              child: const Text('점수 기록 지우기'),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// 지난 문제 다시 보기
// ------------------------------------------------------------------

/// 푼 기록 최신순 + 날짜 구분선. 날짜 안에서는 챌린지 회차 카드 / '한 문제 더 풀기' / '매일 퀴즈' 묶음으로 나눈다.
class QuizHistoryScreen extends StatefulWidget {
  final QuizStore store;
  final Future<QuizBank> Function() bank;
  const QuizHistoryScreen({super.key, required this.store, required this.bank});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  QuizBank? _bank;
  bool _wrongOnly = false;

  @override
  void initState() {
    super.initState();
    widget.bank().then((b) {
      if (mounted) setState(() => _bank = b);
    });
  }

  static String _dayLabel(String day) {
    final p = day.split('-');
    return '${p[0]}년 ${int.parse(p[1])}월 ${int.parse(p[2])}일';
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    // 지금 문제 풀에 없는 id(예전 q001~ 등)는 목록에서 숨긴다. 날짜 기록(연속·오늘 제외)은 그대로 남아 있다.
    final records = [
      for (final r in widget.store.records)
        if (bank?.byId(r.id) != null) r,
    ];
    final runs = {for (final r in widget.store.runs) r.id: r};
    // 점수 기록을 지운 뒤(점수 있는 기록이 없으면)는 [틀린 문제만] 칩을 숨긴다
    final scored = widget.store.hasScores;
    if (!scored) _wrongOnly = false;
    // 최신순: 저장 순서가 시간순이므로 뒤집는다. 날짜 안에서는 묶음별로 나눈다:
    // 챌린지 회차마다 카드 하나, '한 문제 더 풀기' 묶음, '매일 퀴즈' 묶음 (묶음 순서 = 그 묶음의 가장 최근 기록 순)
    final days = <String, Map<String, _HistoryGroup>>{};
    for (final r in records.reversed) {
      final key = r.src == kQuizChallenge && r.run != null ? 'run:${r.run}' : r.src;
      final g = days.putIfAbsent(r.day, () => {}).putIfAbsent(key, () => _HistoryGroup(r.src, r.run));
      g.records.add(r);
    }
    final groups = <({String day, _HistoryGroup g})>[];
    for (final MapEntry(key: day, value: byKey) in days.entries) {
      for (final g in byKey.values) {
        if (g.run != null) {
          // 챌린지 문제는 푼 순서대로, [틀린 문제만]이면 틀린 문제가 있는 회차만
          g.records.setAll(0, g.records.reversed.toList());
          if (_wrongOnly && !g.records.any((a) => a.correct == false)) continue;
        } else if (_wrongOnly) {
          g.records.removeWhere((r) => r.correct != false);
          if (g.records.isEmpty) continue;
        }
        groups.add((day: day, g: g));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('지난 문제 다시 보기')),
      body: bank == null
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.only(bottom: listBottomPad(context)),
              children: [
                if (scored) _FilterChips(wrongOnly: _wrongOnly, onChanged: (v) => setState(() => _wrongOnly = v)),
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
                for (final (i, e) in groups.indexed) ...[
                  if (i == 0 || groups[i - 1].day != e.day) _DayDivider(_dayLabel(e.day)),
                  if (e.g.run != null)
                    _RunTile(run: runs[e.g.run], answers: e.g.records, bank: bank)
                  else ...[
                    _GroupTitle(
                      e.g.src == kQuizExtra ? '한 문제 더 풀기 · ${e.g.records.length}문제' : '매일 퀴즈 · ${e.g.records.length}문제',
                    ),
                    for (final r in e.g.records) QuizRecordTile(record: r, question: bank.byId(r.id)),
                  ],
                ],
              ],
            ),
    );
  }
}

/// 지난 문제 다시 보기의 한 묶음 (같은 날, 같은 출처. 챌린지는 회차별)
class _HistoryGroup {
  final String src;
  final String? run;
  final records = <QuizRecord>[];
  _HistoryGroup(this.src, this.run);
}

/// 묶음 소제목 '한 문제 더 풀기 · n문제' / '매일 퀴즈 · n문제'
class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kQuizNavy),
    ),
  );
}

class _DayDivider extends StatelessWidget {
  final String label;
  const _DayDivider(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1)),
      ],
    ),
  );
}

/// 문제 한 줄: 문제, 내 답 → 정답 (맞으면 초록 체크, 틀리면 차분한 주황) + 오른쪽 [해설].
/// [해설]을 누르면 바로 아래 말풍선(위쪽 꼬리)에 해설·분야·근거가 펼쳐지고, 다시 누르면 접힌다.
class QuizRecordTile extends StatefulWidget {
  final QuizRecord record;
  final QuizQuestion? question;
  const QuizRecordTile({super.key, required this.record, required this.question});

  @override
  State<QuizRecordTile> createState() => _QuizRecordTileState();
}

class _QuizRecordTileState extends State<QuizRecordTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final q = widget.question;
    String ox(bool v) => v ? 'O' : 'X';
    final scored = r.correct != null && r.choice != null;
    final color = !scored ? _grey : (r.correct! ? kQuizOk : kQuizMiss);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q != null) ...[QuizCategoryChip(q), const SizedBox(height: 4)],
          Text(q?.question ?? '(지금은 없는 문제예요)', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (scored) ...[
                Icon(r.correct! ? Icons.check_circle : Icons.info_outline, size: 16, color: color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  scored
                      ? '내 답 ${ox(r.choice!)} → 정답 ${q == null ? '-' : ox(q.answer)}'
                      : '정답 ${q == null ? '-' : ox(q.answer)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              if (q != null)
                SizedBox(
                  height: 30,
                  child: _open
                      ? FilledButton(
                          style: _explainStyle(filled: true),
                          onPressed: () => setState(() => _open = false),
                          child: const Text('해설'),
                        )
                      : OutlinedButton(
                          style: _explainStyle(filled: false),
                          onPressed: () => setState(() => _open = true),
                          child: const Text('해설'),
                        ),
                ),
            ],
          ),
          if (_open && q != null) _ExplainBubble(q),
        ],
      ),
    );
  }

  static ButtonStyle _explainStyle({required bool filled}) => ButtonStyle(
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
    minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
    visualDensity: VisualDensity.compact,
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    backgroundColor: WidgetStatePropertyAll(filled ? kQuizNavy : Colors.white),
    foregroundColor: WidgetStatePropertyAll(filled ? Colors.white : kQuizNavy),
    side: const WidgetStatePropertyAll(BorderSide(color: kQuizNavy, width: 1.2)),
  );
}

/// 해설 말풍선: 위쪽 오른편(해설 버튼 아래)에 꼬리, 연한 네이비 바탕
class _ExplainBubble extends StatelessWidget {
  final QuizQuestion q;
  const _ExplainBubble(this.q);

  static const _bg = Color(0xFFEEF2F8);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 22),
          child: CustomPaint(size: const Size(14, 8), painter: _TailPainter(_bg)),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (q.explain.isNotEmpty) Text(q.explain, style: const TextStyle(fontSize: 13, height: 1.45)),
            const SizedBox(height: 6),
            Text('분야: ${q.catLabel}', style: const TextStyle(fontSize: 12, color: _grey)),
            if (q.basis.isNotEmpty) Text('근거: ${q.basis}', style: const TextStyle(fontSize: 12, color: _grey)),
          ],
        ),
      ),
    ],
  );
}

class _TailPainter extends CustomPainter {
  final Color color;
  _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close(),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

/// [전체] [틀린 문제만] 칩
class _FilterChips extends StatelessWidget {
  final bool wrongOnly;
  final ValueChanged<bool> onChanged;
  const _FilterChips({required this.wrongOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Wrap(
      spacing: 8,
      children: [
        QuizSelectChip(label: '전체', selected: !wrongOnly, onTap: () => onChanged(false)),
        QuizSelectChip(label: '틀린 문제만', selected: wrongOnly, onTap: () => onChanged(true)),
      ],
    ),
  );
}

/// 챌린지 회차 문제 목록 (내 답·정답, 누르면 해설·근거). 위에 [전체] [틀린 문제만], 기본은 전체.
/// 점수 기록을 지운 회차면 칩 없이 문제만.
class RunAnswersList extends StatefulWidget {
  final List<QuizRecord> answers;
  final QuizBank bank;
  const RunAnswersList({super.key, required this.answers, required this.bank});

  @override
  State<RunAnswersList> createState() => _RunAnswersListState();
}

class _RunAnswersListState extends State<RunAnswersList> {
  bool _wrongOnly = false;

  @override
  Widget build(BuildContext context) {
    final scored = widget.answers.any((a) => a.correct != null);
    final list = _wrongOnly ? widget.answers.where((a) => a.correct == false).toList() : widget.answers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scored) _FilterChips(wrongOnly: _wrongOnly, onChanged: (v) => setState(() => _wrongOnly = v)),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '틀린 문제가 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          ),
        for (final a in list) QuizRecordTile(record: a, question: widget.bank.byId(a.id)),
      ],
    );
  }
}

/// 챌린지 회차 트로피 카드 (시각·문항 수·정답률·시간). 누르면 카드 안에 그 회차 문제들 (왼쪽 골드 세로줄 + 연한 배경). 점수를 지운 회차는 '챌린지 · N문제'.
class _RunTile extends StatefulWidget {
  final ChallengeRun? run;
  final List<QuizRecord> answers;
  final QuizBank bank;
  const _RunTile({required this.run, required this.answers, required this.bank});

  @override
  State<_RunTile> createState() => _RunTileState();
}

class _RunTileState extends State<_RunTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final n = run?.n ?? widget.answers.length;
    final scored = run != null ? run.scored : widget.answers.every((a) => a.correct != null);
    final ok = run?.correct ?? widget.answers.where((a) => a.correct == true).length;
    final at = run == null ? null : DateTime.fromMillisecondsSinceEpoch(run.at);
    final time = at == null ? '' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined, color: kQuizGold),
            title: Text(scored ? '챌린지 $n문제 · 정답률 ${n == 0 ? 0 : (ok * 100 / n).round()}%' : '챌린지 · $n문제'),
            subtitle: Text(
              [
                if (time.isNotEmpty) time,
                if (scored) '$ok/$n 정답',
                if (scored && run?.ms != null) quizDuration(run!.ms!),
              ].join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E6),
                border: Border(left: BorderSide(color: kQuizGold, width: 3)),
              ),
              child: RunAnswersList(answers: widget.answers, bank: widget.bank),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// 한 문제 더 풀기
// ------------------------------------------------------------------

/// 오늘의 팝업과 같은 디자인으로 1문제씩. 오늘 이미 푼 문제는 오늘은 다시 안 나온다. '추가 문제'로 기록.
class QuizPracticeScreen extends StatefulWidget {
  final QuizStore store;
  final Future<QuizBank> Function() bank;
  const QuizPracticeScreen({super.key, required this.store, required this.bank});

  @override
  State<QuizPracticeScreen> createState() => _QuizPracticeScreenState();
}

class _QuizPracticeScreenState extends State<QuizPracticeScreen> {
  QuizQuestion? _q;
  QuizBank? _bank;
  Set<String> _cats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.bank().then((b) {
      if (!mounted) return;
      _bank = b;
      // 저장값이 없으면 전체, 지금 풀에 없는 분야는 뺀다
      _cats = (widget.store.cats(practice: true) ?? b.allCatKeys).intersection(b.allCatKeys);
      _next();
    });
  }

  Future<void> _next() async {
    final s = widget.store;
    final cats = _cats;
    final q = cats.isEmpty
        ? null
        : await s.next(_bank!, exclude: s.solvedOn(_today()), where: (q) => cats.contains(q.catKey));
    if (!mounted) return;
    setState(() {
      _q = q;
      _loading = false;
    });
  }

  Future<void> _setCats(Set<String> v) async {
    setState(() => _cats = v);
    await widget.store.setCats(v, practice: true);
    // 지금 문제가 고른 분야 밖이면 다음 문제로
    if (_q == null || !v.contains(_q!.catKey)) await _next();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final bank = _bank;
    // 분야 선택은 접어 두는 칸으로 (문제를 가리지 않게)
    final picker = bank == null
        ? const SizedBox.shrink()
        : ExpansionTile(
            title: Text(
              _cats.length == bank.allCatKeys.length ? '분야: 전체' : '분야: ${_cats.length}개 선택',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [QuizCategoryPicker(bank: bank, selected: _cats, onChanged: _setCats)],
          );
    return Scaffold(
      appBar: AppBar(title: const Text('한 문제 더 풀기')),
      body: _loading
          ? const SizedBox.shrink()
          : q == null
          ? ListView(
              children: [
                picker,
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _cats.isEmpty ? '분야를 하나 이상 골라 주세요' : '오늘 준비된 문제를 모두 풀었어요!\n내일 다시 만나요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: _grey, height: 1.5),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(top: 0),
              children: [
                picker,
                QuizSheet(
                  key: ValueKey(q.id),
                  question: q,
                  sheet: false,
                  label: '안전 OX Quiz',
                  onAnswer: (c) => widget.store.record(
                    QuizRecord(
                      _today(),
                      q.id,
                      c,
                      c == q.answer,
                      src: kQuizExtra,
                      at: DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
                  actions: (ctx) => [
                    quizGoldButton('다음 문제', _next),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('그만하기'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ------------------------------------------------------------------
// 안전 OX 챌린지
// ------------------------------------------------------------------

/// 시작 화면: 분야 선택(다중, 저장) + 문항 수 [10] [20] [30] [50] (선택 분야 문항 수보다 크면 비활성, 기본 20·마지막 선택 기억),
/// 문항 수별 최고 기록, 결과 카드 이름, [시작] (분야 0개면 비활성)
class ChallengeStartScreen extends StatefulWidget {
  final QuizStore store;
  final Future<QuizBank> Function() bank;
  const ChallengeStartScreen({super.key, required this.store, required this.bank});

  @override
  State<ChallengeStartScreen> createState() => _ChallengeStartScreenState();
}

class _ChallengeStartScreenState extends State<ChallengeStartScreen> {
  QuizBank? _bank;
  Set<String> _cats = {};
  late int _want = widget.store.challengeSize; // 고른 문항 수 (분야를 바꿔도 기억)

  @override
  void initState() {
    super.initState();
    widget.bank().then((b) {
      if (!mounted) return;
      setState(() {
        _bank = b;
        _cats = (widget.store.cats(practice: false) ?? b.allCatKeys).intersection(b.allCatKeys);
      });
    });
  }

  int get _count => _bank?.only(_cats).active.length ?? 0;

  /// 지금 실제로 쓸 문항 수 (고른 값이 불가능하면 가능한 최대값, 하나도 안 되면 null)
  int? get _n => _cats.isEmpty ? null : fitChallengeSize(_want, _count);

  Future<void> _setCats(Set<String> v) async {
    setState(() => _cats = v);
    await widget.store.setCats(v, practice: false);
  }

  Future<void> _start() async {
    final n = _n!;
    await widget.store.setChallengeSize(n);
    final all = _cats.length == _bank!.allCatKeys.length;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChallengeRunScreen(store: widget.store, bank: _bank!.only(_cats), n: n, cats: all ? null : _cats.length),
      ),
    );
    if (mounted) setState(() {}); // 최고 기록 다시
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final count = _count;
    final n = _n;
    return Scaffold(
      appBar: AppBar(title: const Text('안전 OX 챌린지')),
      body: bank == null
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, listBottomPad(context)),
              children: [
                QuizCategoryPicker(bank: bank, selected: _cats, onChanged: _setCats),
                const SizedBox(height: 12),
                const Text('몇 문제에 도전할까요?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('선택된 문제 $count개 · 해설은 끝나고 볼 수 있어요', style: const TextStyle(fontSize: 12, color: _grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final s in kChallengeSizes) ...[
                      if (s != kChallengeSizes.first) const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: n == s ? kQuizNavy : Colors.white,
                              foregroundColor: n == s ? Colors.white : kQuizNavy,
                              side: BorderSide(
                                color: challengeSizeEnabled(s, count) ? kQuizNavy : const Color(0xFFDADCE0),
                              ),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: challengeSizeEnabled(s, count) && _cats.isNotEmpty
                                ? () => setState(() => _want = s)
                                : null,
                            child: Text('$s'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                const Text('내 최고 기록', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                for (final s in kChallengeSizes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text('$s문제', style: const TextStyle(color: _grey)),
                        ),
                        Expanded(
                          child: Text(switch (widget.store.best(s)) {
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
                        (widget.store.name ?? '').isEmpty ? '(없음 · 날짜만)' : widget.store.name!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await askCardName(context, widget.store);
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

/// 진행: 'N / 20', 경과 시간(초, 멈춤 없음), 진행 막대, 큰 [O] [X]. 답하면 0.6초 맞음/틀림 후 자동 다음.
/// ✕(또는 뒤로가기)는 "챌린지를 그만둘까요? 기록은 남지 않아요" 확인.
class ChallengeRunScreen extends StatefulWidget {
  final QuizStore store;

  /// 고른 분야의 문제 풀 (여기서 무작위·중복 없이)
  final QuizBank bank;
  final int n;

  /// 고른 분야 수 (null = 전체)
  final int? cats;
  const ChallengeRunScreen({super.key, required this.store, required this.bank, required this.n, this.cats});

  @override
  State<ChallengeRunScreen> createState() => _ChallengeRunScreenState();
}

class _ChallengeRunScreenState extends State<ChallengeRunScreen> {
  late final List<QuizQuestion> _qs = QuizStore.challengeSet(widget.bank, widget.n);
  final _choices = <bool>[];
  final _watch = Stopwatch()..start();
  late final int _startedAt = DateTime.now().millisecondsSinceEpoch;
  Timer? _tick, _advance;
  bool? _picked; // 지금 문제에서 고른 답 (0.6초 표시 중)

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

  void _pick(bool v) {
    if (_picked != null) return;
    setState(() => _picked = v);
    _advance = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _choices.add(v);
      if (_choices.length >= _qs.length) {
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
        QuizRecord(
          day,
          _qs[i].id,
          _choices[i],
          _choices[i] == _qs[i].answer,
          src: kQuizChallenge,
          run: id,
          at: _startedAt,
        ),
    ];
    final run = ChallengeRun(
      id: id,
      at: _startedAt,
      n: _qs.length,
      correct: answers.where((a) => a.correct == true).length,
      ms: _watch.elapsedMilliseconds,
      cats: widget.cats,
    );
    final prevBest = widget.store.best(run.n);
    await widget.store.saveRun(run, answers);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChallengeResultScreen(
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

  @override
  Widget build(BuildContext context) {
    final i = _choices.length;
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
            QuizCategoryChip(q),
            const SizedBox(height: 8),
            Text(q.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 24),
            Row(
              children: [
                for (final v in [true, false]) ...[
                  if (!v) const SizedBox(width: 12),
                  Expanded(
                    child: quizOxButton(
                      v,
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
                      picked == q.answer ? '맞아요' : '아쉬워요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: picked == q.answer ? kQuizOk : kQuizMiss,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 결과 카드에 넣을 이름 묻기 (선택). 비우면 날짜만. 처음 공유할 때와 챌린지 시작 화면 [바꾸기]에서.
Future<void> askCardName(BuildContext context, QuizStore store) async {
  final ctrl = TextEditingController(text: store.name ?? '');
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('결과 카드에 넣을 이름'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 12,
        decoration: const InputDecoration(hintText: '예) 홍길동 (비우면 날짜만)', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('비워 두기')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('저장')),
      ],
    ),
  );
  // 창 밖을 눌러 닫아도 다시 묻지 않게 지금 값(처음이면 빈칸)으로 저장
  await store.setName(v ?? store.name ?? '');
}

/// 챌린지 결과 분야별 정답 수 (나온 순서대로, 분야명 '그룹 · 분야')
List<({String label, int correct, int n})> challengeByCategory(List<QuizQuestion> qs, List<QuizRecord> answers) {
  final m = <String, ({String label, int correct, int n})>{};
  for (var i = 0; i < qs.length && i < answers.length; i++) {
    final q = qs[i];
    final cur = m[q.catKey] ?? (label: q.catLabel, correct: 0, n: 0);
    m[q.catKey] = (label: cur.label, correct: cur.correct + (answers[i].correct == true ? 1 : 0), n: cur.n + 1);
  }
  return m.values.toList();
}

/// 결과 이미지와 함께 보내는 짧은 문구
String challengeShareText(ChallengeRun r) => '안전 OX 챌린지 ${r.percent}%! 공감카드 관리에서 도전해보세요';

/// 결과: 위쪽 결과 카드(그대로 공유 이미지) + [문제 전체 보기] [다시 도전] [결과 이미지 공유]
class ChallengeResultScreen extends StatefulWidget {
  final QuizStore store;
  final QuizBank bank;
  final ChallengeRun run;
  final List<QuizQuestion> questions;
  final List<QuizRecord> answers;
  final bool newBest;
  const ChallengeResultScreen({
    super.key,
    required this.store,
    required this.bank,
    required this.run,
    required this.questions,
    required this.answers,
    required this.newBest,
  });

  @override
  State<ChallengeResultScreen> createState() => _ChallengeResultScreenState();
}

class _ChallengeResultScreenState extends State<ChallengeResultScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  /// 결과 카드를 PNG(pixelRatio 3)로 → 임시 파일 → 공유 시트. 저장소 권한 없이, 공유 뒤 임시 파일 삭제.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    File? file;
    try {
      if (widget.store.name == null) {
        await askCardName(context, widget.store);
        if (!mounted) return;
        setState(() {}); // 이름이 들어간 카드로 다시 그린 뒤 찍는다
        await WidgetsBinding.instance.endOfFrame;
      }
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = await Native.cacheDir() ?? Directory.systemTemp.path;
      file = File('$dir/safety_ox_${widget.run.id}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      // share_plus 가 자기 캐시로 복사해서 넘기므로 여기 파일은 바로 지워도 된다
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: challengeShareText(widget.run),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('공유하지 못했어요: $e')));
      }
    } finally {
      try {
        if (file != null && file.existsSync()) file.deleteSync();
      } catch (_) {}
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
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
                  name: w.store.name,
                  date: DateTime.fromMillisecondsSinceEpoch(w.run.at),
                  newBest: w.newBest,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 분야별 정답률 (공유 카드에는 넣지 않음)
          const Text('분야별 정답률', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final c in challengeByCategory(w.questions, w.answers))
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
                    children: [RunAnswersList(answers: w.answers, bank: w.bank)],
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
                builder: (_) => ChallengeRunScreen(store: w.store, bank: w.bank, n: w.run.n, cats: w.run.cats),
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
