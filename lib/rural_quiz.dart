import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quiz.dart';

/// 실험실 > 법령 Quiz (REQ-47 농어촌정비법, REQ-51 건설기술 진흥법·국가계약법·건축법). OX + 객관식(4지선다) 섞어서 출제.
/// 문제 파일 quiz/rural_questions.json (네 법령이 한 파일, 앱에 내장, tools/rural_quiz_export.py 로 만듦).
/// 기록은 안전 OX 와 따로, 법령마다 따로 (저장 키 접두어 [LawQuiz.keyPrefix]) — 서로 정답률·최고 기록이 섞이지 않는다.
const kRuralAsset = 'quiz/rural_questions.json';

/// 법령 Quiz 하나 (문제 파일의 그룹 하나 = 실험실 항목 하나)
class LawQuiz {
  /// 문제 파일 그룹 이름 (예 '농어촌정비법')
  final String group;

  /// 저장 키 접두어. 농어촌정비법은 예전 키(rural_*)를 그대로 쓴다
  final String keyPrefix;

  /// 등급 배지 앞말 (quizGrade topic)
  final String short;
  final IconData icon;
  const LawQuiz(this.group, this.keyPrefix, this.short, this.icon);

  /// 실험실·앱바·결과 카드 제목: '농어촌정비법 Quiz'
  String get title => '$group Quiz';
  String get challengeTitle => '$group 챌린지';
  String get cardSubtitle => '$group OX·객관식';
}

const kRuralLaw = LawQuiz('농어촌정비법', 'rural', '정비법', Icons.agriculture_outlined);

/// 실험실 순서 (REQ-51)
const kLawQuizzes = [
  kRuralLaw,
  LawQuiz('건설기술 진흥법', 'law_ctech', '건진법', Icons.engineering_outlined),
  LawQuiz('국가계약법', 'law_contract', '국계법', Icons.gavel_outlined),
  LawQuiz('건축법', 'law_building', '건축법', Icons.apartment_outlined),
];

class RuralQuestion {
  final String id, group, category, question, explain, basis;

  /// 개정 시점 (예 '2024.1.2 개정(해당 항)'). 없으면 ''
  final String amended;

  /// 객관식이면 보기 4개, OX 면 빈 목록
  final List<String> choices;

  /// 정답: OX 는 1(O)/0(X), 객관식은 보기 번호 1~4
  final int answer;
  final bool active;
  const RuralQuestion({
    required this.id,
    required this.group,
    required this.category,
    required this.question,
    required this.choices,
    required this.answer,
    required this.explain,
    required this.basis,
    this.amended = '',
    this.active = true,
  });

  /// 문제 아래 한 줄: '근거 · 개정 시점'. 둘 다 비면 '' (줄 숨김)
  String get basisLine => [basis, amended].where((s) => s.trim().isNotEmpty).join(' · ');

  bool get isChoice => choices.isNotEmpty;
  String get catKey => '$group|$category';
  String get catLabel => '$group · $category';

  /// 고른 답 [pick] (OX 1/0, 객관식 1~4) 이 맞는지
  bool isCorrect(int pick) => pick == answer;

  /// 화면에 보이는 답 이름: 'O' / 'X' / '3번'
  String label(int pick) => isChoice ? '$pick번' : (pick == 1 ? 'O' : 'X');

  factory RuralQuestion.fromJson(Map<String, dynamic> j) {
    final choice = j['type'] == 'choice';
    final a = j['answer'];
    return RuralQuestion(
      id: j['id'] as String,
      group: j['group'] as String? ?? '농어촌정비법',
      category: j['category'] as String? ?? kQuizOther,
      question: j['question'] as String,
      choices: choice ? [for (final c in j['choices'] as List) c as String] : const [],
      answer: choice ? (a as num).toInt() : ((a as bool) ? 1 : 0),
      explain: j['explain'] as String? ?? '',
      basis: j['basis'] as String? ?? '',
      amended: j['amended'] as String? ?? '',
      active: j['active'] as bool? ?? true,
    );
  }
}

class RuralBank {
  final int version;
  final List<RuralQuestion> questions;
  final List<QuizGroup> groups;
  const RuralBank(this.version, this.questions, this.groups);

  List<RuralQuestion> get active => questions.where((q) => q.active).toList();
  RuralQuestion? byId(String id) => questions.where((q) => q.id == id).firstOrNull;

  /// 분야 선택 화면(QuizCategoryPicker)용: 분야·문항 수만 같은 QuizBank (정답 값은 쓰지 않음)
  QuizBank get pickerBank => QuizBank(version, '', [
    for (final q in questions)
      QuizQuestion(
        id: q.id,
        group: q.group,
        category: q.category,
        question: q.question,
        answer: true,
        explain: '',
        basis: '',
        active: q.active,
      ),
  ], groups);

  /// 형식이 틀리거나 활성 문항이 0개면 null. 깨진 문항 하나는 건너뛴다.
  static RuralBank? parse(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final qs = <RuralQuestion>[];
      final seen = <String>{};
      for (final q in j['questions'] as List) {
        try {
          final x = RuralQuestion.fromJson(q as Map<String, dynamic>);
          if (x.isChoice && (x.choices.length != 4 || x.answer < 1 || x.answer > 4)) continue;
          if (seen.add(x.id)) qs.add(x);
        } catch (_) {}
      }
      final groups = [
        for (final g in (j['groups'] as List?) ?? const [])
          (
            name: ((g as Map<String, dynamic>)['name'] as String).trim(),
            categories: [for (final c in g['categories'] as List) (c as String).trim()],
          ),
      ];
      final bank = RuralBank((j['version'] as num).toInt(), qs, groups);
      return bank.active.isEmpty ? null : bank;
    } catch (_) {
      return null;
    }
  }

  static Future<RuralBank?> load() async => parse(await rootBundle.loadString(kRuralAsset));

  /// 한 법령만 (문항·분야). 활성 문항이 없으면 null
  RuralBank? only(String group) {
    final b = RuralBank(version, [
      for (final q in questions)
        if (q.group == group) q,
    ], groups.where((g) => g.name == group).toList());
    return b.active.isEmpty ? null : b;
  }
}

/// 푼 기록 한 건. [pick] = 고른 답 (OX 1/0, 객관식 1~4). [src] 'extra'(한 문제 더) / 'challenge', [run] 챌린지 회차 id.
/// '점수 기록 지우기' 뒤에는 [pick]·[correct] 가 null (푼 문제·날짜·출처·회차만 남음, REQ-50)
class RuralRecord {
  final String day, id;
  final int? pick;
  final bool? correct;
  final int? at;
  final String src;
  final String? run;
  const RuralRecord(this.day, this.id, this.pick, this.correct, {this.at, this.src = kQuizExtra, this.run});

  Map<String, dynamic> toJson() => {
    'd': day,
    'q': id,
    'p': ?pick,
    'ok': ?correct,
    't': ?at,
    if (src != kQuizExtra) 's': src,
    'r': ?run,
  };
  factory RuralRecord.fromJson(Map<String, dynamic> j) => RuralRecord(
    j['d'] as String,
    j['q'] as String,
    (j['p'] as num?)?.toInt(),
    j['ok'] as bool?,
    at: (j['t'] as num?)?.toInt(),
    src: j['s'] as String? ?? kQuizExtra,
    run: j['r'] as String?,
  );
}

/// 법령 Quiz 기록 (안전 OX 의 quiz_* 키와 따로, 법령마다 따로). 키 = '{접두어}_log_v1' 등.
/// 농어촌정비법은 접두어 'rural' 이라 예전 기록(rural_*)을 그대로 읽는다.
class RuralStore {
  final SharedPreferences _p;
  final LawQuiz quiz;
  RuralStore(this._p, [this.quiz = kRuralLaw]);

  String get kLog => '${quiz.keyPrefix}_log_v1';
  String get kBag => '${quiz.keyPrefix}_bag_v1';
  String get kCats => '${quiz.keyPrefix}_cats_v1';
  String get kRuns => '${quiz.keyPrefix}_runs_v1';
  String get kChallengeCats => '${quiz.keyPrefix}_cats_challenge_v1';
  String get kChallengeSize => '${quiz.keyPrefix}_challenge_size_v1';

  /// 결과 카드 이름은 안전 OX 와 같이 쓴다 (사람 이름이라 하나로)
  QuizStore get nameStore => QuizStore(_p);

  // ---------------- 챌린지 (REQ-48) ----------------

  List<ChallengeRun> get runs => [
    for (final s in _p.getStringList(kRuns) ?? const <String>[])
      ChallengeRun.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  /// 챌린지 한 회차 저장 (회차 결과 + 문제별 기록)
  Future<void> saveRun(ChallengeRun run, List<RuralRecord> answers) async {
    await _p.setStringList(kRuns, [...?_p.getStringList(kRuns), jsonEncode(run.toJson())]);
    await _p.setStringList(kLog, [...?_p.getStringList(kLog), for (final a in answers) jsonEncode(a.toJson())]);
  }

  /// 문항 수별 최고 기록 (정답률 → 시간)
  ChallengeRun? best(int n) {
    ChallengeRun? b;
    for (final r in runs.where((r) => r.n == n)) {
      if (isBetterRun(r, b)) b = r;
    }
    return b;
  }

  /// 챌린지 분야 선택 (한 문제 더 풀기와 따로). null = 전체
  Set<String>? get challengeCats => _p.getStringList(kChallengeCats)?.toSet();
  Future<void> setChallengeCats(Set<String> keys) => _p.setStringList(kChallengeCats, keys.toList());

  int get challengeSize => _p.getInt(kChallengeSize) ?? kChallengeDefaultSize;
  Future<void> setChallengeSize(int n) => _p.setInt(kChallengeSize, n);

  /// 챌린지 문제: 고른 분야의 활성 문항에서 [n] 개를 무작위로 (OX·객관식 섞임, 오늘 푼 문제 포함 가능)
  static List<RuralQuestion> challengeSet(RuralBank bank, int n, {Set<String>? cats, Random? random}) => ([
    for (final q in bank.active)
      if (cats == null || cats.contains(q.catKey)) q,
  ]..shuffle(random ?? Random())).take(n).toList();

  /// 고른 분야의 활성 문항 수
  static int activeCount(RuralBank bank, Set<String>? cats) =>
      bank.active.where((q) => cats == null || cats.contains(q.catKey)).length;

  List<RuralRecord> get records => [
    for (final s in _p.getStringList(kLog) ?? const <String>[])
      RuralRecord.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  Future<void> record(RuralRecord r) => _p.setStringList(kLog, [...?_p.getStringList(kLog), jsonEncode(r.toJson())]);

  int get solvedCount => records.length;

  /// 점수가 남은 기록 수 (화면 '푼 문제'. 정답률과 같은 기준이 되게, REQ-67 29: 점수 기록을 지우면 둘 다 새로)
  int get scoredCount => records.where((r) => r.correct != null).length;

  /// 정답률 (푼 게 없으면 null)
  /// 정답률: 점수가 남아 있는 기록만 (지운 뒤 새로 푼 문제부터 다시 집계). 없으면 null
  int? get percent {
    final rs = records.where((r) => r.correct != null).toList();
    return rs.isEmpty ? null : (rs.where((r) => r.correct!).length * 100 / rs.length).round();
  }

  /// 점수가 남은 기록이 하나라도 있는지
  bool get hasScores => records.any((r) => r.correct != null);

  /// 지우기 직전 기록 (점수 기록 지우기 [되돌리기]용)
  ({List<String>? log, List<String>? runs}) snapshotScores() =>
      (log: _p.getStringList(kLog), runs: _p.getStringList(kRuns));
  Future<void> restoreScores(({List<String>? log, List<String>? runs}) snap) async {
    snap.log == null ? await _p.remove(kLog) : await _p.setStringList(kLog, snap.log!);
    snap.runs == null ? await _p.remove(kRuns) : await _p.setStringList(kRuns, snap.runs!);
  }

  /// 점수 기록 지우기 (REQ-50, 안전 OX 와 같은 동작, 정비법 기록만): 내 답·정답 여부·챌린지 점수·시간(→ 정답률·최고 기록)을 지운다.
  /// 푼 문제 id·날짜·출처·챌린지 회차(푼 문제 수·지난 문제 목록)는 남는다. 안전 OX 기록(quiz_*)은 건드리지 않는다.
  Future<void> clearScores() async {
    await _p.setStringList(kLog, [
      for (final r in records)
        jsonEncode(RuralRecord(r.day, r.id, null, null, at: r.at, src: r.src, run: r.run).toJson()),
    ]);
    await _p.setStringList(kRuns, [
      for (final r in runs)
        jsonEncode(ChallengeRun(id: r.id, at: r.at, n: r.n, correct: null, ms: null, cats: r.cats).toJson()),
    ]);
  }

  Set<String> solvedOn(String day) => {
    for (final r in records)
      if (r.day == day) r.id,
  };

  /// 분야 선택 ('그룹|분야'). 저장값이 없으면 null = 전체
  Set<String>? get cats => _p.getStringList(kCats)?.toSet();
  Future<void> setCats(Set<String> keys) => _p.setStringList(kCats, keys.toList());

  /// 다음 문제: 섞어 둔 순서에서 하나씩 (한 바퀴 돌기 전엔 같은 문제 안 나옴). [exclude](오늘 푼 문제)는 건너뜀.
  /// 고른 분야에 낼 문제가 없으면 null.
  Future<RuralQuestion?> next(
    RuralBank bank, {
    Set<String> exclude = const {},
    Set<String>? cats,
    Random? random,
  }) async {
    final rnd = random ?? Random();
    final active = {for (final q in bank.active) q.id: q};
    bool ok(String id) => !exclude.contains(id) && (cats == null || cats.contains(active[id]!.catKey));
    if (!active.keys.any(ok)) return null;
    var bag = (_p.getStringList(kBag) ?? const []).where(active.containsKey).toList();
    if (!bag.any(ok)) bag = active.keys.toList()..shuffle(rnd);
    final id = bag.firstWhere(ok);
    bag.remove(id);
    await _p.setStringList(kBag, bag);
    return active[id];
  }
}

/// 실험실 법령 Quiz 부제 (REQ-67 28): 'n문제 · 분야 n개', 건축법은 '· 2027 개정 반영'. 파일을 못 읽었으면 예전 문구
String lawQuizSummary(RuralBank? bank, LawQuiz l) {
  final b = bank?.only(l.group);
  if (b == null) return 'OX·객관식 문제를 분야별로 풀어요';
  final cats = b.groups.isEmpty ? b.active.map((q) => q.category).toSet().length : b.groups.first.categories.length;
  return '${b.active.length}문제 · 분야 $cats개${l.group == '건축법' ? ' · 2027 개정 반영' : ''}';
}
