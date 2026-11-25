// Tests for the optional `build_targets` user-define in hook/build.dart.
//
// Only the skip/validation paths are exercised here: they return or throw
// before any `go build`, so these tests need no Go toolchain.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:test/test.dart';

import '../../hook/build.dart' as hook;

PackageUserDefines _defines(Map<String, Object?> defines) => PackageUserDefines(
  workspacePubspec: PackageUserDefinesSource(
    defines: defines,
    basePath: Directory.current.uri,
  ),
);

CodeAssetExtension _code(OS os) => CodeAssetExtension(
  targetArchitecture: Architecture.arm64,
  targetOS: os,
  linkModePreference: LinkModePreference.dynamic,
  macOS: os == OS.macOS ? MacOSCodeConfig(targetVersion: 13) : null,
  iOS: os == OS.iOS
      ? IOSCodeConfig(targetSdk: IOSSdk.iPhoneOS, targetVersion: 16)
      : null,
);

void main() {
  for (final os in [OS.macOS, OS.windows, OS.linux]) {
    test(
      'skips the Go build for ${os.name} when not in build_targets',
      () async {
        await testBuildHook(
          mainMethod: hook.main,
          extensions: [_code(os)],
          userDefines: _defines({
            'build_targets': ['ios', 'android'],
          }),
          check: (input, output) {
            expect(output.assets.encodedAssets, isEmpty);
          },
        );
      },
    );
  }

  test('rejects a non-list build_targets', () async {
    await expectLater(
      testBuildHook(
        mainMethod: hook.main,
        extensions: [_code(OS.macOS)],
        userDefines: _defines({'build_targets': 'ios'}),
        check: (_, _) {},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects non-string entries', () async {
    await expectLater(
      testBuildHook(
        mainMethod: hook.main,
        extensions: [_code(OS.macOS)],
        userDefines: _defines({
          'build_targets': ['ios', 42],
        }),
        check: (_, _) {},
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
