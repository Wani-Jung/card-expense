import 'dart:io';
import 'dart:ui' as ui;

import 'package:card_expense/challenge_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2.1.2: 아이콘을 바꿀 때 앱 안 로고(챌린지 결과 카드)를 빠뜨리지 않게.
/// `python tools/app_icon.py build` 가 둘 다 같은 그림으로 만든다 → 작게 줄여 비교해 거의 같아야 한다.
void main() {
  Future<List<int>> pixels(String path) async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync(), targetWidth: 64, targetHeight: 64);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  }

  testWidgets('앱 안 로고 = 스토어 아이콘(앱 아이콘)과 같은 그림', (tester) async {
    final (logo, store) = (await tester.runAsync(() async => (await pixels(kShareCardLogo), await pixels('store/playstore_icon_512.png'))))!;
    var diff = 0;
    for (var i = 0; i < logo.length; i += 4) {
      diff += (logo[i] - store[i]).abs() + (logo[i + 1] - store[i + 1]).abs() + (logo[i + 2] - store[i + 2]).abs();
    }
    expect(diff / (logo.length / 4) / 3, lessThan(6), reason: '아이콘을 바꿨으면 python tools/app_icon.py build 로 앱 안 로고도 다시 만들 것');
  });

  test('예전 원형 로고 파일을 아무 데서도 안 씀', () {
    final hits = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.readAsStringSync().contains('gonggam_navy')) f.path,
      if (File('pubspec.yaml').readAsStringSync().contains('gonggam_navy')) 'pubspec.yaml',
    ];
    expect(hits, isEmpty);
  });
}
