import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Generate App Icon', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: Key('icon'),
          child: ColoredBox(
            color: Color(0xFF154B3C),
            child: Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.point_of_sale_rounded,
                size: 320,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
    final finder = find.byKey(const Key('icon'));
    final RenderRepaintBoundary boundary = tester.firstRenderObject(finder);
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    final file = File('assets/icon.png');
    await file.writeAsBytes(buffer);
  });
}
