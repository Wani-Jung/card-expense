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
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Native.setHandler((method) async {
      if (method == 'onNewSms') await _drain();
      if (method == 'permissionsChanged') await _refreshPerms();
    });
    // 네이티브 저장소가 비어 있을 수 있으니 시작할 때마다 맞춰 둔다.
    Native.setSettings(widget.digits, widget.sender);
    _onResume();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    // 설정이 바뀌면 store 의 자동 불러오기 표시가 지워져 있으므로 다시 불러온다.
    if (old.digits != widget.digits || old.sender != widget.sender) _maybeAutoImport();
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
    await _refreshPerms();
    await Native.cancelNotifications();
  }

  Future<void> _refreshPerms() async {
    final p = await Native.permissionStatus();
    if (mounted) setState(() => _perms = p);
    await _maybeAutoImport();
  }

  /// 문자 권한이 처음 허용됐거나 설정이 바뀐 뒤면 1년치를 한 번 불러온다.
  Future<void> _maybeAutoImport() async {
    if (!_perms.sms || widget.store.autoImported || _importing) return;
    await _importInbox();
    await widget.store.setAutoImported();
  }

  Future<void> _drain() async {
    final raws = await Native.drainInbox();
    if (raws.isNotEmpty) await _ingest(raws);
  }

  /// 새 문자를 내역에 넣는다. 이미 있는 건은 건너뛴다. 추가된 건수를 돌려준다.
  Future<int> _ingest(List<RawSms> raws) async {
    final ids = _items.map((e) => e.id).toSet();
    var added = 0;
    for (final r in raws) {
      final p = parseSms(r.body, cardDigits: widget.digits, receivedAt: r.receivedAt);
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

  Future<void> _importInbox() async {
    if (_importing) return;
    _importing = true;
    _toast('최근 1년 문자를 불러오는 중…');
    try {
      final scan = await Native.readSmsInbox(365);
      final cardMatched = scan.items
          .where((r) => parseSms(r.body, cardDigits: widget.digits, receivedAt: r.receivedAt) != null)
          .length;
      final n = await _ingest(scan.items);
      if (n > 0) {
        _toast('$n건 불러왔어요. 분류 대기 목록에서 골라주세요');
      } else {
        await _showScanResult(scan, cardMatched);
      }
    } on PlatformException catch (e) {
      _toast(e.code == 'NO_PERMISSION' ? '문자 권한을 먼저 허용해주세요' : '불러오기 실패: ${e.message}');
    } finally {
      _importing = false;
    }
  }

  /// 0건일 때 어디서 걸렸는지 보여준다.
  Future<void> _showScanResult(InboxScan scan, int cardMatched) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새로 불러온 문자가 없어요'),
        content: Text(
          'SMS ${scan.smsScanned}건 · MMS ${scan.mmsScanned}건 검사\n'
          '발신번호(${widget.sender}) 일치 ${scan.items.length}건\n'
          '카드번호(${widget.digits}) 일치 $cardMatched건\n\n'
          '${cardMatched > 0 ? '모두 이미 들어와 있는 내역이에요.' : '설정의 카드번호·발신번호를 확인해주세요.'}',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
      ),
    );
  }

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
          maxLines: 8,
          minLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '승인 문자 내용을 붙여넣으세요'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('추가')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    if (parseSms(text, cardDigits: widget.digits) == null) {
      _toast('카드번호 ${widget.digits} 승인 문자로 읽을 수 없어요');
      return;
    }
    final n = await _ingest([RawSms(text, DateTime.now())]);
    _toast(n == 0 ? '이미 있는 내역이에요' : '추가했어요. 분류해주세요');
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
                case 'import':
                  _importInbox();
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
              PopupMenuItem(value: 'import', child: Text('문자함에서 최근 1년 불러오기')),
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
            const Text('문자 자동 감지를 위해 아래 권한을 켜주세요',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (!perms.sms)
                FilledButton.tonal(onPressed: Native.requestSmsPermission, child: const Text('문자 권한')),
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
