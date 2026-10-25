---
name: flutter-setup-flavors
description: Sets up environment config with envied, AppConfig, and injectable environments for a single environment, several flavors, or one more flavor such as demo or qa. Use when creating environments, adding or converting flavors, or moving hardcoded config into AppConfig.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 19:20:00 GMT
---
# Setting Up Flavors and Environment Config

Follow the Flutter Flavors rule and the Flutter Architecture rule. The app reads config through `AppConfig`. Only the `AppConfig` implementations in `core/config/` import `envied` classes.

## Input

Read the environments from the request. If it does not name them, ask, and suggest `dev`, `pre`, and `prod` as a starting point, not a requirement. Also ask, when it matters for the case, for each flavor's application ID suffix and display name.

```yaml
environments: [dev, pre, prod]   # or [prod] for a single environment
add: demo                         # only when adding to an existing setup
copy_from: pre                    # the flavor the new one resembles
```

Pick one case:

- **Single environment.** One environment, or the request says no flavors. No native flavors, no `--flavor`.
- **Several flavors from scratch.** Two or more environments and no flavors yet.
- **Add a flavor.** The project already has flavors. Change nothing in the existing ones.

To go from a single environment to several, rename `.env` to `.env.<name>` for the existing environment, then follow "Several flavors from scratch" for all of them.

## Workflow

- [ ] **1. Inspect.** Read `pubspec.yaml`, `lib/main*.dart`, `core/config/`, `core/di/`, `.gitignore`, `android/app/build.gradle(.kts)`, `ios/Flutter/*.xcconfig`, the Xcode schemes, and `.vscode/launch.json`. Reuse any existing names and layout.
- [ ] **2. Packages.** Add `envied` and dev dependencies `envied_generator` and `build_runner` when missing.
- [ ] **3. Env files.** Create `.env.<flavor>` (or `.env`) and its committed `.example` twin with the same keys and empty values. Add the ignore entries to `.gitignore`.
- [ ] **4. Env classes.** One `@Envied` class per env file in `core/config/env/`.
- [ ] **5. AppConfig.** Create the `AppConfig` class when missing, and one implementation per flavor with `@LazySingleton(as: AppConfig, env: ['<flavor>'])`. A single environment uses no `env`. Shared values live once in `AppConfig`.
- [ ] **6. DI and bootstrap.** Make the DI setup take the environment. Add one shared `bootstrap` in `app/` and one `main_<flavor>.dart` per flavor that only calls it. A single environment keeps `main.dart`.
- [ ] **7. Android.** Several flavors only: add a flavor dimension and one entry per flavor in `productFlavors`.
- [ ] **8. iOS.** Several flavors only: add the build configurations, xcconfig files, schemes, and Podfile mappings for each flavor.
- [ ] **9. Launch configs.** Several flavors only: create `.vscode/launch.json` when it is missing, with one entry per flavor. When it exists, add only the missing entries and keep the others. If `.gitignore` ignores `.vscode/`, tell the user the file stays local.
- [ ] **10. Generate.** Run `dart run build_runner clean`, then the project's `build_runner build` command.
- [ ] **11. Verify.** Run or build each touched flavor (`flutter run --flavor <flavor> -t lib/main_<flavor>.dart`). Report which flavors ran and which could not, for example iOS without a Mac.

When adding a flavor, do steps 3 to 11 for the new flavor only, copying the nearest existing flavor, and tell the user to add its `.env` values to the CI secret store.

## Layout

```text
.env.dev                    # ignored
.env.dev.example            # committed
lib/
├── app/
│   └── bootstrap.dart
├── core/
│   ├── config/
│   │   ├── app_config.dart
│   │   ├── app_config_dev.dart
│   │   └── env/
│   │       ├── dev_env.dart
│   │       └── dev_env.g.dart   # generated, ignored
│   └── di/
│       └── injection.dart
├── main_dev.dart
└── main_prod.dart
```

## Dart

```gitignore
.env*
!.env*.example
lib/core/config/env/*.g.dart
```

```dotenv
# .env.dev.example
BASE_URL=
MAPS_API_KEY=
```

```dart
// core/config/env/dev_env.dart
import 'package:envied/envied.dart';

part 'dev_env.g.dart';

@Envied(path: '.env.dev')
abstract class DevEnv {
  @EnviedField(varName: 'BASE_URL')
  static const String baseUrl = _DevEnv.baseUrl;

  @EnviedField(varName: 'MAPS_API_KEY', obfuscate: true)
  static final String mapsApiKey = _DevEnv.mapsApiKey;
}
```

An obfuscated field must be `static final`, not `const`.

```dart
// core/config/app_config.dart
abstract class AppConfig {
  String get baseUrl;
  String get mapsApiKey;

  Duration get timeout => const Duration(seconds: 30);
}
```

```dart
// core/config/app_config_dev.dart
@LazySingleton(as: AppConfig, env: ['dev'])
class DevAppConfig extends AppConfig {
  @override
  String get baseUrl => DevEnv.baseUrl;

  @override
  String get mapsApiKey => DevEnv.mapsApiKey;
}
```

```dart
// core/di/injection.dart
final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies(String environment) =>
    getIt.init(environment: environment);
```

```dart
// app/bootstrap.dart
void bootstrap(String flavor) {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies(flavor);
  runApp(const App());
}
```

```dart
// main_dev.dart
void main() => bootstrap('dev');
```

For a single environment, the implementation has no `env`, `configureDependencies()` takes no argument, and `main.dart` calls it before `runApp`.

When the app restores a session or loads other state at startup, make `bootstrap` return `Future<void>`, await that work after `configureDependencies` and before `runApp`, and declare `Future<void> main() => bootstrap('dev');`.

## Android

```kotlin
// android/app/build.gradle.kts
android {
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "MyApp Dev")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "MyApp")
        }
    }
}
```

Set `android:label="@string/app_name"` in `AndroidManifest.xml` when flavors have their own display name. Match the Groovy syntax when the project uses `build.gradle`.

## iOS

For each flavor:

1. In Xcode, duplicate the `Debug`, `Release`, and `Profile` build configurations as `Debug-<flavor>`, `Release-<flavor>`, and `Profile-<flavor>`.
2. Create a shared scheme named exactly `<flavor>` that uses those configurations. Flutter selects the scheme by the `--flavor` name.
3. Add `ios/Flutter/<flavor>.xcconfig` that includes the matching `Debug.xcconfig` or `Release.xcconfig` and sets the bundle ID suffix and display name, and assign it to the new configurations.
4. Map the configurations in the `Podfile` (`'Debug-dev' => :debug`, `'Release-dev' => :release`, `'Profile-dev' => :release`), then run `pod install`.

Xcode project edits are error-prone from the command line. When they cannot be verified on a Mac, list the remaining iOS steps for the user instead of claiming they are done.

## Launch config

Each entry uses the flavor name for `name` and `--flavor`, and points `program` at that flavor's entry point.

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "dev",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_dev.dart",
      "args": ["--flavor", "dev"]
    },
    {
      "name": "prod",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_prod.dart",
      "args": ["--flavor", "prod"]
    }
  ]
}
```
