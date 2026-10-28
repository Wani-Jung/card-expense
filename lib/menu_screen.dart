import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'flavor.dart';
import 'layout.dart';

/// 우측 상단 톱니 → 메뉴 화면. 기능을 섹션별로 묶는다.
/// 내역 넣기·정산·업데이트 확인은 메뉴를 닫고 메인 화면에서 실행해 결과가 메인에 보이게 한다.
class MenuScreen extends StatefulWidget {
  final String monthLabel;
  final VoidCallback onImport, onPaste, onOcr, onCopy, onVendors, onSettings, onListener, onUpdate;

  /// 내역 관리 건수 (미분류, 확인 필요, 무시한). 각 화면에서 돌아오면 다시 센다.
  final ({int pending, int check, int ignored}) Function() counts;
  final Future<void> Function() onUnclassified, onCheck, onIgnored;

  const MenuScreen({
    super.key,
    required this.monthLabel,
    required this.onImport,
    required this.onPaste,
    required this.onOcr,
    required this.onCopy,
    required this.onVendors,
    required this.onSettings,
    required this.onListener,
    required this.onUpdate,
    required this.counts,
    required this.onUnclassified,
    required this.onCheck,
    required this.onIgnored,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    final w = widget;
    // 메뉴를 닫고 메인에서 실행
    VoidCallback closeThen(VoidCallback f) => () {
          Navigator.pop(context);
          f();
        };

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5F6368))),
        );
    Widget item(IconData icon, String title, String subtitle, VoidCallback? onTap, {Widget? trailing}) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: trailing,
          onTap: onTap,
        );
    // 건수 배지: 0건이면 회색, 1건 이상이면 진하게
    Widget badge(int n) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: n == 0 ? const Color(0xFFF1F3F4) : const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$n건',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: n == 0 ? const Color(0xFF9AA0A6) : Colors.white)),
        );
    // 내역 관리 화면을 열고, 돌아오면 건수 다시 세기
    VoidCallback openThen(Future<void> Function() f) => () async {
          await f();
          if (mounted) setState(() {});
        };
    final c = w.counts();

    return Scaffold(
      appBar: AppBar(title: const Text('메뉴')),
      body: ListView(
        padding: EdgeInsets.only(bottom: listBottomPad(context)),
        children: [
          section('내역 넣기'),
          if (isFullEdition)
            item(Icons.history, '지난 문자 1년치 불러오기', '문자함에서 카드 승인 문자를 찾아 분류 대기에 넣어요',
                closeThen(w.onImport)),
          item(Icons.content_paste, '문자 붙여넣기', '복사한 카드 문자를 여러 건 한 번에 넣어요', closeThen(w.onPaste)),
          item(Icons.image_search, '문자 캡처화면 업로드', '대화방 스크롤 캡처에서 글자를 읽어 넣어요', closeThen(w.onOcr)),
          section('내역 관리'),
          item(Icons.inbox_outlined, '미분류 내역', '모든 달의 분류 대기 건을 한 번에 정리해요', openThen(w.onUnclassified),
              trailing: badge(c.pending)),
          item(Icons.fact_check_outlined, '확인 필요 내역', '분류 실수·중복·날짜 이상이 의심되는 건을 보여줘요',
              openThen(w.onCheck),
              trailing: badge(c.check)),
          item(Icons.visibility_off_outlined, '무시한 내역', '무시한 문자를 다시 분류하거나 대기로 되돌려요', openThen(w.onIgnored),
              trailing: badge(c.ignored)),
          section('정산'),
          item(Icons.copy, '이번 달 내역 복사', '${w.monthLabel} 수립/사용과 내역을 정산용 텍스트로 복사해요',
              closeThen(w.onCopy)),
          section('업체 관리'),
          item(Icons.storefront, '등록 업체·추천 키워드', '가맹점 이름으로 차량비/운영비를 추천해요', w.onVendors),
          section('설정'),
          item(Icons.credit_card, '카드번호 변경', '승인 문자에 적힌 카드번호 네자리', w.onSettings),
          item(Icons.phone, '발신번호 변경', '카드 승인 문자를 보내는 번호', w.onSettings),
          item(Icons.notifications_active_outlined, '알림 접근 설정', '메시지 앱 알림에서 승인 문자를 자동으로 찾아요',
              w.onListener),
          section('앱 정보'),
          item(Icons.system_update, '업데이트 확인', '새 버전이 있으면 받을 수 있어요', closeThen(w.onUpdate)),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => item(
              Icons.info_outline,
              '현재 버전',
              '$kAppName ${snap.hasData ? 'v${snap.data!.version}' : ''} · $editionLabel',
              null,
            ),
          ),
        ],
      ),
    );
  }
}
