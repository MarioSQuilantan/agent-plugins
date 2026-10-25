---
name: flutter-apply-architecture-best-practices
description: Adds a Flutter feature using feature-first Clean Architecture with Cubit, use cases, FpDart, injectable, and core services. Use when structuring a project, adding a feature, or refactoring state management and layers.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 21:00:00 GMT
---
# Adding a Flutter Feature

Follow the Flutter Architecture rule. This skill is the workflow for that rule.

Do not introduce `ChangeNotifier`, `ViewModel`, `ListenableBuilder`, `Bloc` event classes, Provider, Riverpod, or GetX. Do not create a root layout of `lib/data`, `lib/domain`, and `lib/ui`.

Read the nearest feature first and copy its folders, names, imports, annotations, and result type (`Either` or `TaskEither`). If that code contradicts the rule, new code follows the rule. Create a directory only when a file is about to live there.

## Workflow

Copy this checklist and complete it in order.

- [ ] **1. Entity.** Add an immutable domain entity under `features/<feature>/domain/entities/` with value equality (`Equatable`, or Freezed when the project uses it). No Flutter, JSON, or HTTP types.
- [ ] **2. Contract.** Add an abstract repository under `domain/repositories/`. Every method returns `Either<Failure, T>` or `TaskEither<Failure, T>`, except a `watch` method, which returns a `Stream` of entities.
- [ ] **3. Use case.** Add one class per business operation under `domain/use_cases/`, named `<Operation>UseCase` in `<operation>_use_case.dart`. Put business rules and branching here; field validation belongs in form inputs (`flutter-build-form`). A failure that only this feature produces extends `Failure` in `domain/failures/`. Skip the use case only when the operation forwards a single repository call and adds no rule.
- [ ] **4. Model.** Add a response model under `data/models/` with `fromJson`, `toJson`, and `toEntity()`. Add a request type under `data/requests/` only when the call sends its own body or query object.
- [ ] **5. Core service.** Use the existing core service for the capability (`NetworkService`, `SecureStorageService`, and so on). If the package has no service yet, follow `flutter-wrap-package-service`, or `flutter-use-http-package` for HTTP.
- [ ] **6. Datasource.** Add the call under `data/datasources/`. Inject the core service, decode with `fromJson`, and map exceptions to `Failure` with the helper in `core/errors/`. No SDK imports.
- [ ] **7. Repository.** Implement the contract under `data/repositories/`. Map the model with `toEntity()`. Do not catch exceptions here.
- [ ] **8. Cubit.** Add a `sealed` state with value equality and a `Cubit<State>` under `presentation/cubit/`. The Cubit calls the use case and emits `initial`, `loading`, success, and `failure`. Ignore a repeated submit while a request is in flight, and return without emitting when the Cubit closed during the `await`.
- [ ] **9. UI.** Add a page under `presentation/pages/` that provides the Cubit with `BlocProvider(create: (_) => getIt<XCubit>())` and renders a view from `presentation/widgets/`. The view receives state and callbacks. Render with `BlocBuilder` and trigger navigation, dialogs, and snackbars from a `BlocListener`.
- [ ] **10. Register.** Use `@LazySingleton(as: Contract)` for the repository implementation, `@lazySingleton` for the datasource, `@injectable` for use cases and screen Cubits, and `@lazySingleton` for an app-wide Cubit such as the session. Regenerate the injection config with the project's `build_runner` command. Do not edit `*.config.dart` by hand.
- [ ] **11. Route.** Add the page to the existing GoRouter table.
- [ ] **12. Tests.** Test the datasource with a mocked core service, and test the use case and the Cubit transitions when the behavior can fail or branch. Use the mock library already in the project; when there is none, add `mocktail` and `bloc_test` as dev dependencies. Test Cubits with `blocTest`.
- [ ] **13. Checks.** Run the formatter, `dart analyze`, and the relevant tests. Report which commands ran.

## Where code goes

```text
lib/features/<feature>/
├── data/
│   ├── datasources/
│   ├── models/
│   ├── repositories/
│   └── requests/
├── domain/
│   ├── entities/
│   ├── failures/
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── cubit/
    ├── inputs/
    ├── pages/
    └── widgets/
```

The root widget and the GoRouter table go in `app/`. Environment config goes in `core/config/`. Injection setup and SDK modules go in `core/di/`. Exceptions, the shared failures, the exception-to-`Failure` helper, and the `Failure`-to-message extension go in `core/errors/`. `NetworkService` and `SessionEvents` go in `core/network/`. Storage services go in `core/storage/`. Other platform or vendor services go in `core/services/`.

Move feature code into `core/` only when two features already use it.

## Call chain

The example is sign-in end to end: authenticate remotely, apply a business rule, persist the token, and publish the session that the router reads.

Domain entity and contract. The token is an opaque string; the domain does not know how it is stored or sent:

```dart
class AuthSession extends Equatable {
  const AuthSession({required this.user, required this.accessToken});

  final User user;
  final String accessToken;

  @override
  List<Object?> get props => [user, accessToken];
}

abstract class AuthRepository {
  TaskEither<Failure, AuthSession> signIn({
    required String email,
    required String password,
  });
  TaskEither<Failure, Unit> saveSession(AuthSession session);
  TaskEither<Failure, Unit> signOut();
  TaskEither<Failure, User?> restoreSession();
  User? get currentUser;
  Stream<User?> watchSession();
}
```

```dart
// features/authentication/domain/failures/email_not_verified_failure.dart
class EmailNotVerifiedFailure extends Failure {
  const EmailNotVerifiedFailure();
}
```

Datasources, the only place that creates a `Failure`. The remote one calls the API; the local one stores the token through `SecureStorageService` with the shared key from `core/storage/storage_keys.dart`:

```dart
@lazySingleton
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._network);

  final NetworkService _network;

  TaskEither<Failure, AuthSessionModel> signIn(SignInRequest request) =>
      TaskEither.tryCatch(
        () async {
          final json = await _network.post('/auth/login', body: request.toJson());
          return AuthSessionModel.fromJson(json as Map<String, dynamic>);
        },
        mapToFailure,
      );
}

@lazySingleton
class AuthLocalDataSource {
  AuthLocalDataSource(this._storage);

  final SecureStorageService _storage;

  TaskEither<Failure, Unit> saveToken(String token) => TaskEither.tryCatch(
        () async {
          await _storage.write(StorageKeys.accessToken, token);
          return unit;
        },
        mapToFailure,
      );

  TaskEither<Failure, Unit> deleteToken() => TaskEither.tryCatch(
        () async {
          await _storage.delete(StorageKeys.accessToken);
          return unit;
        },
        mapToFailure,
      );
}
```

```dart
// core/storage/storage_keys.dart
abstract final class StorageKeys {
  static const accessToken = 'access_token';
}
```

Repository, which combines both datasources, maps without catching, and publishes the session only after it is saved. It exposes the current user synchronously, so the session Cubit starts from the saved session whenever it is created. It also ends the session when `SessionEvents` reports an expired token:

```dart
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local, SessionEvents sessionEvents) {
    sessionEvents.expired.listen((_) => _expireSession());
  }

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final _session = StreamController<User?>.broadcast();
  User? _currentUser;

  @override
  User? get currentUser => _currentUser;

  void _publish(User? user) {
    _currentUser = user;
    _session.add(user);
  }

  @override
  TaskEither<Failure, AuthSession> signIn({
    required String email,
    required String password,
  }) =>
      _remote
          .signIn(SignInRequest(email: email, password: password))
          .map((model) => model.toEntity());

  @override
  TaskEither<Failure, Unit> saveSession(AuthSession session) =>
      _local.saveToken(session.accessToken).map((_) {
        _publish(session.user);
        return unit;
      });

  @override
  TaskEither<Failure, Unit> signOut() => _local.deleteToken().map((_) {
        _publish(null);
        return unit;
      });

  @override
  Stream<User?> watchSession() => _session.stream;

  Future<void> _expireSession() async {
    await _local.deleteToken().run();
    _publish(null);
  }
}
```

The server already rejected the token, so `_expireSession` ends the session even when deleting the token fails.

Use case with a business rule. In this example `User` also has an `isEmailVerified` field. Field checks such as "required" already ran in the form inputs. The session is saved only when the rule passes, so the router never sees a session that is about to be rejected:

```dart
@injectable
class SignInUseCase {
  SignInUseCase(this._repository);

  final AuthRepository _repository;

  TaskEither<Failure, User> call(SignInParams params) => _repository
      .signIn(email: params.email, password: params.password)
      .flatMap(
        (session) => session.user.isEmailVerified
            ? _repository.saveSession(session).map((_) => session.user)
            : TaskEither.left(const EmailNotVerifiedFailure()),
      );
}
```

The sign-in screen has input fields, so its Cubit is the form Cubit in `flutter-build-form`, which calls `SignInUseCase`. It does not navigate on success: the session Cubit changes, and the router redirect in `flutter-setup-declarative-routing` moves the user.

App-wide session Cubit. Watching, restoring, and signing out each forward a single repository call, so it calls the repository directly:

```dart
sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final User user;

  @override
  List<Object?> get props => [user];
}

@lazySingleton
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository)
      : super(_stateFor(_repository.currentUser)) {
    _subscription = _repository
        .watchSession()
        .listen((user) => emit(_stateFor(user)));
  }

  final AuthRepository _repository;
  late final StreamSubscription<User?> _subscription;

  static SessionState _stateFor(User? user) => user == null
      ? const SessionUnauthenticated()
      : SessionAuthenticated(user);

  Future<void> restore() async {
    final result = await _repository.restoreSession().run();
    if (isClosed) return;
    emit(_stateFor(result.getOrElse((_) => null)));
  }

  Future<void> signOut() async {
    final result = await _repository.signOut().run();
    if (isClosed) return;
    result.match((_) => emit(const SessionUnauthenticated()), (_) {});
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

On success the session stream emits `null`. If deleting the token fails, `signOut` still ends the session in memory.

`restoreSession` keeps the user signed in across launches. It returns `null` when no token is stored; otherwise it loads the user with the remote datasource and publishes it. `bootstrap` is async and awaits `getIt<SessionCubit>().restore()` before `runApp`, so the first redirect already sees the restored session. A failed restore leaves the user signed out but keeps the token, so an offline launch does not sign the user out; a rejected token is removed through `SessionEvents`. An expired token needs no code in pages or Cubits: `SessionEvents` reaches the repository, the session stream emits `null`, and the router redirect sends the user to `/login`.

A screen that loads data or performs one action uses a sealed state. For a profile screen backed by a `GetProfileUseCase` that returns `TaskEither<Failure, User>`:

```dart
sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.user);
  final User user;

  @override
  List<Object?> get props => [user];
}

class ProfileFailure extends ProfileState {
  const ProfileFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._getProfileUseCase) : super(const ProfileInitial());

  final GetProfileUseCase _getProfileUseCase;

  Future<void> load() async {
    if (state is ProfileLoading) return;
    emit(const ProfileLoading());
    final result = await _getProfileUseCase().run();
    if (isClosed) return;
    result.fold(
      (failure) => emit(ProfileFailure(failure)),
      (user) => emit(ProfileLoaded(user)),
    );
  }
}
```

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProfileCubit>()..load(),
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) => ProfileView(
          state: state,
          onRetry: context.read<ProfileCubit>().load,
        ),
      ),
    );
  }
}
```

`ProfileView` is a `StatelessWidget` that takes `state` and `onRetry` and renders one branch per sealed state with a `switch`. It never reads the Cubit, so previews and widget tests pump it with plain values. Any navigation runs from a `BlocListener` in the page. Neither widget calls the repository, the datasource, or a service.
