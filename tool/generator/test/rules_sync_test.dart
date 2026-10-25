// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Returns the rule text after its YAML frontmatter.
String _body(File file) {
  final text = file.readAsStringSync().replaceAll('\r\n', '\n');
  final frontmatter = RegExp(r'^---\n[\s\S]*?\n---\n').firstMatch(text);
  return frontmatter == null ? text : text.substring(frontmatter.end);
}

void main() {
  test('each .mdc rule has a .md copy with the same body', () {
    final currentPath = Directory.current.path;
    final repoRoot = currentPath.endsWith(p.join('tool', 'generator'))
        ? Directory.current.parent.parent
        : Directory.current;

    final rulesDir = Directory(p.join(repoRoot.path, 'rules'));
    expect(rulesDir.existsSync(), isTrue);

    final cursorRules = rulesDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.mdc'))
        .toList();
    expect(cursorRules, isNotEmpty);

    for (final mdc in cursorRules) {
      final md = File(p.setExtension(mdc.path, '.md'));
      final name = p.basenameWithoutExtension(mdc.path);
      expect(md.existsSync(), isTrue, reason: '$name.mdc has no $name.md copy');
      expect(
        _body(md),
        _body(mdc),
        reason: '$name.md and $name.mdc must have the same body',
      );
    }
  });
}
