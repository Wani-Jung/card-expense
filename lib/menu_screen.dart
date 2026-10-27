import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'flavor.dart';

/// 우측 상단 톱니 → 메뉴 화면. 기능을 섹션별로 묶는다.
/// 내역 넣기·정산·업데이트 확인은 메뉴를 닫고 메인 화면에서 실행해 결과가 메인에 보이게 한다.
class MenuScreen extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onImport, onPaste, onOcr, onCopy, onVendors, onSettings, onListener, onUpdate, onDiagnose;

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
    required this.onDiagnose,
  });

  @override
  Widget build(BuildContext context) {
    // 메뉴를 닫고 메인에서 실행
    VoidCallback closeThen(VoidCallback f) => () {
          Navigator.pop(context);
          f();
        };

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          section('내역 넣기'),
          if (isFullEdition)
            item(Icons.history, '지난 문자 1년치 불러오기', '문자함에서 카드 승인 문자를 찾아 분류 대기에 넣어요',
                closeThen(onImport)),
          item(Icons.content_paste, '문자 붙여넣기', '복사한 카드 문자를 여러 건 한 번에 넣어요', closeThen(onPaste)),
          item(Icons.image_search, '문자 캡처화면 업로드', '대화방 스크롤 캡처에서 글자를 읽어 넣어요', closeThen(onOcr)),
          section('정산'),
          item(Icons.copy, '이번 달 내역 복사', '$monthLabel 수립/사용과 내역을 정산용 텍스트로 복사해요', closeThen(onCopy)),
          section('업체 관리'),
          item(Icons.storefront, '등록 업체·추천 키워드', '가맹점 이름으로 차량비/운영비를 추천해요', onVendors),
          section('설정'),
          item(Icons.credit_card, '카드번호 변경', '승인 문자에 적힌 카드번호 네자리', onSettings),
          item(Icons.phone, '발신번호 변경', '카드 승인 문자를 보내는 번호', onSettings),
          item(Icons.notifications_active_outlined, '알림 접근 설정', '메시지 앱 알림에서 승인 문자를 자동으로 찾아요', onListener),
          section('앱 정보'),
          item(Icons.system_update, '업데이트 확인', '새 버전이 있으면 받을 수 있어요', closeThen(onUpdate)),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => item(
              Icons.info_outline,
              '현재 버전',
              '$kAppName ${snap.hasData ? 'v${snap.data!.version}' : ''} · $editionLabel',
              null,
            ),
          ),
          if (isFullEdition) ...[
            section('관리자 (전용판)'),
            item(Icons.manage_search, '문자 저장소 진단', 'SMS·MMS·RCS 저장소에 접근되는지 확인해요', onDiagnose),
          ],
        ],
      ),
    );
  }
}
