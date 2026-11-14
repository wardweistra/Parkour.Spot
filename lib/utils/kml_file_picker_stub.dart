import 'package:file_selector/file_selector.dart';

import 'picked_kml_file.dart';

export 'picked_kml_file.dart' show PickedKmlFile;

/// Native: system file picker. Returns null when the user cancels.
///
/// No type filter: Android file providers report KML/KMZ under inconsistent
/// MIME types (often `application/octet-stream`), which would grey the files
/// out. The upload function validates the contents.
Future<PickedKmlFile?> pickKmlFile() async {
  final file = await openFile();
  if (file == null) return null;
  return PickedKmlFile(name: file.name, bytes: await file.readAsBytes());
}
