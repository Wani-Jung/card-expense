import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 스크롤 목록 끝 여백. 앱이 하단 내비게이션 바 뒤까지 그려지므로(edge-to-edge)
/// 마지막 항목이 바에 가리지 않게 바 높이(viewPadding.bottom) + 24 를 둔다.
/// 바 높이를 0 으로 알려 주는 기기가 있어도 가리지 않게 최소 48(3버튼 바 높이)은 확보한다.
double listBottomPad(BuildContext context, {double extra = 24}) =>
    math.max(MediaQuery.of(context).viewPadding.bottom, 48) + extra;
