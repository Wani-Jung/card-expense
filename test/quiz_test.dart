import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:card_expense/quiz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuizQuestion _q(String id, {bool active = true}) =>
    QuizQuestion(id: id, category: '분야', question: '문제 $id', answer: true, explain: '', basis: '', active: active);

QuizBank _bank(List<QuizQuestion> qs, {int version = 1}) => QuizBank(version, '2026-10-29', qs);

String _json(int version, List<String> ids) => jsonEncode({
  'version': version,
  'updated': '2026-10-29',
  'questions': [
    for (final id in ids)
      {'id': id, 'category': '분야', 'question': '문제', 'answer': true, 'explain': '', 'basis': '', 'active': true},
  ],
});

Future<QuizStore> _store([Map<String, Object> init = const {}]) async {
  SharedPreferences.setMockInitialValues(init);
  return QuizStore(await SharedPreferences.getInstance());
}

void main() {
  group('하루 1회 판정', () {
    QuizDecision d({String? last, int count = 5, bool blocked = false, String today = '2026-10-29'}) =>
        decideQuiz(today: today, lastDay: last, activeCount: count, blocked: blocked);

    test('그날 처음이면 띄우고, 같은 날 다시 열면 안 뜸', () {
      expect(d(last: null), QuizDecision.show);
      expect(d(last: '2026-10-28'), QuizDecision.show);
      expect(d(last: '2026-10-29'), QuizDecision.alreadyToday);
    });

    test('날짜 경계: 기기 시간 0시 기준', () {
      expect(quizDay(DateTime(2026, 10, 29, 23, 59)), '2026-10-29');
      expect(quizDay(DateTime(2026, 10, 30, 0, 0)), '2026-10-30');
      expect(quizDay(DateTime(2027, 1, 1)), '2027-01-01');
      expect(
        d(last: quizDay(DateTime(2026, 10, 29, 23, 59)), today: quizDay(DateTime(2026, 10, 30, 0, 1))),
        QuizDecision.show,
      );
    });

    test('활성 문항 0개면 안 뜸, 다른 팝업이 먼저 뜬 날은 건너뜀', () {
      expect(d(count: 0), QuizDecision.noQuestions);
      expect(d(blocked: true), QuizDecision.skipToday);
      // 이미 띄운 날이면 팝업 여부와 상관없이 그대로
      expect(d(last: '2026-10-29', blocked: true), QuizDecision.alreadyToday);
    });
  });

  group('셔플백', () {
    test('한 바퀴 동안 중복 없이 전부, 다음 바퀴는 다시 섞어서', () async {
      final s = await _store();
      final bank = _bank([for (var i = 1; i <= 10; i++) _q('q$i')]);
      final rnd = Random(7);
      final round1 = [for (var i = 0; i < 10; i++) (await s.next(bank, random: rnd))!.id];
      expect(round1.toSet(), hasLength(10));
      final round2 = [for (var i = 0; i < 10; i++) (await s.next(bank, random: rnd))!.id];
      expect(round2.toSet(), hasLength(10));
    });

    test('기기마다 순서가 다름 (섞임)', () async {
      final bank = _bank([for (var i = 1; i <= 20; i++) _q('q$i')]);
      final a = await _store();
      final first = [for (var i = 0; i < 20; i++) (await a.next(bank, random: Random(1)))!.id];
      final b = await _store();
      final second = [for (var i = 0; i < 20; i++) (await b.next(bank, random: Random(2)))!.id];
      expect(first, isNot(second));
    });

    test('새 문항은 이번 바퀴 남은 순서에 섞여 들어가고, 이미 낸 문제는 안 나옴', () async {
      final s = await _store();
      final rnd = Random(3);
      final old = _bank([for (var i = 1; i <= 5; i++) _q('q$i')]);
      final done = {for (var i = 0; i < 3; i++) (await s.next(old, random: rnd))!.id};
      final grown = _bank([...old.questions, _q('q6'), _q('q7')], version: 2);
      final rest = [for (var i = 0; i < 4; i++) (await s.next(grown, random: rnd))!.id];
      expect(rest.toSet(), hasLength(4));
      expect(rest.toSet().intersection(done), isEmpty);
      expect(rest, containsAll(['q6', 'q7']));
    });

    test('active=false 문항은 출제 안 함, 0개면 null', () async {
      final s = await _store();
      final bank = _bank([_q('a'), _q('b', active: false), _q('c')]);
      expect(bank.active.map((q) => q.id), ['a', 'c']);
      final got = {for (var i = 0; i < 6; i++) (await s.next(bank))!.id};
      expect(got, {'a', 'c'});
      expect(await s.next(_bank([_q('x', active: false)])), isNull);
    });
  });

  group('문제 풀 (내장본·원격본)', () {
    test('앱에 넣은 questions.json 이 형식에 맞고 활성 문항이 있음', () {
      final bank = QuizBank.parse(File('quiz/questions.json').readAsStringSync())!;
      expect(bank.version, greaterThanOrEqualTo(1));
      expect(bank.active, isNotEmpty);
      expect(bank.questions.map((q) => q.id).toSet(), hasLength(bank.questions.length));
    });

    test('원격 실패·깨진 파일·버전이 같거나 낮으면 내장본 그대로', () async {
      final s = await _store();
      final now = DateTime(2026, 10, 29, 9);
      expect(await s.refresh(1, now: now, fetch: () async => null), isFalse);
      expect(s.cached, isNull);
      final asset = _json(1, ['q1']);
      expect((await s.load(readAsset: () async => asset)).version, 1);

      final s2 = await _store();
      expect(await s2.refresh(1, now: now, fetch: () async => '{깨진'), isFalse);
      expect(await s2.refresh(1, now: now.add(const Duration(days: 2)), fetch: () async => _json(1, ['q9'])), isFalse);
      expect(s2.cached, isNull);
    });

    test('원격 버전이 높으면 캐시해서 다음부터 그걸 씀, 하루 1회만 확인', () async {
      final s = await _store();
      final now = DateTime(2026, 10, 29, 9);
      var calls = 0;
      Future<String?> fetch() async {
        calls++;
        return _json(2, ['q1', 'q2']);
      }

      expect(await s.refresh(1, now: now, fetch: fetch), isTrue);
      final bank = await s.load(readAsset: () async => _json(1, ['q1']));
      expect(bank.version, 2);
      expect(bank.questions, hasLength(2));
      // 24시간 안에는 다시 안 받음
      await s.refresh(2, now: now.add(const Duration(hours: 5)), fetch: fetch);
      expect(calls, 1);
      // 앱을 업데이트해 내장본이 더 새 버전이면 내장본
      expect((await s.load(readAsset: () async => _json(3, ['q1']))).version, 3);
    });
  });

  test('기록·통계: 기기에만 날짜·문항·선택·정답 여부, v1.16 기록 이어짐', () async {
    // v1.16 형식(출처 없음) 기록이 남아 있는 기기
    final s = await _store({
      'quiz_log_v1': [
        jsonEncode({'d': '2026-10-30', 'id': 'q1', 'c': true, 'ok': true}),
      ],
    });
    expect(s.records.single.src, kQuizDaily);
    await s.record(const QuizRecord('2026-10-31', 'q2', false, false, src: kQuizExtra));
    await s.record(const QuizRecord('2026-10-31', 'q3', true, true));
    expect(s.solvedCount, 3);
    expect(s.percent, 67);
    expect(s.menuText('2026-10-31'), '연속 2일 · 정답률 67%');
    expect(s.records[1].toJson(), {'d': '2026-10-31', 'id': 'q2', 'c': false, 'ok': false, 's': 'extra'});
    expect((await _store()).menuText('2026-10-31'), '오늘의 문제를 풀어보세요');
  });

  test('스위치 삭제: 예전에 꺼 둔 기기(quiz_enabled_v1=false)도 그날 처음이면 뜸', () async {
    final s = await _store({'quiz_enabled_v1': false});
    expect(decideQuiz(today: '2026-10-31', lastDay: s.lastDay, activeCount: 5, blocked: false), QuizDecision.show);
  });

  group('연속 일수', () {
    test('오늘까지 이어지면 오늘 포함, 오늘 아직이면 어제까지', () {
      expect(quizStreak(['2026-10-29', '2026-10-30', '2026-10-31'], '2026-10-31'), 3);
      expect(quizStreak(['2026-10-29', '2026-10-30'], '2026-10-31'), 2);
    });

    test('날짜가 끊기면 거기서 멈춤, 이틀 비면 0', () {
      expect(quizStreak(['2026-10-27', '2026-10-29', '2026-10-30'], '2026-10-30'), 2);
      expect(quizStreak(['2026-10-27', '2026-10-28'], '2026-10-30'), 0);
      expect(quizStreak([], '2026-10-30'), 0);
    });

    test('월·연도 경계와 같은 날 여러 번', () {
      expect(quizStreak(['2026-12-31', '2027-01-01', '2027-01-01'], '2027-01-01'), 2);
      expect(quizStreak(['2026-02-28', '2026-03-01'], '2026-03-01'), 2);
    });

    test('추가 문제·챌린지만 푼 날은 연속에 안 들어감', () async {
      final s = await _store();
      await s.record(const QuizRecord('2026-10-30', 'q1', true, true));
      await s.record(const QuizRecord('2026-10-31', 'q2', true, true, src: kQuizExtra));
      expect(s.streak('2026-10-31'), 1);
    });
  });

  group('오늘 푼 문제 제외 출제', () {
    test('오늘 푼 문제(오늘의 문제·추가·챌린지)는 안 나오고, 다 풀면 null (소진)', () async {
      final s = await _store();
      final bank = _bank([for (var i = 1; i <= 4; i++) _q('q$i')]);
      await s.record(const QuizRecord('2026-10-31', 'q1', true, true));
      await s.record(const QuizRecord('2026-10-31', 'q2', true, true, src: kQuizChallenge, run: 'c1'));
      await s.record(const QuizRecord('2026-10-30', 'q3', true, true)); // 어제 푼 건 괜찮음
      final today = s.solvedOn('2026-10-31');
      expect(today, {'q1', 'q2'});
      final got = <String>{};
      for (var i = 0; i < 2; i++) {
        final q = (await s.next(bank, exclude: {...today, ...got}))!;
        got.add(q.id);
      }
      expect(got, {'q3', 'q4'});
      expect(await s.next(bank, exclude: {...today, ...got}), isNull);
    });

    test('셔플백에 남은 게 전부 오늘 푼 문제여도 다른 문제를 낸다', () async {
      final s = await _store();
      final bank = _bank([for (var i = 1; i <= 3; i++) _q('q$i')]);
      final rnd = Random(5);
      final first = (await s.next(bank, random: rnd))!.id; // 남은 순서 2개
      final rest = bank.active.map((q) => q.id).where((id) => id != first).toSet();
      final q = await s.next(bank, exclude: rest, random: rnd);
      expect(q!.id, first);
    });
  });

  group('챌린지', () {
    ChallengeRun run(String id, int ok, int ms, {int n = 20}) => ChallengeRun(id: id, at: 0, n: n, correct: ok, ms: ms);

    test('최고 기록: 정답률 높은 순 → 같으면 시간 짧은 순, 문항 수별 따로', () async {
      expect(isBetterRun(run('a', 18, 200000), run('b', 17, 90000)), isTrue);
      expect(isBetterRun(run('a', 17, 90000), run('b', 17, 100000)), isTrue);
      expect(isBetterRun(run('a', 17, 100000), run('b', 17, 90000)), isFalse);
      expect(isBetterRun(run('a', 17, 90000), run('b', 17, 90000)), isFalse);
      expect(isBetterRun(run('a', 1, 1), null), isTrue);

      final s = await _store();
      await s.saveRun(run('r1', 15, 100000), const []);
      await s.saveRun(run('r2', 18, 150000), const []);
      await s.saveRun(run('r3', 18, 120000), const []);
      await s.saveRun(run('r4', 30, 300000, n: 30), const []);
      expect(s.best(20)!.id, 'r3');
      expect(s.best(30)!.id, 'r4');
      expect(s.best(50), isNull);
      expect(s.best(20, except: 'r3')!.id, 'r2');
    });

    test('활성 문항 수보다 큰 문항 수는 비활성', () {
      expect(challengeSizeEnabled(20, 91), isTrue);
      expect(challengeSizeEnabled(50, 91), isTrue);
      expect(challengeSizeEnabled(30, 25), isFalse);
      expect(challengeSizeEnabled(20, 20), isTrue);
    });

    test('문제는 활성 문항에서 중복 없이 랜덤, 회차·문제별 기록 저장', () async {
      final bank = _bank([for (var i = 1; i <= 30; i++) _q('q$i'), _q('off', active: false)]);
      final set = QuizStore.challengeSet(bank, 20, random: Random(1));
      expect(set, hasLength(20));
      expect(set.map((q) => q.id).toSet(), hasLength(20));
      expect(set.any((q) => q.id == 'off'), isFalse);

      final s = await _store();
      await s.saveRun(run('c9', 1, 5000, n: 2), [
        const QuizRecord('2026-10-31', 'q1', true, true, src: kQuizChallenge, run: 'c9'),
        const QuizRecord('2026-10-31', 'q2', true, false, src: kQuizChallenge, run: 'c9'),
      ]);
      expect(s.runs.single.id, 'c9');
      expect(s.records.where((r) => r.run == 'c9'), hasLength(2));
      expect(quizDuration(134000), '2분 14초');
    });
  });

  test('등급 경계: 100 / 90 / 80 / 60%', () {
    String g(int ok, int n) => quizGrade(ok, n).label;
    expect(g(20, 20), '안전 마스터');
    expect(quizGrade(20, 20).emoji, '🏆');
    expect(g(19, 20), '안전 달인'); // 95%
    expect(g(18, 20), '안전 달인'); // 90%
    expect(g(17, 20), '안전 베테랑'); // 85%
    expect(g(16, 20), '안전 베테랑'); // 80%
    expect(g(15, 20), '안전 실무자'); // 75%
    expect(g(12, 20), '안전 실무자'); // 60%
    expect(g(11, 20), '안전 새내기'); // 55%
    expect(g(0, 20), '안전 새내기');
    expect(g(27, 30), '안전 달인'); // 90%
    expect(g(26, 30), '안전 베테랑'); // 86.7%
    expect(g(29, 50), '안전 새내기'); // 58%
  });

  group('점수 기록 지우기', () {
    test('지울 것: 내 답·정답 여부·챌린지 점수·시간·최고 기록 / 남길 것: 문제·날짜·출처·회차·연속·이름', () async {
      final s = await _store();
      await s.setName('홍길동');
      await s.record(const QuizRecord('2026-10-30', 'q1', true, true));
      await s.record(const QuizRecord('2026-10-31', 'q2', false, false, src: kQuizExtra, at: 5));
      await s.saveRun(const ChallengeRun(id: 'c1', at: 9, n: 1, correct: 1, ms: 3000), [
        const QuizRecord('2026-10-31', 'q3', true, true, src: kQuizChallenge, run: 'c1', at: 9),
      ]);
      expect(s.best(1), isNotNull);
      await s.clearScores();

      final rs = s.records;
      expect(rs.map((r) => (r.day, r.id, r.src)), [
        ('2026-10-30', 'q1', kQuizDaily),
        ('2026-10-31', 'q2', kQuizExtra),
        ('2026-10-31', 'q3', kQuizChallenge),
      ]);
      expect(rs.every((r) => r.choice == null && r.correct == null), isTrue);
      expect(rs.last.run, 'c1');
      expect(rs[1].at, 5);
      expect(s.percent, isNull);
      expect(s.hasScores, isFalse);
      expect(s.runs.single.id, 'c1');
      expect(s.runs.single.scored, isFalse);
      expect(s.best(1), isNull);
      // 남는 것
      expect(s.solvedCount, 3);
      expect(s.streak('2026-10-31'), 1);
      expect(s.solvedOn('2026-10-31'), {'q2', 'q3'});
      expect(s.name, '홍길동');
      expect(s.menuText('2026-10-31'), '연속 1일');
    });

    test('지운 뒤 새로 푼 문제부터 다시 집계', () async {
      final s = await _store();
      await s.record(const QuizRecord('2026-10-30', 'q1', true, false));
      await s.clearScores();
      await s.record(const QuizRecord('2026-10-31', 'q2', true, true));
      await s.record(const QuizRecord('2026-10-31', 'q3', true, false, src: kQuizExtra));
      expect(s.percent, 50);
      expect(s.hasScores, isTrue);
      expect(s.menuText('2026-10-31'), '연속 2일 · 정답률 50%');
      await s.saveRun(const ChallengeRun(id: 'c2', at: 1, n: 20, correct: 10, ms: 1000), const []);
      expect(s.best(20)!.id, 'c2');
    });
  });

  test('결과 카드 이름: 처음엔 null(물어봄), 비워 두면 빈칸으로 저장', () async {
    final s = await _store();
    expect(s.name, isNull);
    await s.setName('  ');
    expect(s.name, '');
    await s.setName(' 홍길동 ');
    expect(s.name, '홍길동');
  });

  test('매일 OX 퀴즈 꺼짐이면 판정은 disabled (그날을 쓰지 않음), 기본 꺼짐', () async {
    expect(
      decideQuiz(today: '2026-10-30', lastDay: null, activeCount: 5, blocked: false, enabled: false),
      QuizDecision.disabled,
    );
    expect(decideQuiz(today: '2026-10-30', lastDay: null, activeCount: 5, blocked: false), QuizDecision.show);
    final s = await _store({'quiz_enabled_v1': true});
    expect(s.dailyOn, isFalse);
    await s.setDailyOn(true);
    expect(s.dailyOn, isTrue);
  });
}
