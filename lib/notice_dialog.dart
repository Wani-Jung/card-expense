import 'package:flutter/material.dart';

import 'layout.dart';

/// 앱 포인트 골드 (아이콘·[확인] 버튼)
const kGold = Color(0xFFF0A500);

/// 골드 위 글자
const kGoldText = Color(0xFF3E2700);

/// 차량비 잔여 경고 주황 (요약표 경고 표시와 경고 팝업이 같은 색을 쓴다, REQ-52·55)
const kCarWarn = Color(0xFFF57C00);

/// 진한 주황 꽉 찬 원 + 흰 '!' (요약표 차량비 잔여 칸 모서리, 경고 팝업 제목 옆)
class WarnBadge extends StatelessWidget {
  final double size;
  const WarnBadge({super.key, this.size = 19});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: kCarWarn, shape: BoxShape.circle),
    child: Text(
      '!',
      textScaler: TextScaler.noScaling,
      style: TextStyle(color: Colors.white, fontSize: size * 0.72, fontWeight: FontWeight.w900, height: 1),
    ),
  );
}

/// 안내 팝업 위쪽의 작은 숫자 칸 하나 (라벨 작게, 숫자 크게)
class NoticeStat {
  final String label, value;

  /// 강조 칸(연한 주황 바탕 + 진한 숫자). 아니면 회색 칸
  final bool highlight;
  const NoticeStat(this.label, this.value, {this.highlight = false});
}

/// 확인 하나짜리 안내 팝업 (REQ-55 공용): 아이콘 + 제목 / 숫자 칸 / 본문 / 골드 [확인].
/// 본문은 줄을 직접 나눠 넘긴다(\n). 다크 테마에서도 읽히게 색은 테마에서 가져온다(골드·주황은 고정).
class NoticeDialog extends StatelessWidget {
  final Widget? icon;
  final String title, body;
  final List<NoticeStat> stats;
  final String okLabel;
  const NoticeDialog({
    super.key,
    this.icon,
    required this.title,
    required this.body,
    this.stats = const [],
    this.okLabel = '확인',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = scheme.onSurface;
    Widget stat(NoticeStat s) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: s.highlight
              ? kCarWarn.withValues(alpha: dark ? 0.24 : 0.12)
              : onSurface.withValues(alpha: dark ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.label, style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.65))),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                s.value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: s.highlight ? FontWeight.w800 : FontWeight.w600,
                  color: s.highlight ? (dark ? const Color(0xFFFFB74D) : const Color(0xFFB45309)) : onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 10)],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface),
                  ),
                ),
              ],
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[if (i > 0) const SizedBox(width: 8), stat(stats[i])],
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              keepWords(body),
              style: TextStyle(fontSize: 15, height: 1.6, color: onSurface.withValues(alpha: 0.78)),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kGoldText,
                  shape: const StadiumBorder(),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 아래 빈 공간 줄이기 (버튼 높이 ≥ 44 라 누르기는 충분)
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  textStyle: (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(okLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showNoticeDialog(
  BuildContext context, {
  Widget? icon,
  required String title,
  required String body,
  List<NoticeStat> stats = const [],
}) => showDialog<void>(
  context: context,
  builder: (_) => NoticeDialog(icon: icon, title: title, body: body, stats: stats),
);
