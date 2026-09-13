import 'dart:typed_data';

class PickedKmlFile {
  final String name;
  final Uint8List bytes;

  const PickedKmlFile({required this.name, required this.bytes});
}

Future<PickedKmlFile?> pickKmlFile() async {
  throw UnsupportedError('KML file upload is only supported on web');
}
