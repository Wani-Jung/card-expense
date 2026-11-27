import 'package:flutter/material.dart';

import 'layout.dart';

/// 앱 포인트 골드 (아이콘·[확인] 버튼)
const kGold = Color(0xFFF0A500);

/// 문자 권한이 없을 때 메뉴 '권한 설정'·권한 설정 '문자 읽기'에 붙이는 노란 느낌표 (2.1.1)
const kPermAlert = kGold;

/// 노란 느낌표 하나 (문자 권한 필요). 툴팁 '문자 권한이 꺼져 있어요'
class PermAlertBadge extends StatelessWidget {
  final double size;
  const PermAlertBadge({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) =>
      Tooltip(message: '문자 권한이 꺼져 있어요', child: WarnBadge(size: size, color: kPermAlert));
}

/// 골드 위 글자
const kGoldText = Color(0xFF3E2700);

/// 차량비 잔여 경고 주황 (요약표 경고 표시와 경고 팝업이 같은 색을 쓴다, REQ-52·55)
const kCarWarn = Color(0xFFF57C00);

/// 진한 주황 꽉 찬 원 + 흰 '!' (요약표 차량비 잔여 칸 모서리, 경고 팝업 제목 옆)
class WarnBadge extends StatelessWidget {
  final double size;

  /// 원 색. 기본은 진한 주황(차량비 잔여 경고). 권한 안내 표시는 노랑([kPermAlert])
  final Color color;
  const WarnBadge({super.key, this.size = 19, this.color = kCarWarn});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      '!',
      textScaler: TextScaler.noScaling,
      style: TextStyle(color: Colors.white, fontSize: size * 0.72, fontWeight: FontWeight.w900, height: 1),
    ),
  );
}

/// 경고가 아닌 안내 팝업의 아이콘 (REQ-59): 남색 원 안 'i' (다크 테마에선 밝은 파랑)
class NoticeInfoIcon extends StatelessWidget {
  final double size;
  const NoticeInfoIcon({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) => Icon(
    Icons.info_rounded,
    size: size,
    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8AB4F8) : const Color(0xFF1F3A68),
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

  /// 본문 아래 덧붙일 내용 (예: 접었다 펴는 원문 목록). 길면 이 부분만 스크롤
  final Widget? child;

  /// 제목 줄을 길게 누르면 (숨은 진단 정보용, 기본 화면엔 표시 없음)
  final VoidCallback? onTitleLongPress;

  /// 골드 버튼을 누르면 팝업을 닫고 이어서 할 일 (예: [업데이트]). 없으면 닫기만
  final VoidCallback? onOk;

  /// 골드 버튼 왼쪽 글자 버튼 (예: [나중에]). 누르면 닫기만. 없으면 버튼 하나
  final String? cancelLabel;
  const NoticeDialog({
    super.key,
    this.icon,
    required this.title,
    required this.body,
    this.stats = const [],
    this.okLabel = '확인',
    this.child,
    this.onTitleLongPress,
    this.onOk,
    this.cancelLabel,
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
            // 칸이 좁아도 라벨이 단어 중간에서 줄바꿈되지 않게 한 줄로 줄여서 (REQ-59: 칸 3개)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                s.label,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.65)),
              ),
            ),
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onTitleLongPress,
              child: Row(
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
            if (body.isNotEmpty)
              Text(
                keepWords(body),
                style: TextStyle(fontSize: 15, height: 1.6, color: onSurface.withValues(alpha: 0.78)),
              ),
            if (child != null) Flexible(child: SingleChildScrollView(child: child)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cancelLabel != null) ...[
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: onSurface.withValues(alpha: 0.7)),
                    onPressed: () => Navigator.pop(context),
                    child: Text(cancelLabel!),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kGoldText,
                      shape: const StadiumBorder(),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 아래 빈 공간 줄이기 (버튼 높이 ≥ 44 라 누르기는 충분)
                      padding: EdgeInsets.symmetric(horizontal: cancelLabel == null ? 26 : 20, vertical: 12),
                      textStyle: (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onOk?.call();
                    },
                    // 좁은 화면에서 [보조][긴 라벨]이 한 줄에 안 들어가면 글자를 줄인다 (REQ-64 'Play 스토어에서 보기')
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(okLabel, maxLines: 1)),
                  ),
                ),
              ],
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
  String okLabel = '확인',
  Widget? child,
}) => showDialog<void>(
  context: context,
  builder: (_) => NoticeDialog(icon: icon, title: title, body: body, stats: stats, okLabel: okLabel, child: child),
);
