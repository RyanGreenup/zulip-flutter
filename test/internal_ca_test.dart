import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:zulip/internal_ca.dart';

void main() {
  test('build security context', () {
    check(internalCaSecurityContext).returnsNormally();
  });

  test('install http overrides', () {
    addTearDown(() => HttpOverrides.global = null);
    final before = HttpOverrides.current;
    installInternalCaTrust();
    check(HttpOverrides.current).isNotNull();
    check(identical(HttpOverrides.current, before)).isFalse();
  });
}
