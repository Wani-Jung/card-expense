import 'package:flutter/material.dart';

import 'expense.dart';

const kCarColor = Color(0xFF2E7D32);
const kOpsColor = Color(0xFFFFC107);
const kOpsText = Color(0xFF4E2A00); // 노랑 위에서 잘 읽히는 진한 갈색

/// 누를 수 없는 고정 분류 배지 '차량'/'운영'(/'무시'). 메인 내역 목록·업체 관리 목록 공용.
class CategoryBadge extends StatelessWidget {
  final String? category;
  const CategoryBadge(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (category) {
      kCar => ('차량', kCarColor, Colors.white),
      kOps => ('운영', kOpsColor, kOpsText),
      _ => ('무시', Colors.black12, Colors.black54),
    };
    return Container(
      width: 44,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
    );
  }
}
