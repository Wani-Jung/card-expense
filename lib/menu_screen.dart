import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'flavor.dart';
import 'layout.dart';

/// 우측 상단 톱니 → 메뉴 화면. 섹션 제목 없이 한 목록, 항목 사이엔 얇은 구분선만.
/// '결제내역 입력'·'내역 관리'는 그 자리에서 펼친다. 접힌 상태 7개는 스크롤 없이 한 화면에.
/// 내역 넣기·업데이트 확인은 메뉴를 닫고 메인 화면에서 실행해 결과가 메인에 보이게 한다.
class MenuScreen extends StatefulWidget {
  final VoidCallback onImport, onPaste, onOcr, onVendors, onUpdate;

  /// (전용판) 권한 설정에서 문자 읽기를 끄면 1년치 불러오기를 흐리게
  final bool Function() importEnabled;

  /// 카드 문자 설정 (카드번호·발신번호). 저장하고 돌아오면 설명의 현재 값을 다시 읽는다.
  final Future<void> Function() onSettings;
  final String Function() cardSummary;

  /// 권한 설정. 설명은 "알림 감지 켜짐 · 문자 읽기 켜짐" 같은 현재 상태 요약
  final Future<void> Function() onPermissions;
  final String Function() permSummary;

  /// 내역 관리 건수 (미분류, 확인 필요, 무시한). 각 화면에서 돌아오면 다시 센다.
  final ({int pending, int check, int ignored}) Function() counts;
  final Future<void> Function() onUnclassified, onCheck, onIgnored;

  const MenuScreen({
    super.key,
    required this.onImport,
    required this.onPaste,
    required this.onOcr,
    required this.onVendors,
    required this.onUpdate,
    required this.importEnabled,
    required this.onSettings,
    required this.cardSummary,
    required this.onPermissions,
    required this.permSummary,
    required this.counts,
    required this.onUnclassified,
    required this.onCheck,
    required this.onIgnored,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _inputOpen = false;

  /// 기본 접힘. 확인 필요가 1건 이상이면 펼친 상태로 시작
  late bool _manageOpen = widget.counts().check > 0;
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  static const _subBg = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    // 메뉴를 닫고 메인에서 실행
    VoidCallback closeThen(VoidCallback f) => () {
      Navigator.pop(context);
      f();
    };
    // 화면을 열고, 돌아오면 건수·설명 다시 읽기
    VoidCallback openThen(Future<void> Function() f) => () async {
      await f();
      if (mounted) setState(() {});
    };

    // 건수 배지: 0건이면 회색, 1건 이상이면 진하게
    Widget badge(int n) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: n == 0 ? const Color(0xFFF1F3F4) : const Color(0xFF1F1F1F),
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

    Widget item(IconData icon, String title, String subtitle, VoidCallback? onTap, {Widget? trailing}) => ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Icon(icon),
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
            () => setState(() => _inputOpen = !_inputOpen),
            trailing: chevron(_inputOpen),
          ),
          if (_inputOpen) ...[
            if (isFullEdition) sub(Icons.history, '지난 문자 1년치 불러오기', importOn ? closeThen(w.onImport) : null),
            sub(Icons.content_paste, '문자 붙여넣기', closeThen(w.onPaste)),
            sub(Icons.image_search, '문자 캡처화면 업로드', closeThen(w.onOcr)),
          ],
          line,
          item(
            Icons.fact_check_outlined,
            '내역 관리',
            '미분류 · 확인 필요 · 무시한 내역',
            () => setState(() => _manageOpen = !_manageOpen),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [badge(c.pending + c.check), const SizedBox(width: 4), chevron(_manageOpen)],
            ),
          ),
          if (_manageOpen) ...[
            sub(Icons.inbox_outlined, '미분류 내역', openThen(w.onUnclassified), trailing: badge(c.pending)),
            sub(Icons.rule, '확인 필요 내역', openThen(w.onCheck), trailing: badge(c.check)),
            sub(Icons.visibility_off_outlined, '무시한 내역', openThen(w.onIgnored), trailing: badge(c.ignored)),
          ],
          line,
          item(Icons.storefront, '등록 업체·추천 키워드', '가맹점 이름으로 차량비/운영비를 추천해요', w.onVendors),
          line,
          item(Icons.credit_card, '카드 문자 설정', w.cardSummary(), openThen(w.onSettings)),
          line,
          item(Icons.shield_outlined, '권한 설정', w.permSummary(), openThen(w.onPermissions)),
          line,
          FutureBuilder<PackageInfo>(
            future: _info,
            builder: (_, snap) => item(
              Icons.system_update,
              '업데이트 확인',
              '현재 ${snap.hasData ? 'v${snap.data!.version}' : ''} · $editionLabel',
              closeThen(w.onUpdate),
            ),
          ),
          line,
          item(Icons.person_outline, '제작자', 'wani', null),
        ],
      ),
    );
  }
}
