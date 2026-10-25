---
name: flutter-implement-json-serialization
description: Map JSON with dart:convert on data-layer models that expose fromJson, toJson, and toEntity. Use when adding or changing API models. Keep domain entities free of JSON.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 17:45:00 GMT
---
# JSON Models in the Data Layer

Put `fromJson` and `toJson` on a class in `features/<feature>/data/models/`. The domain entity in `domain/entities/` has no JSON methods and does not import `dart:convert`. Connect them with `toEntity()`.

Use manual mapping. Do not add `json_serializable` or Freezed for this task unless the feature already uses that generator.

`NetworkService` already decodes the response body, so a datasource receives a `Map` or a `List`, not a string. Encoding and decoding raw strings happens only inside the network impl.

## Rules

- Cast the decoded value before reading fields. An object is `Map<String, dynamic>`. A list is `List<dynamic>` cast to `List<Map<String, dynamic>>`.
- Prefer a `switch` pattern for a single object so a missing or mistyped field fails in `fromJson`.
- Name the data class with a `Model` suffix (`UserModel`) and the entity without it (`User`).
- Keep API key names inside the model. The entity uses the app's field names.
- Put an outbound body in `data/requests/` with `toJson`. Do not put that request type in the domain.
- Map a long list off the UI isolate with `compute()` when mapping causes jank. The function passed to `compute()` must be top-level or static.
- `fromJson` may throw `FormatException`, and a wrong cast throws `TypeError`. The datasource maps both to a `Failure` with the helper in `core/errors/`. The repository and the Cubit never see the exception.

## Workflow

- [ ] Create `data/models/<name>_model.dart` with `final` fields, `fromJson`, `toJson`, and `toEntity()`.
- [ ] Create or reuse the domain entity. Do not add JSON to it.
- [ ] Add `data/requests/<name>_request.dart` only when the call sends a body that is not the response model.
- [ ] Call `NetworkService` in the datasource, pass the decoded value to `fromJson`, and return `Either` or `TaskEither`.
- [ ] Add a unit test for `fromJson`, `toJson`, and `toEntity`, including a payload that is missing a required field.
- [ ] Run the formatter and `dart analyze`.

## Examples

Response model and entity:

```dart
class User {
  const User({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;
}

class UserModel {
  const UserModel({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'id': final int id, 'name': final String name, 'email': final String email} =>
        UserModel(id: id, name: name, email: email),
      _ => throw const FormatException('Failed to read UserModel.'),
    };
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  User toEntity() => User(id: id, name: name, email: email);
}
```

Request body:

```dart
class UpdateUserRequest {
  const UpdateUserRequest({required this.name});

  final String name;

  Map<String, dynamic> toJson() => {'name': name};
}
```

Single object in a datasource:

```dart
TaskEither<Failure, UserModel> fetchUser(int id) => TaskEither.tryCatch(
      () async {
        final json = await _network.get('/users/$id') as Map<String, dynamic>;
        return UserModel.fromJson(json);
      },
      (error, _) => mapToFailure(error),
    );
```

Long list, mapped off the UI isolate:

```dart
List<UserModel> parseUsers(List<dynamic> json) =>
    json.cast<Map<String, dynamic>>().map(UserModel.fromJson).toList();

TaskEither<Failure, List<UserModel>> fetchUsers() => TaskEither.tryCatch(
      () async {
        final json = await _network.get('/users') as List<dynamic>;
        return compute(parseUsers, json);
      },
      (error, _) => mapToFailure(error),
    );
```

The repository calls `model.toEntity()` and returns `TaskEither<Failure, User>`. The domain entity never sees the JSON map.
