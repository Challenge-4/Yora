import 'dart:io';

import 'package:flutter/widgets.dart';

double mobileBottomInset(BuildContext context) {
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  return Platform.isIOS ? inset / 2 : inset;
}
