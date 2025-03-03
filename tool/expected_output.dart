// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Parse and yield data cases (each a [DataCase]) from [path].
Iterable<DataCase> dataCasesInFile({
  required String path,
  String? baseDir,
}) sync* {
  final file = p.basename(path).replaceFirst(RegExp(r'\..+$'), '');
  baseDir ??= p.relative(p.dirname(path), from: p.dirname(p.dirname(path)));

  // Explicitly create a File, in case the entry is a Link.
  final lines = File(path).readAsLinesSync();

  final frontMatter = StringBuffer();

  var i = 0;

  while (!lines[i].startsWith('>>>')) {
    frontMatter.write('${lines[i++]}\n');
  }

  while (i < lines.length) {
    var description = lines[i++].replaceFirst(RegExp(r'>>>\s*'), '').trim();
    final skip = description.startsWith('skip:');
    if (description == '') {
      description = 'line ${i + 1}';
    } else {
      description = 'line ${i + 1}: $description';
    }

    final input = StringBuffer();
    while (!lines[i].startsWith('<<<')) {
      input.writeln(lines[i++]);
    }

    final expectedOutput = StringBuffer();
    while (++i < lines.length && !lines[i].startsWith('>>>')) {
      expectedOutput.writeln(lines[i]);
    }

    final dataCase = DataCase(
      directory: baseDir,
      file: file,
      front_matter: frontMatter.toString(),
      description: description,
      skip: skip,
      input: input.toString(),
      expectedOutput: expectedOutput.toString(),
    );
    yield dataCase;
  }
}

/// Parse and return data cases (each a [DataCase]) from [directory].
///
/// By default, only read data cases from files with a `.unit` extension. Data
/// cases are read from files located immediately in [directory], or
/// recursively, according to [recursive].
Iterable<DataCase> _dataCases({
  required String directory,
  String extension = 'unit',
  bool recursive = true,
}) {
  final entries =
      Directory(directory).listSync(recursive: recursive, followLinks: false);
  final results = <DataCase>[];
  for (final entry in entries) {
    if (!entry.path.endsWith(extension)) {
      continue;
    }

    final relativeDir =
        p.relative(p.dirname(entry.path), from: p.dirname(directory));

    results.addAll(dataCasesInFile(path: entry.path, baseDir: relativeDir));
  }

  // The API makes no guarantees on order. This is just here for stability in
  // tests.
  results.sort((a, b) {
    final compare = a.directory.compareTo(b.directory);
    if (compare != 0) return compare;

    return a.file.compareTo(b.file);
  });
  return results;
}

/// Parse and yield data cases (each a [DataCase]) from the directory containing
/// [library], optionally under [subdirectory].
///
/// By default, only read data cases from files with a `.unit` extension. Data
/// cases are read from files located immediately in [directory], or
/// recursively, according to [recursive].
///
/// The typical use case of this method is to declare a library at the top of a
/// Dart test file, then reference the symbol with a pound sign. Example:
///
/// ```dart
/// library my_package.test.this_test;
///
/// import 'package:expected_output/expected_output.dart';
/// import 'package:test/test.dart';
///
/// void main() {
///   for (final dataCase
///       in dataCasesUnder(library: #my_package.test.this_test)) {
///     // ...
///   }
/// }
/// ```
Iterable<DataCase> dataCasesUnder({
  required String testDirectory,
  String extension = 'unit',
  bool recursive = true,
}) sync* {
  final directory = p.join(p.current, 'test', testDirectory);
  for (final dataCase in _dataCases(
    directory: directory,
    extension: extension,
    recursive: recursive,
  )) {
    yield dataCase;
  }
}

/// All of the data pertaining to a particular test case, namely the [input] and
/// [expectedOutput].
class DataCase {
  final String directory;
  final String file;

  // ignore: non_constant_identifier_names
  final String front_matter;
  final String description;
  final bool skip;
  final String input;
  final String expectedOutput;

  DataCase({
    this.directory = '',
    this.file = '',
    // ignore: non_constant_identifier_names
    this.front_matter = '',
    this.description = '',
    this.skip = false,
    required this.input,
    required this.expectedOutput,
  });

  /// A good standard description for `test()`, derived from the data directory,
  /// the particular data file, and the test case description.
  String get testDescription => [directory, file, description].join(' ');
}
