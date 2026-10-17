import 'dart:math' as math;
import 'dart:ui';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

const double kMinWindowWidth = 960.0;
const double kMinWindowHeight = 650.0;

const String prefsWindowMaximizedKey = 'window_maximized';
const String prefsWindowXKey = 'window_x';
const String prefsWindowYKey = 'window_y';
const String prefsWindowWidthKey = 'window_width';
const String prefsWindowHeightKey = 'window_height';

Future<Rect> defaultRestoreBounds() async {
  final display = await screenRetriever.getPrimaryDisplay();
  final visibleSize = display.visibleSize ?? display.size;
  final visiblePosition = display.visiblePosition ?? Offset.zero;
  const scale = 0.8;
  final width = visibleSize.width * scale;
  final height = visibleSize.height * scale;
  final left = visiblePosition.dx + (visibleSize.width - width) / 2;
  final top = visiblePosition.dy + (visibleSize.height - height) / 2;
  return Rect.fromLTWH(left, top, width, height);
}

Future<Rect> sanitizedRestoreBounds(Rect saved) async {
  final displays = await screenRetriever.getAllDisplays();
  Rect? hostDisplayBounds;
  for (final display in displays) {
    final size = display.visibleSize ?? display.size;
    final position = display.visiblePosition ?? Offset.zero;
    final displayRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    if (displayRect.overlaps(saved)) {
      hostDisplayBounds = displayRect;
      break;
    }
  }
  if (hostDisplayBounds == null) {
    return defaultRestoreBounds();
  }
  final width = saved.width.clamp(kMinWindowWidth, hostDisplayBounds.width);
  final height = saved.height.clamp(kMinWindowHeight, hostDisplayBounds.height);
  final left = saved.left.clamp(hostDisplayBounds.left, hostDisplayBounds.right - width);
  final top = saved.top.clamp(hostDisplayBounds.top, hostDisplayBounds.bottom - height);
  return Rect.fromLTWH(left, top, width, height);
}

Future<void> centerWindowOnPrimaryDisplay() async {
  final bounds = await windowManager.getBounds();
  final display = await screenRetriever.getPrimaryDisplay();
  final visibleSize = display.visibleSize ?? display.size;
  final visiblePosition = display.visiblePosition ?? Offset.zero;
  final left = visiblePosition.dx + (visibleSize.width - bounds.width) / 2;
  final top = visiblePosition.dy + (visibleSize.height - bounds.height) / 2;
  await windowManager.setPosition(Offset(left, top));
}

Future<Rect?> displayAreaContaining(Rect bounds) async {
  final displays = await screenRetriever.getAllDisplays();
  Rect? best;
  var bestOverlap = 0.0;
  for (final display in displays) {
    final size = display.visibleSize ?? display.size;
    final position = display.visiblePosition ?? Offset.zero;
    final area = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    final overlap = area.intersect(bounds);
    final surface = overlap.width > 0 && overlap.height > 0 ? overlap.width * overlap.height : 0.0;
    if (surface > bestOverlap) {
      bestOverlap = surface;
      best = area;
    }
  }
  return best;
}

Future<void> centerWindowOnDisplayArea(Rect? area) async {
  if (area == null) {
    await centerWindowOnPrimaryDisplay();
    return;
  }
  final bounds = await windowManager.getBounds();
  final width = math.min(math.max(bounds.width, kMinWindowWidth), area.width);
  final height = math.min(math.max(bounds.height, kMinWindowHeight), area.height);
  await windowManager.setBounds(Rect.fromLTWH(
    area.left + (area.width - width) / 2,
    area.top + (area.height - height) / 2,
    width,
    height,
  ));
}
