// 스토어 스크린샷 드라이버 (REQ-53): 기기에서 찍은 PNG 를 build/store_screenshots/ 에 저장한다.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
    final f = File('build/store_screenshots/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
    stdout.writeln('screenshot: ${f.path} (${bytes.length} bytes)');
    return true;
  },
);
