import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sms_parser.dart';

/// 분류: null 이면 분류 대기.
const kCar = 'car';
const kOps = 'ops';
const kIgnored = 'ignored';

class Expense {
  final String id;
  final int amount;
  final DateTime dateTime;
  final String merchant;
  final bool isCancel;
  final String raw;
  String? category;

  Expense({
    required this.id,
    required this.amount,
    required this.dateTime,
    required this.merchant,
    required this.isCancel,
    required this.raw,
    this.category,
  });

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
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        amount: j['amount'] as int,
        dateTime: DateTime.parse(j['dateTime'] as String),
        merchant: j['merchant'] as String? ?? '',
        isCancel: j['isCancel'] as bool? ?? false,
        raw: j['raw'] as String? ?? '',
        category: j['category'] as String?,
      );
}

class Store {
  static const _kItems = 'expenses_v1';
  static const _kDigits = 'card_digits';

  final SharedPreferences _prefs;
  Store._(this._prefs);

  static Future<Store> open() async => Store._(await SharedPreferences.getInstance());

  String? get cardDigits => _prefs.getString(_kDigits);
  Future<void> setCardDigits(String v) => _prefs.setString(_kDigits, v);

  List<Expense> loadItems() {
    final s = _prefs.getString(_kItems);
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
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

/// 정산용 텍스트. 화면에서 보고 있는 달 기준.
String settlementText(List<Expense> items, DateTime month, String digits) {
  final inMonth = items.where((e) => e.inMonth(month)).toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final b = StringBuffer('[${month.year}년 ${month.month}월 법카 정산] NH기업$digits\n');
  var total = 0;
  for (final (cat, label) in [(kCar, '차량비'), (kOps, '운영비')]) {
    final list = inMonth.where((e) => e.category == cat).toList();
    final sum = list.fold<int>(0, (s, e) => s + e.signedAmount);
    total += sum;
    b.writeln();
    b.writeln('■ $label ${list.length}건 / ${won(sum)}');
    for (final e in list) {
      final d = e.dateTime;
      b.writeln(' ${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)} '
          '${e.merchant}${e.isCancel ? ' (승인취소)' : ''} ${won(e.signedAmount)}');
    }
  }
  b.writeln();
  b.writeln('■ 합계 ${won(total)}');
  final pending = inMonth.where((e) => e.category == null).length;
  if (pending > 0) b.writeln('※ 미분류 $pending건 있음');
  return b.toString();
}
