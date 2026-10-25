---
name: flutter-build-form
description: Builds a Flutter form with formz inputs, a Cubit, and stateless field widgets, wired to an existing use case. Use when adding a form, adding fields to a form, or changing form validation.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 21:00:00 GMT
---
# Building a Form

Follow the Flutter Architecture rule. This skill covers presentation only. If the submit needs a use case, repository, or datasource that does not exist, ask before creating it, then follow `flutter-apply-architecture-best-practices`.

Field values and errors live in the Cubit. Widgets render state and forward input. Do not keep field values in a `StatefulWidget` or a `TextEditingController`, and do not call a use case or repository from a widget.

## Input

Read the form from YAML or plain language. Ask only when a field, its validators, or the submit use case is unclear.

```yaml
form: login
feature: authentication
fields:
  - name: email
    type: String
    validators: [required, email]
  - name: password
    type: String
    obscure: true
    validators: [required, min:8]
submit: SignInUseCase
```

## Workflow

- [ ] **1. Package.** Add `formz` only when `pubspec.yaml` does not already depend on it.
- [ ] **2. Siblings.** Read existing forms, form Cubits, and inputs. Copy their names, folders, error-text style, and state equality. Reuse `core/forms/inputs/` before creating an input.
- [ ] **3. Inputs.** Create one `FormzInput<T, E>` per missing field with an error enum and a `validator`. Put it in `presentation/inputs/` when only this feature uses it, or in `core/forms/inputs/` when a second feature needs it. Field validation (required, format, length) lives only here.
- [ ] **4. Error text.** Add an extension on each error enum that returns the message. When the project has localizations, the extension takes them as a parameter (`String text(AppLocalizations l10n)`) and the form widget passes `AppLocalizations.of(context)`. An input never reads a `BuildContext`.
- [ ] **5. State.** One class with the inputs, `FormzMixin`, a `FormzSubmissionStatus`, and the last `Failure`, with value equality. Not a sealed class and not a Freezed union. Write it with Freezed when `pubspec.yaml` already depends on `freezed`; otherwise extend `Equatable` and write `copyWith` by hand. Do not add Freezed for a form.
- [ ] **6. Cubit.** One method per field change, plus `submit`. `submit` marks every input dirty, stops when `Formz.validate` fails, ignores a call while in progress, sets `inProgress`, runs the use case, returns if the Cubit closed while waiting, and emits `success` or `failure`.
- [ ] **7. Page.** Provide the Cubit with `BlocProvider(create: (_) => getIt<XCubit>())` and react to `status` in a `BlocListener` (snackbar, navigation). Turn the failure into text by matching the feature's own failures first and falling back to the core `FailureMessage` extension. On a sign-in form a 401 means wrong credentials, not an expired session. A sign-in or sign-up form does not navigate on success: the session changes and the router redirect moves the user.
- [ ] **8. Form and fields.** The form widget reads the Cubit and passes values, errors, and callbacks to stateless field widgets. Rebuild each field with its own `BlocSelector` so a keystroke does not rebuild the whole form.
- [ ] **9. Register.** Annotate the Cubit like its siblings, `@injectable` by default. Regenerate the injection config with the project's `build_runner` command.
- [ ] **10. Tests.** Test each input's `validator`, the Cubit transitions with `blocTest` (invalid submit, in progress, success, failure), and the field widgets with plain values. Mock the use case with the project's mock library, or `mocktail` when there is none, and register a fallback value for its params type.
- [ ] **11. Checks.** Run the formatter and `dart analyze` on the touched files. Report which commands ran.

When adding a field to an existing form, extend the state, the Cubit, and the form widget, and add only the new input.

## Layout

```text
lib/core/forms/inputs/                  # inputs shared by two or more features
lib/features/<feature>/presentation/
  cubit/<form>_cubit.dart
  cubit/<form>_state.dart
  inputs/<field>.dart                   # inputs used only by this feature
  pages/<form>_page.dart
  widgets/<form>_form.dart
  widgets/<field>_field.dart
```

Match existing folder names (`view/`, `screens/`) when siblings use them.

## Controllers and local state

- Use `initialValue` and `onChanged` by default.
- Use a `TextEditingController` only when the Cubit must write the text: prefilling an edit form after a load, clearing the form, or autocomplete. The field widget owns the controller and updates it from a `BlocListener` when the Cubit value differs from `controller.text`.
- A `StatefulWidget` with `setState` is allowed for state that never leaves the field, such as toggling password visibility.

## Example: login

Inputs, shared in `core/forms/inputs/`:

```dart
import 'package:formz/formz.dart';

enum EmailValidationError { empty, invalid }

class Email extends FormzInput<String, EmailValidationError> {
  const Email.pure([super.value = '']) : super.pure();
  const Email.dirty([super.value = '']) : super.dirty();

  static final _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  EmailValidationError? validator(String value) {
    if (value.isEmpty) return EmailValidationError.empty;
    if (!_pattern.hasMatch(value)) return EmailValidationError.invalid;
    return null;
  }
}

extension EmailValidationErrorText on EmailValidationError {
  String get text => switch (this) {
        EmailValidationError.empty => 'Required',
        EmailValidationError.invalid => 'Invalid email',
      };
}

enum PasswordValidationError { empty, tooShort }

class Password extends FormzInput<String, PasswordValidationError> {
  const Password.pure([super.value = '']) : super.pure();
  const Password.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String value) {
    if (value.isEmpty) return PasswordValidationError.empty;
    if (value.length < 8) return PasswordValidationError.tooShort;
    return null;
  }
}

extension PasswordValidationErrorText on PasswordValidationError {
  String get text => switch (this) {
        PasswordValidationError.empty => 'Required',
        PasswordValidationError.tooShort => 'Use at least 8 characters',
      };
}
```

With localizations, the extension takes them as a parameter, and the form calls `email.displayError?.text(AppLocalizations.of(context))`:

```dart
extension EmailValidationErrorText on EmailValidationError {
  String text(AppLocalizations l10n) => switch (this) {
        EmailValidationError.empty => l10n.fieldRequired,
        EmailValidationError.invalid => l10n.invalidEmail,
      };
}
```

State written by hand, for a project without Freezed:

```dart
class LoginState extends Equatable with FormzMixin {
  const LoginState({
    this.email = const Email.pure(),
    this.password = const Password.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.failure,
  });

  final Email email;
  final Password password;
  final FormzSubmissionStatus status;
  final Failure? failure;

  @override
  List<FormzInput<dynamic, dynamic>> get inputs => [email, password];

  @override
  List<Object?> get props => [email, password, status, failure];

  // `failure` is not carried over: every copy clears it unless a new one is passed.
  LoginState copyWith({
    Email? email,
    Password? password,
    FormzSubmissionStatus? status,
    Failure? failure,
  }) =>
      LoginState(
        email: email ?? this.email,
        password: password ?? this.password,
        status: status ?? this.status,
        failure: failure,
      );
}
```

State with Freezed, for a project that already uses it:

```dart
@freezed
abstract class LoginState with _$LoginState, FormzMixin {
  const LoginState._();

  const factory LoginState({
    @Default(Email.pure()) Email email,
    @Default(Password.pure()) Password password,
    @Default(FormzSubmissionStatus.initial) FormzSubmissionStatus status,
    Failure? failure,
  }) = _LoginState;

  @override
  List<FormzInput<dynamic, dynamic>> get inputs => [email, password];
}
```

With Freezed, `copyWith` keeps `failure` unless it is passed, so field changes clear it explicitly: `state.copyWith(email: Email.dirty(value), failure: null)`. Match the `abstract` or `sealed` keyword and the `part` directive used by sibling Freezed classes.

Cubit (shown for the hand-written state):

```dart
@injectable
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._signInUseCase) : super(const LoginState());

  final SignInUseCase _signInUseCase;

  void emailChanged(String value) =>
      emit(state.copyWith(email: Email.dirty(value)));

  void passwordChanged(String value) =>
      emit(state.copyWith(password: Password.dirty(value)));

  Future<void> submit() async {
    if (state.status.isInProgress) return;

    final email = Email.dirty(state.email.value);
    final password = Password.dirty(state.password.value);
    emit(state.copyWith(email: email, password: password));
    if (!Formz.validate([email, password])) return;

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));
    final result = await _signInUseCase(
      SignInParams(email: email.value, password: password.value),
    ).run();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(status: FormzSubmissionStatus.failure, failure: failure),
      ),
      (_) => emit(state.copyWith(status: FormzSubmissionStatus.success)),
    );
  }
}
```

Page, form, and fields:

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoginCubit>(),
      child: BlocListener<LoginCubit, LoginState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          final failure = state.failure;
          if (state.status.isFailure && failure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_signInMessage(failure))),
            );
          }
        },
        child: const Scaffold(body: LoginForm()),
      ),
    );
  }

  String _signInMessage(Failure failure) => switch (failure) {
        EmailNotVerifiedFailure() => 'Verify your email before signing in',
        UnauthorizedFailure() => 'Wrong email or password',
        _ => failure.message,
      };
}

class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    return Column(
      children: [
        BlocSelector<LoginCubit, LoginState, Email>(
          selector: (state) => state.email,
          builder: (context, email) => EmailField(
            errorText: email.displayError?.text,
            onChanged: cubit.emailChanged,
          ),
        ),
        BlocSelector<LoginCubit, LoginState, Password>(
          selector: (state) => state.password,
          builder: (context, password) => PasswordField(
            errorText: password.displayError?.text,
            onChanged: cubit.passwordChanged,
          ),
        ),
        BlocSelector<LoginCubit, LoginState, FormzSubmissionStatus>(
          selector: (state) => state.status,
          builder: (context, status) => ElevatedButton(
            onPressed: status.isInProgressOrSuccess ? null : cubit.submit,
            child: status.isInProgress
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Login'),
          ),
        ),
      ],
    );
  }
}

class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.onChanged, this.errorText});

  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(labelText: 'Email', errorText: errorText),
      onChanged: onChanged,
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.onChanged, this.errorText});

  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      obscureText: _obscured,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: 'Password',
        errorText: widget.errorText,
        suffixIcon: IconButton(
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
```

Cubit test with `mocktail` and `bloc_test`:

```dart
class MockSignInUseCase extends Mock implements SignInUseCase {}

void main() {
  late MockSignInUseCase signInUseCase;
  const email = Email.dirty('ana@example.com');
  const password = Password.dirty('secret123');

  setUpAll(() {
    registerFallbackValue(const SignInParams(email: '', password: ''));
  });

  setUp(() => signInUseCase = MockSignInUseCase());

  blocTest<LoginCubit, LoginState>(
    'emits inProgress then failure when sign in fails',
    setUp: () => when(() => signInUseCase(any()))
        .thenReturn(TaskEither.left(const NetworkFailure())),
    build: () => LoginCubit(signInUseCase),
    seed: () => const LoginState(email: email, password: password),
    act: (cubit) => cubit.submit(),
    expect: () => const [
      LoginState(
        email: email,
        password: password,
        status: FormzSubmissionStatus.inProgress,
      ),
      LoginState(
        email: email,
        password: password,
        status: FormzSubmissionStatus.failure,
        failure: NetworkFailure(),
      ),
    ],
  );
}
```

After a successful sign-in, `SignInUseCase` saves the session, `SessionCubit` emits `SessionAuthenticated`, and the router redirect leaves `/login`. A form that does not change the session, such as editing a profile, navigates from its `BlocListener` on success.

`PasswordField` is stateful only for the visibility toggle. Its value still lives in the Cubit. Widget tests and previews target `EmailField` and `PasswordField` with plain values, and `LoginForm` with `BlocProvider.value` and a Cubit built from a mocked use case.
