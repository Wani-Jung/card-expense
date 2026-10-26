import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'budget.dart';
import 'expense.dart';
import 'flavor.dart';
import 'native.dart';
import 'paste_screen.dart';
import 'sms_parser.dart';
import 'update_check.dart';

const kCarColor = Color(0xFF2E7D32);
const kOpsColor = Color(0xFFFFC107);
const kOpsText = Color(0xFF4E2A00); // 노랑 위에서 잘 읽히는 진한 갈색
const kOverBg = Color(0xFFFFEBEE);
const kOverText = Color(0xFFC62828);

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
      title: kAppName,
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
          const SizedBox(height: 32),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => Text(
              '$kAppName ${snap.hasData ? 'v${snap.data!.version}' : ''} · $editionLabel',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45),
            ),
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
  late final Budgets _budgets = widget.store.loadBudgets();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  PermStatus _perms = const PermStatus();
  bool _importing = false;

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
    _checkUpdate(manual: false);
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    // (전용판) 설정이 바뀌면 자동 불러오기 표시가 지워져 있으므로 다시 불러온다.
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
    await _takeShared();
    await _refreshPerms();
    await Native.cancelNotifications();
  }

  Future<void> _refreshPerms() async {
    final p = await Native.permissionStatus();
    if (mounted) setState(() => _perms = p);
    await _maybeAutoImport();
  }

  /// 알림 감지·SMS 리시버가 쌓아 둔 문자. 네이티브에서 이미 걸렀으므로 카드번호는 다시 보지 않는다.
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

  /// 공유로 받은 텍스트를 한 건씩 나눠 넣고 결과를 알려준다.
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

  // ---------------- (전용판) 지난 문자 1년치 불러오기 ----------------

  /// 문자 권한이 처음 허용됐거나 설정이 바뀐 뒤면 1년치를 한 번 불러온다.
  Future<void> _maybeAutoImport() async {
    if (!isFullEdition || _perms.sms != true || widget.store.autoImported || _importing) return;
    await _importInbox();
    await widget.store.setAutoImported();
  }

  Future<void> _importInbox() async {
    if (_importing) return;
    if (_perms.sms != true) {
      await Native.requestSmsPermission();
      return; // 허용되면 permissionsChanged → 자동 불러오기
    }
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

  // ---------------- 업데이트 확인 ----------------

  /// 자동 확인은 하루 한 번, 실패하면 조용히 넘어간다. '나중에' 누른 버전은 자동으로는 다시 안 띄운다.
  Future<void> _checkUpdate({required bool manual}) async {
    final store = widget.store;
    if (!manual) {
      final last = store.updateCheckedAt;
      if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) return;
      await store.setUpdateCheckedAt(DateTime.now());
    }
    final current = (await PackageInfo.fromPlatform()).version;
    final latest = await fetchLatestTag();
    if (!mounted) return;
    if (latest == null) {
      if (manual) _toast('업데이트 정보를 확인하지 못했어요. 인터넷 연결을 확인해주세요');
      return;
    }
    if (!isNewerVersion(latest, current)) {
      if (manual) _toast('최신 버전이에요 (v$current · $editionLabel)');
      return;
    }
    if (!manual && store.updateSkippedTag == latest) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('새 버전 $latest가 있어요'),
        content: Text('지금 버전 v$current · $editionLabel\n[업데이트]를 누르면 브라우저에서 APK를 받아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('나중에')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('업데이트')),
        ],
      ),
    );
    if (go == true) {
      await launchUrl(Uri.parse(latestApkUrl), mode: LaunchMode.externalApplication);
    } else if (go == false) {
      await store.setUpdateSkippedTag(latest);
    }
  }

  // ---------------- 메뉴 동작 ----------------

  Future<void> _openPaste() async {
    final added = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => PasteScreen(
        digits: widget.digits,
        existingIds: _items.map((e) => e.id).toSet(),
        onAdd: _ingest,
      ),
    ));
    if (added != null && added > 0) _toast('$added건 추가했어요. 분류해주세요');
  }

  Future<void> _copyMonth() async {
    final text = settlementText(_items, _month, widget.digits, _budgets.forMonth(_month));
    await Clipboard.setData(ClipboardData(text: text));
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

  /// 수립 입력 (만원 단위, 소수점 가능). 빈칸으로 저장하면 지운다.
  Future<void> _editBudget(String label, int? current, void Function(int?) apply) async {
    final ctrl = TextEditingController(text: current == null ? '' : manwon(current));
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_month.month}월 $label 수립'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(
            suffixText: '만원',
            helperText: '예) 34.25 → 342,500원 · 비우면 지워져요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('저장')),
        ],
      ),
    );
    if (input == null) return;
    try {
      final won = parseManwon(input);
      setState(() => apply(won));
      await widget.store.saveBudgets(_budgets);
    } on FormatException catch (e) {
      _toast(e.message);
    }
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
        title: Text('$kAppName · ${widget.digits}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'paste':
                  _openPaste();
                case 'import':
                  _importInbox();
                case 'copy':
                  _copyMonth();
                case 'listener':
                  Native.openNotificationAccessSettings();
                case 'update':
                  _checkUpdate(manual: true);
                case 'settings':
                  _openSettings();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'paste', child: Text('문자 붙여넣기 (여러 건 가능)')),
              if (isFullEdition) const PopupMenuItem(value: 'import', child: Text('지난 문자 1년치 불러오기')),
              const PopupMenuItem(value: 'copy', child: Text('이번 달 내역 복사 (정산용)')),
              const PopupMenuItem(value: 'listener', child: Text('알림 접근 설정 열기')),
              const PopupMenuItem(value: 'update', child: Text('업데이트 확인')),
              const PopupMenuItem(value: 'settings', child: Text('설정 (카드번호·발신번호)')),
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
            _BudgetTable(
              budget: _budgets.forMonth(_month),
              usage: MonthUsage.of(monthItems, _month),
              onEditTotal: () => _editBudget(
                  '합계', _budgets.forMonth(_month).total, (w) => _budgets.setTotal(_month, w)),
              onEditCar: () => _editBudget(
                  '차량비', _budgets.forMonth(_month).car, (w) => _budgets.setCar(_month, w)),
            ),
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
            const Text('지난 문자는 메시지 앱에서 문자 선택 → 공유 → $kAppName',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (perms.sms == false)
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

/// 수립/사용 표 (단위: 만원). 합계·차량비 수립은 터치해서 입력, 운영비 수립은 자동 계산.
class _BudgetTable extends StatelessWidget {
  final MonthBudget budget;
  final MonthUsage usage;
  final VoidCallback onEditTotal, onEditCar;
  const _BudgetTable({
    required this.budget,
    required this.usage,
    required this.onEditTotal,
    required this.onEditCar,
  });

  static const _headerBg = Color(0xFFF2F2F2);

  Widget _cell(String text,
      {Color? bg, Color? fg, bool bold = false, VoidCallback? onTap, bool editable = false}) {
    final child = Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text,
                  style: TextStyle(
                      fontSize: 16, color: fg, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 14, color: Colors.black38),
          ],
        ],
      ),
    );
    return onTap == null ? child : InkWell(onTap: onTap, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final totalOver = isOverBudget(usage.total, budget.total);
    final carOver = isOverBudget(usage.car, budget.car);
    Widget used(int won, bool over) =>
        _cell(manwon(won), bg: over ? kOverBg : null, fg: over ? kOverText : null, bold: over);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4, right: 2),
          child: Text('(단위: 만원)', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        Table(
          border: TableBorder.all(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
          columnWidths: const {0: FlexColumnWidth(1.0), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(1.2)},
          defaultVerticalAlignment: TableCellVerticalAlignment.fill,
          children: [
            TableRow(children: [
              _cell('', bg: _headerBg),
              _cell('수립', bg: _headerBg, bold: true),
              _cell('사용', bg: _headerBg, bold: true),
            ]),
            TableRow(children: [
              _cell('합계', bg: _headerBg, bold: true),
              _cell(manwonOrDash(budget.total), onTap: onEditTotal, editable: true),
              used(usage.total, totalOver),
            ]),
            TableRow(children: [
              _cell('차량비', bg: const Color(0xFFE8F5E9), fg: kCarColor, bold: true),
              _cell(manwonOrDash(budget.car), onTap: onEditCar, editable: true),
              used(usage.car, carOver),
            ]),
            TableRow(children: [
              _cell('운영비', bg: const Color(0xFFFFF8E1), fg: kOpsText, bold: true),
              // 자동 계산. 음수면 입력 오류(차량비 수립 > 합계 수립)
              _cell(manwonOrDash(budget.ops),
                  bg: budget.opsInvalid ? kOverBg : null,
                  fg: budget.opsInvalid ? kOverText : Colors.black54,
                  bold: budget.opsInvalid),
              used(usage.ops, false), // 운영비는 초과 표시 안 함
            ]),
          ],
        ),
        if (budget.opsInvalid)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('차량비 수립이 합계 수립보다 커요', style: TextStyle(fontSize: 12, color: kOverText)),
          ),
      ],
    );
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
