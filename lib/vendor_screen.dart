import 'package:flutter/material.dart';

import 'category_badge.dart';
import 'expense.dart';
import 'layout.dart';
import 'vendor.dart';

/// 메뉴 > 업체 관리. 키워드(직접 등록 + 기본)와 자동 등록 업체를 보고 바꾸거나 지운다.
class VendorScreen extends StatefulWidget {
  final VendorBook book;
  final Future<void> Function() onChanged;
  const VendorScreen({super.key, required this.book, required this.onChanged});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  VendorBook get _book => widget.book;

  Future<void> _changed() async {
    setState(() {});
    await widget.onChanged();
  }

  /// 섹션 [전체 삭제]: 확인 → 삭제 → 스낵바 5초 [되돌리기](전부 원상 복구)
  Future<void> _deleteAll({required String what, required int count, required void Function() run}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('$what $count개를 모두 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD93025)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // 되돌리기용 원래 상태
    final keywords = List.of(_book.keywords);
    final removed = {..._book.removedDefaults};
    final learned = Map.of(_book.learned);
    run();
    await _changed();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$what를 모두 삭제했어요'),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () async {
            _book.keywords
              ..clear()
              ..addAll(keywords);
            _book.removedDefaults
              ..clear()
              ..addAll(removed);
            _book.learned
              ..clear()
              ..addAll(learned);
            await _changed();
          },
        ),
      ));
  }

  Future<void> _restoreDefaults() async {
    final n = _book.restoreDefaults();
    await _changed();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(n == 0 ? '빠진 기본 키워드가 없어요' : '$n개를 다시 넣었어요')));
  }

  Widget _deleteAllButton(int count, VoidCallback onPressed) => TextButton(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFD93025),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: count == 0 ? null : onPressed,
        child: const Text('전체 삭제'),
      );

  Future<void> _add() async {
    final ctrl = TextEditingController();
    var cat = kOps;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('추천 키워드 추가'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '키워드',
                helperText: '가맹점 이름에 들어 있으면 추천해요 (대소문자 무시)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: kCar, label: Text('차량비')),
                ButtonSegment(value: kOps, label: Text('운영비')),
              ],
              selected: {cat},
              onSelectionChanged: (v) => setLocal(() => cat = v.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
          ],
        ),
      ),
    );
    final word = ctrl.text.trim();
    if (ok != true || keywordKey(word).isEmpty) return;
    // 같은 키워드가 있으면 카테고리만 바꾼다
    _book.keywords.removeWhere((k) => keywordKey(k.keyword) == keywordKey(word));
    _book.keywords.insert(0, KeywordRule(word, cat));
    await _changed();
  }

  /// 행을 누르면 여는 작은 바텀시트: 이름 + [차량비] [운영비] (현재 값 체크) + [저장]
  Future<void> _pickCategory(String name, String current, Future<void> Function(String cat) apply) async {
    var cat = current;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, listBottomPad(ctx, extra: 8)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: kCar, label: Text('차량비')),
                ButtonSegment(value: kOps, label: Text('운영비')),
              ],
              selected: {cat},
              onSelectionChanged: (v) => setLocal(() => cat = v.first),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(ctx, cat),
              child: const Text('저장'),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await apply(picked);
    await _changed();
  }

  /// 삭제 전 확인 "'이름'을 목록에서 뺄까요?"
  Future<void> _confirmRemove(String name, VoidCallback remove) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text("'$name'${_objectParticle(name)} 목록에서 뺄까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('빼기')),
        ],
      ),
    );
    if (ok != true) return;
    remove();
    await _changed();
  }

  /// [배지] 이름 (회색 설명) ………… [휴지통]. 카테고리는 행을 눌러서만 바꾼다.
  Widget _row(String name, String cat, String? sub,
          {required Future<void> Function(String cat) onCategory, required VoidCallback onRemove}) =>
      ListTile(
        leading: CategoryBadge(cat),
        title: Text(name),
        subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        onTap: () => _pickCategory(name, cat, onCategory),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '삭제',
          onPressed: () => _confirmRemove(name, onRemove),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keywords = _book.keywords;
    final learned = _book.learned.entries.toList()..sort((a, b) => a.value.name.compareTo(b.value.name));
    Widget header(String title, String sub, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
            ?trailing,
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('업체 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('추가'),
      ),
      body: ListView(
        // '+ 추가' 버튼(높이 56 + 아래 여백 16)에 마지막 항목이 가리지 않게
        padding: EdgeInsets.only(bottom: listBottomPad(context, extra: 56 + 16 + 32)),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('추천 순서: 자동 등록 업체 > 직접 등록 키워드 > 기본 키워드',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          header('추천 키워드', '가맹점 이름에 키워드가 들어 있으면 그 분류를 추천해요',
              trailing: _deleteAllButton(
                  keywords.length,
                  () => _deleteAll(what: '추천 키워드', count: keywords.length, run: _book.removeAllKeywords))),
          if (keywords.isEmpty)
            const ListTile(title: Text('등록된 키워드가 없어요', style: TextStyle(color: Colors.black45))),
          // 직접 등록 키워드 → 기본 키워드(차량비 / 운영비로 묶어서)
          for (final (title, list) in [
            ('직접 등록', [for (final k in keywords) if (!k.isDefault) k]),
            ('기본 키워드 · 차량비', [for (final k in keywords) if (k.isDefault && k.category == kCar) k]),
            ('기본 키워드 · 운영비', [for (final k in keywords) if (k.isDefault && k.category == kOps) k]),
          ])
            if (list.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Text('$title (${list.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5F6368))),
              ),
              for (final k in list)
                _row(k.keyword, k.category, k.isDefault ? '기본 키워드' : null,
                    onCategory: (cat) async {
                      final i = keywords.indexOf(k);
                      if (i >= 0) keywords[i] = k.withCategory(cat);
                    },
                    // 기본 키워드를 지우면 기억해서 업데이트 때 되살리지 않는다
                    onRemove: () => _book.removeKeyword(k)),
            ],
          // 추천 키워드 맨 아래: 지운 기본 키워드 다시 넣기
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('기본 키워드 다시 넣기'),
                onPressed: _restoreDefaults,
              ),
            ),
          ),
          header('자동 등록된 업체', '분류할 때 고른 카테고리를 기억해요. 같은 가맹점이 또 오면 추천해요',
              trailing: _deleteAllButton(
                  learned.length,
                  () => _deleteAll(what: '자동 등록 업체', count: learned.length, run: _book.learned.clear))),
          if (learned.isEmpty)
            const ListTile(title: Text('아직 없어요', style: TextStyle(color: Colors.black45))),
          for (final entry in learned)
            _row(entry.value.name, entry.value.category, null,
                onCategory: (cat) async => _book.learned[entry.key] = LearnedVendor(entry.value.name, cat),
                onRemove: () => _book.learned.remove(entry.key)),
        ],
      ),
    );
  }
}

/// 목적격 조사: 받침 있으면 '을', 없으면 '를'. 한글로 안 끝나면 '을(를)'.
String _objectParticle(String word) {
  if (word.isEmpty) return '을(를)';
  final c = word.runes.last;
  if (c < 0xAC00 || c > 0xD7A3) return '을(를)';
  return (c - 0xAC00) % 28 == 0 ? '를' : '을';
}
