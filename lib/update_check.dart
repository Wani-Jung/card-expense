import 'dart:convert';
import 'dart:io';

import 'flavor.dart';

const _latestApi = 'https://api.github.com/repos/Wani-Jung/card-expense/releases/latest';
const _downloadBase = 'https://github.com/Wani-Jung/card-expense/releases/latest/download';

/// 판에 맞는 최신 APK 고정 링크.
String get latestApkUrl =>
    '$_downloadBase/${isFullEdition ? 'app-full-release.apk' : 'app-release.apk'}';

/// "v1.4.0", "1.4.0", "1.4.0+12" → [1, 4, 0]. 형식이 아니면 null.
List<int>? parseVersion(String v) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(v.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// [latest] 가 [current] 보다 새 버전인지. 둘 중 하나라도 못 읽으면 false.
bool isNewerVersion(String latest, String current) {
  final a = parseVersion(latest), b = parseVersion(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// 최신 정식 릴리스 태그(v*)를 가져온다. dev 프리릴리스는 GitHub latest API 가 이미 빼 준다.
/// 인터넷이 없거나 실패하면 null. 예외는 밖으로 내보내지 않는다.
Future<String?> fetchLatestTag() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(Uri.parse(_latestApi));
    req.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'card-expense-app');
    final res = await req.close().timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['prerelease'] == true || j['draft'] == true) return null;
    final tag = j['tag_name'] as String?;
    return tag != null && tag.startsWith('v') && parseVersion(tag) != null ? tag : null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
