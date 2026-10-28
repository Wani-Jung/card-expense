import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'expense.dart';
import 'ingest.dart';
import 'layout.dart';
import 'sms_parser.dart';
import 'vendor.dart';

/// 붙여넣기 결과. Home 이 [report] 의 새 내역을 넣고, [revive] 면 무시했던 문자도 분류 대기로 돌린다.
class PasteResult {
  final IngestReport report;
  final bool revive;
  const PasteResult(this.report, this.revive);
}

/// 문자 붙여넣기 (여러 건 가능).
/// 입력칸은 항상 빈칸으로 열고, 클립보드에 카드 승인 문자가 있으면 위에 미리보기로 보여준다.
class PasteScreen extends StatefulWidget {
  final String digits;

  /// 붙여넣은 텍스트를 한 건씩 나눠 새 내역/중복/무시했던 문자/승인 문자 아님으로 분류한다.
  final IngestReport Function(String text) classify;

  /// 가맹점 이름으로 차량비/운영비 추천.
  final Recommendation? Function(String merchant) recommend;

  const PasteScreen({super.key, required this.digits, required this.classify, required this.recommend});

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

  Future<void> _checkClipboard() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final now = DateTime.now();
    final found = [
      if (text != null)
        for (final m in splitMessages(text)) ?parseSms(m, cardDigits: widget.digits, receivedAt: now),
    ];
    if (!mounted) return;
    setState(() {
      _clipText = found.isEmpty ? null : text;
      _clipFound = found;
    });
  }

  Future<void> _submit(String text) async {
    final r = widget.classify(text);
    if (r.fresh.isEmpty && r.ignoredHits.isEmpty) {
      // 넣을 게 없으면 확인 없이 결과(중복·승인 문자 아님 내용)만 보여준다
      Navigator.pop(context, PasteResult(r, false));
      return;
    }
    var revive = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('분류 대기에 넣을까요?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.total}건 중 새 내역 ${r.fresh.length}건, 중복 ${r.dup}건'
                '${r.ignoredHits.isNotEmpty ? ', 무시했던 문자 ${r.ignoredHits.length}건' : ''}'
                '${r.rejected.isNotEmpty ? ', 승인 문자 아님 ${r.rejected.length}건' : ''}'),
            if (r.ignoredHits.isNotEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: revive,
                onChanged: (v) => setLocal(() => revive = v ?? false),
                title: Text('무시했던 문자 ${r.ignoredHits.length}건도 다시 분류 대기로'),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('넣기')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, PasteResult(r, revive));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문자 붙여넣기')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, listBottomPad(context)),
        children: [
          if (_clipText != null) _ClipPreview(found: _clipFound, recommend: widget.recommend, onUse: () => _submit(_clipText!)),
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

String _recText(Recommendation? r) =>
    r == null ? '' : ' · ${r.source == RecSource.learned ? r.badge : '${categoryLabel(r.category)} 추천'}';

class _ClipPreview extends StatelessWidget {
  final List<ParsedSms> found;
  final Recommendation? Function(String merchant) recommend;
  final VoidCallback onUse;
  const _ClipPreview({required this.found, required this.recommend, required this.onUse});

  @override
  Widget build(BuildContext context) {
    const maxLines = 5;
    return Card(
      color: const Color(0xFFF5F5F5),
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
                ' · ${won(p.isCancel ? -p.amount : p.amount)}'
                '${_recText(recommend(p.merchant))}',
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
