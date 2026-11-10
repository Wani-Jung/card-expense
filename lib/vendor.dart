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
final kDefaultCarKeywords = _without(kRemovedDefaultKeywords, [
  ...kDefaultCarKeywordsV1,
  'S-OIL',
  '충전소',
  'LPG',
  '가스충전',
  '전기차충전',
  '하이패스',
  '한국도로공사',
  '톨게이트',
  '파킹',
  '정비',
  '카센터',
  '공업사',
  '모터스',
  '오토',
  '자동차',
  '타이어',
  '블루핸즈',
  '스피드메이트',
  '세차',
  '카워시',
  '교통안전공단',
]);

/// 운영비 기본 키워드 (v2 에서 새로 생김, v3 에 알파문구·드림디포 추가)
final kDefaultOpsKeywords = _without(kRemovedDefaultKeywords, [
  '식당',
  '한식',
  '분식',
  '김밥',
  '국밥',
  '칼국수',
  '냉면',
  '반점',
  '중화요리',
  '고기',
  '갈비',
  '삼겹',
  '치킨',
  '피자',
  '버거',
  '맥도날드',
  '롯데리아',
  '맘스터치',
  '서브웨이',
  '도시락',
  '한솥',
  '카페',
  '커피',
  '스타벅스',
  '이디야',
  '투썸',
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
  '씨유',
  '다이소',
  '문구',
  '알파문구',
  '드림디포',
  '오피스',
  '철물',
  '마트',
  '우체국',
  '인쇄',
  '복사',
]);

/// 기본 키워드 세트 버전. 올리면 기존 설치 기기에 새 기본 키워드를 한 번 추가한다.
/// v3 (REQ-47): 알파문구·드림디포 추가, 더 짧은 기본 키워드에 덮여 추천이 안 바뀌는 기본 키워드 정리.
const kDefaultKeywordsVersion = 3;

/// v3 에서 기본 목록에서 뺀 키워드: 같은 분류의 더 짧은 기본 키워드에 포함돼 추천 결과가 같다
/// ('주유소' ⊂ '주유', 'SK에너지' ⊂ '에너지' …). '알파문구'는 '문구'에 덮이지만 요청대로 기본에 넣었다.
const kRemovedDefaultKeywords = [
  '주유소',
  '에쓰오일',
  '오일뱅크',
  '셀프주유',
  '알뜰주유',
  'SK에너지',
  'GS칼텍스',
  '에스오일',
  '현대오일뱅크',
  '주차장',
  '한국타이어',
  '금호타이어',
  '넥센타이어',
  '오토큐',
  '엔진오일',
  '자동차검사',
  '식육식당',
  '버거킹',
  '메가커피',
  '이마트24',
  '하나로마트',
];

List<String> _without(List<String> drop, List<String> words) {
  final d = {for (final w in drop) keywordKey(w)};
  return _dedupe([
    for (final w in words)
      if (!d.contains(keywordKey(w))) w,
  ]);
}

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

/// [short] 가 [long] 을 덮는지: [long] 에 맞는 가맹점은 반드시 [short] 에도 맞는다
bool keywordCovers(String short, String long) {
  final s = keywordKey(short), l = keywordKey(long);
  if (s.isEmpty || s.length >= l.length) return false;
  return _shortLatin(s) ? l.startsWith(s) : l.contains(s);
}

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

  String get key => keywordKey(keyword);

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
  /// [영구 삭제] 해도 여기 남겨 둔다 (되살리지 않는 규칙 유지) — 목록에서만 [purged] 로 숨긴다.
  final Set<String> removedDefaults;

  /// 지운 직접 등록 키워드 (분류와 함께 기억, REQ-47). '지운 키워드'에서 다시 넣을 수 있다.
  final List<KeywordRule> removedCustom;

  /// '지운 키워드'에서 [영구 삭제]한 기본 키워드 (keywordKey). 목록에 안 보이게만 한다.
  final Set<String> purged;
  VendorBook(
    this.learned,
    this.keywords, {
    this.defaultsVersion = kDefaultKeywordsVersion,
    Set<String>? removedDefaults,
    List<KeywordRule>? removedCustom,
    Set<String>? purged,
  }) : removedDefaults = removedDefaults ?? {},
       removedCustom = removedCustom ?? [],
       purged = purged ?? {};

  factory VendorBook.initial() => VendorBook({}, defaultKeywordRules());

  /// 기존 설치 기기: 기본 키워드 세트가 새 버전이면 새로 생긴 기본 키워드만 한 번 추가한다.
  /// 예전 버전에 있던 것(사용자가 지웠을 수 있음)·지운 기본 키워드·이미 있는 키워드는 건너뛴다. 바꿨으면 true.
  bool upgradeDefaults() {
    if (defaultsVersion >= kDefaultKeywordsVersion) return false;
    if (defaultsVersion < 3) _dropCoveredDefaults();
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

  /// v3 정리: 이 기기 목록에 있는 기본 키워드 중 [kRemovedDefaultKeywords] 이면서, 같은 분류의 더 짧은
  /// 키워드가 목록에 남아 있어 추천이 안 바뀌는 것만 뺀다. 짧은 쪽을 지운 기기는 그대로 둔다.
  /// 직접 등록 키워드는 건드리지 않는다. 뺀 것은 '지운 키워드'에도 안 나온다 (사용자가 지운 게 아니므로).
  void _dropCoveredDefaults() {
    final drop = {for (final w in kRemovedDefaultKeywords) keywordKey(w)};
    keywords.removeWhere((k) =>
        k.isDefault &&
        drop.contains(k.key) &&
        keywords.any((s) => !identical(s, k) && s.category == k.category && keywordCovers(s.keyword, k.keyword)));
  }

  /// 키워드 지우기. 기본 키워드는 지운 것으로 기억(업데이트 때 안 되살림), 직접 등록은 분류와 함께 기억.
  void removeKeyword(KeywordRule k) {
    keywords.remove(k);
    if (k.isDefault) {
      removedDefaults.add(k.key);
      purged.remove(k.key);
    } else {
      removedCustom
        ..removeWhere((r) => r.key == k.key)
        ..add(k);
    }
  }

  /// '지운 키워드': 지운 기본 키워드(지금 기본 목록 기준) + 지운 직접 등록 키워드. 목록에 다시 있거나 영구 삭제한 것은 뺀다.
  List<KeywordRule> get removedKeywords {
    final have = {for (final k in keywords) k.key};
    return [
      for (final r in removedCustom)
        if (!have.contains(r.key)) r,
      for (final r in defaultKeywordRules())
        if (removedDefaults.contains(r.key) && !purged.contains(r.key) && !have.contains(r.key)) r,
    ];
  }

  /// '지운 키워드' [다시 넣기]. 넣은 개수
  int restoreRemoved(Iterable<KeywordRule> picked) {
    final have = {for (final k in keywords) k.key};
    var n = 0;
    for (final r in picked) {
      if (r.isDefault) {
        removedDefaults.remove(r.key);
      } else {
        removedCustom.removeWhere((x) => x.key == r.key);
      }
      if (have.add(r.key)) {
        keywords.add(r);
        n++;
      }
    }
    return n;
  }

  /// '지운 키워드' [영구 삭제]: 목록에서 완전히 지운다. 기본 키워드는 계속 '지운 것'으로 남아 업데이트로 안 되살아난다.
  void purgeRemoved(Iterable<KeywordRule> picked) {
    for (final r in picked) {
      if (r.isDefault) {
        purged.add(r.key);
      } else {
        removedCustom.removeWhere((x) => x.key == r.key);
      }
    }
  }

  /// 키워드를 새로 넣을 때: 지운 목록에 있던 같은 키워드는 지운 목록에서 뺀다
  void addKeyword(KeywordRule k) {
    keywords
      ..removeWhere((x) => x.key == k.key)
      ..insert(0, k);
    removedCustom.removeWhere((x) => x.key == k.key);
    removedDefaults.remove(k.key);
  }

  /// 추천 키워드 전체 삭제 (기본 + 직접 등록). 기본 키워드는 지운 것으로 기억 (업데이트 때 안 되살아나게)
  void removeAllKeywords() {
    for (final k in List.of(keywords)) {
      removeKeyword(k);
    }
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
    'removedCustom': removedCustom.map((k) => k.toJson()).toList(),
    'purged': purged.toList(),
  };

  factory VendorBook.fromJson(Map<String, dynamic> j) => VendorBook(
    (j['learned'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, LearnedVendor.fromJson(v as Map<String, dynamic>)),
    ),
    [for (final k in (j['keywords'] as List? ?? [])) KeywordRule.fromJson(k as Map<String, dynamic>)],
    defaultsVersion: (j['defaultsVersion'] as num?)?.toInt() ?? 1,
    removedDefaults: {for (final k in (j['removedDefaults'] as List? ?? [])) k as String},
    removedCustom: [
      for (final k in (j['removedCustom'] as List? ?? [])) KeywordRule.fromJson(k as Map<String, dynamic>),
    ],
    purged: {for (final k in (j['purged'] as List? ?? [])) k as String},
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
