import 'expense.dart';

/// 처음 설치하면 업체 관리 목록에 들어가는 차량비 기본 키워드. 사용자가 지울 수 있다.
const kDefaultCarKeywords = [
  '주유소',
  '주유',
  '충전소',
  '셀프',
  '오일',
  '에너지',
  '칼텍스',
  'S-OIL',
  '에쓰오일',
  '오일뱅크',
  '세차',
  '정비',
  '카센터',
  '타이어',
  '주차',
];

/// 키워드 비교용: 대소문자·공백·하이픈·점 무시. "S-OIL", "S OIL", "s-oil" → "soil"
String keywordKey(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-_.·]'), '');

/// 같은 가맹점 비교용: 키워드 비교 + (주)/㈜/주식회사·괄호·따옴표 무시. "(주)홍성 칼국수" == "홍성칼국수"
String merchantKey(String s) =>
    keywordKey(s.replaceAll(RegExp(r'\(주\)|㈜|주식회사'), '')).replaceAll(RegExp(r'''[()\[\]{}"',/]'''), '');

class KeywordRule {
  final String keyword;
  final String category; // kCar / kOps
  final bool isDefault;
  const KeywordRule(this.keyword, this.category, {this.isDefault = false});

  KeywordRule withCategory(String c) => KeywordRule(keyword, c, isDefault: isDefault);

  Map<String, dynamic> toJson() => {'keyword': keyword, 'category': category, 'isDefault': isDefault};
  factory KeywordRule.fromJson(Map<String, dynamic> j) =>
      KeywordRule(j['keyword'] as String, j['category'] as String, isDefault: j['isDefault'] as bool? ?? false);
}

/// 일괄 정리에서 배운 업체. [name] 은 화면 표시용 원래 이름.
class LearnedVendor {
  final String name;
  final String category;
  const LearnedVendor(this.name, this.category);
  Map<String, dynamic> toJson() => {'name': name, 'category': category};
  factory LearnedVendor.fromJson(Map<String, dynamic> j) => LearnedVendor(j['name'] as String, j['category'] as String);
}

enum RecSource { learned, keyword, defaultKeyword }

class Recommendation {
  final String category;
  final RecSource source;
  const Recommendation(this.category, this.source);

  /// 버튼 위 작은 표시. 등록 업체면 '지난번 운영비', 키워드면 '추천'.
  String get badge => source == RecSource.learned ? '지난번 ${categoryLabel(category)}' : '추천';
}

String categoryLabel(String c) => c == kCar ? '차량비' : '운영비';

/// 업체 관리: 자동 등록 업체 + 키워드(직접 등록·기본).
class VendorBook {
  final Map<String, LearnedVendor> learned; // merchantKey → 업체
  final List<KeywordRule> keywords;
  VendorBook(this.learned, this.keywords);

  factory VendorBook.initial() =>
      VendorBook({}, [for (final k in kDefaultCarKeywords) KeywordRule(k, kCar, isDefault: true)]);

  /// 우선순위: 자동 등록 업체(가맹점 이름 일치) > 직접 등록 키워드 > 기본 키워드.
  /// 같은 단계 안에서는 긴 키워드가 먼저 ('오일뱅크' 가 '오일' 보다 먼저).
  Recommendation? recommend(String merchant) {
    final mk = merchantKey(merchant);
    if (mk.isEmpty) return null;
    final l = learned[mk];
    if (l != null) return Recommendation(l.category, RecSource.learned);
    final name = keywordKey(merchant);
    for (final isDefault in [false, true]) {
      final rules = keywords.where((k) => k.isDefault == isDefault).toList()
        ..sort((a, b) => keywordKey(b.keyword).length.compareTo(keywordKey(a.keyword).length));
      for (final k in rules) {
        final kk = keywordKey(k.keyword);
        if (kk.isNotEmpty && name.contains(kk)) {
          return Recommendation(k.category, isDefault ? RecSource.defaultKeyword : RecSource.keyword);
        }
      }
    }
    return null;
  }

  /// 분류한 가맹점을 기억한다 (마지막에 고른 카테고리 기준). 되돌리기용으로 이전 값을 돌려준다.
  LearnedVendor? learn(String merchant, String category) {
    final mk = merchantKey(merchant);
    if (mk.isEmpty) return null;
    final prev = learned[mk];
    learned[mk] = LearnedVendor(merchant.trim(), category);
    return prev;
  }

  /// 되돌리기: [learn] 전 상태로.
  void restore(String merchant, LearnedVendor? prev) {
    final mk = merchantKey(merchant);
    if (prev == null) {
      learned.remove(mk);
    } else {
      learned[mk] = prev;
    }
  }

  Map<String, dynamic> toJson() => {
    'learned': learned.map((k, v) => MapEntry(k, v.toJson())),
    'keywords': keywords.map((k) => k.toJson()).toList(),
  };

  factory VendorBook.fromJson(Map<String, dynamic> j) => VendorBook(
    (j['learned'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, LearnedVendor.fromJson(v as Map<String, dynamic>)),
    ),
    [for (final k in (j['keywords'] as List? ?? [])) KeywordRule.fromJson(k as Map<String, dynamic>)],
  );
}

/// 일괄 정리 대상: [picked] 와 같은 가맹점인 다른 '분류 대기' 건. 분류된 건은 건드리지 않는다.
/// [includeIgnored] (무시한 내역에서 고를 때): '직접 무시' 건도 포함. '중복'·'취소로 상쇄'로 무시한 건은 이유가 있어 뺀다.
List<Expense> sameVendorPending(List<Expense> items, Expense picked, {bool includeIgnored = false}) {
  final mk = merchantKey(picked.merchant);
  if (mk.isEmpty) return [];
  bool target(Expense e) =>
      e.category == null || (includeIgnored && e.category == kIgnored && !e.ignoredAsDuplicate && !e.ignoredAsOffset);
  return items.where((e) => !identical(e, picked) && target(e) && merchantKey(e.merchant) == mk).toList();
}
