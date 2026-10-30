import 'package:flutter/material.dart';

import 'layout.dart';
import 'native.dart';

/// 권한 안내(Prominent Disclosure). 시스템 권한 창·설정 화면으로 보내기 직전에 전체 화면으로 먼저 보여준다.
/// [동의하고 계속] → true, [나중에]·뒤로가기 → false. 매번 이 안내부터 (동의를 기억하지 않음).
class DisclosureScreen extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const DisclosureScreen({super.key, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false, // 아래 여백은 listBottomPad 로 (내비게이션 바 포함)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 48, color: const Color(0xFF1F3A68)),
                  const SizedBox(height: 20),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(body, style: const TextStyle(fontSize: 16, height: 1.6)),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, listBottomPad(context) - 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('동의하고 계속', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('나중에', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

const kSmsDisclosureTitle = '카드 승인 문자 읽기 권한 안내';
const kSmsDisclosureBody =
    '공감카드 관리는 카드사에서 받은 승인·취소 문자를 읽어 날짜, 금액, 가맹점을 지출 내역으로 자동 정리합니다. '
    '이를 위해 문자 읽기 권한이 필요합니다.\n\n'
    '카드 문자가 아닌 일반 문자는 저장하지 않으며, 읽은 내용은 휴대폰 밖으로 보내지 않습니다.\n\n'
    "'지난 문자 불러오기'를 실행하면 최근 1년의 문자에서 카드 문자만 찾아 가져옵니다.";

const kListenerDisclosureTitle = '카드 승인 알림 읽기 권한 안내';
const kListenerDisclosureBody =
    '공감카드 관리는 메시지 앱에 뜨는 카드 승인·취소 알림을 읽어 지출 내역으로 자동 정리합니다. '
    '이를 위해 알림 접근 권한이 필요합니다.\n\n'
    '카드 승인 알림만 저장하고 다른 알림은 저장하지 않으며, 읽은 내용은 휴대폰 밖으로 보내지 않습니다.\n\n'
    '[동의하고 계속]을 누르면 휴대폰 설정의 알림 접근 화면이 열립니다. 공감카드 관리를 켜주세요.';

Future<bool> _showDisclosure(BuildContext context, IconData icon, String title, String body) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => DisclosureScreen(icon: icon, title: title, body: body),
    )) ==
    true;

/// (전용판) 문자 권한 요청: 안내 화면 → [동의하고 계속]일 때만 시스템 권한 창. 동의했으면 true.
Future<bool> requestSmsWithDisclosure(BuildContext context) async {
  if (!await _showDisclosure(context, Icons.sms_outlined, kSmsDisclosureTitle, kSmsDisclosureBody)) return false;
  await Native.requestSmsPermission();
  return true;
}

/// 알림 접근 설정 화면 열기: 안내 화면 → [동의하고 계속]일 때만 설정 화면으로. 동의했으면 true.
Future<bool> openNotificationAccessWithDisclosure(BuildContext context) async {
  if (!await _showDisclosure(
      context, Icons.notifications_active_outlined, kListenerDisclosureTitle, kListenerDisclosureBody)) {
    return false;
  }
  await Native.openNotificationAccessSettings();
  return true;
}
