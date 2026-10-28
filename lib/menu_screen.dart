import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'flavor.dart';
import 'layout.dart';

/// 우측 상단 톱니 → 메뉴 화면. 기능을 섹션별로 묶는다.
/// 내역 넣기·정산·업데이트 확인은 메뉴를 닫고 메인 화면에서 실행해 결과가 메인에 보이게 한다.
class MenuScreen extends StatefulWidget {
  final String monthLabel;
  final VoidCallback onImport, onPaste, onOcr, onCopy, onVendors, onSettings, onListener, onUpdate;

  /// 무시한 내역 건수. 무시한 내역 화면에서 되살리고 돌아오면 다시 센다.
  final int Function() ignoredCount;
  final Future<void> Function() onIgnored;

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
    required this.ignoredCount,
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
    Widget item(IconData icon, String title, String subtitle, VoidCallback? onTap) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          onTap: onTap,
        );

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
          item(Icons.visibility_off_outlined, '무시한 내역 (${w.ignoredCount()}건)', '무시한 문자를 다시 분류하거나 대기로 되돌려요',
              () async {
            await w.onIgnored();
            if (mounted) setState(() {});
          }),
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
