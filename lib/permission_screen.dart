import 'package:flutter/material.dart';

import 'disclosure.dart';
import 'expense.dart';
import 'flavor.dart';
import 'layout.dart';
import 'native.dart';

/// 메뉴 > 권한 설정. 항목마다 '앱에서 사용' 스위치(기기에 저장, 기본 켜짐) + 시스템 권한 상태.
/// 앱으로 돌아올 때마다(onResume) 시스템 권한 상태를 다시 읽는다.
class PermissionScreen extends StatefulWidget {
  final Store store;
  final PermStatus Function() perms;

  /// 메인 상태가 바뀔 때 올라간다 (권한 새로고침 결과가 여기로 들어온다)
  final Listenable changes;
  final Future<void> Function() refresh;

  /// 스위치를 바꾼 뒤 (네이티브 알림·메인 배너 갱신)
  final Future<void> Function() onUsageChanged;

  const PermissionScreen({
    super.key,
    required this.store,
    required this.perms,
    required this.changes,
    required this.refresh,
    required this.onUsageChanged,
  });

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.refresh();
  }

  Future<void> _setListener(bool on) async {
    await widget.store.setUse(listener: on);
    await widget.onUsageChanged();
    if (!mounted) return;
    setState(() {});
    // 시스템 권한이 아직 없으면 안내 화면 → 동의하면 알림 접근 설정 화면
    if (on && !widget.perms().listener) await openNotificationAccessWithDisclosure(context);
  }

  Future<void> _setSms(bool on) async {
    await widget.store.setUse(sms: on);
    await widget.onUsageChanged();
    if (mounted) setState(() {});
  }

  Widget _status(bool granted) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: granted ? const Color(0xFFE6F4EA) : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(granted ? '허용됨' : '꺼짐',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: granted ? const Color(0xFF1E8E3E) : const Color(0xFF80868B))),
      );

  Widget _smallButton(String label, VoidCallback onPressed) => SizedBox(
        height: 30,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 30),
            textStyle: const TextStyle(fontSize: 12),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );

  Widget _card({
    required String title,
    required String desc,
    required bool use,
    required ValueChanged<bool> onUse,
    required bool granted,
    Widget? action,
    Widget? footer,
  }) =>
      Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              const Text('앱에서 사용', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
              Switch(value: use, onChanged: onUse),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368))),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Text('시스템 권한', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              _status(granted),
              const Spacer(),
              ?action,
              const SizedBox(width: 8),
            ]),
            ?footer,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.changes,
        builder: (context, _) {
          final p = widget.perms();
          final s = widget.store;
          final smsGranted = p.sms == true;
          return Scaffold(
            appBar: AppBar(title: const Text('권한 설정')),
            body: ListView(
              padding: EdgeInsets.only(top: 4, bottom: listBottomPad(context)),
              children: [
                _card(
                  title: '알림 감지',
                  desc: '메시지 앱 알림에서 카드 승인 문자를 자동으로 찾아요',
                  use: s.useListener,
                  onUse: _setListener,
                  granted: p.listener,
                  action: _smallButton('설정 열기', () => openNotificationAccessWithDisclosure(context)),
                ),
                if (isFullEdition)
                  _card(
                    title: '문자 읽기',
                    desc: '문자함에서 카드 승인 문자를 읽고, 새 문자를 바로 받아요',
                    use: s.useSms,
                    onUse: _setSms,
                    granted: smsGranted,
                    action: smsGranted
                        ? null
                        : p.smsBlocked
                            ? _smallButton('설정 열기', Native.openAppSettings)
                            : _smallButton('권한 요청', () => requestSmsWithDisclosure(context)),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Text('권한 자체를 끄려면', style: TextStyle(fontSize: 12, color: Color(0xFF80868B))),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          onPressed: Native.openAppSettings,
                          child: const Text('휴대폰 설정 열기'),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}
