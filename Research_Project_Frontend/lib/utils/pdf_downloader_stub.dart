import 'dart:typed_data';

Future<String> saveOrOpenPdf(Uint8List bytes, String fileName) async {
  return 'PDF generated ($fileName), size: ${bytes.lengthInBytes} bytes';
}
