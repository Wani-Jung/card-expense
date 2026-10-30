import 'expense.dart';

/// v1 (처음부터 있던) 차량비 기본 키워드 15개. 업데이트 때 '새로 생긴 것'만 추가하려고 남겨 둔다.
const kDefaultCarKeywordsV1 = [
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

/// 차량비 기본 키워드 (v2 = v1 + 확장). 처음 설치하면 업체 관리 목록에 들어가고, 사용자가 지울 수 있다.
final kDefaultCarKeywords = _dedupe([
  ...kDefaultCarKeywordsV1,
  '주유소',
  '셀프주유',
  '알뜰주유',
  'SK에너지',
  'GS칼텍스',
  'S-OIL',
  '에스오일',
  '현대오일뱅크',
  '오일뱅크',
  '충전소',
  'LPG',
  '가스충전',
  '전기차충전',
  '하이패스',
  '한국도로공사',
  '톨게이트',
  '주차장',
  '파킹',
  '정비',
  '카센터',
  '공업사',
  '모터스',
  '오토',
  '자동차',
  '타이어',
  '한국타이어',
  '금호타이어',
  '넥센타이어',
  '블루핸즈',
  '오토큐',
  '스피드메이트',
  '세차',
  '카워시',
  '엔진오일',
  '자동차검사',
  '교통안전공단',
]);

/// 운영비 기본 키워드 (v2 에서 새로 생김)
final kDefaultOpsKeywords = _dedupe([
  '식당',
  '한식',
  '분식',
  '김밥',
  '국밥',
  '칼국수',
  '냉면',
  '반점',
  '중화요리',
  '식육식당',
  '고기',
  '갈비',
  '삼겹',
  '치킨',
  '피자',
  '버거',
  '맥도날드',
  '롯데리아',
  '맘스터치',
  '버거킹',
  '서브웨이',
  '도시락',
  '한솥',
  '카페',
  '커피',
  '스타벅스',
  '이디야',
  '투썸',
  '메가커피',
  '메가MGC',
  '빽다방',
  '컴포즈',
  '할리스',
  '파스쿠찌',
  '베이커리',
  '제과',
  '파리바게뜨',
  '뚜레쥬르',
  '편의점',
  'GS25',
  '세븐일레븐',
  '이마트24',
  '씨유',
  '다이소',
  '문구',
  '오피스',
  '철물',
  '하나로마트',
  '마트',
  '우체국',
  '인쇄',
  '복사',
]);

/// 기본 키워드 세트 버전. 올리면 기존 설치 기기에 새 기본 키워드를 한 번 추가한다.
const kDefaultKeywordsVersion = 2;

List<String> _dedupe(List<String> words) {
  final seen = <String>{};
  return [
    for (final w in words)
      if (seen.add(keywordKey(w))) w,
  ];
}

/// 기본 키워드 전체 (차량비 + 운영비)
List<KeywordRule> defaultKeywordRules() => [
  for (final k in kDefaultCarKeywords) KeywordRule(k, kCar, isDefault: true),
  for (final k in kDefaultOpsKeywords) KeywordRule(k, kOps, isDefault: true),
];

/// 영문·숫자 3자 이하 키워드(LPG 등)는 가맹점 이름 앞부분 일치일 때만 (엉뚱한 부분 일치 방지)
bool _shortLatin(String kk) => kk.length <= 3 && RegExp(r'^[a-z0-9]+$').hasMatch(kk);

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

  /// 이 목록에 들어 있는 기본 키워드 세트 버전 (저장값이 없던 예전 기기는 1)
  int defaultsVersion;

  /// 사용자가 지운 기본 키워드 (keywordKey). 업데이트로 기본 키워드를 추가할 때 되살리지 않는다.
  final Set<String> removedDefaults;
  VendorBook(
    this.learned,
    this.keywords, {
    this.defaultsVersion = kDefaultKeywordsVersion,
    Set<String>? removedDefaults,
  }) : removedDefaults = removedDefaults ?? {};

  factory VendorBook.initial() => VendorBook({}, defaultKeywordRules());

  /// 기존 설치 기기: 기본 키워드 세트가 새 버전이면 새로 생긴 기본 키워드만 한 번 추가한다.
  /// 예전 버전에 있던 것(사용자가 지웠을 수 있음)·지운 기본 키워드·이미 있는 키워드는 건너뛴다. 바꿨으면 true.
  bool upgradeDefaults() {
    if (defaultsVersion >= kDefaultKeywordsVersion) return false;
    final have = {for (final k in keywords) keywordKey(k.keyword)};
    final old = defaultsVersion <= 1 ? {for (final k in kDefaultCarKeywordsV1) keywordKey(k)} : <String>{};
    for (final r in defaultKeywordRules()) {
      final kk = keywordKey(r.keyword);
      if (have.contains(kk) || old.contains(kk) || removedDefaults.contains(kk)) continue;
      keywords.add(r);
      have.add(kk);
    }
    defaultsVersion = kDefaultKeywordsVersion;
    return true;
  }

  /// 키워드 지우기. 기본 키워드면 지운 것으로 기억한다.
  void removeKeyword(KeywordRule k) {
    keywords.remove(k);
    if (k.isDefault) removedDefaults.add(keywordKey(k.keyword));
  }

  /// 추천 키워드 전체 삭제 (기본 + 직접 등록). 기본 키워드는 지운 것으로 기억 (업데이트 때 안 되살아나게)
  void removeAllKeywords() {
    for (final k in List.of(keywords)) {
      removeKeyword(k);
    }
  }

  /// [기본 키워드 다시 넣기]: 지금 목록에 없는 기본 키워드를 다시 넣고 지운 목록에서 뺀다. 이미 있으면 건너뜀. 넣은 개수.
  int restoreDefaults() {
    final have = {for (final k in keywords) keywordKey(k.keyword)};
    var n = 0;
    for (final r in defaultKeywordRules()) {
      final kk = keywordKey(r.keyword);
      removedDefaults.remove(kk);
      if (have.add(kk)) {
        keywords.add(r);
        n++;
      }
    }
    return n;
  }

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
        if (kk.isNotEmpty && (_shortLatin(kk) ? name.startsWith(kk) : name.contains(kk))) {
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
    'defaultsVersion': defaultsVersion,
    'removedDefaults': removedDefaults.toList(),
  };

  factory VendorBook.fromJson(Map<String, dynamic> j) => VendorBook(
    (j['learned'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, LearnedVendor.fromJson(v as Map<String, dynamic>)),
    ),
    [for (final k in (j['keywords'] as List? ?? [])) KeywordRule.fromJson(k as Map<String, dynamic>)],
    defaultsVersion: (j['defaultsVersion'] as num?)?.toInt() ?? 1,
    removedDefaults: {for (final k in (j['removedDefaults'] as List? ?? [])) k as String},
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
