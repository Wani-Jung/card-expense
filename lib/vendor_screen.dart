import 'package:flutter/material.dart';

import 'category_badge.dart';
import 'expense.dart';
import 'layout.dart';
import 'vendor.dart';
import 'snack.dart';

/// 메뉴 > 업체 관리. 추천 키워드는 차량비/운영비 묶음 안에 칩으로 촘촘히 (직접 등록 = 색 채움, 기본 = 테두리).
/// 칩을 누르면 분류 변경·삭제. 지운 키워드는 '지운 키워드 (n)'에서 골라 다시 넣거나 영구 삭제.
/// 자동 등록 업체는 한 줄씩.
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

  /// 되돌리기용 상태 사진 (키워드·지운 목록·자동 등록 업체 전부)
  VoidCallback _snapshot() {
    final keywords = List.of(_book.keywords);
    final removed = {..._book.removedDefaults};
    final custom = List.of(_book.removedCustom);
    final purged = {..._book.purged};
    final learned = Map.of(_book.learned);
    return () {
      _book.keywords
        ..clear()
        ..addAll(keywords);
      _book.removedDefaults
        ..clear()
        ..addAll(removed);
      _book.removedCustom
        ..clear()
        ..addAll(custom);
      _book.purged
        ..clear()
        ..addAll(purged);
      _book.learned
        ..clear()
        ..addAll(learned);
    };
  }

  void _undoSnack(String msg, VoidCallback restore) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () async {
            restore();
            await _changed();
          },
        ),
      ));
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
    final restore = _snapshot();
    run();
    await _changed();
    if (mounted) _undoSnack('$what를 모두 삭제했어요', restore);
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              _categorySegments(cat, (v) => setLocal(() => cat = v)),
            ],
          ),
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
    _book.addKeyword(KeywordRule(word, cat));
    await _changed();
  }

  static Widget _categorySegments(String cat, ValueChanged<String> onChanged) => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: kCar, label: Text('차량비')),
      ButtonSegment(value: kOps, label: Text('운영비')),
    ],
    selected: {cat},
    onSelectionChanged: (v) => onChanged(v.first),
  );

  /// 키워드·업체를 누르면 여는 바텀시트: 이름 + [차량비] [운영비] + [저장], 아래 [삭제]
  Future<void> _edit({
    required String name,
    String? note,
    required String current,
    required void Function(String cat) apply,
    required VoidCallback remove,
  }) async {
    var cat = current;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, listBottomPad(ctx, extra: 8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (note != null) Text(note, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 16),
              _categorySegments(cat, (v) => setLocal(() => cat = v)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(ctx, cat),
                child: const Text('저장'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFD93025)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('삭제'),
                onPressed: () => Navigator.pop(ctx, '_delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == '_delete') {
      await _confirmRemove(name, remove);
      return;
    }
    if (picked == null || picked == current) return;
    apply(picked);
    await _changed();
  }

  /// 삭제 전 확인 "'이름'을 목록에서 뺄까요?" → 빼고 5초 [되돌리기]
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
    final restore = _snapshot();
    remove();
    await _changed();
    if (mounted) _undoSnack("'$name'${_objectParticle(name)} 뺐어요", restore);
  }

  void _editKeyword(KeywordRule k) => _edit(
    name: k.keyword,
    note: k.isDefault ? '기본 키워드' : '직접 등록',
    current: k.category,
    apply: (cat) {
      final i = _book.keywords.indexOf(k);
      if (i >= 0) _book.keywords[i] = k.withCategory(cat);
    },
    // 기본 키워드를 지우면 기억해서 업데이트 때 되살리지 않는다
    remove: () => _book.removeKeyword(k),
  );

  Future<void> _openRemoved() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemovedKeywordsScreen(book: _book, onChanged: widget.onChanged),
    ));
    if (mounted) setState(() {});
  }

  /// 차량비 / 운영비 묶음: 제목(개수) + 칩 (직접 등록 먼저)
  Widget _group(String cat) {
    final list = [
      for (final k in _book.keywords)
        if (k.category == cat && !k.isDefault) k,
      for (final k in _book.keywords)
        if (k.category == cat && k.isDefault) k,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(cat),
              const SizedBox(width: 8),
              Text(
                '${categoryLabel(cat)} (${list.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3C4043)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Text('키워드가 없어요', style: TextStyle(color: Colors.black45, fontSize: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final k in list) KeywordChip(rule: k, onTap: () => _editKeyword(k))],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keywords = _book.keywords;
    final removed = _book.removedKeywords;
    final learned = _book.learned.entries.toList()..sort((a, b) => a.value.name.compareTo(b.value.name));
    Widget header(String title, String sub, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
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
            child: Text(
              '추천 순서: 자동 등록 업체 > 직접 등록 키워드 > 기본 키워드',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          header(
            '추천 키워드',
            '가맹점 이름에 키워드가 들어 있으면 그 분류를 추천해요',
            trailing: _deleteAllButton(
              keywords.length,
              () => _deleteAll(what: '추천 키워드', count: keywords.length, run: _book.removeAllKeywords),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                _LegendDot(filled: true),
                SizedBox(width: 4),
                Text('직접 등록', style: TextStyle(fontSize: 12, color: Colors.black54)),
                SizedBox(width: 12),
                _LegendDot(filled: false),
                SizedBox(width: 4),
                Text('기본 키워드', style: TextStyle(fontSize: 12, color: Colors.black54)),
                SizedBox(width: 12),
                Flexible(
                  child: Text('누르면 분류 변경·삭제', style: TextStyle(fontSize: 12, color: Colors.black38)),
                ),
              ],
            ),
          ),
          _group(kCar),
          _group(kOps),
          // 지운 키워드 (0개면 숨김)
          if (removed.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: TextButton.icon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text('지운 키워드 (${removed.length})'),
                  onPressed: _openRemoved,
                ),
              ),
            ),
          header(
            '자동 등록된 업체',
            '분류할 때 고른 카테고리를 기억해요. 같은 가맹점이 또 오면 추천해요',
            trailing: _deleteAllButton(
              learned.length,
              () => _deleteAll(what: '자동 등록 업체', count: learned.length, run: _book.learned.clear),
            ),
          ),
          if (learned.isEmpty) const ListTile(title: Text('아직 없어요', style: TextStyle(color: Colors.black45))),
          for (final entry in learned)
            ListTile(
              leading: CategoryBadge(entry.value.category),
              title: Text(entry.value.name),
              onTap: () => _edit(
                name: entry.value.name,
                current: entry.value.category,
                apply: (cat) => _book.learned[entry.key] = LearnedVendor(entry.value.name, cat),
                remove: () => _book.learned.remove(entry.key),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '삭제',
                onPressed: () => _confirmRemove(entry.value.name, () => _book.learned.remove(entry.key)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 키워드 칩: 직접 등록 = 분류 색 채움, 기본 = 흰 바탕 + 분류 색 테두리
class KeywordChip extends StatelessWidget {
  final KeywordRule rule;
  final VoidCallback? onTap;
  const KeywordChip({super.key, required this.rule, this.onTap});

  @override
  Widget build(BuildContext context) {
    final car = rule.category == kCar;
    final color = car ? kCarColor : kOpsColor;
    final custom = !rule.isDefault;
    final fg = custom ? (car ? Colors.white : kOpsText) : (car ? kCarColor : kOpsText);
    return Material(
      color: custom ? color : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: color, width: 1.2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            rule.keyword,
            style: TextStyle(fontSize: 13, color: fg, fontWeight: custom ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final bool filled;
  const _LegendDot({required this.filled});

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: filled ? const Color(0xFF5F6368) : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF5F6368)),
    ),
  );
}

/// 업체 관리 > 지운 키워드: 체크한 것만 [다시 넣기], [모두 선택], [영구 삭제](확인).
/// 지운 기본 키워드는 영구 삭제해도 업데이트 때 되살아나지 않는다.
class RemovedKeywordsScreen extends StatefulWidget {
  final VendorBook book;
  final Future<void> Function() onChanged;
  const RemovedKeywordsScreen({super.key, required this.book, required this.onChanged});

  @override
  State<RemovedKeywordsScreen> createState() => _RemovedKeywordsScreenState();
}

class _RemovedKeywordsScreenState extends State<RemovedKeywordsScreen> {
  final _picked = <String>{}; // keywordKey

  List<KeywordRule> get _list => widget.book.removedKeywords;
  List<KeywordRule> get _selected => [
    for (final r in _list)
      if (_picked.contains(r.key)) r,
  ];

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(appSnackBar(content: Text(msg)));

  Future<void> _restore() async {
    final n = widget.book.restoreRemoved(_selected);
    _picked.clear();
    await widget.onChanged();
    if (!mounted) return;
    setState(() {});
    _toast('$n개를 다시 넣었어요');
  }

  Future<void> _purge() async {
    final sel = _selected;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('${sel.length}개를 지운 키워드 목록에서도 완전히 지울까요?\n다시 넣을 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD93025)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.book.purgeRemoved(sel);
    _picked.clear();
    await widget.onChanged();
    if (!mounted) return;
    setState(() {});
    _toast('${sel.length}개를 영구 삭제했어요');
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final allOn = list.isNotEmpty && list.every((r) => _picked.contains(r.key));
    return Scaffold(
      appBar: AppBar(
        title: Text('지운 키워드 (${list.length})'),
        actions: [
          TextButton(
            onPressed: list.isEmpty
                ? null
                : () => setState(() {
                    allOn ? _picked.clear() : _picked.addAll(list.map((r) => r.key));
                  }),
            child: Text(allOn ? '선택 해제' : '모두 선택'),
          ),
        ],
      ),
      body: list.isEmpty
          ? const Center(child: Text('지운 키워드가 없어요', style: TextStyle(color: Colors.black45)))
          : ListView(
              padding: EdgeInsets.only(bottom: listBottomPad(context, extra: 72)),
              children: [
                for (final r in list)
                  CheckboxListTile(
                    value: _picked.contains(r.key),
                    onChanged: (v) => setState(() => v == true ? _picked.add(r.key) : _picked.remove(r.key)),
                    secondary: CategoryBadge(r.category),
                    title: Text(r.keyword),
                    subtitle: Text(r.isDefault ? '기본 키워드' : '직접 등록', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
      bottomNavigationBar: list.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFD93025)),
                      onPressed: _picked.isEmpty ? null : _purge,
                      child: const Text('영구 삭제'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _picked.isEmpty ? null : _restore,
                      child: Text('다시 넣기${_picked.isEmpty ? '' : ' (${_picked.length})'}'),
                    ),
                  ],
                ),
              ),
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
