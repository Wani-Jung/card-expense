import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flavor.dart';
import 'layout.dart';

/// 우측 상단 톱니 → 메뉴 화면. 섹션 제목 없이 한 목록, 항목 사이엔 얇은 구분선만.
/// '결제내역 입력'·'내역 관리'는 그 자리에서 펼친다 (펼침 항목은 한 번에 하나만). 접힌 상태는 스크롤 없이 한 화면에.
/// 모든 항목은 메뉴를 닫지 않고 메뉴 위에 화면을 띄운다 → 뒤로가기 하면 메뉴로. 돌아오면 건수·설명을 다시 읽고
/// 펼침 상태는 그대로. 1년치 불러오기·업데이트 확인도 메뉴에 머문 채 진행 표시와 결과 창을 띄운다.
class MenuScreen extends StatefulWidget {
  final Future<void> Function() onImport, onPaste, onOcr, onVendors;

  /// 업데이트 확인. 메뉴를 닫지 않고, 확인하는 동안 항목 오른쪽에 작은 로딩 표시.
  /// null(스토어판)이면 '업데이트 확인' 대신 누를 수 없는 '버전 정보'만 보인다.
  final Future<void> Function()? onUpdate;

  /// (전용판) 권한 설정에서 문자 읽기를 끄면 1년치 불러오기를 흐리게
  final bool Function() importEnabled;

  /// 카드 문자 설정 (카드번호·발신번호). 저장하고 돌아오면 설명의 현재 값을 다시 읽는다.
  final Future<void> Function() onSettings;
  final String Function() cardSummary;

  /// 권한 설정. 설명은 "알림 감지 켜짐 · 문자 읽기 켜짐" 같은 현재 상태 요약
  final Future<void> Function() onPermissions;
  final String Function() permSummary;

  /// 설정 ('매일 OX 퀴즈' 스위치). 설명은 '매일 OX 퀴즈 켜짐/꺼짐'
  final Future<void> Function() onAppSettings;
  final String Function() appSettingsSummary;

  /// 안전 OX Quiz: 설명 "연속 N일 · 정답률 NN%", 누르면 안전 OX Quiz 화면
  final String Function() quizSummary;
  final Future<void> Function() onQuiz;

  /// 내역 관리 건수 (미분류, 확인 필요, 무시한, 확인한 = 차량비·운영비로 분류된 전체). 각 화면에서 돌아오면 다시 센다.
  final ({int pending, int check, int ignored, int confirmed}) Function() counts;
  final Future<void> Function() onUnclassified, onCheck, onIgnored, onConfirmed;

  const MenuScreen({
    super.key,
    required this.onImport,
    required this.onPaste,
    required this.onOcr,
    required this.onVendors,
    this.onUpdate,
    required this.importEnabled,
    required this.onSettings,
    required this.cardSummary,
    required this.onPermissions,
    required this.permSummary,
    required this.onAppSettings,
    required this.appSettingsSummary,
    required this.quizSummary,
    required this.onQuiz,
    required this.counts,
    required this.onUnclassified,
    required this.onCheck,
    required this.onIgnored,
    required this.onConfirmed,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// 펼친 항목 (한 번에 하나만). 기본 접힘, 확인 필요가 1건 이상이면 내역 관리를 펼친 채 시작
  late String? _expanded = widget.counts().check > 0 ? 'manage' : null;
  void _toggle(String key) => setState(() => _expanded = _expanded == key ? null : key);

  /// 진행 중인 항목 (오른쪽 작은 로딩): 'import' 1년치 불러오기, 'update' 업데이트 확인
  final _busy = <String>{};
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  static const _subBg = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    // 메뉴 위에 화면을 띄우고, 돌아오면 건수·설명 다시 읽기 (펼침 상태는 그대로)
    VoidCallback openThen(Future<void> Function() f) => () async {
      await f();
      if (mounted) setState(() {});
    };
    // 메뉴에 머문 채 실행, 끝날 때까지 오른쪽에 작은 로딩
    VoidCallback? busyThen(String key, Future<void> Function() f) => _busy.contains(key)
        ? null
        : () async {
            setState(() => _busy.add(key));
            try {
              await f();
            } finally {
              if (mounted) setState(() => _busy.remove(key));
            }
          };
    Widget? spinner(String key) => _busy.contains(key)
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : null;

    // 건수 배지: 0건이면 회색. [alert](미분류·확인 필요, 내역 관리 합계)는 1건 이상이면 빨강, 나머지는 검정
    Widget badge(int n, {bool alert = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: n == 0 ? const Color(0xFFF1F3F4) : (alert ? const Color(0xFFD93025) : const Color(0xFF1F1F1F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$n건',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: n == 0 ? const Color(0xFF9AA0A6) : Colors.white,
        ),
      ),
    );

    Widget item(IconData? icon, String title, String subtitle, VoidCallback? onTap, {Widget? trailing, Widget? leading}) =>
        ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: leading ?? Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
    // 펼친 하위 항목: 들여쓰기 + 약간 작은 글씨 + 아주 연한 회색 배경
    Widget sub(IconData icon, String title, VoidCallback? onTap, {Widget? trailing}) => ListTile(
      tileColor: _subBg,
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: trailing,
      enabled: onTap != null,
      onTap: onTap,
    );
    Widget chevron(bool open) => Icon(open ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF5F6368));
    const line = Divider(height: 1, thickness: 0.5);

    final c = w.counts();
    final importOn = w.importEnabled();

    return Scaffold(
      appBar: AppBar(title: const Text('메뉴')),
      body: ListView(
        padding: EdgeInsets.only(bottom: listBottomPad(context)),
        children: [
          item(
            Icons.add_card,
            '결제내역 입력',
            '문자 불러오기 · 붙여넣기 · 캡처 업로드',
            () => _toggle('input'),
            trailing: chevron(_expanded == 'input'),
          ),
          if (_expanded == 'input') ...[
            if (isFullEdition)
              sub(
                Icons.history,
                '지난 문자 1년치 불러오기',
                importOn ? busyThen('import', w.onImport) : null,
                trailing: spinner('import'),
              ),
            sub(Icons.content_paste, '문자 붙여넣기', openThen(w.onPaste)),
            sub(Icons.image_search, '문자 캡처화면 업로드', openThen(w.onOcr)),
          ],
          line,
          item(
            Icons.fact_check_outlined,
            '내역 관리',
            '미분류 · 확인 필요 · 무시한 내역',
            () => _toggle('manage'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                badge(c.pending + c.check, alert: true),
                const SizedBox(width: 4),
                chevron(_expanded == 'manage'),
              ],
            ),
          ),
          if (_expanded == 'manage') ...[
            sub(Icons.inbox_outlined, '미분류 내역', openThen(w.onUnclassified), trailing: badge(c.pending, alert: true)),
            sub(Icons.rule, '확인 필요 내역', openThen(w.onCheck), trailing: badge(c.check, alert: true)),
            sub(Icons.visibility_off_outlined, '무시한 내역', openThen(w.onIgnored), trailing: badge(c.ignored)),
            sub(Icons.task_alt, '확인한 내역', openThen(w.onConfirmed), trailing: badge(c.confirmed)),
          ],
          line,
          item(Icons.storefront, '등록 업체·추천 키워드', '가맹점 이름으로 차량비/운영비를 추천해요', openThen(w.onVendors)),
          line,
          item(null, '안전 OX Quiz', w.quizSummary(), openThen(w.onQuiz), leading: const QuizIcon()),
          line,
          item(Icons.credit_card, '카드 문자 설정', w.cardSummary(), openThen(w.onSettings)),
          line,
          item(Icons.shield_outlined, '권한 설정', w.permSummary(), openThen(w.onPermissions)),
          line,
          item(Icons.tune, '설정', w.appSettingsSummary(), openThen(w.onAppSettings)),
          line,
          item(
            Icons.privacy_tip_outlined,
            '개인정보처리방침',
            '문자·알림은 휴대폰 안에서만 처리해요',
            () => launchUrl(Uri.parse(kPrivacyUrl), mode: LaunchMode.externalApplication),
          ),
          line,
          FutureBuilder<PackageInfo>(
            future: _info,
            builder: (_, snap) {
              final version = '${snap.hasData ? 'v${snap.data!.version}' : ''} · $editionLabel';
              final onUpdate = w.onUpdate;
              // 스토어판: 업데이트는 플레이스토어가 맡는다. 버전만 보여 주고 누르는 반응 없음
              if (onUpdate == null) return item(Icons.info_outline, '버전 정보', version, null);
              return item(
                Icons.system_update,
                '업데이트 확인',
                '현재 $version',
                busyThen('update', onUpdate),
                trailing: spinner('update'),
              );
            },
          ),
          // 크레딧: 목록 항목이 아니라 맨 아래 작은 회색 글씨 (누르는 반응 없음)
          const Padding(
            padding: EdgeInsets.only(top: 32, bottom: 8),
            child: Center(
              child: Text('Made by wani', style: TextStyle(fontSize: 12, color: Color(0xFF9AA0A6))),
            ),
          ),
        ],
      ),
    );
  }
}

/// 메뉴 '안전 OX Quiz' 아이콘: 다른 메뉴 아이콘과 같은 24dp·같은 색, 둥근 사각 테두리 안에 굵은 'QUIZ'.
/// 외부 폰트·이미지 없이 직접 그린다 (글자는 칸에 맞게 자동 크기).
class QuizIcon extends StatelessWidget {
  final double size;
  const QuizIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? ListTileTheme.of(context).iconColor ?? const Color(0xFF5F6368);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _QuizIconPainter(color)),
    );
  }
}

class _QuizIconPainter extends CustomPainter {
  final Color color;
  _QuizIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.085;
    final rect = Rect.fromLTWH(stroke / 2 + s * 0.04, s * 0.2, s - stroke - s * 0.08, s * 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.14)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    // 'QUIZ' 를 테두리 안쪽 폭에 맞춰 자동 크기
    final inner = rect.deflate(stroke * 1.1);
    var fontSize = inner.height;
    TextPainter tp;
    do {
      tp = TextPainter(
        text: TextSpan(
          text: 'QUIZ',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: color, height: 1, letterSpacing: 0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      fontSize -= 0.25;
    } while ((tp.width > inner.width || tp.height > inner.height) && fontSize > 2);
    tp.paint(canvas, Offset(inner.center.dx - tp.width / 2, inner.center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_QuizIconPainter old) => old.color != color;
}
