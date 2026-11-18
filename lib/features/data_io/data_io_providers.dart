import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/import/spreadsheet_reader.dart';
import '../../domain/import/import_runner.dart';

/// A file the user picked: its name and contents.
typedef PickedFile = ({String name, Uint8List bytes});

/// Opens the system file picker for spreadsheets. Overridden in tests.
final spreadsheetPickerProvider = Provider<Future<PickedFile?> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: importableExtensions,
    );
    if (files.isEmpty) return null;
    final file = files.first;
    return (name: file.name, bytes: await file.xFile.readAsBytes());
  },
);

final importRunnerProvider = Provider<ImportRunner>(
  (ref) => ImportRunner(ref.watch(entryRepositoryProvider), ref.watch(categoryRepositoryProvider)),
);
