import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'expense.dart';
import 'native.dart';
import 'sms_parser.dart';

/// 문자 붙여넣기 (여러 건 가능).
/// 입력칸은 항상 빈칸으로 열고, 클립보드에 카드 승인 문자가 있으면 위에 미리보기로 보여준다.
class PasteScreen extends StatefulWidget {
  final String digits;
  final Set<String> existingIds;

  /// 문자들을 내역에 넣고 실제로 추가된 건수를 돌려준다.
  final Future<int> Function(List<RawSms>) onAdd;

  const PasteScreen({super.key, required this.digits, required this.existingIds, required this.onAdd});

  @override
  State<PasteScreen> createState() => _PasteScreenState();
}

class _PasteScreenState extends State<PasteScreen> with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  String? _clipText;
  List<ParsedSms> _clipFound = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 메시지 앱에서 복사하고 돌아오면 다시 확인
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  List<(String, ParsedSms)> _analyze(String text) {
    final now = DateTime.now();
    return [
      for (final m in splitMessages(text))
        if (parseSms(m, cardDigits: widget.digits, receivedAt: now) case final p?) (m, p),
    ];
  }

  Future<void> _checkClipboard() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final found = text == null ? <(String, ParsedSms)>[] : _analyze(text);
    if (!mounted) return;
    setState(() {
      _clipText = found.isEmpty ? null : text;
      _clipFound = found.map((f) => f.$2).toList();
    });
  }

  Future<void> _submit(String text) async {
    final found = _analyze(text);
    final messenger = ScaffoldMessenger.of(context);
    if (found.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('카드번호 ${widget.digits} 승인 문자를 찾지 못했어요')));
      return;
    }
    final seen = {...widget.existingIds};
    final fresh = <(String, ParsedSms)>[];
    for (final f in found) {
      if (seen.add(f.$2.id)) fresh.add(f);
    }
    final dup = found.length - fresh.length;
    if (fresh.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('${found.length}건 모두 이미 들어와 있어요')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('분류 대기에 넣을까요?'),
        content: Text('${found.length}건 중 새 내역 ${fresh.length}건'
            '${dup > 0 ? ', 중복 $dup건' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('${fresh.length}건 넣기')),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    final added = await widget.onAdd([for (final f in fresh) RawSms(f.$1, now)]);
    if (mounted) Navigator.pop(context, added);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문자 붙여넣기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_clipText != null) _ClipPreview(found: _clipFound, onUse: () => _submit(_clipText!)),
          const Text(
            '메시지 앱에서 카드 문자를 길게 눌러 여러 개 선택 → 복사 → 여기에 붙여넣으면 한 번에 들어가요',
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '여기에 승인 문자를 붙여넣으세요 (여러 건 가능)',
              hintStyle: TextStyle(color: Colors.black38),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _ctrl.text.trim().isEmpty ? null : () => _submit(_ctrl.text),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _ClipPreview extends StatelessWidget {
  final List<ParsedSms> found;
  final VoidCallback onUse;
  const _ClipPreview({required this.found, required this.onUse});

  @override
  Widget build(BuildContext context) {
    const maxLines = 5;
    return Card(
      color: const Color(0xFFE8F5E9),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('복사된 문자 ${found.length}건 발견', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final p in found.take(maxLines))
              Text(
                '${two(p.dateTime.month)}/${two(p.dateTime.day)} ${two(p.dateTime.hour)}:${two(p.dateTime.minute)}'
                ' · ${p.merchant.isEmpty ? '(가맹점 미상)' : p.merchant}'
                ' · ${won(p.isCancel ? -p.amount : p.amount)}',
                style: const TextStyle(fontSize: 13),
              ),
            if (found.length > maxLines)
              Text('외 ${found.length - maxLines}건', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            FilledButton(onPressed: onUse, child: const Text('이걸로 넣기')),
          ],
        ),
      ),
    );
  }
}
