import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'kml_file_picker_stub.dart';

Future<PickedKmlFile?> pickKmlFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.kml,.kmz,application/vnd.google-earth.kml+xml,application/vnd.google-earth.kmz';
  input.style.display = 'none';
  web.document.body?.appendChild(input);

  final completer = Completer<PickedKmlFile?>();
  input.onChange.listen((_) async {
    try {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }
      final file = files.item(0);
      if (file == null) {
        completer.complete(null);
        return;
      }
      final buffer = await file.arrayBuffer().toDart;
      completer.complete(
        PickedKmlFile(
          name: file.name,
          bytes: Uint8List.view(buffer.toDart),
        ),
      );
    } catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    } finally {
      input.remove();
    }
  });

  input.click();
  return completer.future;
}
