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
    QuizDecision d({String? last, bool enabled = true, int count = 5, bool blocked = false, String today = '2026-10-29'}) =>
        decideQuiz(today: today, lastDay: last, enabled: enabled, activeCount: count, blocked: blocked);

    test('그날 처음이면 띄우고, 같은 날 다시 열면 안 뜸', () {
      expect(d(last: null), QuizDecision.show);
      expect(d(last: '2026-10-28'), QuizDecision.show);
      expect(d(last: '2026-10-29'), QuizDecision.alreadyToday);
    });

    test('날짜 경계: 기기 시간 0시 기준', () {
      expect(quizDay(DateTime(2026, 10, 29, 23, 59)), '2026-10-29');
      expect(quizDay(DateTime(2026, 10, 30, 0, 0)), '2026-10-30');
      expect(quizDay(DateTime(2027, 1, 1)), '2027-01-01');
      expect(d(last: quizDay(DateTime(2026, 10, 29, 23, 59)), today: quizDay(DateTime(2026, 10, 30, 0, 1))),
          QuizDecision.show);
    });

    test('꺼 둠·활성 문항 0개면 안 뜸, 다른 팝업이 먼저 뜬 날은 건너뜀', () {
      expect(d(enabled: false), QuizDecision.disabled);
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

  test('기록·통계: 기기에만 날짜·문항·선택·정답 여부', () async {
    final s = await _store();
    expect(s.statsText, '지금까지 0문제 · 정답률 -');
    await s.record(const QuizRecord('2026-10-29', 'q1', true, true));
    await s.record(const QuizRecord('2026-10-30', 'q2', false, false));
    await s.record(const QuizRecord('2026-10-31', 'q3', true, true));
    expect(s.statsText, '지금까지 3문제 · 정답률 67%');
    expect(s.records.first.toJson(), {'d': '2026-10-29', 'id': 'q1', 'c': true, 'ok': true});
    expect(s.enabled, isTrue);
  });
}
