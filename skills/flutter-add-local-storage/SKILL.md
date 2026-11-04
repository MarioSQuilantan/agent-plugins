---
name: flutter-add-local-storage
description: Stores data on the device through core services, with flat preferences behind PreferencesService (shared_preferences) and relational or cached data behind DatabaseService (Drift), and secrets in SecureStorageService. Use when persisting settings, caching API data, building offline-first features, adding a table, or writing a database migration.
metadata:
  model: manual
  last_modified: Wed, 04 Nov 2026 18:00:00 GMT
---
# Storing Data Locally

Follow the Flutter Architecture rule. Local storage is infrastructure, so the app talks to core services, not to packages. `DatabaseService` works like `NetworkService`: the interface uses app types only (a table name and `Map<String, Object?>` rows), and the datasource decodes rows with `fromRow` as it decodes JSON with `fromJson`.

Do not call `SharedPreferencesAsync`, `AppDatabase`, or a Drift query from a datasource, a Cubit, or a widget. Do not use `StreamBuilder` or `FutureBuilder` over storage; the Cubit listens and emits states.

## Choose the store

| Data | Store | Service |
|---|---|---|
| Tokens, passwords, API keys, personal secrets | Keychain or Keystore (`flutter_secure_storage`) | `SecureStorageService`, from `flutter-wrap-package-service` |
| A few flat values: theme, locale, flags, last tab | `shared_preferences` | `PreferencesService` |
| Lists, records, relations, queries, cached API data, offline-first | Drift (SQLite) | `DatabaseService` |

Never put a secret in preferences or the database. Do not add Hive, Isar, or a second database package; the original `hive` is unmaintained, and Drift covers structured data.

## Workflow

- [ ] **1. Choose.** Pick the store from the table. Reuse the service in `core/services/<capability>/` when it exists and add only the missing method.
- [ ] **2. Dependencies.** Preferences: `flutter pub add shared_preferences`. Database: `flutter pub add drift drift_flutter path_provider dev:drift_dev dev:build_runner`. Let `pub` choose versions. If the project uses `bloc_test` and the newest `drift_dev` does not resolve because both need different `analyzer` versions, keep `bloc_test` and let `pub` pick an older `drift_dev` (`flutter pub add dev:drift_dev:any drift:any`).
- [ ] **3. Exceptions.** Add `StorageException` and `DatabaseException` to `core/errors/` when missing, and map both to `StorageFailure` in the exception-to-`Failure` helper.
- [ ] **4. Service.** Create the interface and impl in `core/services/preferences/` or `core/services/database/`, and register the SDK instance in a `@module` under `core/di/`.
- [ ] **5. Schema.** For the database, add the table in `core/services/database/tables/`, add its names to `DbTables`, list it in `@DriftDatabase`, and bump `schemaVersion` with a migration when the app already shipped.
- [ ] **6. Model.** Add `fromRow` and `toRow` to the feature model, next to `fromJson` and `toEntity`.
- [ ] **7. Datasource.** Add a local datasource that injects the service, decodes, and maps every exception with `mapToFailure`. A watch returns `Stream<Either<Failure, T>>`.
- [ ] **8. Repository and Cubit.** The repository maps to entities without catching and may combine the remote and local datasources. The Cubit subscribes to the watch and cancels it in `close`.
- [ ] **9. Generate and check.** Run the project's `build_runner` command, the formatter, `dart analyze`, and the tests. Report which commands ran.

## Errors

```dart
// core/errors/exceptions.dart
class StorageException implements Exception {
  const StorageException();
}

class DatabaseException implements Exception {
  const DatabaseException();
}
```

Add `StorageException() || DatabaseException() => const StorageFailure()` to `mapToFailure`, and a `StorageFailure` message to the `FailureMessage` extension.

## Preferences

```dart
// core/services/preferences/preferences_service.dart
abstract class PreferencesService {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}
```

```dart
// core/services/preferences/preferences_service_impl.dart
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: PreferencesService)
class PreferencesServiceImpl implements PreferencesService {
  PreferencesServiceImpl(this._preferences);

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) =>
      _guard(() => _preferences.getString(key));

  @override
  Future<void> setString(String key, String value) =>
      _guard(() => _preferences.setString(key, value));

  @override
  Future<bool?> getBool(String key) => _guard(() => _preferences.getBool(key));

  @override
  Future<void> setBool(String key, bool value) =>
      _guard(() => _preferences.setBool(key, value));

  @override
  Future<void> remove(String key) => _guard(() => _preferences.remove(key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (_, stackTrace) {
      Error.throwWithStackTrace(const StorageException(), stackTrace);
    }
  }
}
```

```dart
// core/services/preferences/preference_keys.dart
abstract final class PreferenceKeys {
  static const themeMode = 'theme_mode';
  static const onboardingSeen = 'onboarding_seen';
}
```

```dart
// core/di/preferences_module.dart
@module
abstract class PreferencesModule {
  @lazySingleton
  SharedPreferencesAsync get preferences => SharedPreferencesAsync();
}
```

Use `SharedPreferencesAsync`. The legacy `SharedPreferences` API is planned for deprecation and needs `getInstance()` at startup. Add a method to the interface only when a feature needs that type. A settings datasource injects `PreferencesService` and wraps each call in `TaskEither.tryCatch(..., mapToFailure)`, like any other datasource.

## Database

### Schema

The schema stays typed in Drift so migrations are checked. `DbTables` holds the names the datasources use, and the table reads its column names from it, so the two cannot drift apart:

```dart
// core/services/database/db_tables.dart
abstract final class DbTables {
  static const todos = 'todos';
}

abstract final class TodosColumns {
  static const id = 'id';
  static const title = 'title';
  static const isDone = 'is_done';
  static const createdAt = 'created_at';
}
```

```dart
// core/services/database/tables/todos_table.dart
import 'package:drift/drift.dart';

@DataClassName('TodoRow')
class Todos extends Table {
  TextColumn get id => text().named(TodosColumns.id)();
  TextColumn get title => text().named(TodosColumns.title)();
  BoolColumn get isDone =>
      boolean().named(TodosColumns.isDone).withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named(TodosColumns.createdAt)();

  @override
  Set<Column> get primaryKey => {id};
}
```

Drift derives the SQL table name from the class name (`Todos` becomes `todos`); it must equal the `DbTables` constant. `@DataClassName` keeps the generated row class from colliding with the domain entity. Nothing outside this folder uses that row class.

```dart
// core/services/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Todos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(
        name: 'app',
        native: const DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      );
}
```

`driftDatabase` opens the file lazily on a background isolate, so `bootstrap` does not need to await it. Web needs the extra setup in the Drift web guide; add it only when the project targets web.

```dart
// core/di/database_module.dart
@module
abstract class DatabaseModule {
  @LazySingleton(dispose: closeDatabase)
  AppDatabase get database => AppDatabase();
}

Future<void> closeDatabase(AppDatabase database) => database.close();
```

Register one `AppDatabase` for the whole app. Opening two instances on the same file breaks stream updates.

### Service

```dart
// core/services/database/database_service.dart
abstract class DatabaseService {
  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?> args = const [],
    String? orderBy,
    int? limit,
  });

  Stream<List<Map<String, Object?>>> watch(
    String table, {
    String? where,
    List<Object?> args = const [],
    String? orderBy,
  });

  Future<void> insert(
    String table,
    Map<String, Object?> values, {
    bool replace = false,
  });

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    List<Object?> args = const [],
  });

  Future<int> delete(
    String table, {
    required String where,
    List<Object?> args = const [],
  });

  Future<T> transaction<T>(Future<T> Function() action);
}
```

```dart
// core/services/database/database_service_impl.dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DatabaseService)
class DatabaseServiceImpl implements DatabaseService {
  DatabaseServiceImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?> args = const [],
    String? orderBy,
    int? limit,
  }) =>
      _guard(() async {
        final rows = await _select(table, where, args, orderBy, limit).get();
        return [for (final row in rows) row.data];
      });

  @override
  Stream<List<Map<String, Object?>>> watch(
    String table, {
    String? where,
    List<Object?> args = const [],
    String? orderBy,
  }) =>
      _select(table, where, args, orderBy, null)
          .watch()
          .map((rows) => [for (final row in rows) row.data])
          .transform(
            StreamTransformer.fromHandlers(
              handleError: (error, stackTrace, sink) =>
                  sink.addError(_translate(error), stackTrace),
            ),
          );

  @override
  Future<void> insert(
    String table,
    Map<String, Object?> values, {
    bool replace = false,
  }) =>
      _guard(() async {
        final info = _table(table, values.keys);
        final verb = replace ? 'INSERT OR REPLACE' : 'INSERT';
        final marks = List.filled(values.length, '?').join(', ');
        await _db.customInsert(
          '$verb INTO $table (${values.keys.join(', ')}) VALUES ($marks)',
          variables: _variables(values.values),
          updates: {info},
        );
      });

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    List<Object?> args = const [],
  }) =>
      _guard(() {
        final info = _table(table, values.keys);
        final set = values.keys.map((column) => '$column = ?').join(', ');
        return _db.customUpdate(
          'UPDATE $table SET $set WHERE $where',
          variables: _variables([...values.values, ...args]),
          updates: {info},
          updateKind: UpdateKind.update,
        );
      });

  @override
  Future<int> delete(
    String table, {
    required String where,
    List<Object?> args = const [],
  }) =>
      _guard(
        () => _db.customUpdate(
          'DELETE FROM $table WHERE $where',
          variables: _variables(args),
          updates: {_table(table)},
          updateKind: UpdateKind.delete,
        ),
      );

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _guard(() => _db.transaction(action));

  Selectable<QueryRow> _select(
    String table,
    String? where,
    List<Object?> args,
    String? orderBy,
    int? limit,
  ) {
    final info = _table(table);
    final sql = StringBuffer('SELECT * FROM $table');
    if (where != null) sql.write(' WHERE $where');
    if (orderBy != null) sql.write(' ORDER BY $orderBy');
    if (limit != null) sql.write(' LIMIT $limit');
    return _db.customSelect(
      sql.toString(),
      variables: _variables(args),
      readsFrom: {info},
    );
  }

  TableInfo _table(String name, [Iterable<String> columns = const []]) {
    final info =
        _db.allTables.where((t) => t.actualTableName == name).firstOrNull;
    if (info == null) throw ArgumentError.value(name, 'table', 'Unknown table');
    final known = {for (final column in info.$columns) column.name};
    for (final column in columns) {
      if (!known.contains(column)) {
        throw ArgumentError.value(column, 'column', 'Unknown column in $name');
      }
    }
    return info;
  }

  List<Variable> _variables(Iterable<Object?> values) =>
      [for (final value in values) Variable<Object>(value)];

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException {
      rethrow;
    } on Exception catch (_, stackTrace) {
      Error.throwWithStackTrace(const DatabaseException(), stackTrace);
    }
  }

  Object _translate(Object error) =>
      error is Exception && error is! DatabaseException
          ? const DatabaseException()
          : error;
}
```

Why it is built this way:

- Every `Exception` becomes `DatabaseException`. On a device, `driftDatabase` runs queries on a background isolate and reports SQLite errors as `DriftRemoteException`, while an in-memory test database throws `SqliteException`. Catching by type would miss one of them. `Error` subclasses (`ArgumentError`, `TypeError`) are programming errors and pass through to `UnexpectedFailure`.
- Values always travel as `?` arguments. Only table and column names are interpolated, and `_table` rejects any name the schema does not have.
- `readsFrom` and `updates` name the table, so a `watch` emits again after every write through the service.
- `transaction` rolls back when the action throws. Inside it, call only `DatabaseService` methods, and decode rows after it returns, so a decoding error is not reported as a database error.

### Model and datasource

The model reads and writes SQLite values: `String`, `int`, `double`, `Uint8List`, or `null`. Drift stores a `BoolColumn` as `0` or `1` and a `DateTimeColumn` as Unix seconds by default, so the model converts:

```dart
// features/todos/data/models/todo_model.dart
factory TodoModel.fromRow(Map<String, Object?> row) => TodoModel(
      id: row[TodosColumns.id]! as String,
      title: row[TodosColumns.title]! as String,
      isDone: row[TodosColumns.isDone] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row[TodosColumns.createdAt]! as int) * 1000,
      ),
    );

Map<String, Object?> toRow() => {
      TodosColumns.id: id,
      TodosColumns.title: title,
      TodosColumns.isDone: isDone ? 1 : 0,
      TodosColumns.createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
    };
```

A missing or mistyped column throws `TypeError`, which the helper maps to `SerializationFailure`.

```dart
// features/todos/data/datasources/todos_local_data_source.dart
@lazySingleton
class TodosLocalDataSource {
  TodosLocalDataSource(this._database);

  final DatabaseService _database;

  Stream<Either<Failure, List<TodoModel>>> watchTodos() => _database
      .watch(DbTables.todos, orderBy: '${TodosColumns.createdAt} DESC')
      .map(
        (rows) => Either<Failure, List<TodoModel>>.tryCatch(
          () => rows.map(TodoModel.fromRow).toList(),
          mapToFailure,
        ),
      )
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) =>
              sink.add(Left(mapToFailure(error, stackTrace))),
        ),
      );

  TaskEither<Failure, Unit> saveTodo(TodoModel todo) => TaskEither.tryCatch(
        () async {
          await _database.insert(DbTables.todos, todo.toRow(), replace: true);
          return unit;
        },
        mapToFailure,
      );

  TaskEither<Failure, Unit> setDone(String id, {required bool isDone}) =>
      TaskEither.tryCatch(
        () async {
          await _database.update(
            DbTables.todos,
            {TodosColumns.isDone: isDone ? 1 : 0},
            where: '${TodosColumns.id} = ?',
            args: [id],
          );
          return unit;
        },
        mapToFailure,
      );

  TaskEither<Failure, Unit> replaceTodos(List<TodoModel> todos) =>
      TaskEither.tryCatch(
        () => _database.transaction(() async {
          await _database.delete(DbTables.todos, where: '1 = 1');
          for (final todo in todos) {
            await _database.insert(DbTables.todos, todo.toRow());
          }
          return unit;
        }),
        mapToFailure,
      );
}
```

The watch turns every error into a `Left`, so the stream never ends with an exception and the datasource stays the only place that creates a `Failure`.

### Repository and offline-first

```dart
// features/todos/data/repositories/todos_repository_impl.dart
@LazySingleton(as: TodosRepository)
class TodosRepositoryImpl implements TodosRepository {
  TodosRepositoryImpl(this._remote, this._local);

  final TodosRemoteDataSource _remote;
  final TodosLocalDataSource _local;

  @override
  Stream<Either<Failure, List<Todo>>> watchTodos() => _local.watchTodos().map(
        (result) => result.map(
          (models) => models.map((model) => model.toEntity()).toList(),
        ),
      );

  @override
  TaskEither<Failure, Unit> refreshTodos() =>
      _remote.fetchTodos().flatMap(_local.replaceTodos);

  @override
  TaskEither<Failure, Unit> saveTodo(Todo todo) =>
      _local.saveTodo(TodoModel.fromEntity(todo));

  @override
  TaskEither<Failure, Unit> setDone(String id, {required bool isDone}) =>
      _local.setDone(id, isDone: isDone);
}
```

Offline-first means the screen always reads the local table. `refreshTodos` fetches from the API and writes the result to the table, and the open watch emits the new rows. When the refresh fails, the cached rows stay on screen and the Cubit reports the failure. Writing local changes back to the API (a sync queue, conflict rules) is a separate feature; add it only when the request asks for it.

### Cubit

```dart
@injectable
class TodosCubit extends Cubit<TodosState> {
  TodosCubit(this._repository) : super(const TodosLoading());

  final TodosRepository _repository;
  StreamSubscription<Either<Failure, List<Todo>>>? _subscription;

  void watch() {
    _subscription ??= _repository.watchTodos().listen(
          (result) => emit(result.fold(TodosFailure.new, TodosLoaded.new)),
        );
  }

  Future<void> refresh() async {
    final result = await _repository.refreshTodos().run();
    if (isClosed) return;
    result.match((failure) => emit(TodosFailure(failure)), (_) {});
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
```

`TodosState` is a sealed state with `TodosLoading`, `TodosLoaded`, and `TodosFailure`, as in the architecture skill. Watching and refreshing each forward one repository call, so the Cubit calls the repository directly; put any rule in a use case. The page creates the Cubit with `getIt<TodosCubit>()..watch()..refresh()` and renders with `BlocBuilder`.

### Migrations

Bump `schemaVersion` every time a shipped table changes, and handle each step in `migration`:

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(todos, todos.dueDate);
        }
      },
    );
```

- Add the new constant to `TodosColumns` and the column to the table, then update `fromRow` and `toRow`.
- A new column on an existing table is nullable or has a default, or the upgrade fails on existing rows.
- Drift also calls `onUpgrade` on a downgrade (`from > to`). Do not assume `from < to`.
- Once the app has shipped, export each schema with `dart run drift_dev make-migrations` (configure `databases` in `build.yaml`), and prefer the generated `stepByStep` helper. Test each step with `SchemaVerifier`, following the Drift migration testing guide.
- Never edit an old step after release; add a new one.

## Tests

- **Service.** Test `DatabaseServiceImpl` against an in-memory database: `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))` in `setUp`, and `database.close()` in `tearDown`. Cover insert and query, a watch that emits after an update, a constraint violation that throws `DatabaseException`, and a transaction that rolls back.
- **Datasource.** Mock `DatabaseService` or `PreferencesService` with `mocktail`, as with `NetworkService`. Cover decoding, a `DatabaseException` that becomes `StorageFailure`, a malformed row that becomes `SerializationFailure`, and a stream error that becomes a `Left`.
- **Cubit.** Mock the repository and stub `watchTodos()` with `Stream.fromIterable([...])`. Use `blocTest` for the emitted states.
- **Integration.** An integration test that needs a clean database registers `AppDatabase(NativeDatabase.memory())` in a scope pushed with `getIt.pushNewScope` after the DI setup.

## Do not

```dart
// In a datasource, Cubit, or widget:
final db = AppDatabase();
final prefs = await SharedPreferences.getInstance();
StreamBuilder(stream: context.read<AppDatabase>().select(db.todos).watch(), ...);
```

Inject `DatabaseService` or `PreferencesService` into a datasource, expose a watch through the repository, and render Cubit states.
