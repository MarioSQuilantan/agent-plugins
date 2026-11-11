---
name: flutter-wrap-package-service
description: Wraps an infrastructure package (HTTP client, Firebase, secure storage, image picker, sharing, location, permissions) behind a core service interface and impl registered with injectable. Use when adding, replacing, or using a package that does I/O, calls platform channels, or exposes a vendor API.
metadata:
  model: manual
  last_modified: Wed, 04 Nov 2026 18:00:00 GMT
---
# Wrapping a Package in a Core Service

Follow the Flutter Architecture rule. The app talks to a capability, not to a package. Only the service impl and its DI module import the SDK. Drift is the exception owned by `flutter-add-local-storage`: `AppDatabase` and its tables also import `package:drift`, and a test of that service may import it to open an in-memory database.

For HTTP, use `flutter-use-http-package`, which defines `NetworkService`. For preferences and the Drift database, use `flutter-add-local-storage`, which defines `PreferencesService` and `DatabaseService`. This skill covers every other infrastructure package and the general pattern.

## Which packages get a service

Wrap a package when it does I/O, calls platform channels, or exposes a vendor API: Firebase, `flutter_secure_storage`, `shared_preferences`, `drift`, `image_picker`, `share_plus`, `geolocator`, `permission_handler`, `url_launcher`, analytics SDKs, and HTTP clients.

Do not wrap architecture or pure-Dart utility packages: `flutter_bloc`, `go_router`, `fpdart`, `injectable`, `get_it`, `equatable`, `formz`, `meta`, `collection`, `intl`, `freezed_annotation`, `json_annotation`. `envied` is not wrapped either; only `AppConfig` implementations in `core/config/` import it. Widget packages such as `auto_size_text` are not services; only the text helpers in `core/theme/` import them.

## Workflow

- [ ] **1. Scope.** List the operations the app needs from the package. Do not mirror the whole SDK.
- [ ] **2. Look for a sibling.** Search `lib/core/services/` for a service that already covers the package or capability. Reuse it and add the missing method there. Never write a second wrapper for the same SDK.
- [ ] **3. Interface.** Create `core/services/<capability>/<capability>_service.dart` with an abstract class that uses app types only (`String`, `Map<String, dynamic>`, entities, file paths). No SDK types in signatures.
- [ ] **4. Exceptions.** Add any new app exception to `core/errors/` and add its case to the exception-to-`Failure` helper.
- [ ] **5. Impl.** Create `<capability>_service_impl.dart` in the same folder. Import the SDK here. Catch SDK exceptions and throw app exceptions. Annotate with `@LazySingleton(as: <Capability>Service)` unless siblings use another annotation.
- [ ] **6. Module.** Register the SDK instance with a `@lazySingleton` getter in a `@module` under `core/di/`. Do not construct the SDK in the impl constructor.
- [ ] **7. Wire.** Inject the service interface into the datasource constructor. The datasource maps exceptions to `Failure`.
- [ ] **8. Regenerate.** Run the project's `build_runner` command and check that the generated config registers the new service.
- [ ] **9. Check.** Run the formatter, `dart analyze`, and the tests for the touched datasource. Report which commands ran.

## Where it goes

Every service gets its own folder under `core/services/`, named after the capability. The folder holds the interface, the impl, and the types only that service uses, such as its keys or events:

```text
core/services/
├── network/          NetworkService, SessionEvents
├── secure_storage/   SecureStorageService, StorageKeys
├── preferences/      PreferencesService, PreferenceKeys
├── database/         DatabaseService, AppDatabase, tables, DbTables
└── image_picker/     ImagePickerService
```

`@module` classes that register SDK instances stay in `core/di/`. Do not create `core/network/`, `core/storage/`, or a service outside `core/services/`. When an existing project already keeps services elsewhere, leave them and put new services under `core/services/` unless the request asks to move them.

## Rules

- The interface never exposes SDK types (`XFile`, `DocumentSnapshot`, `Response`) or SDK exceptions (`PlatformException`, `FirebaseException`, `DioException`).
- Name the service after the capability (`SecureStorageService`, `ImagePickerService`), not the package, unless sibling services use package names.
- Use the project's `Failure` types. Do not create a `Failure` in the service; the service throws app exceptions and the datasource maps them.
- Datasources and Cubits never instantiate an SDK (`ImagePicker()`, `FirebaseAuth.instance`, `const FlutterSecureStorage()`).
- Never call `GetIt.I.register*` by hand in app code.
- Import each file directly unless the project already uses barrels.

## Example: secure storage

```dart
// core/services/secure_storage/secure_storage_service.dart
abstract class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
```

```dart
// core/services/secure_storage/secure_storage_service_impl.dart
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SecureStorageService)
class SecureStorageServiceImpl implements SecureStorageService {
  SecureStorageServiceImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _guard(() => _storage.delete(key: key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      throw const StorageException();
    }
  }
}
```

```dart
// core/di/storage_module.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

@module
abstract class StorageModule {
  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}
```

```dart
// core/errors/exceptions.dart
class StorageException implements Exception {
  const StorageException();
}
```

Add `StorageException() => const StorageFailure()` to the exception-to-`Failure` helper.

## Do not

```dart
// In a datasource, Cubit, or widget:
import 'package:image_picker/image_picker.dart';

final picker = ImagePicker();
final XFile? file = await picker.pickImage(source: ImageSource.gallery);
```

Inject `ImagePickerService` instead, and return a file path or an app type from it.
