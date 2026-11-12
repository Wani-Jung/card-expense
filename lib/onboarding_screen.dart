import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'budget.dart';
import 'flavor.dart';
import 'layout.dart';
import 'sms_parser.dart';

/// 사용법을 마치고 이어서 할 일 (3단계의 버튼)
enum OnboardingAction { none, importInbox, paste }

const kDefaultSender = '1588-1600';

/// 카드번호 네자리 설명 (괄호부터 다음 줄, C3)
const kDigitsHelp = '승인 문자에 적힌 카드번호 네자리\n(예: "NH기업0000승인" 이면 0000)';

bool validCardSettings(String digits, String sender) =>
    RegExp(r'^\d{4}$').hasMatch(digits) && normalizeNumber(sender).length >= 7;

/// 사전입력사항 3단계 (첫 실행, 메뉴 > 사전입력사항에서 다시 보기). 넘기기·건너뛰기.
/// ① 이번 달 전체·차량비 수립 ② 발신번호·카드번호 네자리 ③ 과거 이력 불러오기(전용판) / 붙여넣기·공유하기 안내.
/// 첫 실행에서는 ②가 꼭 필요하다 (카드번호가 없으면 문자를 못 알아봄) — 건너뛰기를 눌러도 ②에서 멈춘다.
class OnboardingScreen extends StatefulWidget {
  /// 메뉴에서 연 경우 false (닫기 버튼, 카드 설정은 이미 있음)
  final bool firstRun;
  final MonthBudget budget;
  final String? digits, sender;
  final Future<void> Function(int? total, int? car) onBudget;
  final Future<void> Function(String digits, String sender) onSettings;
  final void Function(OnboardingAction action) onDone;

  const OnboardingScreen({
    super.key,
    required this.firstRun,
    required this.budget,
    required this.digits,
    required this.sender,
    required this.onBudget,
    required this.onSettings,
    required this.onDone,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  late final _total = TextEditingController(text: widget.budget.total == null ? '' : manwon(widget.budget.total!));
  late final _car = TextEditingController(text: widget.budget.car == null ? '' : manwon(widget.budget.car!));
  late final _digits = TextEditingController(text: widget.digits ?? '');
  late final _sender = TextEditingController(text: widget.sender ?? kDefaultSender);
  late bool _settingsSaved = widget.digits != null && widget.sender != null;
  String? _budgetError;

  bool get _cardValid => validCardSettings(_digits.text, _sender.text);

  void _go(int page) {
    FocusScope.of(context).unfocus();
    _pages.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// ① 수립 저장. 비우면 그대로 둔다. 잘못 넣었으면 안내하고 false.
  Future<bool> _saveBudget() async {
    try {
      final t = _total.text.trim().isEmpty ? null : parseManwon(_total.text);
      final c = _car.text.trim().isEmpty ? null : parseManwon(_car.text);
      if (t != null && c != null && c > t) {
        setState(() => _budgetError = '차량비가 전체보다 클 수 없어요');
        return false;
      }
      setState(() => _budgetError = null);
      if (t != widget.budget.total || c != widget.budget.car) await widget.onBudget(t, c);
      return true;
    } on FormatException catch (e) {
      setState(() => _budgetError = e.message);
      return false;
    }
  }

  /// ② 카드 설정 저장. 형식이 맞아야 넘어간다.
  Future<bool> _saveSettings() async {
    if (!_cardValid) return false;
    final d = _digits.text, s = _sender.text.trim();
    if (d != widget.digits || s != widget.sender || !_settingsSaved) await widget.onSettings(d, s);
    _settingsSaved = true;
    return true;
  }

  Future<void> _next() async {
    if (_page == 0 && !await _saveBudget()) return;
    if (_page == 1 && !await _saveSettings()) return;
    if (_page < 2) {
      _go(_page + 1);
    } else {
      widget.onDone(OnboardingAction.none);
    }
  }

  Future<void> _skip() async {
    if (_page == 0) await _saveBudget();
    if (_page == 1) await _saveSettings();
    if (!_settingsSaved) {
      // 첫 실행: 카드번호·발신번호는 꼭 필요하다
      if (_page != 1) _go(1);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('카드번호 네자리와 발신번호는 꼭 넣어야 시작할 수 있어요')));
      }
      return;
    }
    widget.onDone(OnboardingAction.none);
  }

  Future<void> _finishWith(OnboardingAction a) async {
    if (!_settingsSaved && !await _saveSettings()) return;
    widget.onDone(a);
  }

  Widget _title(int n, String title, [String? sub]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$n / 3', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8D6200))),
      const SizedBox(height: 6),
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      if (sub != null) ...[
        const SizedBox(height: 8),
        Text(keepWords(sub), style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF5F6368))),
      ],
      const SizedBox(height: 20),
    ],
  );

  static const _label = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  Widget _money(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label, suffixText: '만원', border: const OutlineInputBorder()),
    ),
  );

  Widget _budgetPage() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    children: [
      _title(1, '이번 달 수립 금액'),
      _money('전체 (합계)', _total),
      _money('차량비', _car),
      if (_budgetError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_budgetError!, style: const TextStyle(color: Color(0xFFD93025))),
        ),
    ],
  );

  Widget _cardPage() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    children: [
      _title(2, '카드 문자 설정'),
      const Text('카드번호 네자리', style: _label),
      const SizedBox(height: 4),
      Text(keepWords(kDigitsHelp), style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 8),
      TextField(
        controller: _digits,
        keyboardType: TextInputType.number,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 26, letterSpacing: 10),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(child: Text('발신번호', style: _label)),
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => setState(() => _sender.text = kDefaultSender),
            child: const Text('기본값으로'),
          ),
        ],
      ),
      Text(keepWords('카드 승인 문자를 보내는 번호 (기본값 $kDefaultSender)'), style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 8),
      TextField(
        controller: _sender,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
        style: const TextStyle(fontSize: 22),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
      ),
    ],
  );

  Widget _historyPage() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    children: isFullEdition
        ? [
            _title(3, '지난 결제 불러오기', '문자함에 남아 있는 카드 승인 문자를 기간을 골라 한 번에 가져올 수 있어요. 앞으로 오는 문자는 자동으로 들어와요.'),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.history),
              label: const Text('지난 문자 불러오기'),
              onPressed: _cardValid || _settingsSaved ? () => _finishWith(OnboardingAction.importInbox) : null,
            ),
          ]
        : [
            _title(3, '지난 결제 넣기', '지난 승인 문자는 두 가지 방법으로 넣을 수 있어요. 앞으로 오는 문자는 알림 감지를 켜면 자동으로 들어와요.'),
            _howTo(Icons.content_paste, '붙여넣기', '메시지 앱에서 카드 문자를 길게 눌러 복사한 뒤 메뉴 > 결제내역 입력 > 문자 붙여넣기'),
            _howTo(Icons.share, '공유하기', '메시지 앱에서 문자를 골라 공유 → $kAppName'),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.content_paste),
              label: const Text('지금 문자 붙여넣기'),
              onPressed: _cardValid || _settingsSaved ? () => _finishWith(OnboardingAction.paste) : null,
            ),
          ],
  );

  Widget _howTo(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1F3A68)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(keepWords(body), style: const TextStyle(color: Color(0xFF5F6368))),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final last = _page == 2;
    final canNext = _page != 1 || _cardValid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('사전입력사항'),
        automaticallyImplyLeading: !widget.firstRun,
        actions: [TextButton(onPressed: _skip, child: const Text('건너뛰기'))],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pages,
              // 넘기기: ②에서 카드 설정이 안 맞으면 손으로 넘겨도 다음 장으로 못 간다
              physics: _page == 1 && !_cardValid && !_settingsSaved ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: (p) async {
                if (_page == 0 && p > 0) await _saveBudget();
                if (_page == 1 && p > 1) await _saveSettings();
                setState(() => _page = p);
              },
              children: [_budgetPage(), _cardPage(), _historyPage()],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, listBottomPad(context) - 24),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? const Color(0xFF1F3A68) : const Color(0xFFDADCE0),
                    ),
                  ),
                const Spacer(),
                if (_page > 0) TextButton(onPressed: () => _go(_page - 1), child: const Text('이전')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canNext ? _next : null,
                  child: Text(last ? (widget.firstRun ? '시작하기' : '닫기') : '다음'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
