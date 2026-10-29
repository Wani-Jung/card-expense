import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오늘의 안전 OX. 문제 풀은 앱에 넣은 quiz/questions.json(기본값) + GitHub 원격본(버전이 높으면 기기에 캐시).
/// 앱을 불편하게 만들지 않는 게 원칙: 첫 프레임 뒤에만 읽고, 원격은 백그라운드·하루 1회·3초·실패는 조용히.
const kQuizAsset = 'quiz/questions.json';
const kQuizRemote = 'https://raw.githubusercontent.com/Wani-Jung/card-expense/main/quiz/questions.json';

class QuizQuestion {
  final String id;
  final String category;
  final String question;

  /// true = O, false = X
  final bool answer;
  final String explain;
  final String basis;
  final bool active;
  const QuizQuestion({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.explain,
    required this.basis,
    this.active = true,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: j['id'] as String,
    category: j['category'] as String? ?? '',
    question: j['question'] as String,
    answer: j['answer'] as bool,
    explain: j['explain'] as String? ?? '',
    basis: j['basis'] as String? ?? '',
    active: j['active'] as bool? ?? true,
  );
}

class QuizBank {
  final int version;
  final String updated;
  final List<QuizQuestion> questions;
  const QuizBank(this.version, this.updated, this.questions);

  /// 출제 대상 (active=false 제외)
  List<QuizQuestion> get active => questions.where((q) => q.active).toList();

  QuizQuestion? byId(String id) => questions.where((q) => q.id == id).firstOrNull;

  /// 형식이 틀리면 null (원격본이 깨져 있어도 앱은 내장본으로 계속)
  static QuizBank? parse(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      final qs = [for (final q in j['questions'] as List) QuizQuestion.fromJson(q as Map<String, dynamic>)];
      return QuizBank((j['version'] as num).toInt(), j['updated'] as String? ?? '', qs);
    } catch (_) {
      return null;
    }
  }
}

/// 날짜 키 (기기 시간 기준 하루). 2026-10-29
String quizDay(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// 하루 1회 자동 출제 판정
enum QuizDecision {
  show,

  /// 꺼 둠 / 활성 문항 0개 — 그날을 쓴 것으로 치지 않는다
  disabled,
  noQuestions,

  /// 오늘 이미 띄웠거나 건너뜀
  alreadyToday,

  /// 첫 실행 설정 직후 / 다른 팝업이 먼저 뜸 — 그날은 건너뛴다
  skipToday,
}

QuizDecision decideQuiz({
  required String today,
  required String? lastDay,
  required bool enabled,
  required int activeCount,
  required bool blocked,
}) {
  if (!enabled) return QuizDecision.disabled;
  if (lastDay == today) return QuizDecision.alreadyToday;
  if (activeCount == 0) return QuizDecision.noQuestions;
  if (blocked) return QuizDecision.skipToday;
  return QuizDecision.show;
}

/// 푼 기록 한 건 (기기에만 저장, 통계용)
class QuizRecord {
  final String day, id;
  final bool choice, correct;
  const QuizRecord(this.day, this.id, this.choice, this.correct);
  Map<String, dynamic> toJson() => {'d': day, 'id': id, 'c': choice, 'ok': correct};
  factory QuizRecord.fromJson(Map<String, dynamic> j) =>
      QuizRecord(j['d'] as String, j['id'] as String, j['c'] as bool, j['ok'] as bool);
}

/// 퀴즈 기기 저장 (shared_preferences)
class QuizStore {
  final SharedPreferences _p;
  QuizStore(this._p);

  static const _kEnabled = 'quiz_enabled_v1';
  static const _kLastDay = 'quiz_last_day_v1';
  static const _kBag = 'quiz_bag_v1';
  static const _kKnown = 'quiz_known_v1';
  static const _kLog = 'quiz_log_v1';
  static const _kCache = 'quiz_cache_v1';
  static const _kFetchedAt = 'quiz_fetched_at_v1';

  /// 메뉴 스위치. 기본 켜짐
  bool get enabled => _p.getBool(_kEnabled) ?? true;
  Future<void> setEnabled(bool v) => _p.setBool(_kEnabled, v);

  /// 자동 출제를 판정(띄움·건너뜀)한 마지막 날
  String? get lastDay => _p.getString(_kLastDay);
  Future<void> setLastDay(String day) => _p.setString(_kLastDay, day);

  // ---------------- 셔플백 ----------------

  /// 다음 문제. 기기마다 섞어 둔 순서에서 하나씩 꺼낸다. 한 바퀴 다 돌기 전엔 같은 문제가 안 나온다.
  /// 새로 생긴 활성 문항은 남은 순서 안 아무 데나 섞어 넣고, 빠진(비활성·삭제) 문항은 순서에서 뺀다.
  Future<QuizQuestion?> next(QuizBank bank, {Random? random}) async {
    final rnd = random ?? Random();
    final active = {for (final q in bank.active) q.id: q};
    if (active.isEmpty) return null;
    var bag = (_p.getStringList(_kBag) ?? const []).where(active.containsKey).toList();
    final known = (_p.getStringList(_kKnown) ?? const []).toSet();
    final fresh = active.keys.where((id) => !known.contains(id)).toList()..shuffle(rnd);
    for (final id in fresh) {
      bag.insert(rnd.nextInt(bag.length + 1), id);
    }
    known.addAll(fresh);
    if (bag.isEmpty) {
      // 한 바퀴 끝: 전체를 다시 섞는다
      bag = active.keys.toList()..shuffle(rnd);
      known
        ..clear()
        ..addAll(active.keys);
    }
    final id = bag.removeAt(0);
    await _p.setStringList(_kBag, bag);
    await _p.setStringList(_kKnown, known.toList());
    return active[id];
  }

  // ---------------- 기록·통계 ----------------

  List<QuizRecord> get records => [
    for (final s in _p.getStringList(_kLog) ?? const <String>[])
      QuizRecord.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  Future<void> record(QuizRecord r) => _p.setStringList(_kLog, [...?_p.getStringList(_kLog), jsonEncode(r.toJson())]);

  /// 메뉴 설명 "지금까지 N문제 · 정답률 NN%"
  String get statsText {
    final rs = records;
    if (rs.isEmpty) return '지금까지 0문제 · 정답률 -';
    final ok = rs.where((r) => r.correct).length;
    return '지금까지 ${rs.length}문제 · 정답률 ${(ok * 100 / rs.length).round()}%';
  }

  // ---------------- 문제 풀 ----------------

  String? get cached => _p.getString(_kCache);

  /// 앱에 넣은 기본본과 기기 캐시(원격에서 받은 것) 중 버전이 높은 쪽
  static QuizBank pick(QuizBank builtIn, QuizBank? cache) =>
      cache != null && cache.version > builtIn.version ? cache : builtIn;

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
