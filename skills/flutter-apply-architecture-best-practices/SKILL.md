---
name: flutter-apply-architecture-best-practices
description: Adds a Flutter feature using feature-first Clean Architecture with Cubit, use cases, FpDart, injectable, and core services. Use when structuring a project, adding a feature, or refactoring state management and layers.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 17:45:00 GMT
---
# Adding a Flutter Feature

Follow the Flutter Architecture rule. This skill is the workflow for that rule.

Do not introduce `ChangeNotifier`, `ViewModel`, `ListenableBuilder`, `Bloc` event classes, Provider, Riverpod, or GetX. Do not create a root layout of `lib/data`, `lib/domain`, and `lib/ui`.

Read the nearest feature first and copy its folders, names, imports, annotations, and result type (`Either` or `TaskEither`). If that code contradicts the rule, new code follows the rule. Create a directory only when a file is about to live there.

## Workflow

Copy this checklist and complete it in order.

- [ ] **1. Entity.** Add an immutable domain entity under `features/<feature>/domain/entities/`. No Flutter, JSON, or HTTP types.
- [ ] **2. Contract.** Add an abstract repository under `domain/repositories/`. Every method returns `Either<Failure, T>` or `TaskEither<Failure, T>`.
- [ ] **3. Use case.** Add one class per business operation under `domain/use_cases/`, named `<Operation>UseCase` in `<operation>_use_case.dart`. Put business rules and branching here; field validation belongs in form inputs (`flutter-build-form`). Skip the use case only when the operation forwards a single repository call and adds no rule.
- [ ] **4. Model.** Add a response model under `data/models/` with `fromJson`, `toJson`, and `toEntity()`. Add a request type under `data/requests/` only when the call sends its own body or query object.
- [ ] **5. Core service.** Use the existing core service for the capability (`NetworkService`, `SecureStorageService`, and so on). If the package has no service yet, follow `flutter-wrap-package-service`, or `flutter-use-http-package` for HTTP.
- [ ] **6. Datasource.** Add the call under `data/datasources/`. Inject the core service, decode with `fromJson`, and map exceptions to `Failure` with the helper in `core/errors/`. No SDK imports.
- [ ] **7. Repository.** Implement the contract under `data/repositories/`. Map the model with `toEntity()`. Do not catch exceptions here.
- [ ] **8. Cubit.** Add a `sealed` state and a `Cubit<State>` under `presentation/cubit/`. The Cubit calls the use case and emits `initial`, `loading`, success, and `failure`. Ignore a repeated submit while a request is in flight.
- [ ] **9. UI.** Add a page under `presentation/pages/` that provides the Cubit with `BlocProvider(create: (_) => getIt<XCubit>())` and renders a view from `presentation/widgets/`. The view receives state and callbacks. Render with `BlocBuilder` and trigger navigation, dialogs, and snackbars from a `BlocListener`.
- [ ] **10. Register.** Use `@LazySingleton(as: Contract)` for the repository implementation, `@lazySingleton` for the datasource, and `@injectable` for use cases and Cubits. Regenerate the injection config with the project's `build_runner` command. Do not edit `*.config.dart` by hand.
- [ ] **11. Route.** Add the page to the existing GoRouter table.
- [ ] **12. Tests.** Test the datasource with a mocked core service, and test the use case and the Cubit transitions when the behavior can fail or branch. Use the mock library already in the project.
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
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── cubit/
    ├── pages/
    └── widgets/
```

Injection setup and SDK modules go in `core/di/`. Exceptions, failures, and the exception-to-`Failure` helper go in `core/errors/`. `NetworkService` goes in `core/network/`. Storage services go in `core/storage/`. Other platform or vendor services go in `core/services/`.

Move feature code into `core/` only when two features already use it.

## Call chain

Datasource, the only place that creates a `Failure`:

```dart
@lazySingleton
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._network);

  final NetworkService _network;

  TaskEither<Failure, UserModel> signIn(SignInRequest request) =>
      TaskEither.tryCatch(
        () async {
          final json = await _network.post('/auth/login', body: request.toJson());
          return UserModel.fromJson(json as Map<String, dynamic>);
        },
        (error, _) => mapToFailure(error),
      );
}
```

Repository, which maps without catching:

```dart
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  TaskEither<Failure, User> signIn({
    required String email,
    required String password,
  }) =>
      _remote
          .signIn(SignInRequest(email: email, password: password))
          .map((model) => model.toEntity());
}
```

Use case with a business rule (field checks such as "required" already ran in the form inputs):

```dart
@injectable
class SignInUseCase {
  SignInUseCase(this._repository);

  final AuthRepository _repository;

  TaskEither<Failure, User> call(SignInParams params) => _repository
      .signIn(
        email: params.email.trim().toLowerCase(),
        password: params.password,
      )
      .flatMap(
        (user) => user.isEmailVerified
            ? TaskEither.right(user)
            : TaskEither.left(const EmailNotVerifiedFailure()),
      );
}
```

The sign-in screen has input fields, so its Cubit is the form Cubit in `flutter-build-form`, which calls `SignInUseCase`.

A screen that loads data or performs one action uses a sealed state. For a profile screen backed by a `GetProfileUseCase` that returns `TaskEither<Failure, User>`:

```dart
sealed class ProfileState {
  const ProfileState();
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
}

class ProfileFailure extends ProfileState {
  const ProfileFailure(this.failure);
  final Failure failure;
}

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._getProfileUseCase) : super(const ProfileInitial());

  final GetProfileUseCase _getProfileUseCase;

  Future<void> load() async {
    if (state is ProfileLoading) return;
    emit(const ProfileLoading());
    final result = await _getProfileUseCase().run();
    result.fold(
      (failure) => emit(ProfileFailure(failure)),
      (user) => emit(ProfileLoaded(user)),
    );
  }
}
```

The page wraps `ProfileView` in `BlocProvider(create: (_) => getIt<ProfileCubit>()..load())`. `ProfileView` renders one branch per sealed state with `BlocBuilder`, and any navigation runs from a `BlocListener`. Neither calls the repository, the datasource, or a service.
