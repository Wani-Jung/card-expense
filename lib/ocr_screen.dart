import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'expense.dart';
import 'native.dart';
import 'ocr_parse.dart';
import 'sms_parser.dart';
import 'vendor.dart';

/// 확인 화면에서 고른 결과.
class OcrResult {
  final List<ParsedSms> add; // 새로 넣을 것
  final List<String> revive; // 무시했던 문자 중 다시 분류 대기로 돌릴 id
  const OcrResult(this.add, this.revive);
}

enum _Status { fresh, dup, ignored, invalid }

/// 문자 캡처화면 업로드 (OCR). 사진 선택기 → 긴 이미지는 잘라서 → 기기 안에서 한국어 인식 → 확인 화면.
/// 캡처 이미지는 저장하지 않고 인식이 끝나면 바로 지운다.
class OcrScreen extends StatefulWidget {
  final String digits;
  final Map<String, Expense> existing;

  /// 가맹점 이름으로 차량비/운영비 추천.
  final Recommendation? Function(String merchant) recommend;
  const OcrScreen({super.key, required this.digits, required this.existing, required this.recommend});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  List<OcrCandidate>? _cands;
  String? _progress;
  int _images = 0;

  _Status _statusOf(OcrCandidate c) {
    final id = c.id;
    if (id == null) return _Status.invalid;
    final ex = widget.existing[id];
    if (ex == null) return _Status.fresh;
    return ex.category == kIgnored ? _Status.ignored : _Status.dup;
  }

  Future<void> _pick() async {
    // 안드로이드 사진 선택기: 저장소 권한 없이 고른 사진만 받는다.
    final impl = ImagePickerPlatform.instance;
    if (impl is ImagePickerAndroid) impl.useAndroidPhotoPicker = true;
    final files = await ImagePicker().pickMultiImage(requestFullMetadata: false);
    if (files.isEmpty) return;

    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    final now = DateTime.now();
    final all = <OcrCandidate>[];
    final ids = <String>{};
    try {
      for (var i = 0; i < files.length; i++) {
        setState(() => _progress = '글자 인식 중… (${i + 1}/${files.length})');
        final slices = await Native.sliceImage(files[i].path);
        final texts = <String>[];
        for (final s in slices) {
          final r = await recognizer.processImage(InputImage.fromFilePath(s));
          // 위에서 아래 순서로 이어 붙인다
          final blocks = [...r.blocks]..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
          texts.add(blocks.map((b) => b.text).join('\n'));
          if (s != files[i].path) _deleteQuietly(s);
        }
        _deleteQuietly(files[i].path);
        for (final c in ocrCandidates(texts, widget.digits, now)) {
          final id = c.id;
          if (id != null && !ids.add(id)) continue; // 여러 장에 같은 문자가 찍힌 경우
          all.add(c);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('인식하지 못했어요: $e')));
      }
    } finally {
      await recognizer.close();
    }
    for (final c in all) {
      c.selected = _statusOf(c) == _Status.fresh;
    }
    if (mounted) {
      setState(() {
        _progress = null;
        _images = files.length;
        _cands = all;
      });
    }
  }

  void _deleteQuietly(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  // ---------------- 수정 ----------------

  Future<void> _editDate(OcrCandidate c) async {
    final base = c.dateTime ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t == null) return;
    setState(() {
      c.dateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      c.selected = _statusOf(c) == _Status.fresh;
    });
  }

  Future<void> _editAmount(OcrCandidate c) async {
    final v = await _ask('금액 (원)', c.amount?.toString() ?? '', number: true);
    if (v == null) return;
    setState(() {
      c.amount = int.tryParse(v.replaceAll(RegExp(r'\D'), ''));
      c.selected = _statusOf(c) == _Status.fresh;
    });
  }

  Future<void> _editMerchant(OcrCandidate c) async {
    final v = await _ask('가맹점', c.merchant);
    if (v != null) setState(() => c.merchant = v.trim());
  }

  Future<String?> _ask(String title, String initial, {bool number = false}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('확인')),
        ],
      ),
    );
  }

  void _submit() {
    final add = <ParsedSms>[];
    final revive = <String>[];
    for (final c in _cands!.where((c) => c.selected && c.valid)) {
      switch (_statusOf(c)) {
        case _Status.fresh:
          add.add(c.toParsed());
        case _Status.ignored:
          revive.add(c.id!);
        default:
      }
    }
    Navigator.pop(context, OcrResult(add, revive));
  }

  // ---------------- 화면 ----------------

  @override
  Widget build(BuildContext context) {
    final cands = _cands;
    final selected = cands?.where((c) => c.selected && c.valid && _statusOf(c) != _Status.dup).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('문자 캡처화면 업로드')),
      body: _progress != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_progress!),
            ]))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '메시지 앱에서 카드 문자 대화방을 스크롤 캡처로 길게 찍어서 올리면 한 번에 들어가요',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 4),
                const Text('캡처 이미지는 기기 안에서 글자만 읽고 바로 지워요',
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(cands == null ? '캡처 이미지 선택 (여러 장 가능)' : '다른 이미지 선택'),
                  onPressed: _pick,
                ),
                if (cands != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    cands.isEmpty
                        ? '이미지 $_images장에서 카드번호 ${widget.digits} 승인 문자를 찾지 못했어요'
                        : '이미지 $_images장에서 ${cands.length}건 찾았어요. 확인하고 추가해주세요',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final c in cands) _card(c),
                ],
              ],
            ),
      bottomNavigationBar: cands == null || cands.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: selected == 0 ? null : _submit,
                  child: Text('선택한 $selected건 추가'),
                ),
              ),
            ),
    );
  }

  Widget _card(OcrCandidate c) {
    final status = _statusOf(c);
    final (label, color) = switch (status) {
      _Status.fresh => ('새 내역', const Color(0xFF2E7D32)),
      _Status.dup => ('이미 있음', Colors.black45),
      _Status.ignored => ('무시했던 문자', const Color(0xFF8D6E63)),
      _Status.invalid => ('확인 필요', Colors.red),
    };
    final d = c.dateTime;
    Widget field(String text, VoidCallback onTap, {bool missing = false, bool bold = false}) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Flexible(
                child: Text(text,
                    style: TextStyle(
                      color: missing ? Colors.red : null,
                      fontWeight: bold ? FontWeight.bold : null,
                      fontSize: bold ? 17 : 14,
                    )),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 14, color: Colors.black38),
            ]),
          ),
        );
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: status == _Status.invalid ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: c.selected && status != _Status.dup,
            onChanged: c.valid && status != _Status.dup ? (v) => setState(() => c.selected = v ?? false) : null,
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(4)),
                  child: Text(label, style: TextStyle(fontSize: 12, color: color)),
                ),
                if (widget.recommend(c.merchant) case final r?) ...[
                  const SizedBox(width: 6),
                  Text(
                    r.source == RecSource.learned ? r.badge : '${categoryLabel(r.category)} 추천',
                    style: TextStyle(fontSize: 12, color: r.category == kCar ? const Color(0xFF2E7D32) : const Color(0xFF8D6E00)),
                  ),
                ],
                if (c.isCancel) ...[
                  const SizedBox(width: 6),
                  const Text('승인취소', style: TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ]),
              field(
                d == null ? '날짜·시간을 못 읽었어요 (눌러서 입력)' : fmtDateTime(d),
                () => _editDate(c),
                missing: d == null,
              ),
              field(c.merchant.isEmpty ? '(가맹점 없음 · 눌러서 입력)' : c.merchant, () => _editMerchant(c)),
              field(
                c.amount == null ? '금액을 못 읽었어요 (눌러서 입력)' : won(c.isCancel ? -c.amount! : c.amount!),
                () => _editAmount(c),
                missing: c.amount == null,
                bold: true,
              ),
              Text(c.raw.replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black38)),
            ]),
          ),
        ]),
      ),
    );
  }
}
