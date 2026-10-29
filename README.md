# Flutter Agent Plugins

Agent plugins for Flutter, maintained by the Flutter team.

A collection of plugins designed to extend AI agent capabilities for Flutter development. These plugins bundle together skills, MCP server configuration, and rules to provide tailored workflows and instructions for happy path Flutter development. By giving the agent domain expertise and repeatable workflows, you drastically reduce mistakes and ensure agents reliably complete tasks following best practices.

Plugins can package various customizations together. A key component of these plugins is **Agent Skills**, which are simple folders of files that can be seen as complementary to MCP: where MCP gives an agent access to specialized tools, a Skill teaches the agent “how” to use tools for a specific task.

You can also install the [Dart skills](https://github.com/dart-lang/skills) for Dart tasks.

## Installation

Refer to [Get started developing with AI](https://docs.flutter.dev/ai/get-started) for detailed instructions on how to install the plugins for your preferred agent.

## Available Skills

| Skill | Description | Example prompt |
|---|---|---|
| [flutter-add-animation](skills/flutter-add-animation/SKILL.md) | Adds Flutter animations at the lowest level that works, from implicit widgets to AnimationController, page transitions, Hero, and animated painters, driven by Cubit state and respecting reduced motion. Use when animating a widget, a state change, a list, a route transition, or a custom drawing. | Animate the profile screen between loading, loaded, and error states |
| [flutter-add-integration-test](skills/flutter-add-integration-test/SKILL.md) | Configures Flutter Driver for app interaction and converts MCP actions into permanent integration tests. Use when adding integration testing to a project, exploring UI components via MCP, or automating user flows with the integration_test package. | Add an integration test that validates the checkout experience |
| [flutter-add-widget-preview](skills/flutter-add-widget-preview/SKILL.md) | Adds interactive widget previews to the project using the previews.dart system. Use when creating new UI components or updating existing screens to ensure consistent design and interactive testing. | Create a preview for the ProductCard widget with different price states |
| [flutter-add-widget-test](skills/flutter-add-widget-test/SKILL.md) | Implement a component-level test using `WidgetTester` to verify UI rendering and user interactions (tapping, scrolling, entering text). Use when validating that a specific widget displays correct data and responds to events as expected. | Add a widget test for the CustomButton to verify the onTap callback is called |
| [flutter-apply-architecture-best-practices](skills/flutter-apply-architecture-best-practices/SKILL.md) | Adds a Flutter feature using feature-first Clean Architecture with Cubit, use cases, FpDart, injectable, and core services. Use when structuring a project, adding a feature, or refactoring state management and layers. | Add a sign-in feature with a Cubit, use case, and repository |
| [flutter-apply-responsive-text](skills/flutter-apply-responsive-text/SKILL.md) | Applies the project's typography and keeps text readable in constrained space by choosing between wrapping, maxLines with ellipsis, and bounded shrinking. Use when creating or changing text widgets, fixing text overflow, adding typography styles, or adapting text to screen size and text scaling. | Make the product card title fit two lines without overflowing |
| [flutter-build-form](skills/flutter-build-form/SKILL.md) | Builds a Flutter form with formz inputs, a Cubit, and stateless field widgets, wired to an existing use case. Use when adding a form, adding fields to a form, or changing form validation. | Add a login form with email and password validation |
| [flutter-build-responsive-layout](skills/flutter-build-responsive-layout/SKILL.md) | Use `LayoutBuilder`, `MediaQuery`, or `Expanded/Flexible` to create a layout that adapts to different screen sizes. Use when you need the UI to look good on both mobile and tablet/desktop form factors. | Make the home screen responsive so it displays a grid on tablets and a list on phones |
| [flutter-fix-layout-issues](skills/flutter-fix-layout-issues/SKILL.md) | Fixes Flutter layout errors (overflows, unbounded constraints) using Dart and Flutter MCP tools. Use when addressing "RenderFlex overflowed", "Vertical viewport was given unbounded height", or similar layout issues. | Fix the overflow error on the profile page when the keyboard is visible |
| [flutter-implement-json-serialization](skills/flutter-implement-json-serialization/SKILL.md) | Map JSON with `dart:convert` on data-layer models that expose `fromJson`, `toJson`, and `toEntity`. Use when adding or changing API models. Keep domain entities free of JSON. | Add a UserModel with fromJson, toJson, and toEntity |
| [flutter-setup-declarative-routing](skills/flutter-setup-declarative-routing/SKILL.md) | Configure `MaterialApp.router` using a package like `go_router` for advanced URL-based navigation. Use when developing web applications or mobile apps that require specific deep linking and browser history support. | Set up GoRouter with paths for home, details, and settings |
| [flutter-setup-flavors](skills/flutter-setup-flavors/SKILL.md) | Sets up environment config with envied, AppConfig, and injectable environments for a single environment, several flavors, or one more flavor such as demo or qa. Use when creating environments, adding or converting flavors, or moving hardcoded config into AppConfig. | Set up dev, pre, and prod flavors with envied |
| [flutter-setup-localization](skills/flutter-setup-localization/SKILL.md) | Add `flutter_localizations` and `intl` dependencies, enable "generate true" in `pubspec.yaml`, and create an `l10n.yaml` configuration file. Use when initializing localization support for a new Flutter project. | Setup localization and add English and Spanish translations |
| [flutter-use-http-package](skills/flutter-use-http-package/SKILL.md) | Calls a REST API through the app's `NetworkService` and implements that service with `http`, Dio, or another client. Use when a feature fetches from or sends data to a REST API, or when adding or replacing the HTTP client. | Fetch the product list from the API through NetworkService and a Cubit |
| [flutter-wrap-package-service](skills/flutter-wrap-package-service/SKILL.md) | Wraps an infrastructure package (HTTP client, Firebase, secure storage, image picker, sharing, location, permissions) behind a core service interface and impl registered with injectable. Use when adding, replacing, or using a package that does I/O, calls platform channels, or exposes a vendor API. | Add image_picker behind an ImagePickerService |
## Contributing

We aren't accepting pull requests at this time, but we would love to hear your feedback! 

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for more information.

## Code of Conduct

Please see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for more information.
