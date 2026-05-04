import 'dart:typed_data';
import 'dart:html' as html;

Future<String> saveOrOpenPdf(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..target = '_blank';
  anchor.click();
  html.Url.revokeObjectUrl(url);
  return 'Downloaded in browser: $fileName';
}
