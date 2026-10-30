import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'quiz.dart';
import 'quiz_sheet.dart';

/// 결과 카드 상단 왼쪽 이미지. 지금은 앱 아이콘. 나중에 공식 로고를 받으면 assets/brand/ 에 넣고 이 상수만 바꾼다
/// (pubspec.yaml assets 에도 추가). 기관 로고는 아직 넣지 않는다.
const kShareCardLogo = 'assets/icon/wani_card_gold_1024.png';

const _goldLight = Color(0xFFFFE08A);
const _grey = Color(0xFF80868B);
const _ribbonRed = Color(0xFFD93025);

/// "2026.10.29"
String cardDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 챌린지 결과 카드 (세로 2:3). 화면 위쪽에 보이는 이 카드가 그대로 공유 이미지가 된다.
/// 골드 → 연골드 → 네이비 대각선 그라데이션 테두리 10 + 흰 카드. 최고 기록이면 오른쪽 위 빨간 사선 띠.
class ChallengeResultCard extends StatelessWidget {
  final ChallengeRun run;
  final String? name;
  final DateTime date;
  final bool newBest;
  const ChallengeResultCard({
    super.key,
    required this.run,
    required this.name,
    required this.date,
    required this.newBest,
  });

  @override
  Widget build(BuildContext context) {
    final correct = run.correct ?? 0;
    final ms = run.ms ?? 0;
    final grade = quizGrade(correct, run.n);
    final avg = run.n == 0 ? 0.0 : ms / 1000 / run.n;
    final who = (name ?? '').trim();
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kQuizNavy),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _grey)),
        ],
      ),
    );
    // 시스템 글자 크기와 상관없이 카드 모양이 그대로 나오게 (공유 이미지)
    return MediaQuery.withNoTextScaling(
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kQuizGold, _goldLight, kQuizNavy],
              stops: [0, 0.45, 1],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      // 작은 화면에서도 넘치지 않게 통째로 줄인다
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: 280,
                          height: 400,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.asset(kShareCardLogo, width: 32, height: 32, cacheWidth: 128),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '공감카드 관리',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F1F1F),
                                          ),
                                        ),
                                        Text('한국농어촌공사 현장 안전 OX', style: TextStyle(fontSize: 10, color: _grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Text(
                                '안전 OX 챌린지',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: kQuizNavy,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                run.cats == null ? '분야: 전체' : '분야: ${run.cats}개 선택',
                                style: const TextStyle(fontSize: 11, color: _grey),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 132,
                                height: 132,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kQuizGold, width: 5),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${run.percent}%',
                                      style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w800,
                                        color: kQuizNavy,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text('$correct / ${run.n} 정답', style: const TextStyle(fontSize: 12, color: _grey)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(color: kQuizNavy, borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  '${grade.emoji} ${grade.label}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F4F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    stat('${run.n}', '문항 수'),
                                    stat(quizDuration(ms), '걸린 시간'),
                                    stat('${avg.toStringAsFixed(1)}초', '문항당'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                who.isEmpty ? cardDate(date) : '$who · ${cardDate(date)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3C4043),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text('Made by wani', style: TextStyle(fontSize: 10, color: Color(0xFF9AA0A6))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (newBest)
                  Positioned(
                    top: 18,
                    right: -34,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: _ribbonRed,
                        alignment: Alignment.center,
                        child: const Text(
                          '최고 기록!',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
