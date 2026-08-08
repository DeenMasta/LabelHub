import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../domain/entities/import_template.dart';

class TemplateCsvExporter {
  const TemplateCsvExporter();

  Future<String?> export(ImportTemplate template) async {
    final content =
        '${template.fields.map((TemplateField field) => field.key).join(',')}\n';
    final filePath = await FilePicker.saveFile(
      dialogTitle: 'Save blank CSV template',
      fileName: '${template.id}_template.csv',
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      bytes: utf8.encode(content),
    );
    if (filePath == null) {
      return null;
    }
    return filePath.toLowerCase().endsWith('.csv') ? filePath : '$filePath.csv';
  }
}
