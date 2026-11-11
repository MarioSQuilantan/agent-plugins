---
name: flutter-setup-localization
description: Add `flutter_localizations` and `intl` dependencies, enable "generate true" in `pubspec.yaml`, and create an `l10n.yaml` configuration file. Use when initializing localization support for a new Flutter project.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Sun, 25 Oct 2026 22:35:00 GMT
---
# Internationalizing Flutter Applications

## Contents
- [Core Concepts](#core-concepts)
- [Setup Workflow](#setup-workflow)
- [Implementation Workflow](#implementation-workflow)
- [Advanced Formatting](#advanced-formatting)
- [Examples](#examples)

## Core Concepts
Flutter handles internationalization (i18n) and localization (l10n) via the `flutter_localizations` and `intl` packages. The standard approach uses App Resource Bundle (`.arb`) files to define localized strings, which are then compiled into a generated `AppLocalizations` class for type-safe access within the widget tree.

## Setup Workflow

Copy and track this checklist when initializing internationalization in a Flutter project:

- [ ] **Task Progress**
  - [ ] 1. Add dependencies to `pubspec.yaml`.
  - [ ] 2. Enable the `generate` flag.
  - [ ] 3. Create the `l10n.yaml` configuration file.
  - [ ] 4. Register the delegates on `MaterialApp.router` in `lib/app/app.dart`, or on the single `MaterialApp` when the project does not follow the architecture rule.

### 1. Add Dependencies
Add the required localization packages to the project. Execute the following commands in the terminal:
```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

Verify your `pubspec.yaml` includes the following under `dependencies`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
```

### 2. Enable Code Generation
Open `pubspec.yaml` and enable the `generate` flag within the `flutter` section to automate localization tasks:
```yaml
flutter:
  generate: true
```

### 3. Create Configuration File
Create a new file named `l10n.yaml` in the root directory of the Flutter project. Define the input directory, template file, and output file:
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

### 4. Configure the App
`flutter gen-l10n` writes `app_localizations.dart` into `arb-dir` (here `lib/l10n/`). Import `package:<app>/l10n/app_localizations.dart`. Do not set `synthetic-package`: enabling it makes the Flutter tool stop, and `package:flutter_gen` no longer resolves.

In a project that follows the Flutter Architecture rule, register them on the `MaterialApp.router` in `lib/app/app.dart`, next to the theme and `routerConfig`. Use the generated lists so they stay in step with the `.arb` files:

```dart
import 'package:my_app/l10n/app_localizations.dart';

return MaterialApp.router(
  theme: appTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: getIt<AppRouter>().config,
);
```

A project that does not follow that rule sets the same two properties on its single `MaterialApp`.

## Implementation Workflow

Follow this workflow when adding or modifying localized content.

### 1. Define ARB Files
*   **If creating NEW content:** Add the base string to the template file (`lib/l10n/app_en.arb`). Include a description for context.
*   **If EDITING existing content:** Locate the key in all supported `.arb` files and update the values.

```json
{
  "helloWorld": "Hello World!",
  "@helloWorld": {
    "description": "The conventional newborn programmer greeting"
  }
}
```

Create corresponding files for other locales (e.g., `app_es.arb`):
```json
{
  "helloWorld": "¡Hola Mundo!"
}
```

### 2. Generate Localization Classes
Run the following command to trigger code generation:
```bash
flutter pub get
```
*Feedback Loop:* Read the `flutter pub get` output for ARB syntax errors, fix missing commas or mismatched placeholders, and run it again.

### 3. Consume Localized Strings
Access the localized strings in your widget tree using `AppLocalizations.of(context)`. Ensure the widget calling this is a descendant of `MaterialApp`.

```dart
Text(AppLocalizations.of(context)!.helloWorld)
```

## Advanced Formatting

Use placeholders for dynamic data, plurals, and conditional selects.

### Placeholders
Define parameters within curly braces and specify their type in the metadata object.
```json
"hello": "Hello {userName}",
"@hello": {
  "description": "A message with a single parameter",
  "placeholders": {
    "userName": {
      "type": "String",
      "example": "Bob"
    }
  }
}
```

### Plurals
Use the `plural` syntax to handle quantity-based string variations. The `other` case is mandatory.
```json
"nWombats": "{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}",
"@nWombats": {
  "description": "A plural message",
  "placeholders": {
    "count": {
      "type": "num",
      "format": "compact"
    }
  }
}
```

### Selects
Use the `select` syntax for conditional strings, such as gendered text.
```json
"pronoun": "{gender, select, male{he} female{she} other{they}}",
"@pronoun": {
  "description": "A gendered message",
  "placeholders": {
    "gender": {
      "type": "String"
    }
  }
}
```

## Examples

### Complete `l10n.yaml`
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
use-escaping: true
```

### Complete Widget Implementation
```dart
import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';

class GreetingWidget extends StatelessWidget {
  final String userName;
  final int notificationCount;

  const GreetingWidget({
    super.key, 
    required this.userName, 
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(l10n.hello(userName)),
        Text(l10n.nWombats(notificationCount)),
      ],
    );
  }
}
```
