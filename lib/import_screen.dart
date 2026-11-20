import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'disclosure.dart';
import 'expense.dart';
import 'ingest.dart';
import 'layout.dart';
import 'native.dart';
import 'notice_dialog.dart';
import 'sms_parser.dart';

/// (전용판) 지난 문자 불러오기: 기간을 고르고 → 미리보기('이 기간 승인 문자 n건 (새 n · 중복 n)') → [불러오기].
/// SMS·MMS·RCS 후보 저장소 공통. 기간은 시작일 0시 ~ 종료일 다음 날 0시(미포함).
/// 메뉴의 [ImportRangeScreen] 과 사전입력사항 3단계(REQ-54)가 같은 [ImportRangePanel]·[previewImportRange] 를 쓴다.

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

/// 기간의 문자를 읽어 분류만 해 본다 (아직 넣지 않음). 메뉴·사전입력 공용.
/// [existing] 지금 저장된 내역 (id → 내역).
Future<ImportPreview> previewImportRange(
  DateTime start,
  DateTime end, {
  required String digits,
  required Map<String, Expense> existing,
}) async {
  final scan = await Native.readSmsInbox(start, end);
  return importPreviewOf(scan, digits: digits, existing: existing);
}

/// 읽어 온 문자를 분류한다 (REQ-59). 같은 문자가 SMS 와 RCS 후보 저장소 등에서 두 번 읽히면 **한 번만** 센다 —
/// 그래야 미리보기('새 n · 중복 n')와 불러온 뒤 결과 알림의 숫자가 같다. 중복은 이미 저장된 내역과 겹친 것만.
/// 승인 문자로 읽히는 건 승인 id 로, 아닌 건 본문으로 같은지 본다.
ImportPreview importPreviewOf(InboxScan scan, {required String digits, required Map<String, Expense> existing}) {
  final seen = <String>{};
  final unique = <RawSms>[];
  for (final r in scan.items) {
    final id = parseSms(r.body, cardDigits: digits, receivedAt: r.receivedAt)?.id;
    if (seen.add(id ?? 'raw:${r.body.trim()}')) unique.add(r);
  }
  final report = classifyMessages(unique, digits: digits, existing: existing);
  return ImportPreview(scan, report, unique: report.fresh.length + report.dup + report.ignoredHits.length);
}

/// 사전입력 3단계용: 문자 권한이 없으면 안내 화면(disclosure) → 시스템 권한 창 → 결과를 기다린다.
/// 허용되면 true, [나중에]·거부·영구 거부면 false. (권한 창 결과는 앱이 다시 앞으로 올 때 확인한다)
Future<bool> ensureSmsForImport(
  BuildContext context, {
  Future<PermStatus> Function()? status,
  Future<bool> Function(BuildContext)? request,
}) async {
  final check = status ?? Native.permissionStatus;
  if ((await check()).sms == true) return true;
  if ((await check()).smsBlocked) return false;
  if (!context.mounted) return false;
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(onResume: () {
    if (!resumed.isCompleted) resumed.complete();
  });
  try {
    if (!await (request ?? requestSmsWithDisclosure)(context)) return false;
    // 권한 창이 닫히면 앱이 다시 앞으로 온다. 혹시 신호를 놓쳐도 1분 뒤에는 상태만 보고 끝낸다
    for (var i = 0; i < 120 && !resumed.isCompleted; i++) {
      if ((await check()).sms == true) return true;
      await Future.any([resumed.future, Future<void>.delayed(const Duration(milliseconds: 500))]);
    }
    return (await check()).sms == true;
  } finally {
    listener.dispose();
  }
}

/// 메뉴 > 결제내역 입력 > 지난 문자 불러오기 (기본 기간 최근 1년). [불러오기]를 누르면 미리보기를 돌려준다.
class ImportRangeScreen extends StatelessWidget {
  /// 기간의 문자를 읽어 분류만 해 본다 ([start, end) 밀리초 기준)
  final Future<ImportPreview> Function(DateTime start, DateTime end) preview;

  /// 테스트용 시계 (없으면 지금)
  final DateTime Function()? clock;
  const ImportRangeScreen({super.key, required this.preview, this.clock});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('지난 문자 불러오기')),
    body: ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPad(context)),
      children: [
        ImportRangePanel(preview: preview, clock: clock, onConfirm: (r) => Navigator.pop(context, r)),
      ],
    ),
  );
}

/// 기간 고르기(시작일·종료일 + 빠른 선택) → [이 기간 문자 확인] 미리보기 → [불러오기]/[확인].
/// 메뉴 화면과 사전입력 3단계가 같이 쓴다.
class ImportRangePanel extends StatefulWidget {
  final Future<ImportPreview> Function(DateTime start, DateTime end) preview;

  /// [불러오기](새 건이 없으면 [확인])를 눌렀을 때
  final void Function(ImportPreview result) onConfirm;

  /// 처음 기간 (없으면 최근 1년)
  final ({DateTime from, DateTime to}) Function(DateTime now)? initialRange;

  /// 미리보기 전에 할 일 (사전입력: 카드 설정 저장·문자 권한). false 면 미리보기를 하지 않는다
  final Future<bool> Function()? beforePreview;

  /// 위쪽 한 줄 설명을 보일지
  final bool showIntro;
  final DateTime Function()? clock;

  const ImportRangePanel({
    super.key,
    required this.preview,
    required this.onConfirm,
    this.initialRange,
    this.beforePreview,
    this.showIntro = true,
    this.clock,
  });

  @override
  State<ImportRangePanel> createState() => _ImportRangePanelState();
}

class _ImportRangePanelState extends State<ImportRangePanel> {
  late DateTime _from, _to;
  DateTime _now() => (widget.clock ?? DateTime.now)();
  ImportPreview? _result;
  bool _loading = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    final r = (widget.initialRange ?? defaultImportRange)(_now());
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
      if (widget.beforePreview != null && !await widget.beforePreview!()) return;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showIntro) ...[
          const Text(
            '고른 기간의 문자함(SMS·MMS·RCS)에서 카드 승인 문자만 찾아요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
          ),
          const SizedBox(height: 12),
        ],
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
                Text('이 기간 승인 문자 ${r.approvals}건', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('(${r.summary})', style: const TextStyle(fontSize: 14, color: Color(0xFF3C4043))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => widget.onConfirm(r),
            child: Text(r.report.fresh.isEmpty && r.report.ignoredHits.isEmpty ? '확인' : '불러오기'),
          ),
        ],
        if (_failure != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_failure!, style: const TextStyle(color: Color(0xFFD93025), fontSize: 13)),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// 불러오기 결과 (REQ-61): 검사 건수 같은 진단 숫자는 빼고 경우별로 한두 줄. 진단은 제목 길게 누르기로만
// ------------------------------------------------------------------

/// 새로 넣었을 때 (메인 스낵바·사전입력 3단계 공용). 중복이 있으면 한 줄 더
String importAddedMessage(int added, int skipped) =>
    ['분류 대기에 $added건 넣었어요', if (skipped > 0) '이미 있던 $skipped건은 건너뛰었어요'].join('\n');

const kNoNewImportTitle = '새로 불러온 문자가 없어요';
const kNoApprovalTitle = '이 기간엔 카드 승인 문자가 없어요';
const kNoApprovalBody = '카드 문자 설정의 카드번호 끝 4자리가\n맞는지 확인해 보세요.';
String noNewImportBody(int n) => '이 기간 카드 승인 문자 $n건은\n모두 이미 들어와 있어요.';

/// 새로 넣은 게 없을 때의 팝업. 승인 문자가 아예 없으면 카드번호 확인 안내 + [카드 문자 설정] 작은 링크.
/// 제목을 길게 누르면 [importDiagDialog] (검사 건수·주소 형식).
Widget importResultDialog(BuildContext context, ImportPreview p, {VoidCallback? onCardSettings}) {
  final none = p.approvals == 0;
  return NoticeDialog(
    icon: const NoticeInfoIcon(),
    title: none ? kNoApprovalTitle : kNoNewImportTitle,
    body: none ? kNoApprovalBody : noNewImportBody(p.approvals),
    onTitleLongPress: () => showDialog<void>(context: context, builder: (_) => importDiagDialog(p.scan)),
    child: none && onCardSettings != null
        ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () {
                Navigator.pop(context);
                onCardSettings();
              },
              child: const Text('카드 문자 설정'),
            ),
          )
        : null,
  );
}

/// 숨은 진단 (결과 팝업 제목 길게 누르기): 검사한 문자·발신번호 일치·찾은 문자, 카드 승인 문자의 저장소별 주소 형식
Widget importDiagDialog(InboxScan scan) => NoticeDialog(
  title: '불러오기 진단',
  stats: [
    NoticeStat('검사한 문자', '${scan.scanned}건'),
    NoticeStat('발신번호 일치', '${scan.senderMatched}건'),
    NoticeStat('찾은 문자', '${scan.items.length}건'),
  ],
  body: 'SMS ${scan.smsScanned} · MMS ${scan.mmsScanned} · 기타 저장소 ${scan.otherScanned} (카드번호로 찾음 ${scan.otherMatched})',
  child: scan.addrSamples.isEmpty
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText(
            '카드 승인 문자의 주소 형식\n${scan.addrSamples.join('\n')}',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
);
