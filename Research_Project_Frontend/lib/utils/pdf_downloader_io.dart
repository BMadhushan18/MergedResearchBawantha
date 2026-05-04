import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveOrOpenPdf(Uint8List bytes, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  
  // Open the PDF file
  try {
    await OpenFile.open(path, type: 'application/pdf');
  } catch (e) {
    // Silently fail if PDF app not available; file is still saved
  }
  
  return path;
}
