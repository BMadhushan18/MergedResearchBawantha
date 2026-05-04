import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FilePreviewWidget extends StatelessWidget {
  final PlatformFile file;

  const FilePreviewWidget({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final ext = (file.extension ?? '').toLowerCase();

    if (ext == 'csv') {
      return _CsvPreview(file: file);
    }

    if (ext == 'xlsx' || ext == 'xls') {
      return _ExcelPreview(file: file);
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(file.name),
        subtitle: Text('Preview is limited for .$ext files. File size: ${file.size} bytes'),
      ),
    );
  }
}

class _CsvPreview extends StatelessWidget {
  final PlatformFile file;

  const _CsvPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    if (file.bytes == null) {
      return const Card(child: ListTile(title: Text('CSV preview unavailable')));
    }

    final text = utf8.decode(file.bytes!, allowMalformed: true);
    final lines = text.split('\n').take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CSV Preview', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...lines.map((line) => Text(line, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _ExcelPreview extends StatelessWidget {
  final PlatformFile file;

  const _ExcelPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    if (file.bytes == null) {
      return const Card(child: ListTile(title: Text('Excel preview unavailable')));
    }

    late final List<List<Data?>> rows;
    try {
      final excel = Excel.decodeBytes(file.bytes!);
      if (excel.tables.isEmpty) {
        return const Card(child: ListTile(title: Text('No sheets found in workbook')));
      }

      final sheet = excel.tables.values.first;
      rows = sheet.rows.take(8).toList();
    } catch (_) {
      // Some Excel files contain unsupported style/format metadata.
      return Card(
        child: ListTile(
          leading: const Icon(Icons.table_chart),
          title: Text(file.name),
          subtitle: const Text(
            'Excel file selected, but preview is unavailable for this workbook format.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Excel Preview', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...rows.map(
              (row) => Text(
                row.map((c) => c?.value?.toString() ?? '').join(' | '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
