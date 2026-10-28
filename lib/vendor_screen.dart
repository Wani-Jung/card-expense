import 'package:flutter/material.dart';

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

  Widget _categoryChip(String cat, VoidCallback onToggle) {
    final car = cat == kCar;
    return ActionChip(
      label: Text(categoryLabel(cat)),
      labelStyle: TextStyle(color: car ? Colors.white : const Color(0xFF4E2A00), fontWeight: FontWeight.bold),
      backgroundColor: car ? const Color(0xFF2E7D32) : const Color(0xFFFFC107),
      side: BorderSide.none,
      tooltip: '눌러서 바꾸기',
      onPressed: onToggle,
    );
  }

  String _other(String cat) => cat == kCar ? kOps : kCar;

  @override
  Widget build(BuildContext context) {
    final keywords = _book.keywords;
    final learned = _book.learned.entries.toList()..sort((a, b) => a.value.name.compareTo(b.value.name));
    Widget header(String title, String sub) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
        padding: EdgeInsets.only(bottom: listBottomPad(context, extra: 96)),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('추천 순서: 자동 등록 업체 > 직접 등록 키워드 > 기본 키워드',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          header('추천 키워드', '가맹점 이름에 키워드가 들어 있으면 그 분류를 추천해요'),
          if (keywords.isEmpty)
            const ListTile(title: Text('등록된 키워드가 없어요', style: TextStyle(color: Colors.black45))),
          for (final k in List.of(keywords))
            ListTile(
              title: Text(k.keyword),
              subtitle: k.isDefault ? const Text('기본 키워드', style: TextStyle(fontSize: 12)) : null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _categoryChip(k.category, () async {
                  final i = keywords.indexOf(k);
                  if (i >= 0) keywords[i] = k.withCategory(_other(k.category));
                  await _changed();
                }),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                  onPressed: () async {
                    keywords.remove(k);
                    await _changed();
                  },
                ),
              ]),
            ),
          header('자동 등록된 업체', '분류할 때 고른 카테고리를 기억해요. 같은 가맹점이 또 오면 추천해요'),
          if (learned.isEmpty)
            const ListTile(title: Text('아직 없어요', style: TextStyle(color: Colors.black45))),
          for (final entry in learned)
            ListTile(
              title: Text(entry.value.name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _categoryChip(entry.value.category, () async {
                  _book.learned[entry.key] = LearnedVendor(entry.value.name, _other(entry.value.category));
                  await _changed();
                }),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                  onPressed: () async {
                    _book.learned.remove(entry.key);
                    await _changed();
                  },
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
