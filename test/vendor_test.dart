import 'dart:convert';

import 'package:card_expense/expense.dart';
import 'package:card_expense/vendor.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _e(String merchant, String? cat, {int minute = 0}) => Expense(
      id: 'id-$merchant-$minute-$cat',
      amount: 10000,
      dateTime: DateTime(2026, 8, 1, 12, minute),
      merchant: merchant,
      isCancel: false,
      raw: '',
      category: cat,
    );

void main() {
  group('키워드 매칭', () {
    test('대소문자·공백·하이픈 무시', () {
      final b = VendorBook.initial();
      expect(b.recommend('S-OIL 강남주유소')?.category, kCar);
      expect(b.recommend('s oil 셀프')?.category, kCar);
      expect(b.recommend('SOIL')?.category, kCar);
      expect(b.recommend('GS칼텍스(주)월산')?.category, kCar);
      expect(b.recommend('홍성면옥'), isNull);
    });

    test('직접 등록 키워드도 대소문자 무시', () {
      final b = VendorBook.initial()..keywords.add(const KeywordRule('cafe', kOps));
      expect(b.recommend('Blue CAFE 강남')?.category, kOps);
      expect(b.recommend('blue cafe')?.source, RecSource.keyword);
    });

    test('기본 키워드는 지울 수 있다', () {
      final b = VendorBook.initial()..keywords.removeWhere((k) => k.keyword == '파킹');
      expect(b.recommend('강남파킹'), isNull);
    });
  });

  group('매칭 우선순위', () {
    test('자동 등록 업체 > 직접 등록 키워드 > 기본 키워드', () {
      final b = VendorBook.initial();
      // 기본 키워드만: '오일' → 차량비
      expect(b.recommend('오일파스타')!.source, RecSource.defaultKeyword);
      expect(b.recommend('오일파스타')!.category, kCar);

      // 직접 등록 키워드가 기본보다 먼저
      b.keywords.insert(0, const KeywordRule('파스타', kOps));
      expect(b.recommend('오일파스타')!.category, kOps);
      expect(b.recommend('오일파스타')!.source, RecSource.keyword);

      // 자동 등록 업체가 가장 먼저 (사용자 기록)
      b.learn('오일파스타', kCar);
      expect(b.recommend('오일 파스타')!.category, kCar);
      expect(b.recommend('오일 파스타')!.source, RecSource.learned);
      expect(b.recommend('오일 파스타')!.badge, '지난번 차량비');
    });

    test('자동 등록 업체가 기본 키워드와 충돌하면 사용자 기록 우선', () {
      final b = VendorBook.initial()..learn('(주)월산주유소', kOps);
      expect(b.recommend('월산주유소')!.category, kOps);
    });

    test('같은 단계에서는 긴 키워드 먼저', () {
      final b = VendorBook({}, [const KeywordRule('오일', kCar), const KeywordRule('오일뱅크', kOps)]);
      expect(b.recommend('현대오일뱅크')!.category, kOps);
    });

    test('업체 기억·되돌리기', () {
      final b = VendorBook({}, []);
      final prev = b.learn('홍성칼국수', kOps);
      expect(prev, isNull);
      expect(b.recommend('홍성 칼국수')!.badge, '지난번 운영비');
      final prev2 = b.learn('홍성칼국수', kCar); // 마지막에 고른 카테고리 기준
      expect(b.recommend('홍성칼국수')!.category, kCar);
      b.restore('홍성칼국수', prev2);
      expect(b.recommend('홍성칼국수')!.category, kOps);
      b.restore('홍성칼국수', prev);
      expect(b.recommend('홍성칼국수'), isNull);
    });

    test('저장했다 불러와도 같음', () {
      final b = VendorBook.initial()..learn('홍성칼국수', kOps);
      final back = VendorBook.fromJson(b.toJson());
      expect(back.recommend('홍성칼국수')!.category, kOps);
      expect(back.keywords.length, kDefaultCarKeywords.length + kDefaultOpsKeywords.length);
      expect(back.defaultsVersion, kDefaultKeywordsVersion);
    });
  });

  group('같은 업체 일괄 정리 대상', () {
    test('가맹점 이름 정규화해서 같은 대기 건만, 무시·분류된 건은 제외', () {
      final picked = _e('홍성칼국수', null);
      final items = [
        picked,
        _e('홍성 칼국수', null, minute: 1), // 공백 차이 → 대상
        _e('(주)홍성칼국수', null, minute: 2), // (주) 차이 → 대상
        _e('홍성칼국수', kIgnored, minute: 3), // 무시한 건 → 묻지 않고 그대로
        _e('홍성칼국수', kOps, minute: 4), // 이미 분류 → 제외
        _e('홍성국밥', null, minute: 5), // 다른 가맹점
      ];
      final t = sameVendorPending(items, picked);
      expect(t.map((e) => e.dateTime.minute), [1, 2]);
    });

    test('가맹점 이름이 비어 있으면 묶지 않음', () {
      final picked = _e('', null);
      expect(sameVendorPending([picked, _e('', null, minute: 1)], picked), isEmpty);
    });
  });

  test('무시한 내역에서 고를 때: 직접 무시 건도 일괄 대상, 중복·상쇄 무시는 제외', () {
    final picked = _e('고야커피', kIgnored, minute: 1);
    final manual = _e('고야 커피', kIgnored, minute: 2);
    final pending = _e('고야커피', null, minute: 3);
    final dup = _e('고야커피', kIgnored, minute: 4)..ignoreReason = kIgnoreDuplicate;
    final offset = _e('고야커피', kIgnored, minute: 5)..ignoreReason = kIgnoreOffset;
    final done = _e('고야커피', kOps, minute: 6);
    final items = [picked, manual, pending, dup, offset, done];
    expect(sameVendorPending(items, picked), [pending]);
    expect(sameVendorPending(items, picked, includeIgnored: true), [manual, pending]);
  });

  group('기본 키워드 확장 (v2)', () {
    test('새 운영비·차량비 기본 키워드로 추천', () {
      final b = VendorBook.initial();
      expect(b.recommend('스타벅스 강남점')!.category, kOps);
      expect(b.recommend('홍성칼국수')!.category, kOps);
      expect(b.recommend('GS25 월산점')!.category, kOps);
      expect(b.recommend('하나로마트 홍성')!.category, kOps);
      expect(b.recommend('블루핸즈 홍성점')!.category, kCar);
      expect(b.recommend('한국도로공사 하이패스')!.category, kCar);
      expect(b.recommend('스타벅스')!.source, RecSource.defaultKeyword);
      // 중복은 한 번만
      final keys = [for (final k in b.keywords) keywordKey(k.keyword)];
      expect(keys.toSet().length, keys.length);
      expect(kDefaultCarKeywords, containsAll(kDefaultCarKeywordsV1));
    });

    test('영문 3자 이하 키워드(LPG)는 가맹점 이름 앞부분 일치만', () {
      final b = VendorBook({}, [const KeywordRule('LPG', kCar, isDefault: true)]);
      expect(b.recommend('LPG충전소 홍성')!.category, kCar);
      expect(b.recommend('lpg 가스')!.category, kCar);
      expect(b.recommend('HELPGO 마켓'), isNull); // 중간에 lpg 가 있어도 아님
      // 직접 등록한 짧은 영문도 같은 규칙
      final u = VendorBook({}, [const KeywordRule('cu', kOps)]);
      expect(u.recommend('CU 홍성점')!.category, kOps);
      expect(u.recommend('SCUBA 다이빙'), isNull);
    });

    test('기존 설치: 새 기본 키워드는 한 번만 추가, 예전 기본 키워드·지운 키워드는 되살리지 않음', () {
      // v1 기기: 기본 15개 중 '주차' 를 지웠고 직접 등록 '커피'(차량비로 등록) 가 있음
      final v1 = {
        'learned': {},
        'keywords': [
          for (final k in kDefaultCarKeywordsV1)
            if (k != '주차') {'keyword': k, 'category': 'car', 'isDefault': true},
          {'keyword': '커피', 'category': 'car', 'isDefault': false},
        ],
      };
      final b = VendorBook.fromJson(jsonDecode(jsonEncode(v1)) as Map<String, dynamic>);
      expect(b.defaultsVersion, 1);
      expect(b.upgradeDefaults(), isTrue);
      final words = [for (final k in b.keywords) k.keyword];
      expect(words, isNot(contains('주차'))); // 지웠던 v1 기본 키워드는 그대로 없음
      expect(words, contains('스타벅스'));
      expect(words, contains('블루핸즈'));
      expect(words.where((w) => w == '커피'), hasLength(1)); // 이미 있으면 건너뜀
      expect(b.keywords.firstWhere((k) => k.keyword == '커피').category, kCar); // 사용자 값 그대로
      final n = b.keywords.length;
      expect(b.upgradeDefaults(), isFalse); // 한 번만
      expect(b.keywords.length, n);

      // v2 기기에서 기본 키워드를 지우면 기억 → 저장·불러오기 후에도 유지, 다음 업그레이드에서도 안 돌아옴
      b.removeKeyword(b.keywords.firstWhere((k) => k.keyword == '스타벅스'));
      final back = VendorBook.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(back.removedDefaults, contains(keywordKey('스타벅스')));
      back.defaultsVersion = 1; // (가정) 다시 업그레이드가 돌아도
      back.upgradeDefaults();
      expect([for (final k in back.keywords) k.keyword], isNot(contains('스타벅스')));
    });
  });
}
