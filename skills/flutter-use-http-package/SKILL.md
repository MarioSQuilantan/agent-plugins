---
name: flutter-use-http-package
description: Calls a REST API through the app's NetworkService and implements that service with http, Dio, or another client. Use when a feature fetches from or sends data to a REST API, or when adding or replacing the HTTP client.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 18:45:00 GMT
---
# REST Calls Through NetworkService

Follow the Flutter Architecture rule. The app knows `NetworkService`, not the HTTP client. Only `core/network/network_service_impl.dart` and its module in `core/di/` import `http`, `dio`, or any other client. Datasources inject `NetworkService` and create the `Failure`.

Do not call the client from a widget, a Cubit, or a datasource. Do not use `FutureBuilder` for feature data. Do not let `ClientException`, `DioException`, or `SocketException` leave the impl.

## Workflow

- [ ] **1. Reuse.** If `core/network/` already has `NetworkService`, use it and skip to step 6. Add a method only when the interface lacks one.
- [ ] **2. Interface.** Create `NetworkService` with `get`, `post`, `put`, and `delete`. It returns decoded JSON as `Object?` (a map, a list, or `null`) and throws app exceptions.
- [ ] **3. Exceptions.** Add `ServerException`, `UnauthorizedException`, and `NetworkException` to `core/errors/` when they are missing, and add their cases to the exception-to-`Failure` helper.
- [ ] **4. Impl.** Implement the interface with the project's client. Translate client errors and non-2xx statuses into app exceptions. Add auth headers here, reading the token from `SecureStorageService` or the project's token provider. Datasources never pass tokens.
- [ ] **5. Module and platforms.** Register the client in a `@module` under `core/di/`. Add the Android `INTERNET` permission and the macOS `com.apple.security.network.client` entitlement in `DebugProfile.entitlements` and `Release.entitlements` when those targets exist and the entries are missing.
- [ ] **6. Datasource.** Inject `NetworkService`. Wrap the call, decode with `fromJson`, and map any exception with the helper. Return `Either` or `TaskEither`, matching the nearest feature.
- [ ] **7. Repository and Cubit.** The repository maps `model.toEntity()` without catching. The use case and the Cubit follow the architecture skill.
- [ ] **8. Check.** Regenerate the injection config, run the formatter and `dart analyze`, and test the datasource with a mocked `NetworkService`.

## Request rules

- Build URLs inside the impl from the project's base URL config. Datasources pass a path and query map.
- Send POST and PUT bodies as `request.toJson()` from a `data/requests` object. The impl encodes JSON and sets `Content-Type` to `application/json; charset=UTF-8`.
- Treat any 2xx as success. Throw `UnauthorizedException` on 401, `ServerException(statusCode)` on any other non-2xx status, and `NetworkException` on no connection or a timeout.
- Return `null` for an empty body. For DELETE, the datasource returns `Right(unit)`.
- For a large payload, decode in the impl with `compute(jsonDecode, response.body)`.

## Core: interface, exceptions, and mapping

```dart
// core/network/network_service.dart
abstract class NetworkService {
  Future<Object?> get(String path, {Map<String, String>? query});
  Future<Object?> post(String path, {Object? body});
  Future<Object?> put(String path, {Object? body});
  Future<Object?> delete(String path);
}
```

```dart
// core/errors/exceptions.dart
class ServerException implements Exception {
  const ServerException({required this.statusCode});
  final int statusCode;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class NetworkException implements Exception {
  const NetworkException();
}
```

```dart
// core/errors/map_to_failure.dart
Failure mapToFailure(Object error, StackTrace stackTrace) => switch (error) {
      UnauthorizedException() => const UnauthorizedFailure(),
      ServerException(:final statusCode) => ServerFailure(statusCode: statusCode),
      NetworkException() => const NetworkFailure(),
      FormatException() || TypeError() => const SerializationFailure(),
      _ => UnexpectedFailure(error: error, stackTrace: stackTrace),
    };
```

The signature matches `TaskEither.tryCatch`, so datasources pass `mapToFailure` directly. When the project has a logger or crash reporter, report the unexpected case there before returning `UnexpectedFailure`.

Use the project's `Failure` types when they exist. Create them in `core/errors/` only when the project has none, with value equality (`Equatable`, or Freezed when the project uses it).

## Impl with `http`

```dart
// core/network/network_service_impl.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

@LazySingleton(as: NetworkService)
class NetworkServiceImpl implements NetworkService {
  NetworkServiceImpl(this._client, this._config, this._storage);

  final http.Client _client;
  final AppConfig _config;
  final SecureStorageService _storage;

  @override
  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send((headers) => _client.get(_uri(path, query), headers: headers));

  @override
  Future<Object?> post(String path, {Object? body}) => _send(
        (headers) => _client.post(_uri(path), headers: headers, body: _encode(body)),
      );

  @override
  Future<Object?> put(String path, {Object? body}) => _send(
        (headers) => _client.put(_uri(path), headers: headers, body: _encode(body)),
      );

  @override
  Future<Object?> delete(String path) =>
      _send((headers) => _client.delete(_uri(path), headers: headers));

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${_config.baseUrl}$path').replace(queryParameters: query);

  String? _encode(Object? body) => body == null ? null : jsonEncode(body);

  Future<Object?> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final token = await _storage.read('access_token');
    final headers = {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
    };

    final http.Response response;
    try {
      response = await request(headers).timeout(_config.timeout);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerException(statusCode: response.statusCode);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
```

`AppConfig` is the environment config in `core/config/` (base URL, timeout) described in `flutter-setup-flavors`. Register `http.Client` in a module:

```dart
// core/di/network_module.dart
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

@module
abstract class NetworkModule {
  @lazySingleton
  http.Client get httpClient => http.Client();
}
```

With Dio, keep the same interface. Catch `DioException` in the impl: a response with status 401 becomes `UnauthorizedException`, any other response status becomes `ServerException`, and no response becomes `NetworkException`. Return `response.data`.

## Datasource

```dart
@lazySingleton
class ProductsRemoteDataSource {
  ProductsRemoteDataSource(this._network);

  final NetworkService _network;

  TaskEither<Failure, List<ProductModel>> fetchProducts() => TaskEither.tryCatch(
        () async {
          final json = await _network.get('/products') as List<dynamic>;
          return json
              .cast<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList();
        },
        mapToFailure,
      );

  TaskEither<Failure, ProductModel> createProduct(CreateProductRequest request) =>
      TaskEither.tryCatch(
        () async {
          final json = await _network.post('/products', body: request.toJson());
          return ProductModel.fromJson(json as Map<String, dynamic>);
        },
        mapToFailure,
      );

  TaskEither<Failure, Unit> deleteProduct(String id) => TaskEither.tryCatch(
        () async {
          await _network.delete('/products/$id');
          return unit;
        },
        mapToFailure,
      );
}
```

The repository returns `_remote.fetchProducts().map((models) => models.map((m) => m.toEntity()).toList())`. The Cubit emits loading, loaded, or failure, and the page renders them with `BlocBuilder`.
