import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오늘의 안전 OX. 문제 풀은 앱에 넣은 quiz/questions.json(기본값) + GitHub 원격본(버전이 높으면 기기에 캐시).
/// 앱을 불편하게 만들지 않는 게 원칙: 첫 프레임 뒤에만 읽고, 원격은 백그라운드·하루 1회·3초·실패는 조용히.
/// 파일 형식: version 2 = {version, updated, note, groups:[{name, categories}], questions:[{id, group, category, …}]}.
/// version 1(그룹 없음)도 읽는다 (group·category 가 없으면 '기타'). 모르는 필드는 무시한다.
const kQuizAsset = 'quiz/questions.json';
const kQuizRemote = 'https://raw.githubusercontent.com/Wani-Jung/card-expense/main/quiz/questions.json';

/// 그룹·분야가 없는 문항
const kQuizOther = '기타';

class QuizQuestion {
  final String id;

  /// 그룹(예: '서류·절차')과 분야(예: '발주자 의무'). 없으면 '기타'
  final String group;
  final String category;
  final String question;

  /// true = O, false = X
  final bool answer;
  final String explain;
  final String basis;
  final bool active;
  const QuizQuestion({
    required this.id,
    this.group = kQuizOther,
    required this.category,
    required this.question,
    required this.answer,
    required this.explain,
    required this.basis,
    this.active = true,
  });

  /// 분야 선택 키 '그룹|분야'
  String get catKey => '$group|$category';

  /// 문제 카드 칩 '그룹 · 분야'
  String get catLabel => group == kQuizOther && category == kQuizOther ? kQuizOther : '$group · $category';

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: j['id'] as String,
    group: _nonEmpty(j['group']) ?? kQuizOther,
    category: _nonEmpty(j['category']) ?? kQuizOther,
    question: j['question'] as String,
    answer: j['answer'] as bool,
    explain: j['explain'] as String? ?? '',
    basis: j['basis'] as String? ?? '',
    active: j['active'] as bool? ?? true,
  );
}

String? _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// 그룹 하나 (표시 순서대로 분야 목록)
typedef QuizGroup = ({String name, List<String> categories});

class QuizBank {
  final int version;
  final String updated;
  final List<QuizQuestion> questions;
  final List<QuizGroup> _groups;
  const QuizBank(this.version, this.updated, this.questions, [this._groups = const []]);

  /// 출제 대상 (active=false 제외)
  List<QuizQuestion> get active => questions.where((q) => q.active).toList();

  QuizQuestion? byId(String id) => questions.where((q) => q.id == id).firstOrNull;

  /// 그룹·분야 (파일의 groups 순서, 거기 없는 그룹·분야는 문항에 나온 순서로 뒤에 붙임). 활성 문항이 있는 분야만.
  List<QuizGroup> get groups {
    final act = active;
    final out = <String, List<String>>{};
    for (final g in _groups) {
      for (final c in g.categories) {
        if (act.any((q) => q.group == g.name && q.category == c)) out.putIfAbsent(g.name, () => []).add(c);
      }
    }
    for (final q in act) {
      final cs = out.putIfAbsent(q.group, () => []);
      if (!cs.contains(q.category)) cs.add(q.category);
    }
    return [for (final e in out.entries) (name: e.key, categories: e.value)];
  }

  /// 모든 분야 키 ('그룹|분야')
  Set<String> get allCatKeys => {
    for (final g in groups)
      for (final c in g.categories) '${g.name}|$c',
  };

  /// 분야별 활성 문항 수
  Map<String, int> get catCounts {
    final m = <String, int>{};
    for (final q in active) {
      m[q.catKey] = (m[q.catKey] ?? 0) + 1;
    }
    return m;
  }

  /// 형식이 틀리거나 활성 문항이 0개면 null (원격본이 깨져 있어도 앱은 내장본으로 계속).
  /// 문항 하나가 깨져 있으면 그 문항만 건너뛴다. 모르는 필드는 무시.
  static QuizBank? parse(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final qs = <QuizQuestion>[];
      final seen = <String>{};
      for (final q in j['questions'] as List) {
        try {
          final x = QuizQuestion.fromJson(q as Map<String, dynamic>);
          if (seen.add(x.id)) qs.add(x);
        } catch (_) {}
      }
      final groups = <QuizGroup>[];
      for (final g in (j['groups'] as List?) ?? const []) {
        try {
          final m = g as Map<String, dynamic>;
          groups.add((
            name: (m['name'] as String).trim(),
            categories: [for (final c in m['categories'] as List) (c as String).trim()],
          ));
        } catch (_) {}
      }
      final bank = QuizBank((j['version'] as num).toInt(), j['updated'] as String? ?? '', qs, groups);
      return bank.active.isEmpty ? null : bank;
    } catch (_) {
      return null;
    }
  }

  /// [keys] ('그룹|분야') 에 든 문항만 (null 이면 전체)
  QuizBank only(Set<String>? keys) => keys == null
      ? this
      : QuizBank(version, updated, [
          for (final q in questions)
            if (keys.contains(q.catKey)) q,
        ], _groups);
}

/// 날짜 키 (기기 시간 기준 하루). 2026-10-29
String quizDay(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// 하루 1회 자동 출제 판정. 끄는 설정은 없다 (v1.17 에서 스위치 삭제, 꺼 뒀던 기기도 항상 동작).
enum QuizDecision {
  show,

  /// 활성 문항 0개 — 그날을 쓴 것으로 치지 않는다
  noQuestions,

  /// 오늘 이미 띄웠거나 건너뜀 (닫았든 풀었든)
  alreadyToday,

  /// 첫 실행 설정 직후 / 다른 팝업이 먼저 뜸 — 그날은 건너뛴다
  skipToday,
}

QuizDecision decideQuiz({
  required String today,
  required String? lastDay,
  required int activeCount,
  required bool blocked,
}) {
  if (lastDay == today) return QuizDecision.alreadyToday;
  if (activeCount == 0) return QuizDecision.noQuestions;
  if (blocked) return QuizDecision.skipToday;
  return QuizDecision.show;
}

/// 어디서 푼 문제인지
const kQuizDaily = 'daily'; // 오늘의 문제 (하루 1회 팝업)
const kQuizExtra = 'extra'; // 한 문제 더 풀기
const kQuizChallenge = 'challenge'; // 안전 OX 챌린지

String quizSourceLabel(String src) => switch (src) {
  kQuizExtra => '추가 문제',
  kQuizChallenge => '챌린지',
  _ => '오늘의 문제',
};

/// 푼 기록 한 건 (기기에만 저장). [src] 가 없는 v1.16 기록은 오늘의 문제로 본다. [run] 은 챌린지 회차 id.
/// '점수 기록 지우기' 뒤에는 [choice]·[correct] 가 null (푼 문제·날짜·출처만 남음).
class QuizRecord {
  final String day, id;
  final bool? choice, correct;
  final String src;
  final String? run;

  /// 푼 시각 (ms). v1.16 기록은 없음
  final int? at;
  const QuizRecord(this.day, this.id, this.choice, this.correct, {this.src = kQuizDaily, this.run, this.at});
  Map<String, dynamic> toJson() => {
    'd': day,
    'id': id,
    'c': ?choice,
    'ok': ?correct,
    if (src != kQuizDaily) 's': src,
    'r': ?run,
    't': ?at,
  };
  factory QuizRecord.fromJson(Map<String, dynamic> j) => QuizRecord(
    j['d'] as String,
    j['id'] as String,
    j['c'] as bool?,
    j['ok'] as bool?,
    src: j['s'] as String? ?? kQuizDaily,
    run: j['r'] as String?,
    at: (j['t'] as num?)?.toInt(),
  );
}

/// 챌린지 한 회차 결과. '점수 기록 지우기' 뒤에는 [correct]·[ms] 가 null (회차·문항 수만 남음).
class ChallengeRun {
  final String id;
  final int at; // 시작 시각 ms
  final int n;
  final int? correct;
  final int? ms; // 걸린 시간

  /// 고른 분야 수. null 이면 전체 (카드에 '분야: 전체' / '분야: N개 선택')
  final int? cats;
  const ChallengeRun({
    required this.id,
    required this.at,
    required this.n,
    required this.correct,
    required this.ms,
    this.cats,
  });

  bool get scored => correct != null && ms != null;
  int get percent => n == 0 || correct == null ? 0 : (correct! * 100 / n).round();

  Map<String, dynamic> toJson() => {'id': id, 'at': at, 'n': n, 'ok': ?correct, 'ms': ?ms, 'cats': ?cats};
  factory ChallengeRun.fromJson(Map<String, dynamic> j) => ChallengeRun(
    id: j['id'] as String,
    at: (j['at'] as num).toInt(),
    n: (j['n'] as num).toInt(),
    correct: (j['ok'] as num?)?.toInt(),
    ms: (j['ms'] as num?)?.toInt(),
    cats: (j['cats'] as num?)?.toInt(),
  );
}

/// 결과 카드 등급. 100% 🏆 안전 마스터 / 90% 이상 🥇 안전 달인 / 80% 이상 🦺 안전 베테랑 /
/// 60% 이상 👷 안전 실무자 / 60% 미만 📘 안전 새내기 (반올림 없이 정답 수/문항 수로 판정)
({String emoji, String label}) quizGrade(int correct, int n) {
  if (n > 0 && correct >= n) return (emoji: '🏆', label: '안전 마스터');
  if (correct * 10 >= n * 9) return (emoji: '🥇', label: '안전 달인');
  if (correct * 10 >= n * 8) return (emoji: '🦺', label: '안전 베테랑');
  if (correct * 10 >= n * 6) return (emoji: '👷', label: '안전 실무자');
  return (emoji: '📘', label: '안전 새내기');
}

/// 챌린지 문항 수 선택지
const kChallengeSizes = [10, 20, 30, 50];

/// 챌린지 문항 수 기본값 (마지막 선택이 없으면)
const kChallengeDefaultSize = 20;

/// 고른 문항 수 [n] 을 [count](선택 분야 문항 수) 에 맞춘다: 가능하면 그대로, 아니면 가능한 최대값, 하나도 안 되면 null
int? fitChallengeSize(int n, int count) {
  if (challengeSizeEnabled(n, count)) return n;
  final ok = kChallengeSizes.where((s) => challengeSizeEnabled(s, count)).toList();
  return ok.isEmpty ? null : ok.last;
}

/// 활성 문항 수보다 큰 문항 수는 고를 수 없다
bool challengeSizeEnabled(int n, int activeCount) => n <= activeCount;

/// 최고 기록 비교: 정답률 높은 순 → 같으면 시간 짧은 순 (문항 수가 같은 회차끼리)
bool isBetterRun(ChallengeRun a, ChallengeRun? b) {
  if (!a.scored) return false;
  if (b == null || !b.scored) return true;
  final ra = a.correct! * b.n, rb = b.correct! * a.n; // 정답률 비교 (나눗셈 없이)
  if (ra != rb) return ra > rb;
  return a.ms! < b.ms!;
}

/// "2분 14초"
String quizDuration(int ms) {
  final s = (ms / 1000).floor();
  return '${s ~/ 60}분 ${s % 60}초';
}

/// 연속 일수: 오늘의 문제를 푼 날이 이어진 일수. 오늘 아직 안 풀었으면 어제까지 이어진 것도 센다.
int quizStreak(Iterable<String> days, String today) {
  final set = days.toSet();
  DateTime parse(String d) {
    final p = d.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  var cur = parse(today);
  if (!set.contains(today)) cur = DateTime(cur.year, cur.month, cur.day - 1);
  var n = 0;
  while (set.contains(quizDay(cur))) {
    n++;
    cur = DateTime(cur.year, cur.month, cur.day - 1);
  }
  return n;
}

/// 퀴즈 기기 저장 (shared_preferences)
class QuizStore {
  final SharedPreferences _p;
  QuizStore(this._p);

  static const _kLastDay = 'quiz_last_day_v1';
  static const _kBag = 'quiz_bag_v1';
  static const _kKnown = 'quiz_known_v1';
  static const _kLog = 'quiz_log_v1';
  static const _kRuns = 'quiz_runs_v1';
  static const _kName = 'quiz_name_v1';
  static const _kCache = 'quiz_cache_v1';
  static const _kFetchedAt = 'quiz_fetched_at_v1';

  /// 자동 출제를 판정(띄움·건너뜀)한 마지막 날
  String? get lastDay => _p.getString(_kLastDay);
  Future<void> setLastDay(String day) => _p.setString(_kLastDay, day);

  // ---------------- 셔플백 ----------------

  /// 다음 문제. 기기마다 섞어 둔 순서에서 하나씩 꺼낸다. 한 바퀴 다 돌기 전엔 같은 문제가 안 나온다.
  /// 새로 생긴 활성 문항은 남은 순서 안 아무 데나 섞어 넣고, 빠진(비활성·삭제) 문항은 순서에서 뺀다.
  /// [exclude] (오늘 이미 푼 문제)는 건너뛴다. 남은 순서가 전부 제외 대상이면 새 바퀴를 섞고,
  /// 활성 문항이 전부 제외 대상이면 null (오늘 준비된 문제 소진).
  /// [where] (분야 선택 등)을 주면 그 조건에 맞는 문제만 낸다. 셔플백 순서 자체는 전체 문항 기준으로 유지한다.
  Future<QuizQuestion?> next(
    QuizBank bank, {
    Set<String> exclude = const {},
    bool Function(QuizQuestion q)? where,
    Random? random,
  }) async {
    final rnd = random ?? Random();
    final active = {for (final q in bank.active) q.id: q};
    bool ok(String id) => !exclude.contains(id) && (where == null || where(active[id]!));
    if (!active.keys.any(ok)) return null;
    var bag = (_p.getStringList(_kBag) ?? const []).where(active.containsKey).toList();
    final known = (_p.getStringList(_kKnown) ?? const []).toSet();
    final fresh = active.keys.where((id) => !known.contains(id)).toList()..shuffle(rnd);
    for (final id in fresh) {
      bag.insert(rnd.nextInt(bag.length + 1), id);
    }
    known.addAll(fresh);
    if (!bag.any(ok)) {
      // 한 바퀴 끝(또는 남은 게 다 오늘 푼 문제): 전체를 다시 섞는다
      bag = active.keys.toList()..shuffle(rnd);
      known
        ..clear()
        ..addAll(active.keys);
    }
    final id = bag.firstWhere(ok);
    bag.remove(id);
    await _p.setStringList(_kBag, bag);
    await _p.setStringList(_kKnown, known.toList());
    return active[id];
  }

  /// 챌린지 문제: 활성 문항에서 [n] 개를 랜덤으로 (오늘 푼 문제 포함 가능, 셔플백과 별개)
  static List<QuizQuestion> challengeSet(QuizBank bank, int n, {Random? random}) =>
      (bank.active..shuffle(random ?? Random())).take(n).toList();

  // ---------------- 기록·통계 ----------------

  List<QuizRecord> get records => [
    for (final s in _p.getStringList(_kLog) ?? const <String>[])
      QuizRecord.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  Future<void> record(QuizRecord r) => recordAll([r]);
  Future<void> recordAll(Iterable<QuizRecord> rs) =>
      _p.setStringList(_kLog, [...?_p.getStringList(_kLog), for (final r in rs) jsonEncode(r.toJson())]);

  /// 오늘 푼 문제 id (오늘의 문제·추가 문제·챌린지 모두)
  Set<String> solvedOn(String day) => {
    for (final r in records)
      if (r.day == day) r.id,
  };

  List<ChallengeRun> get runs => [
    for (final s in _p.getStringList(_kRuns) ?? const <String>[])
      ChallengeRun.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  /// 챌린지 한 회차 저장 (회차 결과 + 문제별 기록)
  Future<void> saveRun(ChallengeRun run, List<QuizRecord> answers) async {
    await _p.setStringList(_kRuns, [...?_p.getStringList(_kRuns), jsonEncode(run.toJson())]);
    await recordAll(answers);
  }

  /// 문항 수별 최고 기록 ([except] 회차는 빼고)
  ChallengeRun? best(int n, {String? except}) {
    ChallengeRun? b;
    for (final r in runs.where((r) => r.n == n && r.id != except)) {
      if (isBetterRun(r, b)) b = r;
    }
    return b;
  }

  int get solvedCount => records.length;

  /// 정답률: 점수가 남아 있는 기록만 (지운 뒤 새로 푼 문제부터 다시 집계). 없으면 null
  int? get percent {
    final rs = records.where((r) => r.correct != null).toList();
    return rs.isEmpty ? null : (rs.where((r) => r.correct!).length * 100 / rs.length).round();
  }

  /// 점수가 남은 기록이 하나라도 있는지 ([틀린 문제만] 칩을 보일지)
  bool get hasScores => records.any((r) => r.correct != null);

  /// 점수 기록 지우기 (되돌리기 없음). 내 답·정답 여부·챌린지 점수·시간(→ 정답률·최고 기록)을 지운다.
  /// 푼 문제 id·날짜·출처·챌린지 회차, 연속 일수, 오늘 푼 문제 제외, 결과 카드 이름은 남는다.
  Future<void> clearScores() async {
    await _p.setStringList(_kLog, [
      for (final r in records)
        jsonEncode(QuizRecord(r.day, r.id, null, null, src: r.src, run: r.run, at: r.at).toJson()),
    ]);
    await _p.setStringList(_kRuns, [
      for (final r in runs)
        jsonEncode(ChallengeRun(id: r.id, at: r.at, n: r.n, correct: null, ms: null, cats: r.cats).toJson()),
    ]);
  }

  /// 분야 선택 ('그룹|분야' 목록). [practice] 면 '한 문제 더 풀기', 아니면 챌린지 (따로 저장). 저장값이 없으면 null = 전체 선택
  Set<String>? cats({required bool practice}) =>
      _p.getStringList(practice ? 'quiz_cats_practice_v1' : 'quiz_cats_challenge_v1')?.toSet();
  Future<void> setCats(Set<String> keys, {required bool practice}) =>
      _p.setStringList(practice ? 'quiz_cats_practice_v1' : 'quiz_cats_challenge_v1', keys.toList());

  /// 챌린지 문항 수 마지막 선택 (없으면 20)
  int get challengeSize => _p.getInt('quiz_challenge_size_v1') ?? kChallengeDefaultSize;
  Future<void> setChallengeSize(int n) => _p.setInt('quiz_challenge_size_v1', n);

  /// 결과 카드에 넣는 이름 (선택). 한 번도 안 물었으면 null, 비워 두기로 했으면 ''
  String? get name => _p.getString(_kName);
  Future<void> setName(String v) => _p.setString(_kName, v.trim());

  int streak(String today) => quizStreak(records.where((r) => r.src == kQuizDaily).map((r) => r.day), today);

  /// 메뉴 설명 "연속 N일 · 정답률 NN%". 연속이 없으면 "오늘의 문제를 풀어보세요"
  String menuText(String today) {
    final s = streak(today);
    if (s == 0) return '오늘의 문제를 풀어보세요';
    final p = percent;
    return p == null ? '연속 $s일' : '연속 $s일 · 정답률 $p%';
  }

  // ---------------- 문제 풀 ----------------

  String? get cached => _p.getString(_kCache);

  /// 앱에 넣은 기본본과 기기 캐시(원격에서 받은 것) 중 버전이 높은 쪽. 캐시가 깨졌거나 활성 문항이 없으면 기본본.
  static QuizBank pick(QuizBank builtIn, QuizBank? cache) =>
      cache != null && cache.active.isNotEmpty && cache.version > builtIn.version ? cache : builtIn;

  /// 지금 쓸 문제 풀. 화면 쪽에서 한 번 읽고 들고 있으므로 asset 캐시는 쓰지 않는다.
  Future<QuizBank> load({Future<String> Function()? readAsset}) async {
    final text = await (readAsset ?? () => rootBundle.loadString(kQuizAsset, cache: false))();
    final builtIn = QuizBank.parse(text) ?? const QuizBank(0, '', []);
    final c = cached;
    return pick(builtIn, c == null ? null : QuizBank.parse(c));
  }

  /// 원격본 확인 (하루 1회 이하). 지금 것보다 버전이 높으면 캐시해서 다음부터 쓴다. 실패는 조용히 무시.
  /// 캐시했으면 true.
  Future<bool> refresh(int currentVersion, {required DateTime now, Future<String?> Function()? fetch}) async {
    final last = _p.getInt(_kFetchedAt);
    if (last != null && now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < const Duration(hours: 24)) {
      return false;
    }
    await _p.setInt(_kFetchedAt, now.millisecondsSinceEpoch);
    final text = await (fetch ?? fetchRemoteQuiz)();
    if (text == null) return false;
    final bank = QuizBank.parse(text);
    if (bank == null || bank.version <= currentVersion) return false;
    await _p.setString(_kCache, text);
    return true;
  }
}

/// GitHub 원격 문제 파일. 3초 안에 못 받으면 null.
Future<String?> fetchRemoteQuiz() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    return await () async {
      final req = await client.getUrl(Uri.parse(kQuizRemote));
      final res = await req.close();
      if (res.statusCode != 200) return null;
      return await res.transform(utf8.decoder).join();
    }().timeout(const Duration(seconds: 3));
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
