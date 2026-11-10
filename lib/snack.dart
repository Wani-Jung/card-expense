import 'package:flutter/material.dart';

/// 스낵바 버튼([되돌리기]·[보기]) 글자색: 어두운 스낵바 바탕에서 잘 보이는 밝은 노랑
const kSnackAction = Color(0xFFFFD54F);

/// 앱 공용 스낵바. 버튼이 있어도 몇 초 뒤 저절로 닫힌다 (최신 Flutter 는 action 이 있으면 기본으로 안 닫힘, REQ-47).
SnackBar appSnackBar({
  required Widget content,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) => SnackBar(content: content, action: action, duration: duration, persist: false);
