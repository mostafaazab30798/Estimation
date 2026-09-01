// W0.7 — Generate SBOM and license inventory; fail on denylisted licenses.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

final _gpl = RegExp(
  r'GNU (Affero )?General Public License',
  caseSensitive: false,
);

Future<void> main() async {
  final root = Directory.current;
  final legalDir = Directory('${root.path}/docs/legal');
  if (!legalDir.existsSync()) legalDir.createSync(recursive: true);

  print('==> flutter pub get');
  final pubGet = await Process.run('flutter', ['pub', 'get'], runInShell: true);
  if (pubGet.exitCode != 0) {
    stderr.writeln(pubGet.stderr);
    exit(pubGet.exitCode);
  }

  print('==> flutter pub deps --json');
  final deps = await Process.run(
    'flutter',
    ['pub', 'deps', '--json'],
    runInShell: true,
  );
  if (deps.exitCode != 0) {
    stderr.writeln(deps.stderr);
    exit(deps.exitCode);
  }

  final sbomPath = File('${legalDir.path}/sbom.json');
  sbomPath.writeAsStringSync(deps.stdout as String);

  final data = jsonDecode(deps.stdout as String) as Map<String, dynamic>;
  final packages = (data['packages'] as List<dynamic>? ?? [])
      .cast<Map<String, dynamic>>();

  final cachePath = (await Process.run('dart', ['pub', 'cache', 'path']))
      .stdout
      .toString()
      .trim();
  final cache = Directory(cachePath);

  final inventory = <Map<String, String>>[];
  final violations = <String>[];

  for (final pkg in packages) {
    final name = pkg['name'] as String?;
    final version = pkg['version'] as String?;
    if (name == null || version == null) continue;
    if (name == 'estimation') continue; // root app — not a pub cache package

    final pkgDir = Directory('${cache.path}/$name/$version');
    final licenseFile = File('${pkgDir.path}/LICENSE');
    final pubspecFile = File('${pkgDir.path}/pubspec.yaml');

    var licenseText = 'not resolved';
    if (licenseFile.existsSync()) {
      licenseText = licenseFile.readAsStringSync();
    } else if (pubspecFile.existsSync()) {
      for (final line in pubspecFile.readAsLinesSync()) {
        if (line.trim().startsWith('license:')) {
          licenseText = line.split(':').skip(1).join(':').trim();
          break;
        }
      }
    }

    final summary = licenseText
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'not resolved')
        .trim();
    final short =
        summary.length > 80 ? '${summary.substring(0, 77)}...' : summary;

    inventory.add({'name': name, 'version': version, 'license': short});
    if (_gpl.hasMatch(licenseText)) {
      violations.add('$name@$version: contains GPL/AGPL text');
    }
  }

  final invPath = File('${legalDir.path}/license-inventory.json');
  invPath.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({'packages': inventory}),
  );
  print('Wrote ${invPath.path} (${inventory.length} packages)');

  if (violations.isNotEmpty) {
    print('ERROR: GPL/AGPL-licensed dependencies found:');
    for (final v in violations) {
      print('  - $v');
    }
    exit(1);
  }

  print('OK: ${inventory.length} packages — no GPL/AGPL dependencies');
}
