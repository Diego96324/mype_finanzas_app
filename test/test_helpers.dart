// Test helpers to initialize common test environment (SharedPreferences mock, PathProvider fake, etc.)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake PathProvider that returns the system temp directory for application documents
class _FakePathProvider extends PathProviderPlatform {
  final String tempPath;
  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempPath;
  }

  // Other methods can return null or temp path if needed
  @override
  Future<String?> getTemporaryPath() async {
    return tempPath;
  }

  @override
  Future<String?> getDownloadsPath() async {
    return tempPath;
  }
}

/// Call this at the start of tests (in main or setUp) to initialize common mocks.
void initTestEnvironment({bool initSharedPreferences = true}) {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite ffi for unit tests running on the Dart VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  if (initSharedPreferences) {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  }
  final tmp = Directory.systemTemp.createTempSync('mype_test').path;
  PathProviderPlatform.instance = _FakePathProvider(tmp);
}
