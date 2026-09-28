import 'dart:io';
import 'package:image/image.dart' as img;

img.Image _loadLogo(List<String> args) {
  if (args.isNotEmpty) return img.decodePng(File(args[0]).readAsBytesSync())!.convert(numChannels: 4);
  final decoder = img.IcoDecoder();
  final info = decoder.startDecode(File('assets/app_icon.ico').readAsBytesSync())!;
  img.Image? best;
  for (var i = 0; i < info.numFrames; i++) {
    final frame = decoder.decodeFrame(i)!;
    if (best == null || frame.width > best.width) best = frame;
  }
  return best!.convert(numChannels: 4);
}

img.Image _opaqueSquare(img.Image logo, int size, {double logoRatio = 0.72}) {
  final canvas = img.Image(width: size, height: size, numChannels: 3);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  final logoSize = (size * logoRatio).round();
  final scaled = img.copyResize(logo, width: logoSize, height: logoSize, interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, scaled, dstX: (size - logoSize) ~/ 2, dstY: (size - logoSize) ~/ 2);
  return canvas;
}

img.Image _macosIcon(img.Image logo, int size) {
  const work = 1024;
  final canvas = img.Image(width: work, height: work, numChannels: 4);
  img.fillRect(canvas, x1: 100, y1: 100, x2: 923, y2: 923, radius: 185, color: img.ColorRgba8(255, 255, 255, 255));
  const logoSize = 600;
  final scaled = img.copyResize(logo, width: logoSize, height: logoSize, interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, scaled, dstX: (work - logoSize) ~/ 2, dstY: (work - logoSize) ~/ 2);
  return size == work ? canvas : img.copyResize(canvas, width: size, height: size, interpolation: img.Interpolation.average);
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('écrit $path (${image.width}x${image.height})');
}

void main(List<String> args) {
  final logo = _loadLogo(args);

  _write('assets/app_icon.png', img.copyResize(logo, width: 256, height: 256, interpolation: img.Interpolation.cubic));

  const macDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
    _write('$macDir/app_icon_$size.png', _macosIcon(logo, size));
  }

  const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const iosIcons = {
    'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167, 'Icon-App-1024x1024@1x.png': 1024,
  };
  iosIcons.forEach((name, size) => _write('$iosDir/$name', _opaqueSquare(logo, size)));

  const androidIcons = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
  androidIcons.forEach((density, size) =>
      _write('android/app/src/main/res/mipmap-$density/ic_launcher.png', _macosIcon(logo, size)));

  const foregroundSizes = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
  foregroundSizes.forEach((density, size) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    final logoSize = (size * 0.5).round();
    final scaled = img.copyResize(logo, width: logoSize, height: logoSize, interpolation: img.Interpolation.cubic);
    img.compositeImage(canvas, scaled, dstX: (size - logoSize) ~/ 2, dstY: (size - logoSize) ~/ 2);
    _write('android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png', canvas);
  });

  const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  const launchImages = {'LaunchImage.png': 120, 'LaunchImage@2x.png': 240, 'LaunchImage@3x.png': 360};
  launchImages.forEach((name, size) => _write('$launchDir/$name',
      img.copyResize(logo, width: size, height: size, interpolation: img.Interpolation.cubic)));
}
