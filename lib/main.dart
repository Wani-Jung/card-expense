import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'expense.dart';
import 'native.dart';
import 'sms_parser.dart';

const kCarColor = Color(0xFF2E7D32);
const kOpsColor = Color(0xFFFFC107);
const kOpsText = Color(0xFF4E2A00); // 노랑 위에서 잘 읽히는 진한 갈색

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  runApp(CardExpenseApp(store: store));
}

const kDefaultSender = '1588-1600';

class CardExpenseApp extends StatefulWidget {
  final Store store;
  const CardExpenseApp({super.key, required this.store});

  @override
  State<CardExpenseApp> createState() => _CardExpenseAppState();
}

class _CardExpenseAppState extends State<CardExpenseApp> {
  late String? _digits = widget.store.cardDigits;
  late String? _sender = widget.store.senderNumber;

  Future<void> _saveSettings(String digits, String sender) async {
    await widget.store.setSettings(digits, sender);
    await Native.setSettings(digits, sender);
    setState(() {
      _digits = digits;
      _sender = sender;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '법카 정산',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: kCarColor, useMaterial3: true),
      // v1.0.0 에서 올라온 경우 카드번호만 있으므로 발신번호까지 받는다.
      home: _digits == null || _sender == null
          ? SettingsScreen(initialDigits: _digits, onSaved: _saveSettings)
          : HomeScreen(
              store: widget.store,
              digits: _digits!,
              sender: _sender!,
              onSaveSettings: _saveSettings,
            ),
    );
  }
}

// ------------------------------------------------------------------
// 설정: 카드번호 네자리 + 발신번호
// ------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  final Future<void> Function(String digits, String sender) onSaved;
  final String? initialDigits;
  final String? initialSender;
  const SettingsScreen({super.key, required this.onSaved, this.initialDigits, this.initialSender});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _digits = TextEditingController(text: widget.initialDigits ?? '');
  late final _sender = TextEditingController(text: widget.initialSender ?? kDefaultSender);

  bool get _valid =>
      RegExp(r'^\d{4}$').hasMatch(_digits.text) && normalizeNumber(_sender.text).length >= 7;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 17, fontWeight: FontWeight.bold);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('수신 문자에 적힌 카드번호 네자리를 입력해주세요', style: label),
          const SizedBox(height: 4),
          const Text('예) "NH기업0000승인" 이면 0000', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: _digits,
            autofocus: widget.initialDigits == null,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, letterSpacing: 10),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('카드 승인 문자를 보내는 번호를 입력해주세요', style: label),
          const SizedBox(height: 4),
          const Text('NH농협카드는 보통 1588-1600 이에요', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: _sender,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
            style: const TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _valid
                ? () async {
                    final nav = Navigator.of(context);
                    await widget.onSaved(_digits.text, _sender.text.trim());
                    if (nav.canPop()) nav.pop();
                  }
                : null,
            child: const Text('저장', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------------
// 메인 화면
// ------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final Store store;
  final String digits;
  final String sender;
  final Future<void> Function(String digits, String sender) onSaveSettings;
  const HomeScreen({
    super.key,
    required this.store,
    required this.digits,
    required this.sender,
    required this.onSaveSettings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final List<Expense> _items = widget.store.loadItems();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  PermStatus _perms = const PermStatus();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Native.setHandler((method) async {
      if (method == 'onNewSms') await _drain();
      if (method == 'onShared') await _takeShared();
      if (method == 'permissionsChanged') await _refreshPerms();
    });
    // 네이티브 저장소가 비어 있을 수 있으니 시작할 때마다 맞춰 둔다.
    Native.setSettings(widget.digits, widget.sender);
    _onResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }

  Future<void> _onResume() async {
    await _drain();
    await _takeShared();
    await _refreshPerms();
    await Native.cancelNotifications();
  }

  Future<void> _refreshPerms() async {
    final p = await Native.permissionStatus();
    if (mounted) setState(() => _perms = p);
  }

  /// 알림 감지가 쌓아 둔 문자. 네이티브에서 발신번호/카드번호로 이미 걸렀으므로 카드번호는 다시 보지 않는다.
  Future<void> _drain() async {
    final raws = await Native.drainInbox();
    if (raws.isNotEmpty) await _ingest(raws, requireCard: false);
  }

  Future<void> _takeShared() async {
    final texts = await Native.takeShared();
    if (texts.isNotEmpty) await _addTexts(texts, '공유받은');
  }

  /// 새 문자를 내역에 넣는다. 이미 있는 건은 건너뛴다. 추가된 건수를 돌려준다.
  Future<int> _ingest(List<RawSms> raws, {bool requireCard = true}) async {
    final ids = _items.map((e) => e.id).toSet();
    var added = 0;
    for (final r in raws) {
      final p = parseSms(r.body,
          cardDigits: widget.digits, receivedAt: r.receivedAt, requireCard: requireCard);
      if (p == null || ids.contains(p.id)) continue;
      final e = Expense.fromParsed(p);
      if (e.isCancel) {
        // 같은 가맹점·금액의 분류된 승인 건이 있으면 같은 분류로 자동 처리
        final orig = _items.where((o) =>
            !o.isCancel &&
            o.amount == e.amount &&
            o.merchant == e.merchant &&
            (o.category == kCar || o.category == kOps));
        if (orig.isNotEmpty) e.category = orig.last.category;
      }
      _items.add(e);
      ids.add(e.id);
      added++;
    }
    if (added > 0) {
      await widget.store.saveItems(_items);
      if (mounted) setState(() {});
    }
    return added;
  }

  /// 붙여넣기·공유로 받은 텍스트를 [Web발신] 단위로 나눠 넣고 결과를 알려준다.
  Future<void> _addTexts(List<String> texts, String source) async {
    final now = DateTime.now();
    final messages = texts.expand(splitMessages).toList();
    final ok = messages
        .where((m) => parseSms(m, cardDigits: widget.digits, receivedAt: now) != null)
        .map((m) => RawSms(m, now))
        .toList();
    final added = await _ingest(ok);
    final dup = ok.length - added;
    final failed = messages.length - ok.length;
    if (ok.isEmpty) {
      _toast('카드번호 ${widget.digits} 승인 문자를 찾지 못했어요');
      return;
    }
    _toast([
      '$source 문자 $added건 추가',
      if (dup > 0) '중복 $dup건',
      if (failed > 0) '승인 문자 아님 $failed건',
    ].join(' · '));
  }

  Future<void> _setCategory(Expense e, String? cat) async {
    setState(() => e.category = cat);
    await widget.store.saveItems(_items);
  }

  Future<void> _delete(Expense e) async {
    setState(() => _items.remove(e));
    await widget.store.saveItems(_items);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- 메뉴 동작 ----------------

  Future<void> _paste() async {
    final ctrl = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text?.contains(widget.digits) ?? false) ctrl.text = clip!.text!;
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문자 직접 붙여넣기'),
        content: TextField(
          controller: ctrl,
          maxLines: 10,
          minLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '승인 문자를 붙여넣으세요. 여러 건을 한꺼번에 넣어도 돼요.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('추가')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    await _addTexts([text], '붙여넣은');
  }

  Future<void> _copyMonth() async {
    await Clipboard.setData(ClipboardData(text: settlementText(_items, _month, widget.digits)));
    _toast('${_month.year}년 ${_month.month}월 내역을 복사했어요');
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        initialDigits: widget.digits,
        initialSender: widget.sender,
        onSaved: widget.onSaveSettings,
      ),
    ));
  }

  // ---------------- 화면 ----------------

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((e) => e.category == null).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final monthItems = _items.where((e) => e.inMonth(_month) && e.category != null).toList()
      ..sort((a, b) {
        // 무시한 건은 맨 아래로
        final ia = a.category == kIgnored ? 1 : 0, ib = b.category == kIgnored ? 1 : 0;
        if (ia != ib) return ia - ib;
        return b.dateTime.compareTo(a.dateTime);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('법카 정산 · ${widget.digits}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'paste':
                  _paste();
                case 'copy':
                  _copyMonth();
                case 'listener':
                  Native.openNotificationAccessSettings();
                case 'settings':
                  _openSettings();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'paste', child: Text('문자 직접 붙여넣기')),
              PopupMenuItem(value: 'copy', child: Text('이번 달 내역 복사 (정산용)')),
              PopupMenuItem(value: 'listener', child: Text('알림 접근 설정 열기')),
              PopupMenuItem(value: 'settings', child: Text('설정 (카드번호·발신번호)')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onResume,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: [
            if (!_perms.allOk) _PermissionBanner(perms: _perms),
            if (pending.isNotEmpty) ...[
              _SectionTitle('분류 대기 ${pending.length}건'),
              for (final e in pending)
                _PendingCard(
                  e: e,
                  onCar: () => _setCategory(e, kCar),
                  onOps: () => _setCategory(e, kOps),
                  onIgnore: () => _setCategory(e, kIgnored),
                ),
              const SizedBox(height: 12),
            ],
            _MonthHeader(
              month: _month,
              onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
            _Summary(items: monthItems),
            const SizedBox(height: 8),
            if (monthItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('이 달 분류된 내역이 없어요', style: TextStyle(color: Colors.black45))),
              ),
            for (final e in monthItems) _ExpenseTile(e: e, onTap: () => _editSheet(e)),
          ],
        ),
      ),
    );
  }

  Future<void> _editSheet(Expense e) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${e.merchant} ${won(e.signedAmount)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(fmtDateTime(e.dateTime), style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              _RawBox(e.raw),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _CategoryButton(
                    label: '차량비',
                    bg: kCarColor,
                    fg: Colors.white,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setCategory(e, kCar);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryButton(
                    label: '운영비',
                    bg: kOpsColor,
                    fg: kOpsText,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setCategory(e, kOps);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.undo),
                label: const Text('대기로 되돌리기'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _setCategory(e, null);
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('삭제', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (d) => AlertDialog(
                      title: const Text('이 내역을 삭제할까요?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('삭제')),
                      ],
                    ),
                  );
                  if (ok == true && ctx.mounted) {
                    Navigator.pop(ctx);
                    _delete(e);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// 위젯 조각
// ------------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}

class _PermissionBanner extends StatelessWidget {
  final PermStatus perms;
  const _PermissionBanner({required this.perms});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('승인 문자 자동 감지를 위해 아래를 켜주세요',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('지난 문자는 메시지 앱에서 문자 선택 → 공유 → 법카 정산',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (!perms.notification)
                FilledButton.tonal(onPressed: Native.requestNotificationPermission, child: const Text('알림 권한')),
              if (!perms.listener)
                FilledButton.tonal(
                    onPressed: Native.openNotificationAccessSettings, child: const Text('알림 접근')),
            ]),
            TextButton(
              onPressed: Native.openAppSettings,
              child: const Text('버튼을 눌러도 안 뜨면 → 앱 설정 열기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;
  const _CategoryButton({required this.label, required this.bg, required this.fg, required this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: Text(label),
      );
}

class _RawBox extends StatelessWidget {
  final String raw;
  const _RawBox(this.raw);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(6)),
        child: Text(raw, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      );
}

class _PendingCard extends StatelessWidget {
  final Expense e;
  final VoidCallback onCar, onOps, onIgnore;
  const _PendingCard({required this.e, required this.onCar, required this.onOps, required this.onIgnore});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(e.merchant.isEmpty ? '(가맹점 미상)' : e.merchant,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Text(
                e.isCancel ? '승인취소 ${won(e.signedAmount)}' : won(e.amount),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: e.isCancel ? Colors.red : null),
              ),
            ]),
            Text(fmtDateTime(e.dateTime), style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            _RawBox(e.raw),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _CategoryButton(label: '차량비', bg: kCarColor, fg: Colors.white, onPressed: onCar)),
              const SizedBox(width: 8),
              Expanded(child: _CategoryButton(label: '운영비', bg: kOpsColor, fg: kOpsText, onPressed: onOps)),
              const SizedBox(width: 4),
              TextButton(onPressed: onIgnore, child: const Text('무시')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext;
  const _MonthHeader({required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.arrow_left, size: 36)),
          Text('${month.year}년 ${month.month}월',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(onPressed: onNext, icon: const Icon(Icons.arrow_right, size: 36)),
        ],
      );
}

class _Summary extends StatelessWidget {
  final List<Expense> items;
  const _Summary({required this.items});

  @override
  Widget build(BuildContext context) {
    final car = items.where((e) => e.category == kCar).toList();
    final ops = items.where((e) => e.category == kOps).toList();
    int sum(List<Expense> l) => l.fold(0, (s, e) => s + e.signedAmount);
    Widget box(String label, List<Expense> l, Color bg, Color fg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label ${l.length}건', style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(won(sum(l)),
                      style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
    return Column(children: [
      Row(children: [
        box('차량비', car, kCarColor, Colors.white),
        const SizedBox(width: 8),
        box('운영비', ops, kOpsColor, kOpsText),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          const Text('전체 합계', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(won(sum(car) + sum(ops)), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
      ),
    ]);
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense e;
  final VoidCallback onTap;
  const _ExpenseTile({required this.e, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (e.category) {
      kCar => ('차량', kCarColor, Colors.white),
      kOps => ('운영', kOpsColor, kOpsText),
      _ => ('무시', Colors.black12, Colors.black54),
    };
    final ignored = e.category == kIgnored;
    final d = e.dateTime;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 44,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
      ),
      title: Text(
        e.merchant.isEmpty ? '(가맹점 미상)' : e.merchant,
        style: TextStyle(color: ignored ? Colors.black38 : null),
      ),
      subtitle: Text('${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}'
          '${e.isCancel ? ' · 승인취소' : ''}'),
      trailing: Text(
        won(e.signedAmount),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: ignored ? Colors.black38 : (e.isCancel ? Colors.red : null),
          decoration: ignored ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
