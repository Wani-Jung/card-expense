import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native.dart';

/// (전용판) 메뉴 '문자 저장소 진단'. SMS/MMS 와 삼성 RCS 후보 저장소가 열리는지, 몇 행인지, 컬럼이 뭔지 보여준다.
class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key});

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> {
  late final Future<List<StoreDiagnosis>?> _result = Native.diagnoseStores();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문자 저장소 진단')),
      body: FutureBuilder<List<StoreDiagnosis>?>(
        future: _result,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data;
          if (list == null) {
            return const Center(child: Text('진단하지 못했어요. 문자 권한을 확인해주세요.'));
          }
          final text = list.map((d) => d.summary).join('\n\n');
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text('카드번호 일치가 0보다 큰 저장소가 있으면 지난 문자 불러오기에 자동으로 포함돼요.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              for (final d in list)
                Card(
                  color: d.ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SelectableText(d.summary, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('결과 복사'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: text));
                  messenger.showSnackBar(const SnackBar(content: Text('진단 결과를 복사했어요')));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
