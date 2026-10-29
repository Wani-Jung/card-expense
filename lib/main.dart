import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'budget.dart';
import 'cancel_link.dart';
import 'category_badge.dart';
import 'check.dart';
import 'expense.dart';
import 'flavor.dart';
import 'ignored_screen.dart';
import 'ingest.dart';
import 'layout.dart';
import 'menu_screen.dart';
import 'native.dart';
import 'ocr_screen.dart';
import 'paste_screen.dart';
import 'permission_screen.dart';
import 'quiz.dart';
import 'quiz_screens.dart';
import 'quiz_sheet.dart';
import 'review_screens.dart';
import 'sms_parser.dart';
import 'update_check.dart';
import 'vendor.dart';
import 'vendor_screen.dart';

const kOverBg = Color(0xFFFFEBEE);
const kOverText = Color(0xFFC62828);
const kGold = Color(0xFFF0A500); // 앱 아이콘 골드 (포인트 컬러)
const kGoldText = Color(0xFF3E2700); // 골드 위 글자
const kGoldLight = Color(0xFFFFF8E6); // 아주 옅은 골드 (권한 배너 등 표 밖)
const kText = Color(0xFF1F1F1F);
const kSubText = Color(0xFF5F6368);
const kLine = Color(0xFFE0E0E0);
const kSubBg = Color(0xFFF5F5F5);

/// 구글 캘린더처럼 하얗고 깨끗한 무채색 테마. 색은 차량비/운영비 버튼과 골드 포인트에만.
ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: kGold,
    onPrimary: kGoldText,
    primaryContainer: kGoldLight,
    onPrimaryContainer: kGoldText,
    secondary: kSubText,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF1F3F4),
    onSecondaryContainer: kText,
    surface: Colors.white,
    onSurface: kText,
    onSurfaceVariant: kSubText,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: Colors.white,
    surfaceContainerHighest: kSubBg,
    surfaceTint: Colors.transparent,
    outline: Color(0xFFBDBDBD),
    outlineVariant: kLine,
    error: kOverText,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kText,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: kLine),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    dividerTheme: const DividerThemeData(color: kLine),
    // 흰 배경 위 골드 글자는 흐려서 글자 버튼은 진한 골드로
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFF8D6200))),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 하단 내비게이션 바 뒤까지 그리고(투명), 목록 끝 여백은 listBottomPad 로 확보한다.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));
  final store = await Store.open();
  await store.migrate();
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

  /// 첫 실행 설정(카드번호 입력)부터 시작했는지. 그날은 퀴즈를 띄우지 않는다.
  late final bool _firstRun = _digits == null || _sender == null;

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
      theme: buildTheme(),
      // v1.0.0 에서 올라온 경우 카드번호만 있으므로 발신번호까지 받는다.
      home: _digits == null || _sender == null
          ? SettingsScreen(initialDigits: _digits, onSaved: _saveSettings)
          : HomeScreen(
              store: widget.store,
              digits: _digits!,
              sender: _sender!,
              onSaveSettings: _saveSettings,
              firstRun: _firstRun,
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
      appBar: AppBar(title: const Text('카드 문자 설정')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, listBottomPad(context)),
        children: [
          const Text('카드번호 네자리', style: label),
          const SizedBox(height: 4),
          const Text('승인 문자에 적힌 카드번호 네자리 (예: "NH기업0000승인" 이면 0000)',
              style: TextStyle(color: Colors.black54)),
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
          Row(children: [
            const Expanded(child: Text('발신번호', style: label)),
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => setState(() => _sender.text = kDefaultSender),
              child: const Text('기본값으로'),
            ),
          ]),
          const Text('카드 승인 문자를 보내는 번호 (기본값 $kDefaultSender)', style: TextStyle(color: Colors.black54)),
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

  /// 첫 실행 설정을 마치고 막 들어왔는지 (그날 퀴즈 건너뜀)
  final bool firstRun;
  const HomeScreen({
    super.key,
    required this.store,
    required this.digits,
    required this.sender,
    required this.onSaveSettings,
    this.firstRun = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final List<Expense> _items = widget.store.loadItems();
  late final Budgets _budgets = widget.store.loadBudgets();
  late final VendorBook _vendors = widget.store.loadVendors();
  PeriodMode _period = PeriodMode.single; // 보기 기간. 앱을 켤 때마다 1개월
  PeriodView _view = PeriodView(DateTime.now()); // 지금 보는 달 (홀짝·짝홀이면 두 달 합산 단계도)
  DateTime get _month => _view.month;

  /// 요약표 전환 방향 (1: 다음 ▶·왼쪽으로 밀기, -1: 이전 ◀·오른쪽으로 밀기, 0: 모드 변경·달 선택)
  int _slideDir = 0;

  /// ◀ ▶ 와 요약표 스와이프 공통: 한 단계 넘기기
  void _step(int dir) => setState(() {
        _slideDir = dir;
        _view = stepView(_view, _period, dir);
      });

  /// 메인 상태가 바뀔 때마다 올라간다. 메뉴에서 연 미분류·확인 필요 화면이 이걸 듣고 다시 그린다.
  final _changes = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _changes.value++;
  }

  /// 확인 필요 내역 (실수 의심 자동 검사)
  List<CheckIssue> get _issues =>
      findIssues(_items, _vendors, now: DateTime.now(), okKeys: widget.store.checkOk);
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
    Native.setUsage(listener: widget.store.useListener, sms: widget.store.useSms);
    _fixCancelsOnce();
    _onResume();
    _checkUpdate(manual: false);
    _scheduleDailyQuiz();
  }

  // ---------------- 오늘의 안전 OX ----------------

  late final QuizStore _quiz = widget.store.quiz;
  QuizBank? _quizBank;
  Timer? _quizTimer;

  /// 열려 있는 퀴즈 시트 (닫히면 null). 자동 업데이트 창은 이게 닫힌 뒤에 띄운다.
  Future<void>? _quizSheet;

  /// 이번에 앱을 연 뒤 다른 팝업(업데이트 창 등)이 먼저 떴는지. 떴으면 그날 퀴즈는 건너뛴다.
  bool _popupShown = false;

  /// 메인이 다 그려진 뒤(첫 프레임 + 300ms) 하루 1회 판정. 앱 시작을 늦추지 않게 문제 파일도 그때 읽는다.
  void _scheduleDailyQuiz() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quizTimer?.cancel();
      _quizTimer = Timer(const Duration(milliseconds: 300), _maybeDailyQuiz);
    });
  }

  Future<QuizBank> _bank() async => _quizBank ??= await _quiz.load();

  Future<void> _maybeDailyQuiz() async {
    if (!mounted || _quizSheet != null) return;
    final bank = await _bank();
    if (!mounted) return;
    final today = quizDay(DateTime.now());
    final d = decideQuiz(
      today: today,
      lastDay: _quiz.lastDay,
      activeCount: bank.active.length,
      // 첫 실행 설정 직후, 다른 팝업이 먼저 떴거나 메인 위에 다른 화면·창이 있으면 그날은 건너뜀
      blocked: widget.firstRun || _popupShown || !(ModalRoute.of(context)?.isCurrent ?? true),
    );
    if (d == QuizDecision.show || d == QuizDecision.skipToday) await _quiz.setLastDay(today);
    if (d == QuizDecision.show) await _openQuiz();
    // 원격 문제 파일은 그 뒤 백그라운드로 (하루 1회, 3초, 실패는 조용히). 테스트에서는 안 함
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_quiz.refresh(bank.version, now: DateTime.now()));
    }
  }

  /// 퀴즈 시트 띄우기 (하루 1회 자동 / 메뉴 '지금 한 문제 풀기')
  Future<void> _openQuiz() async {
    if (_quizSheet != null) return;
    // 오늘 이미 푼 문제(추가 문제·챌린지 포함)는 빼고
    final q = await _quiz.next(await _bank(), exclude: _quiz.solvedOn(quizDay(DateTime.now())));
    if (!mounted) return;
    if (q == null) {
      _toast('풀 수 있는 문제가 없어요');
      return;
    }
    final sheet = showQuizSheet(context, q,
        onAnswer: (c) => _quiz.record(QuizRecord(quizDay(DateTime.now()), q.id, c, c == q.answer,
            src: kQuizDaily, at: DateTime.now().millisecondsSinceEpoch)));
    _quizSheet = sheet;
    await sheet;
    _quizSheet = null;
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
    _quizTimer?.cancel();
    _changes.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
      // 켜 둔 채 날이 바뀐 뒤 다시 열 때도 하루 1회 판정
      _popupShown = false;
      _scheduleDailyQuiz();
    }
  }

  /// v1.14 업데이트 후 1회: 취소 → 재결제가 '중복'으로 잘못 무시된 건 되살리기, 묶인 취소 분류 맞추기
  Future<void> _fixCancelsOnce() async {
    if (widget.store.cancelFixDone) return;
    final n = fixCancelRebuys(_items);
    if (n > 0) await widget.store.saveItems(_items);
    await widget.store.setCancelFixDone();
    if (n == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _toast('취소·재결제 내역 $n건을 바로잡았어요');
    });
  }

  Future<void> _onResume() async {
    await _drain();
    await _takeShared();
    await _refreshPerms();
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

  Map<String, Expense> get _byId => {for (final e in _items) e.id: e};

  IngestReport _classifyRaw(List<RawSms> raws, {bool requireCard = true}) =>
      classifyMessages(raws, digits: widget.digits, existing: _byId, requireCard: requireCard);

  /// 알림 감지 등에서 조용히 들어온 문자. 새 내역만 넣는다.
  Future<int> _ingest(List<RawSms> raws, {bool requireCard = true}) =>
      _addParsed(_classifyRaw(raws, requireCard: requireCard).fresh);

  /// 무시했던 내역을 다시 분류 대기로.
  Future<void> _revive(Iterable<String> ids) async {
    final byId = _byId;
    for (final id in ids) {
      final e = byId[id];
      if (e != null && e.category == kIgnored) _setCategory(e, null);
    }
    await widget.store.saveItems(_items);
    if (mounted) setState(() {});
  }

  /// 결과 알림. 되살릴 문자나 '승인 문자 아님' 조각이 있으면 창으로, 아니면 스낵바로.
  Future<void> _showResult(String source, IngestReport r, int added, {bool revived = false}) async {
    if (!mounted) return;
    final summary = r.summary(added: added, revived: revived);
    final canRevive = r.ignoredHits.isNotEmpty && !revived;
    if (!canRevive && r.rejected.isEmpty) {
      _toast('$source · $summary');
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final revive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$source 결과'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: [
            Text(summary),
            if (r.rejected.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('승인 문자 아님 ${r.rejected.length}건 내용 보기', style: const TextStyle(fontSize: 14)),
                children: [
                  for (final t in r.rejected.take(50))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      color: kSubBg,
                      child: SelectableText(t, style: const TextStyle(fontSize: 12)),
                    ),
                  if (r.rejected.length > 50) Text('외 ${r.rejected.length - 50}건'),
                ],
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('닫기')),
          if (canRevive)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('무시했던 ${r.ignoredHits.length}건 다시 분류 대기로'),
            ),
        ],
      ),
    );
    if (revive == true) {
      await _revive(r.ignoredHits.map((p) => p.id));
      _toast('${r.ignoredHits.length}건을 분류 대기로 되돌렸어요');
    }
  }

  /// 파싱된 문자를 내역에 넣는다. 이미 있는 id 는 건너뛴다. 추가된 건수를 돌려준다.
  Future<int> _addParsed(List<ParsedSms> list) async {
    final ids = _items.map((e) => e.id).toSet();
    final fresh = <String>{};
    var added = 0;
    for (final p in list) {
      if (ids.contains(p.id)) continue;
      final e = Expense.fromParsed(p);
      _items.add(e);
      ids.add(e.id);
      if (e.isCancel) fresh.add(e.id);
      added++;
    }
    // 새 취소가 원승인과 묶이면 원승인 분류를 그대로 따라간다
    if (fresh.isNotEmpty) followOrigins(_items, only: fresh);
    if (added > 0) {
      await widget.store.saveItems(_items);
      if (mounted) setState(() {});
    }
    return added;
  }

  /// 공유로 받은 텍스트를 한 건씩 나눠 넣고 결과를 알려준다.
  Future<void> _addTexts(List<String> texts, String source) async {
    final r = _classifyRaw(splitToRaw(texts, DateTime.now()));
    final added = await _addParsed(r.fresh);
    await _showResult('$source 문자', r, added);
  }

  /// 분류·무시·대기로 되돌리기. 잘못 눌러도 바로 복구할 수 있게 5초 동안 [되돌리기]를 띄운다.
  ///
  /// [askBulk] (분류 대기에서 고를 때): 같은 가맹점의 다른 대기 건이 있으면 함께 정리할지 묻는다.
  /// 차량비/운영비로 고르면 그 가맹점을 '등록 업체'로 기억한다.
  /// [되돌리기] 한 번이면 같이 정리된 건과 등록 업체까지 전부 원래대로.
  ///
  /// 무시하면 사유도 저장한다 ([dupOf] 가 있으면 '중복', 없으면 '직접 무시'). 무시를 풀면 사유를 지운다.
  ///
  /// [bulkIgnored] (무시한 내역에서 고를 때): 일괄 정리에 같은 가맹점의 '직접 무시' 건도 넣는다.
  Future<void> _classify(Expense e, String? cat,
      {bool askBulk = false, bool bulkIgnored = false, String? dupOf}) async {
    if (e.category == cat) return;
    final isChoice = cat == kCar || cat == kOps;
    // 승인취소 묶음은 한 건씩 따로 분류·무시하지 않는다
    final pairs = pairsById(_items);
    List<Expense> withPartners(List<Expense> list) => {
          for (final t in list) ...[t, if (pairs[t.id] != null) pairs[t.id]!.partnerOf(t)],
        }.toList();
    var targets = withPartners([e]);
    if (askBulk && isChoice) {
      final others = sameVendorPending(_items, e, includeIgnored: bulkIgnored);
      if (others.isNotEmpty) {
        final all = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text("'${e.merchant}' ${bulkIgnored ? '무시·대기' : '대기'} 내역 ${others.length}건도 "
                "${categoryLabel(cat!)}로 정리할까요?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('이번 건만')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('모두 정리')),
            ],
          ),
        );
        if (all == null) return; // 창 밖을 눌러 닫으면 아무것도 안 함
        if (all) targets = withPartners([e, ...others]);
      }
    }

    final before = {for (final t in targets) t: (t.category, t.ignoreReason, t.dupOf, t.ignoredFrom)};
    final learns = isChoice && e.merchant.trim().isNotEmpty;
    final learnedBefore = learns ? _vendors.learn(e.merchant, cat!) : null;
    setState(() {
      for (final t in targets) {
        _setCategory(t, cat, dupOf: dupOf);
      }
    });
    await widget.store.saveItems(_items);
    if (learns) await widget.store.saveVendors(_vendors);
    if (!mounted) return;

    final what = switch (cat) {
      kCar => '차량비로 분류했어요',
      kOps => '운영비로 분류했어요',
      kIgnored => '무시했어요',
      _ => '미분류로 되돌렸어요',
    };
    final who = e.merchant.isEmpty ? won(e.signedAmount) : e.merchant;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(targets.length > 1 ? '$who ${targets.length}건 · $what' : '$who · $what'),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () async {
            setState(() {
              before.forEach((t, b) {
                t
                  ..category = b.$1
                  ..ignoreReason = b.$2
                  ..dupOf = b.$3
                  ..ignoredFrom = b.$4;
              });
              if (learns) _vendors.restore(e.merchant, learnedBefore);
            });
            await widget.store.saveItems(_items);
            if (learns) await widget.store.saveVendors(_vendors);
          },
        ),
      ));
  }

  /// 카테고리 바꾸기 + 무시 사유 정리
  void _setCategory(Expense t, String? cat, {String? dupOf}) {
    t.category = cat;
    t.ignoreReason = cat == kIgnored ? (dupOf != null ? kIgnoreDuplicate : kIgnoreManual) : null;
    t.dupOf = cat == kIgnored ? dupOf : null;
    t.ignoredFrom = null;
  }

  /// 승인 후 취소 [확인했어요]: 묶음 두 건을 '취소로 상쇄'로 함께 무시 (합계는 원래 0)
  Future<void> _ignoreOffset(CheckIssue i) async {
    setState(() {
      for (final t in i.group) {
        t
          ..ignoredFrom = t.category
          ..category = kIgnored
          ..ignoreReason = kIgnoreOffset
          ..dupOf = null;
      }
    });
    await widget.store.saveItems(_items);
    _toast('${i.e.merchant.isEmpty ? won(i.e.amount) : i.e.merchant} · 승인·취소 2건을 무시 목록으로 옮겼어요');
  }

  /// 무시한 내역의 되살리기 3종 공통: [targets] 를 분류 대기(= 미분류 내역)로 보내고 사유 필드를 지운다.
  /// [okKeys] (중복 쌍·취소 묶음)는 다시 확인 필요에 안 뜨게 기억 — [되돌리기] 해도 기억은 남는다.
  /// 스낵바 '미분류 내역으로 옮겼어요' + [보기](미분류 내역) + 5초 [되돌리기](원래 무시 상태·사유 그대로).
  Future<void> _reviveToPending(List<Expense> targets, {List<String> okKeys = const []}) async {
    final before = {for (final t in targets) t: (t.category, t.ignoreReason, t.dupOf, t.ignoredFrom)};
    if (okKeys.isNotEmpty) await widget.store.addCheckOk(okKeys);
    setState(() {
      for (final t in targets) {
        _setCategory(t, null);
      }
    });
    await widget.store.saveItems(_items);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Expanded(
            child: Text(targets.length > 1 ? '${targets.length}건을 미분류 내역으로 옮겼어요' : '미분류 내역으로 옮겼어요'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kGold),
            onPressed: () {
              messenger.hideCurrentSnackBar();
              _openUnclassified();
            },
            child: const Text('보기'),
          ),
        ]),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () async {
            setState(() {
              before.forEach((t, b) {
                t
                  ..category = b.$1
                  ..ignoreReason = b.$2
                  ..dupOf = b.$3
                  ..ignoredFrom = b.$4;
              });
            });
            await widget.store.saveItems(_items);
          },
        ),
      ));
  }

  /// 무시한 내역 '취소로 상쇄' [되살리기]: 묶음 두 건을 미분류로. 다시 승인 후 취소에 안 뜨게 기억
  Future<void> _reviveOffset(List<Expense> group) => _reviveToPending(group,
      okKeys: ['${CheckRule.cancelled.name}|${group.map((g) => g.id).join('+')}']);

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
    if (!isFullEdition || !widget.store.useSms || _perms.sms != true || widget.store.autoImported || _importing) {
      return;
    }
    await _importInbox();
    await widget.store.setAutoImported();
  }

  Future<void> _importInbox() async {
    if (_importing) return;
    if (!widget.store.useSms) {
      _toast('권한 설정에서 문자 읽기를 켜주세요');
      return;
    }
    if (_perms.sms != true) {
      await Native.requestSmsPermission();
      return; // 허용되면 permissionsChanged → 자동 불러오기
    }
    _importing = true;
    _toast('최근 1년 문자를 불러오는 중…');
    try {
      final scan = await Native.readSmsInbox(365);
      final r = _classifyRaw(scan.items);
      final added = await _addParsed(r.fresh);
      if (r.fresh.isEmpty && r.ignoredHits.isEmpty) {
        await _showScanResult(scan, r.fresh.length + r.dup + r.ignoredHits.length);
      } else {
        await _showResult('지난 문자 불러오기', r, added);
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
          'SMS ${scan.smsScanned}건, MMS ${scan.mmsScanned}건'
          '${scan.otherScanned > 0 ? ', 기타 저장소 ${scan.otherScanned}건' : ''} 검사\n'
          '발신번호 일치 ${scan.senderMatched}건\n'
          '카드번호 일치 $cardMatched건\n\n'
          '${cardMatched > 0 ? '모두 이미 들어와 있는 내역이에요.' : '카드 문자가 RCS 기업메시지로 왔다면 문자 저장소에 없을 수 있어요. 메뉴에서 문자 캡처화면 업로드로 넣어주세요.'}',
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
    // 퀴즈 시트가 떠 있으면 닫힌 뒤에 (겹쳐 뜨지 않게)
    if (_quizSheet != null) await _quizSheet;
    if (!mounted) return;
    _popupShown = true;
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
    final res = await Navigator.of(context).push<PasteResult>(MaterialPageRoute(
      builder: (_) => PasteScreen(
        digits: widget.digits,
        classify: (text) => _classifyRaw(splitToRaw([text], DateTime.now())),
        recommend: _vendors.recommend,
      ),
    ));
    if (res == null) return;
    final added = await _addParsed(res.report.fresh);
    if (res.revive) await _revive(res.report.ignoredHits.map((p) => p.id));
    await _showResult('붙여넣은 문자', res.report, added, revived: res.revive);
  }

  Future<void> _openOcr() async {
    final res = await Navigator.of(context).push<OcrResult>(MaterialPageRoute(
      builder: (_) => OcrScreen(digits: widget.digits, existing: _byId, recommend: _vendors.recommend),
    ));
    if (res == null) return;
    final added = await _addParsed(res.add);
    if (res.revive.isNotEmpty) await _revive(res.revive);
    _toast([
      '캡처에서 $added건 추가',
      if (res.revive.isNotEmpty) '무시했던 문자 ${res.revive.length}건 되살림',
    ].join(' · '));
  }

  void _openMenu() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MenuScreen(
        onImport: _importInbox,
        onPaste: _openPaste,
        onOcr: _openOcr,
        onVendors: _openVendors,
        importEnabled: () => widget.store.useSms,
        onSettings: _openSettings,
        cardSummary: () => '카드 ${widget.digits} · 발신 ${widget.sender}',
        onPermissions: _openPermissions,
        permSummary: _permSummary,
        quizSummary: () => _quiz.menuText(quizDay(DateTime.now())),
        onQuiz: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => QuizHomeScreen(store: _quiz, bank: _bank),
            )),
        // 메뉴에 그대로 있고, 결과(스낵바·업데이트 창)도 메뉴 위에서
        onUpdate: () => _checkUpdate(manual: true),
        counts: () => (
          pending: _items.where((e) => e.category == null).length,
          check: _issues.length,
          ignored: _items.where((e) => e.category == kIgnored).length,
          confirmed: _items.where((e) => e.category == kCar || e.category == kOps).length,
        ),
        onUnclassified: _openUnclassified,
        onCheck: _openCheck,
        onIgnored: _openIgnored,
        onConfirmed: _openConfirmed,
      ),
    ));
  }

  Widget _smallButton(String cat, Recommendation? rec, VoidCallback onPressed, {String? label}) =>
      _CategoryButton.of(cat, rec, onPressed, small: true, label: label);

  /// 메뉴 > 미분류 내역. 메인 분류 대기와 같은 동작 (같은 업체 일괄 정리 팝업·되돌리기 포함).
  Future<void> _openUnclassified() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UnclassifiedScreen(
          items: _items,
          changes: _changes,
          recommend: _vendors.recommend,
          onClassify: (e, cat) => _classify(e, cat, askBulk: cat != kIgnored),
          button: _smallButton,
        ),
      ));

  /// 메뉴 > 확인 필요 내역.
  Future<void> _openCheck() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CheckScreen(
          issues: () => _issues,
          changes: _changes,
          onChange: (e, cat) => _classify(e, cat),
          onIgnoreDuplicate: (e, original) => _classify(e, kIgnored, dupOf: original.id),
          onConfirmCancel: _ignoreOffset,
          onOk: (i) async {
            // 중복 의심은 묶음 안 쌍을 전부 맞다고 기억
            await widget.store.addCheckOk(okKeysFor(i));
            if (mounted) setState(() {});
          },
          button: _smallButton,
        ),
      ));

  /// 메뉴 > 무시한 내역. 되살리면 메인 목록에도 바로 반영된다.
  Future<void> _openIgnored() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => IgnoredScreen(
        items: _items,
        recommend: _vendors.recommend,
        changes: _changes,
        // 메인 분류 대기와 같은 동작: 같은 업체 일괄 정리(직접 무시 건 포함)·등록 업체 기억·묶음 짝·되돌리기
        onChange: (e, cat) => _classify(e, cat, askBulk: cat != null, bulkIgnored: true),
        onReviveOffset: _reviveOffset,
        // [대기로 되돌리기]: 미분류로 (승인취소 묶음이면 짝도 같이)
        onRevive: (e) {
          final p = pairsById(_items)[e.id];
          final partner = p?.partnerOf(e);
          return _reviveToPending([e, if (partner != null && partner.category == kIgnored) partner]);
        },
        // [중복 아님 · 되살리기]: 미분류로, 그 쌍은 다시 중복 의심에 안 뜨게
        onReviveDuplicate: (e) =>
            _reviveToPending([e], okKeys: [if (e.dupOf != null) dupPairKey(e.id, e.dupOf!)]),
        carButton: (rec, onPressed) => _CategoryButton.of(kCar, rec, onPressed, small: true),
        opsButton: (rec, onPressed) => _CategoryButton.of(kOps, rec, onPressed, small: true),
      ),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _openVendors() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VendorScreen(
        book: _vendors,
        onChanged: () async {
          await widget.store.saveVendors(_vendors);
          if (mounted) setState(() {});
        },
      ),
    ));

  /// 메뉴 > 내역 관리 > 확인한 내역. 누르면 메인과 같은 편집 시트 (분류 변경·무시·미분류로, 묶음 짝까지)
  Future<void> _openConfirmed() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ConfirmedScreen(items: _items, changes: _changes, onTap: _editSheet),
      ));

  /// 메뉴 > 권한 설정
  Future<void> _openPermissions() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PermissionScreen(
          store: widget.store,
          perms: () => _perms,
          changes: _changes,
          refresh: _refreshPerms,
          onUsageChanged: () async {
            await Native.setUsage(listener: widget.store.useListener, sms: widget.store.useSms);
            if (mounted) setState(() {});
            await _maybeAutoImport();
          },
        ),
      ));

  /// 메뉴 '권한 설정' 설명: "알림 감지 켜짐 · 문자 읽기 켜짐"
  String _permSummary() {
    String part(String name, bool use, bool granted) => use ? (granted ? '$name 켜짐' : '$name 권한 필요') : '$name 꺼짐';
    return [
      part('알림 감지', widget.store.useListener, _perms.listener),
      if (isFullEdition) part('문자 읽기', widget.store.useSms, _perms.sms == true),
    ].join(' · ');
  }

  /// 메인 권한 배너: '앱에서 사용'이 켜져 있는데 시스템 권한이 꺼진 것만
  bool get _needListener => widget.store.useListener && !_perms.listener;
  bool get _needSms => isFullEdition && widget.store.useSms && _perms.sms == false;

  Future<void> _openSettings() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        initialDigits: widget.digits,
        initialSender: widget.sender,
        onSaved: widget.onSaveSettings,
      ),
    ));

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
    // 월 화면이면 그 달, 합산 화면이면 두 달 (표·내역 모두)
    final months = _view.months(_period);
    final combined = months.length > 1;
    final monthItems = _items
        .where((e) => months.any(e.inMonth) && (e.category == kCar || e.category == kOps))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final period = PeriodSummary.of(_budgets, _items, months);
    // 확인 필요 한 줄: 닫은 뒤에는 새 건이 생겼을 때만 다시
    final issues = _issues;
    final closed = widget.store.checkBannerClosed;
    final showCheck = issues.any((i) => !closed.contains(i.key));

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text.rich(TextSpan(children: [
          const TextSpan(text: kAppName),
          TextSpan(
            text: '  ${widget.digits}',
            style: const TextStyle(
                fontSize: 13, fontFamily: 'monospace', color: Colors.black45, fontWeight: FontWeight.normal),
          ),
        ])),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: '메뉴', onPressed: _openMenu),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onResume,
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, 8, 12, listBottomPad(context)),
          children: [
            if (_needListener || _needSms) _PermissionBanner(listener: _needListener, sms: _needSms),
            if (pending.isNotEmpty) ...[
              _SectionTitle('분류 대기 ${pending.length}건'),
              for (final e in pending)
                _PendingCard(
                  e: e,
                  rec: _vendors.recommend(e.merchant),
                  onCar: () => _classify(e, kCar, askBulk: true),
                  onOps: () => _classify(e, kOps, askBulk: true),
                  onIgnore: () => _classify(e, kIgnored),
                ),
              const SizedBox(height: 12),
            ],
            if (showCheck)
              _CheckBanner(
                count: issues.length,
                onOpen: _openCheck,
                onClose: () async {
                  await widget.store.setCheckBannerClosed(issues.map((i) => i.key));
                  setState(() {});
                },
              ),
            _MonthStrip(
              year: _month.year,
              selected: months,
              pair: _period == PeriodMode.single ? const [] : periodMonths(_month, _period),
              // 숫자를 누르면 그 달의 월 화면으로
              onPick: (m) => setState(() {
                _slideDir = 0;
                _view = PeriodView(DateTime(_month.year, m));
              }),
            ),
            _MonthHeader(
              title: _view.title(_period),
              onPrev: () => _step(-1),
              onNext: () => _step(1),
            ),
            // 표를 왼쪽으로 밀면 ▶, 오른쪽으로 밀면 ◀ 와 같다. 수립 칸 터치·보기 선택은 그대로
            _SwipeArea(
              onSwipe: _step,
              child: _SlideSwitcher(
                dir: _slideDir,
                childKey: '${_period.name}|${_view.title(_period)}',
                child: _BudgetTable(
              budget: period.budget,
              usage: period.usage,
              mode: _period,
              modeLabel: periodModeShort(_period),
              // 모드를 바꾸면 보고 있던 달의 월 화면부터
              onMode: (m) => setState(() {
                _slideDir = 0;
                _period = m;
                _view = PeriodView(_view.month);
              }),
              // 수립은 각 달 화면에서만 입력 (합산 화면은 연필도 숨김)
              onEditTotal: combined
                  ? null
                  : () => _editBudget(
                      '합계', _budgets.forMonth(_month).total, (w) => _budgets.setTotal(_month, w)),
              onEditCar: combined
                  ? null
                  : () => _editBudget(
                      '차량비', _budgets.forMonth(_month).car, (w) => _budgets.setCar(_month, w)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (monthItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text(combined ? '이 기간 분류된 내역이 없어요' : '이 달 분류된 내역이 없어요',
                        style: const TextStyle(color: Colors.black45))),
              ),
            for (final (i, e) in monthItems.indexed) ...[
              // 합산 화면: 달이 바뀌는 지점에 작은 구분선
              if (combined && (i == 0 || monthItems[i - 1].dateTime.month != e.dateTime.month))
                _MonthDivider(e.dateTime.month),
              _ExpenseTile(e: e, onTap: () => _editSheet(e)),
            ],
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
                      _classify(e, kCar);
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
                      _classify(e, kOps);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.undo),
                    label: const Text('미분류로 되돌리기'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _classify(e, null);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('무시'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _classify(e, kIgnored);
                    },
                  ),
                ),
              ]),
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
  /// 켜야 하는 것
  final bool listener, sms;
  const _PermissionBanner({required this.listener, required this.sms});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kGoldLight,
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
              if (sms) FilledButton.tonal(onPressed: Native.requestSmsPermission, child: const Text('문자 권한')),
              if (listener)
                FilledButton.tonal(
                    onPressed: Native.openNotificationAccessSettings, child: const Text('알림 접근 켜기')),
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

/// 차량비/운영비 버튼. 추천이 있으면 추천 버튼에 작은 표시([badge])를 달고, 반대 버튼은 연하게([dim]).
/// 연한 버튼도 누르는 건 그대로 된다.
class _CategoryButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;
  final bool dim;
  final String? badge;
  final bool small;
  const _CategoryButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onPressed,
    this.dim = false,
    this.badge,
    this.small = false,
  });

  /// [rec] 기준으로 [category] 버튼을 만든다.
  factory _CategoryButton.of(String category, Recommendation? rec, VoidCallback onPressed,
      {bool small = false, String? label}) {
    final car = category == kCar;
    return _CategoryButton(
      label: label ?? categoryLabel(category),
      bg: car ? kCarColor : kOpsColor,
      fg: car ? Colors.white : kOpsText,
      onPressed: onPressed,
      dim: rec != null && rec.category != category,
      badge: rec != null && rec.category == category ? rec.badge : null,
      small: small,
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: dim ? 0.4 : 1,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: dim ? 0 : null,
          minimumSize: small ? const Size(0, 30) : const Size.fromHeight(52),
          padding: small ? const EdgeInsets.symmetric(horizontal: 10) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 4 : 6)),
          textStyle: TextStyle(fontSize: small ? 12 : 18, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        child: small && badge != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: Text(badge!,
                      style: TextStyle(
                          fontSize: 10, color: bg == kOpsColor ? kOpsText : bg, fontWeight: FontWeight.bold)),
                ),
              ])
            : Text(label),
      ),
    );
    if (badge == null || small) return button;
    final badgeColor = bg == kOpsColor ? kOpsText : bg;
    return Stack(
      clipBehavior: Clip.none,
      fit: small ? StackFit.loose : StackFit.passthrough,
      children: [
        button,
        Positioned(
          top: small ? -9 : -10,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: badgeColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badge!, style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _RawBox extends StatelessWidget {
  final String raw;
  const _RawBox(this.raw);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: kSubBg, borderRadius: BorderRadius.circular(6)),
        child: Text(raw, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      );
}

class _PendingCard extends StatelessWidget {
  final Expense e;
  final Recommendation? rec;
  final VoidCallback onCar, onOps, onIgnore;
  const _PendingCard({
    required this.e,
    required this.rec,
    required this.onCar,
    required this.onOps,
    required this.onIgnore,
  });

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
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _CategoryButton.of(kCar, rec, onCar)),
              const SizedBox(width: 8),
              Expanded(child: _CategoryButton.of(kOps, rec, onOps)),
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
  final String title;
  final VoidCallback onPrev, onNext;
  const _MonthHeader({required this.title, required this.onPrev, required this.onNext});

  /// ◀ ▶ 는 좌우 끝 고정(48×48). 제목 길이가 바뀌어도 화살표는 안 움직이고, 길면 글자만 줄어든다.
  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, VoidCallback onPressed, String tip) => SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: tip,
            onPressed: onPressed,
            icon: Icon(icon, size: 36),
          ),
        );
    return Row(children: [
      arrow(Icons.arrow_left, onPrev, '이전'),
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title,
                maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      arrow(Icons.arrow_right, onNext, '다음'),
    ]);
  }
}

/// 요약표 좌우 스와이프. 가로로 충분히(60px 이상 또는 빠른 플릭) 밀었고
/// 가로 움직임이 세로보다 확실히 클 때만 [onSwipe] (왼쪽으로 밀면 1, 오른쪽이면 -1).
/// 제스처 경쟁에 끼지 않는 Listener 라 표 안의 탭(수립 편집·보기 선택)과 목록 세로 스크롤은 그대로.
class _SwipeArea extends StatefulWidget {
  final void Function(int dir) onSwipe;
  final Widget child;
  const _SwipeArea({required this.onSwipe, required this.child});

  @override
  State<_SwipeArea> createState() => _SwipeAreaState();
}

class _SwipeAreaState extends State<_SwipeArea> {
  int? _pointer;
  Offset _start = Offset.zero;
  Duration _startAt = Duration.zero;

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final d = e.position - _start;
    final dt = (e.timeStamp - _startAt).inMicroseconds / 1e6;
    final speed = dt > 0 ? d.dx.abs() / dt : 0;
    final horizontal = d.dx.abs() > d.dy.abs() * 2;
    final far = d.dx.abs() >= 60;
    final flick = d.dx.abs() >= 24 && speed >= 600;
    if (horizontal && (far || flick)) widget.onSwipe(d.dx < 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          _start = e.position;
          _startAt = e.timeStamp;
        },
        onPointerUp: _up,
        onPointerCancel: (e) {
          if (e.pointer == _pointer) _pointer = null;
        },
        child: widget.child,
      );
}

/// 요약표 넘김 전환: 밀린 방향으로 짧게(200ms) 슬라이드. [dir] 0 이면 페이드만.
class _SlideSwitcher extends StatelessWidget {
  final int dir;
  final String childKey;
  final Widget child;
  const _SlideSwitcher({required this.dir, required this.childKey, required this.child});

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(childKey);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (c, anim) {
          // 들어오는 표는 미는 방향 반대편에서, 나가는 표는 미는 방향으로
          final incoming = c.key == key;
          final from = Offset((incoming ? 0.35 : -0.35) * dir, 0);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(anim), child: c),
          );
        },
        child: KeyedSubtree(key: key, child: child),
      ),
    );
  }
}

/// 메인 표 위 작은 한 줄 "확인이 필요한 내역 N건 ›" (닫기 가능)
class _CheckBanner extends StatelessWidget {
  final int count;
  final VoidCallback onOpen, onClose;
  const _CheckBanner({required this.count, required this.onOpen, required this.onClose});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          color: kSubBg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onOpen,
            child: Row(children: [
              const SizedBox(width: 12),
              const Icon(Icons.error_outline, size: 16, color: kOverText),
              const SizedBox(width: 6),
              Expanded(
                child: Text('확인이 필요한 내역 $count건 ›',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
              ),
              IconButton(
                tooltip: '닫기',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16, color: kSubText),
                onPressed: onClose,
              ),
            ]),
          ),
        ),
      );
}

/// 월 진행 표시줄 (1~12). 보는 달은 골드 동그라미, 홀짝·짝홀 묶음은 연회색 캡슐,
/// 오늘이 속한 실제 이번 달은 숫자 아래 점, 지난 달은 진한 회색·안 온 달은 연한 회색.
class _MonthStrip extends StatelessWidget {
  final int year;
  final List<DateTime> selected; // 골드 동그라미 (합산 화면이면 두 달)
  final List<DateTime> pair; // 연회색 캡슐 (홀짝·짝홀 묶음)
  final ValueChanged<int> onPick;
  const _MonthStrip({required this.year, required this.selected, required this.pair, required this.onPick});

  static const _capsule = Color(0xFFEDEDED);
  static const _future = Color(0xFFBDBDBD);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    bool inYear(DateTime d, int m) => d.year == year && d.month == m;
    final inPair = [for (var m = 1; m <= 12; m++) pair.any((d) => inYear(d, m))];

    Widget cell(int m) {
      final isSel = selected.any((d) => inYear(d, m));
      final isNow = now.year == year && now.month == m;
      final past = year < now.year || (year == now.year && m <= now.month);
      // 캡슐: 묶음 안에서 왼쪽 끝·오른쪽 끝만 둥글게 (연도를 넘는 묶음은 이 해에 한 달만 보이므로 양쪽 둥글게)
      BorderRadius? radius;
      if (inPair[m - 1]) {
        final left = m == 1 || !inPair[m - 2];
        final right = m == 12 || !inPair[m];
        radius = BorderRadius.horizontal(
          left: left ? const Radius.circular(15) : Radius.zero,
          right: right ? const Radius.circular(15) : Radius.zero,
        );
      }
      return Expanded(
        child: InkWell(
          onTap: () => onPick(m),
          customBorder: const CircleBorder(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 30,
              decoration: radius == null ? null : BoxDecoration(color: _capsule, borderRadius: radius),
              alignment: Alignment.center,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: isSel ? const BoxDecoration(color: kGold, shape: BoxShape.circle) : null,
                child: Text(
                  '$m',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : (past ? kSubText : _future),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: isNow ? kSubText : null, shape: BoxShape.circle),
            ),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [for (var m = 1; m <= 12; m++) cell(m)]),
    );
  }
}

/// 합산 화면 내역 목록에서 달이 바뀌는 지점의 작은 구분선.
class _MonthDivider extends StatelessWidget {
  final int month;
  const _MonthDivider(this.month);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
        child: Row(children: [
          Text('$month월', style: const TextStyle(fontSize: 12, color: kSubText, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
        ]),
      );
}

/// 수립/사용/잔여 표 (단위: 만원, 참고용). 합계·차량비 수립은 터치해서 입력(연필 표시), 운영비 수립은 자동 계산.
/// 합계·차량비는 여유/주의(80%~)/초과 3단계로 색을 바꾸고, 운영비는 경고 없이 계획보다 더 썼을 때만 작게 알린다.
class _BudgetTable extends StatelessWidget {
  final MonthBudget budget;
  final MonthUsage usage;
  final PeriodMode mode;
  final String modeLabel;
  final ValueChanged<PeriodMode> onMode;
  final VoidCallback? onEditTotal, onEditCar; // null 이면 편집 불가 (합산 화면)
  const _BudgetTable({
    required this.budget,
    required this.usage,
    required this.mode,
    required this.modeLabel,
    required this.onMode,
    required this.onEditTotal,
    required this.onEditCar,
  });

  // 표 안에서는 초록=차량비, 노랑=운영비 전용. 잔여 열은 네이비 계열, 경고는 빨강 하나.
  static const _opsTitleText = Color(0xFF3E2C00);
  static const _navy = Color(0xFF1F3A68);
  static const _remainHeadBg = Color(0xFFE3E9F3);
  static const _remainBg = Color(0xFFF1F4F9);
  static const _red = Color(0xFFD93025);

  /// 표 칸. 높이를 고정해 둬야 행이 접히지 않는다. 수립 칸은 [onTap] 으로 터치 입력.
  Widget _cell(String text, {Color? bg, Color? fg, bool bold = false, double size = 16, VoidCallback? onTap}) {
    Widget child = Container(
      color: bg,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text,
            style: TextStyle(
                fontSize: size, color: fg ?? kText, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
      ),
    );
    if (onTap == null) return child;
    // 숫자는 가운데 그대로, 연필은 칸 오른쪽 아래 구석에 겹쳐 둔다.
    child = Stack(children: [
      child,
      const Positioned(right: 3, bottom: 3, child: Icon(Icons.edit, size: 13, color: Colors.black38)),
    ]);
    return InkWell(onTap: onTap, child: child);
  }

  /// 합계·차량비 잔여 칸. 가장 눈에 띄게. 주의는 숫자만 빨강, 초과는 빨간 칸에 흰 글씨.
  Widget _remain(int? plan, int used) {
    final level = budgetLevel(used, plan);
    return _cell(
      remainingText(remaining(plan, used)),
      bg: level == BudgetLevel.over ? _red : _remainBg,
      fg: switch (level) {
        BudgetLevel.ok => _navy,
        BudgetLevel.warn => _red,
        BudgetLevel.over => Colors.white,
      },
      bold: true,
      size: 18,
    );
  }

  Widget _modeButton(BuildContext context) => PopupMenuButton<PeriodMode>(
        initialValue: mode,
        onSelected: onMode,
        tooltip: '보기 기간',
        position: PopupMenuPosition.under,
        itemBuilder: (_) => [
          for (final m in PeriodMode.values)
            PopupMenuItem(
              value: m,
              height: 40,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 24, child: m == mode ? const Icon(Icons.check, size: 18) : null),
                Flexible(
                  child: Text(periodModeLabel(m),
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                ),
              ]),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text('$modeLabel ▾',
              style: const TextStyle(fontSize: 13, color: kText, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // 사용 칸은 초과일 때만 빨간 글씨 (주의 단계 색 없음)
    Widget used(int won, int? plan) => _cell(manwon(won), fg: isOverBudget(won, plan) ? _red : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('(단위: 만원)', style: TextStyle(fontSize: 12, color: kSubText)),
          const SizedBox(width: 4),
          _modeButton(context),
        ]),
        const SizedBox(height: 2),
        Table(
          border: TableBorder.all(color: kLine, borderRadius: BorderRadius.circular(6)),
          columnWidths: const {
            0: FlexColumnWidth(1.0),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.1),
            3: FlexColumnWidth(1.4),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              _cell('', bg: kSubBg),
              _cell('수립', bg: kSubBg, bold: true),
              _cell('사용', bg: kSubBg, bold: true),
              _cell('잔여', bg: _remainHeadBg, fg: _navy, bold: true),
            ]),
            TableRow(children: [
              _cell('합계', bg: kSubBg, bold: true),
              _cell(manwonOrDash(budget.total), onTap: onEditTotal),
              used(usage.total, budget.total),
              _remain(budget.total, usage.total),
            ]),
            TableRow(children: [
              _cell('차량비', bg: kCarColor, fg: Colors.white, bold: true),
              _cell(manwonOrDash(budget.car), onTap: onEditCar),
              used(usage.car, budget.car),
              _remain(budget.car, usage.car),
            ]),
            TableRow(children: [
              _cell('운영비', bg: kOpsColor, fg: _opsTitleText, bold: true),
              // 자동 계산. 음수면 입력 오류(차량비 수립 > 합계 수립)
              _cell(manwonOrDash(budget.ops),
                  bg: budget.opsInvalid ? kOverBg : null,
                  fg: budget.opsInvalid ? kOverText : kSubText,
                  bold: budget.opsInvalid),
              _cell(manwon(usage.ops)), // 운영비는 항상 기본색
              _cell('', bg: Colors.white), // 운영비 잔여는 항상 빈 흰 칸
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
    final ignored = e.category == kIgnored;
    final d = e.dateTime;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CategoryBadge(e.category),
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
