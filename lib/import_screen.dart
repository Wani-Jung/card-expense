import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ingest.dart';
import 'layout.dart';
import 'native.dart';

/// (전용판) 지난 문자 불러오기: 기간을 고르고 → 미리보기('이 기간 승인 문자 n건 (새 n · 중복 n)') → [불러오기].
/// SMS·MMS·RCS 후보 저장소 공통. 기간은 시작일 0시 ~ 종료일 다음 날 0시(미포함).

/// 미리보기 결과 (아직 넣지 않은 상태). [불러오기]를 누르면 이걸 돌려준다.
class ImportPreview {
  final InboxScan scan;
  final IngestReport report;

  /// 서로 다른 승인 건 수. 같은 문자가 SMS 와 RCS 후보 저장소에서 겹쳐 읽혀도 한 건으로 센다.
  /// 없으면 분류 결과 합계.
  final int? unique;
  const ImportPreview(this.scan, this.report, {this.unique});

  /// 기간 안의 승인 문자 (새 + 중복 + 무시했던)
  int get approvals => unique ?? report.fresh.length + report.dup + report.ignoredHits.length;

  /// 이미 들어와 있는 건 (겹쳐 읽힌 것 빼고)
  int get duplicates => approvals - report.fresh.length - report.ignoredHits.length;

  String get summary => [
    '새 ${report.fresh.length}',
    '중복 $duplicates',
    if (report.ignoredHits.isNotEmpty) '무시했던 ${report.ignoredHits.length}',
  ].join(' · ');
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 기본 기간: 1년 전 ~ 오늘
({DateTime from, DateTime to}) defaultImportRange(DateTime now) =>
    (from: DateTime(now.year - 1, now.month, now.day), to: _day(now));

enum QuickRange {
  thisMonth('이번 달'),
  lastMonth('지난달'),
  months3('최근 3개월'),
  year1('최근 1년');

  final String label;
  const QuickRange(this.label);

  /// 시작일·종료일 (둘 다 그날 포함)
  ({DateTime from, DateTime to}) range(DateTime now) {
    final today = _day(now);
    return switch (this) {
      thisMonth => (from: DateTime(now.year, now.month, 1), to: today),
      lastMonth => (from: DateTime(now.year, now.month - 1, 1), to: DateTime(now.year, now.month, 0)),
      months3 => (from: DateTime(now.year, now.month - 3, now.day), to: today),
      year1 => defaultImportRange(now),
    };
  }
}

/// 기간이 잘못됐으면 이유, 괜찮으면 null. 1년보다 이른 시작일은 허용.
String? importRangeError(DateTime from, DateTime to, DateTime now) {
  final today = _day(now);
  if (_day(to).isAfter(today) || _day(from).isAfter(today)) return '미래 날짜는 고를 수 없어요';
  if (_day(from).isAfter(_day(to))) return '시작일이 종료일보다 늦어요';
  return null;
}

/// 네이티브 조회 범위 [from 0시, to 다음 날 0시)
({DateTime start, DateTime end}) importQueryRange(DateTime from, DateTime to) =>
    (start: _day(from), end: DateTime(to.year, to.month, to.day + 1));

class ImportRangeScreen extends StatefulWidget {
  /// 기간의 문자를 읽어 분류만 해 본다 ([start, end) 밀리초 기준)
  final Future<ImportPreview> Function(DateTime start, DateTime end) preview;
  /// 테스트용 시계 (없으면 지금)
  final DateTime Function()? clock;
  const ImportRangeScreen({super.key, required this.preview, this.clock});

  @override
  State<ImportRangeScreen> createState() => _ImportRangeScreenState();
}

class _ImportRangeScreenState extends State<ImportRangeScreen> {
  late DateTime _from, _to;
  DateTime _now() => (widget.clock ?? DateTime.now)();
  ImportPreview? _result;
  bool _loading = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    final r = defaultImportRange(_now());
    _from = r.from;
    _to = r.to;
  }

  void _set(DateTime from, DateTime to) => setState(() {
    _from = from;
    _to = to;
    _result = null; // 기간이 바뀌면 미리보기 다시
    _failure = null;
  });

  Future<void> _pick({required bool start}) async {
    final now = _now();
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: _day(now), // 미래 날짜는 고를 수 없게
      helpText: start ? '시작일' : '종료일',
    );
    if (d == null) return;
    start ? _set(d, _to) : _set(_from, d);
  }

  Future<void> _runPreview() async {
    final q = importQueryRange(_from, _to);
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final r = await widget.preview(q.start, q.end);
      if (mounted) setState(() => _result = r);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _failure = e.code == 'NO_PERMISSION' ? '문자 권한을 먼저 허용해주세요' : '읽기 실패: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final error = importRangeError(_from, _to, now);
    final r = _result;
    Widget dateBox(String label, DateTime d, bool start) => Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => _pick(start: start),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
            const SizedBox(height: 2),
            Text(_fmt(d), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F1F1F))),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('지난 문자 불러오기')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPad(context)),
        children: [
          const Text(
            '고른 기간의 문자함(SMS·MMS·RCS)에서 카드 승인 문자만 찾아요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              dateBox('시작일', _from, true),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
              dateBox('종료일', _to, false),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final q in QuickRange.values)
                ActionChip(
                  label: Text(q.label),
                  onPressed: () {
                    final x = q.range(now);
                    _set(x.from, x.to);
                  },
                ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: const TextStyle(color: Color(0xFFD93025), fontSize: 13)),
            ),
          const SizedBox(height: 16),
          if (r == null)
            FilledButton(
              onPressed: error != null || _loading ? null : _runPreview,
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('이 기간 문자 확인'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF1F4F9), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이 기간 승인 문자 ${r.approvals}건',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text('(${r.summary})', style: const TextStyle(fontSize: 14, color: Color(0xFF3C4043))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, r),
              child: Text(r.report.fresh.isEmpty && r.report.ignoredHits.isEmpty ? '확인' : '불러오기'),
            ),
          ],
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_failure!, style: const TextStyle(color: Color(0xFFD93025), fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
