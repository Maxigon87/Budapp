import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class MaterialExcelRow {
  final String nombre;
  final String categoria;
  final double? ultimoPrecio;

  const MaterialExcelRow({
    required this.nombre,
    required this.categoria,
    this.ultimoPrecio,
  });
}

class MaterialExcelImportResult {
  final List<MaterialExcelRow> rows;
  final List<String> errors;

  const MaterialExcelImportResult({
    required this.rows,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

class MaterialsExcelImporter {
  static const List<String> headers = ['Nombre', 'Categoría', 'Último Precio'];

  static Uint8List buildTemplate({List<MaterialExcelRow> rows = const []}) {
    final archive = Archive();
    final rowValues = <List<Object?>>[
      headers,
      if (rows.isEmpty) ...[
        const ['Cable 2.5 mm', 'Electricidad', 1200],
        const ['Caño PVC 2"', 'Ferretería', 8500],
        const ['Tornillo 8x50', 'Ferretería', 150],
      ] else
        ...rows.map((row) => [row.nombre, row.categoria, row.ultimoPrecio]),
    ];

    archive.addFile(ArchiveFile.string('[Content_Types].xml', _contentTypesXml));
    archive.addFile(ArchiveFile.string('_rels/.rels', _rootRelsXml));
    archive.addFile(ArchiveFile.string('xl/workbook.xml', _workbookXml));
    archive.addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRelsXml));
    archive.addFile(ArchiveFile.string('xl/styles.xml', _stylesXml));
    archive.addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', _buildWorksheetXml(rowValues)));

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static MaterialExcelImportResult parse(Uint8List bytes) {
    final errors = <String>[];
    final rows = <MaterialExcelRow>[];

    final archive = ZipDecoder().decodeBytes(bytes);
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) {
      return const MaterialExcelImportResult(
        rows: [],
        errors: ['No se encontró la hoja principal del archivo Excel.'],
      );
    }

    final sharedStrings = _readSharedStrings(archive);
    final sheetXml = utf8.decode(sheetFile.content);
    final parsedRows = _readRows(sheetXml, sharedStrings);

    if (parsedRows.length <= 1) {
      return const MaterialExcelImportResult(
        rows: [],
        errors: ['El archivo no contiene materiales para importar.'],
      );
    }

    for (var rowIndex = 1; rowIndex < parsedRows.length; rowIndex++) {
      final excelRowNumber = rowIndex + 1;
      final row = parsedRows[rowIndex];
      final nombre = _valueAt(row, 0).trim();
      final categoria = _valueAt(row, 1).trim();
      final priceText = _valueAt(row, 2).trim();

      if (nombre.isEmpty && categoria.isEmpty && priceText.isEmpty) {
        continue;
      }

      if (nombre.isEmpty) {
        errors.add('Fila $excelRowNumber: falta el nombre del material.');
        continue;
      }

      if (categoria.isEmpty) {
        errors.add('Fila $excelRowNumber: falta la categoría.');
        continue;
      }

      double? price;
      if (priceText.isNotEmpty) {
        price = _parsePrice(priceText);
        if (price == null || price < 0) {
          errors.add('Fila $excelRowNumber: el precio "$priceText" no es válido.');
          continue;
        }
      }

      rows.add(MaterialExcelRow(nombre: nombre, categoria: categoria, ultimoPrecio: price));
    }

    if (rows.isEmpty && errors.isEmpty) {
      errors.add('El archivo no contiene materiales para importar.');
    }

    return MaterialExcelImportResult(rows: rows, errors: errors);
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];

    final xml = utf8.decode(file.content);
    return RegExp(r'<si[^>]*>(.*?)</si>', dotAll: true)
        .allMatches(xml)
        .map((match) {
          final itemXml = match.group(1) ?? '';
          final text = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
              .allMatches(itemXml)
              .map((textMatch) => _xmlUnescape(textMatch.group(1) ?? ''))
              .join();
          return text;
        })
        .toList();
  }

  static List<List<String>> _readRows(String sheetXml, List<String> sharedStrings) {
    return RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(sheetXml).map((rowMatch) {
      final values = <int, String>{};
      final rowXml = rowMatch.group(1) ?? '';
      for (final cellMatch in RegExp(r'<c([^>]*)>(.*?)</c>', dotAll: true).allMatches(rowXml)) {
        final attributes = cellMatch.group(1) ?? '';
        final cellXml = cellMatch.group(2) ?? '';
        final reference = RegExp(r'\br="([A-Z]+)(\d+)"').firstMatch(attributes)?.group(1);
        if (reference == null) continue;

        final columnIndex = _columnIndex(reference);
        values[columnIndex] = _readCellValue(attributes, cellXml, sharedStrings);
      }

      if (values.isEmpty) return const <String>[];
      final lastIndex = values.keys.reduce((a, b) => a > b ? a : b);
      return List<String>.generate(lastIndex + 1, (index) => values[index] ?? '');
    }).toList();
  }

  static String _readCellValue(String attributes, String cellXml, List<String> sharedStrings) {
    if (attributes.contains('t="inlineStr"')) {
      final match = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).firstMatch(cellXml);
      return _xmlUnescape(match?.group(1) ?? '');
    }

    final value = RegExp(r'<v[^>]*>(.*?)</v>', dotAll: true).firstMatch(cellXml)?.group(1) ?? '';
    if (attributes.contains('t="s"')) {
      final index = int.tryParse(value) ?? -1;
      if (index >= 0 && index < sharedStrings.length) return sharedStrings[index];
      return '';
    }

    return _xmlUnescape(value);
  }

  static int _columnIndex(String letters) {
    var index = 0;
    for (final codeUnit in letters.codeUnits) {
      index = (index * 26) + (codeUnit - 64);
    }
    return index - 1;
  }

  static String _valueAt(List<String> row, int index) {
    if (index >= row.length) return '';
    return row[index];
  }

  static double? _parsePrice(String value) {
    if (value.isEmpty) return null;

    final cleaned = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (cleaned.isEmpty) return null;

    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');
    final decimalSeparatorIndex = lastComma > lastDot ? lastComma : lastDot;
    final fractionalDigits = decimalSeparatorIndex >= 0 ? cleaned.length - decimalSeparatorIndex - 1 : 0;
    if (decimalSeparatorIndex >= 0 && fractionalDigits > 0 && fractionalDigits <= 2) {
      final integerPart = cleaned.substring(0, decimalSeparatorIndex).replaceAll(RegExp(r'[^0-9-]'), '');
      final fractionalPart = cleaned.substring(decimalSeparatorIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
      return double.tryParse('$integerPart.$fractionalPart');
    }

    return double.tryParse(cleaned.replaceAll(RegExp(r'[^0-9-]'), ''));
  }

  static String _buildWorksheetXml(List<List<Object?>> rows) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ')
      ..write('xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<sheetData>');

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final excelRowNumber = rowIndex + 1;
      buffer.write('<row r="$excelRowNumber">');
      for (var columnIndex = 0; columnIndex < rows[rowIndex].length; columnIndex++) {
        final reference = '${_columnName(columnIndex)}$excelRowNumber';
        final value = rows[rowIndex][columnIndex];
        if (value is num) {
          buffer.write('<c r="$reference"><v>$value</v></c>');
        } else {
          buffer.write('<c r="$reference" t="inlineStr"><is><t>${_xmlEscape(value?.toString() ?? '')}</t></is></c>');
        }
      }
      buffer.write('</row>');
    }

    buffer
      ..write('</sheetData>')
      ..write('</worksheet>');
    return buffer.toString();
  }

  static String _columnName(int index) {
    var column = '';
    var value = index + 1;
    while (value > 0) {
      final remainder = (value - 1) % 26;
      column = String.fromCharCode(65 + remainder) + column;
      value = (value - remainder - 1) ~/ 26;
    }
    return column;
  }

  static String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _xmlUnescape(String value) {
    return value
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&');
  }
}

const String _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';

const String _rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

const String _workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Materiales" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

const String _workbookRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
  <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
</styleSheet>''';
