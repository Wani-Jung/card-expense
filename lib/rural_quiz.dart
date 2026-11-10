import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quiz.dart';

/// 실험실 > 농어촌정비법 퀴즈 (REQ-47). OX + 객관식(4지선다) 섞어서 출제.
/// 문제 파일 quiz/rural_questions.json (앱에 내장, tools/rural_quiz_export.py 로 만듦).
/// 기록은 안전 OX 와 따로 (rural_* 키) — 안전 OX 정답률·연속에 섞이지 않는다.
const kRuralAsset = 'quiz/rural_questions.json';

class RuralQuestion {
  final String id, group, category, question, explain, basis;

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
    this.active = true,
  });

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
  QuizBank get pickerBank => QuizBank(
    version,
    '',
    [
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
    ],
    groups,
  );

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
}

/// 푼 기록 한 건. [pick] = 고른 답 (OX 1/0, 객관식 1~4)
class RuralRecord {
  final String day, id;
  final int pick;
  final bool correct;
  final int? at;
  const RuralRecord(this.day, this.id, this.pick, this.correct, {this.at});

  Map<String, dynamic> toJson() => {'d': day, 'q': id, 'p': pick, 'ok': correct, 't': ?at};
  factory RuralRecord.fromJson(Map<String, dynamic> j) =>
      RuralRecord(j['d'] as String, j['q'] as String, (j['p'] as num).toInt(), j['ok'] as bool, at: (j['t'] as num?)?.toInt());
}

/// 농어촌정비법 퀴즈 기록 (안전 OX 의 quiz_* 키와 따로)
class RuralStore {
  static const kLog = 'rural_log_v1';
  static const kBag = 'rural_bag_v1';
  static const kCats = 'rural_cats_v1';

  final SharedPreferences _p;
  RuralStore(this._p);

  List<RuralRecord> get records => [
    for (final s in _p.getStringList(kLog) ?? const <String>[])
      RuralRecord.fromJson(jsonDecode(s) as Map<String, dynamic>),
  ];

  Future<void> record(RuralRecord r) =>
      _p.setStringList(kLog, [...?_p.getStringList(kLog), jsonEncode(r.toJson())]);

  int get solvedCount => records.length;

  /// 정답률 (푼 게 없으면 null)
  int? get percent {
    final rs = records;
    return rs.isEmpty ? null : (rs.where((r) => r.correct).length * 100 / rs.length).round();
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
  Future<RuralQuestion?> next(RuralBank bank, {Set<String> exclude = const {}, Set<String>? cats, Random? random}) async {
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
