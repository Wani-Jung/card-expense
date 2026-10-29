import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'budget.dart';
import 'quiz.dart';
import 'sms_parser.dart';
import 'vendor.dart';

/// 분류: null 이면 분류 대기.
const kCar = 'car';
const kOps = 'ops';
const kIgnored = 'ignored';

/// 무시 사유: 직접 무시(분류 대기·미분류의 [무시]) / 중복(확인 필요의 [하나 무시])
const kIgnoreManual = 'manual';
const kIgnoreDuplicate = 'duplicate';

/// 무시 사유: 취소로 상쇄 (확인 필요 > 승인 후 취소의 [확인했어요]). 원승인·취소 두 건이 함께
const kIgnoreOffset = 'offset';

class Expense {
  final String id;
  final int amount;
  final DateTime dateTime;
  final String merchant;
  final bool isCancel;
  final String raw;
  String? category;

  /// 무시한 이유 (category == kIgnored 일 때만). null 이면 '직접 무시'로 본다 (예전 데이터 포함).
  String? ignoreReason;

  /// '중복'으로 무시했을 때 남겨 둔 원본 내역 id
  String? dupOf;

  /// '취소로 상쇄'로 무시하기 전 카테고리. [되살리기] 하면 이걸로 돌린다.
  String? ignoredFrom;

  Expense({
    required this.id,
    required this.amount,
    required this.dateTime,
    required this.merchant,
    required this.isCancel,
    required this.raw,
    this.category,
    this.ignoreReason,
    this.dupOf,
    this.ignoredFrom,
  });

  /// 확인 필요 > 중복 의심의 [하나 무시]로 무시한 건
  bool get ignoredAsDuplicate => category == kIgnored && ignoreReason == kIgnoreDuplicate;

  /// 승인 후 취소 묶음을 [확인했어요] 로 함께 무시한 건
  bool get ignoredAsOffset => category == kIgnored && ignoreReason == kIgnoreOffset;

  factory Expense.fromParsed(ParsedSms p) => Expense(
        id: p.id,
        amount: p.amount,
        dateTime: p.dateTime,
        merchant: p.merchant,
        isCancel: p.isCancel,
        raw: p.raw,
      );

  /// 합계에 더할 값. 승인취소는 음수.
  int get signedAmount => isCancel ? -amount : amount;

  bool inMonth(DateTime month) =>
      dateTime.year == month.year && dateTime.month == month.month;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'dateTime': dateTime.toIso8601String(),
        'merchant': merchant,
        'isCancel': isCancel,
        'raw': raw,
        'category': category,
        if (ignoreReason != null) 'ignoreReason': ignoreReason,
        if (dupOf != null) 'dupOf': dupOf,
        if (ignoredFrom != null) 'ignoredFrom': ignoredFrom,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        amount: j['amount'] as int,
        dateTime: DateTime.parse(j['dateTime'] as String),
        merchant: j['merchant'] as String? ?? '',
        isCancel: j['isCancel'] as bool? ?? false,
        raw: j['raw'] as String? ?? '',
        category: j['category'] as String?,
        ignoreReason: j['ignoreReason'] as String?,
        dupOf: j['dupOf'] as String?,
        ignoredFrom: j['ignoredFrom'] as String?,
      );
}

/// v1.5.1 1회 정리: RCS JSON 본문 때문에 가맹점에 붙은 "\r\n", "}}}} 같은 찌꺼기를 지우고
/// 본문을 실제 텍스트로 바꾼다. 분류(차량비·운영비·대기·무시)는 그대로 둔다.
/// 정리 후 같은 승인 건(같은 id)이 둘 이상이면 하나만 남긴다 (분류된 것 > 대기 > 무시 순).
List<Expense> cleanupStoredItems(List<Expense> items) {
  int rank(String? c) => c == kCar || c == kOps ? 0 : (c == null ? 1 : 2);
  final byId = <String, Expense>{};
  for (final e in items) {
    // JSON·리터럴 줄바꿈이 든 본문만 다시 읽는다. 나머지는 가맹점만 정리
    // (캡처 확인 화면에서 손으로 고친 금액·날짜를 덮어쓰지 않도록).
    final dirty = e.raw.trimLeft().startsWith('{') || e.raw.contains(r'\n') || e.raw.contains(r'\r');
    final raw = dirty ? normalizeBody(e.raw) : e.raw;
    // 원래 시각을 기준으로 다시 읽어서 연도는 그대로 유지한다
    final p = dirty ? parseSms(raw, cardDigits: '', receivedAt: e.dateTime, requireCard: false) : null;
    final fixed = Expense(
      id: p?.id ?? e.id,
      amount: p?.amount ?? e.amount,
      dateTime: p?.dateTime ?? e.dateTime,
      merchant: p?.merchant ?? cleanMerchant(e.merchant),
      isCancel: p?.isCancel ?? e.isCancel,
      raw: raw,
      category: e.category,
    );
    final prev = byId[fixed.id];
    if (prev == null || rank(fixed.category) < rank(prev.category)) byId[fixed.id] = fixed;
  }
  return byId.values.toList();
}

class Store {
  static const _kItems = 'expenses_v1';
  static const _kDigits = 'card_digits';
  static const _kSender = 'sender_number';
  static const _kBudgets = 'budgets_v1';
  static const _kAutoImported = 'auto_import_done';
  static const _kUpdateChecked = 'update_checked_at';
  static const _kUpdateSkipped = 'update_skipped_tag';

  final SharedPreferences _prefs;
  Store._(this._prefs);

  static Future<Store> open() async => Store._(await SharedPreferences.getInstance());

  String? get cardDigits => _prefs.getString(_kDigits);
  String? get senderNumber => _prefs.getString(_kSender);

  /// 카드번호·발신번호 저장. 하나라도 바뀌면 (전용판) 1년치 자동 불러오기를 다시 하게 한다.
  Future<void> setSettings(String digits, String sender) async {
    if (digits != cardDigits || sender != senderNumber) await _prefs.remove(_kAutoImported);
    await _prefs.setString(_kDigits, digits);
    await _prefs.setString(_kSender, sender);
  }

  /// (전용판) 현재 설정으로 1년치 자동 불러오기를 했는지.
  bool get autoImported => _prefs.getBool(_kAutoImported) ?? false;
  Future<void> setAutoImported() => _prefs.setBool(_kAutoImported, true);

  /// v1.14 취소·재결제 1회 바로잡기를 했는지
  bool get cancelFixDone => _prefs.getBool('cancel_fix_v1') ?? false;
  Future<void> setCancelFixDone() => _prefs.setBool('cancel_fix_v1', true);

  /// 권한 설정 > '앱에서 사용' 스위치. 기본값은 둘 다 켜짐
  bool get useListener => _prefs.getBool('use_listener_v1') ?? true;
  bool get useSms => _prefs.getBool('use_sms_v1') ?? true;
  Future<void> setUse({bool? listener, bool? sms}) async {
    if (listener != null) await _prefs.setBool('use_listener_v1', listener);
    if (sms != null) await _prefs.setBool('use_sms_v1', sms);
  }

  /// 오늘의 안전 OX 저장 (같은 shared_preferences)
  QuizStore get quiz => QuizStore(_prefs);

  static const _kVendors = 'vendor_book_v1';

  /// 업체 관리. 처음이면 기본 키워드가 들어간 상태로 시작한다.
  /// 기존 기기는 기본 키워드 세트가 새 버전이면 새 기본 키워드를 한 번 추가하고 저장한다.
  VendorBook loadVendors() {
    final s = _prefs.getString(_kVendors);
    if (s == null) return VendorBook.initial();
    final book = VendorBook.fromJson(jsonDecode(s) as Map<String, dynamic>);
    if (book.upgradeDefaults()) saveVendors(book);
    return book;
  }

  Future<void> saveVendors(VendorBook v) => _prefs.setString(_kVendors, jsonEncode(v.toJson()));

  Budgets loadBudgets() {
    final s = _prefs.getString(_kBudgets);
    return s == null ? Budgets({}) : Budgets.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveBudgets(Budgets b) => _prefs.setString(_kBudgets, jsonEncode(b.toJson()));

  /// 업데이트 자동 확인은 하루 한 번.
  DateTime? get updateCheckedAt {
    final ms = _prefs.getInt(_kUpdateChecked);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setUpdateCheckedAt(DateTime t) => _prefs.setInt(_kUpdateChecked, t.millisecondsSinceEpoch);

  /// '나중에'를 누른 버전. 자동 확인에서는 다시 띄우지 않는다.
  String? get updateSkippedTag => _prefs.getString(_kUpdateSkipped);
  Future<void> setUpdateSkippedTag(String tag) => _prefs.setString(_kUpdateSkipped, tag);

  static const _kCheckOk = 'check_ok_v1';
  static const _kCheckBannerClosed = 'check_banner_closed_v1';

  /// 확인 필요 내역에서 [이대로 맞아요] 한 키 (규칙|내역 id). 다시 표시하지 않는다.
  Set<String> get checkOk => (_prefs.getStringList(_kCheckOk) ?? const []).toSet();
  Future<void> addCheckOk(Iterable<String> keys) =>
      _prefs.setStringList(_kCheckOk, {...checkOk, ...keys}.toList());

  /// 메인 '확인이 필요한 내역' 줄을 닫을 때 있던 키. 이 밖의 새 건이 생기면 다시 보인다.
  Set<String> get checkBannerClosed => (_prefs.getStringList(_kCheckBannerClosed) ?? const []).toSet();
  Future<void> setCheckBannerClosed(Iterable<String> keys) =>
      _prefs.setStringList(_kCheckBannerClosed, keys.toList());

  static const _kCleanedV1 = 'merchant_cleanup_v1';

  List<Expense> loadItems() {
    final s = _prefs.getString(_kItems);
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 앱 시작 시 1회: 저장된 내역의 가맹점·본문 찌꺼기 정리 ([cleanupStoredItems]).
  Future<void> migrate() async {
    if (_prefs.getBool(_kCleanedV1) ?? false) return;
    final items = loadItems();
    if (items.isNotEmpty) await saveItems(cleanupStoredItems(items));
    await _prefs.setBool(_kCleanedV1, true);
  }

  Future<void> saveItems(List<Expense> items) =>
      _prefs.setString(_kItems, jsonEncode(items.map((e) => e.toJson()).toList()));
}

String won(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b원';
}

String two(int n) => n.toString().padLeft(2, '0');

String fmtDateTime(DateTime d) =>
    '${d.year}.${two(d.month)}.${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
