---
name: flutter-apply-responsive-text
description: Applies the project's typography and keeps text readable in constrained space by choosing between wrapping, maxLines with ellipsis, and bounded shrinking. Use when creating or changing text widgets, fixing text overflow, adding typography styles, or adapting text to screen size and text scaling.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 22:20:00 GMT
---
# Applying Responsive Text

Follow the Flutter Architecture rule. Typography and text helpers live in `core/theme/`. Feature widgets use them and never hardcode a font size, weight, or color.

Text adapts by wrapping or truncating first. Shrinking text is the last option, never goes below a readable size, and never undoes the user's text scaling. A layout error such as "RenderFlex overflowed" is a constraint problem first: follow `flutter-fix-layout-issues`, and `flutter-build-responsive-layout` for layouts per screen size.

## Workflow

- [ ] **1. Inspect.** Read `core/theme/` and the nearest feature. Find the project's text styles (a `TextTheme` in `ThemeData`, a `ThemeExtension`, or a `BuildContext` extension such as `context.h1`) and any fit helper (such as a `.responsive()` extension). Use their names and imports.
- [ ] **2. Style.** Pick the style by the text's role: headings, body, secondary text, captions. Reuse an existing style. Add a style to `core/theme/` only when the design needs one that does not exist, and never inside a feature.
- [ ] **3. Constraints.** Check the parent. Text that shares a `Row` with other widgets goes in `Expanded` or `Flexible`. Text inside a scrollable or an unbounded parent needs a bounded width before any fit behavior works.
- [ ] **4. Behavior.** Choose one behavior from the table below. Do not apply a fit helper to every `Text`.
- [ ] **5. Test.** Add a widget test with a long value, a narrow width, and `TextScaler.linear(2)` for text that can overflow. For a widget with previews, add a preview with a large `textScaleFactor`.
- [ ] **6. Checks.** Run the formatter, `dart analyze`, and the relevant tests. Report which commands ran.

## Choosing a behavior

| Text | Behavior |
|---|---|
| Paragraph or body content | Wrap naturally. No `maxLines`, no shrinking. |
| Dynamic value in a row or card (name, title from an API) | `Expanded` or `Flexible`, `maxLines`, `TextOverflow.ellipsis`. |
| Short label that must stay whole (button, tab, chip, badge) | The project's fit helper, with a readable minimum size. |
| Heading limited to one or two lines | `maxLines` plus the fit helper, with a readable minimum size; ellipsis when it still does not fit. |

The readable minimum is the project's caption size, or 12 logical pixels when there is none. When the text is truncated, keep the full value reachable (a details screen, a tooltip, or `semanticsLabel`).

## Typography in `core/theme/`

When the project has no typography yet, define it once in the theme and read it through `Theme`, so fonts, colors, and dark mode apply everywhere:

```dart
// core/theme/app_text_theme.dart
const appTextTheme = TextTheme(
  headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
  titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
);
```

`ThemeData(textTheme: appTextTheme)` registers it. When the project prefers short names, a `BuildContext` extension maps them to the theme instead of holding its own constants:

```dart
// core/theme/text_styles.dart
extension TextStyles on BuildContext {
  TextTheme get _text => Theme.of(this).textTheme;

  TextStyle get h2 => _text.headlineLarge!;
  TextStyle get body => _text.bodyLarge!;
  TextStyle get caption => _text.bodySmall!;
}
```

If the project's extension holds constant styles that ignore the theme, keep using it; mention the limitation and change it only when the request asks.

## Fit helper

Use the project's helper when it exists. Add one only when the request asks for shrinking text and none exists. With `auto_size_text`, it passes every relevant `Text` property through, keeps the minimum readable, and aligns to the start:

```dart
// core/theme/responsive_text.dart
extension ResponsiveText on Text {
  Widget responsive({double minFontSize = 12}) {
    final text = data;
    if (text == null) return this;
    if (maxLines == null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: this,
      );
    }
    return AutoSizeText(
      text,
      key: key,
      style: style,
      strutStyle: strutStyle,
      maxLines: maxLines,
      minFontSize: minFontSize,
      overflow: overflow,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }
}
```

Without `maxLines`, the helper keeps the text on one line and scales it down, so use that form only for short labels, never for paragraphs. `Text.rich` is returned unchanged.

An existing helper can have known limits: it crashes on `Text.rich` (`data!`), drops `overflow` so ellipsis never shows, allows a minimum such as 2 pixels, or centers the text inside `FittedBox`. Report the limit you find and propose the smallest fix; change shared code only when the request allows it.

## Examples

Dynamic value next to an icon:

```dart
Row(
  children: [
    const Icon(Icons.person),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        user.name,
        style: context.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
)
```

Button label that must stay whole:

```dart
FilledButton(
  onPressed: onContinue,
  child: Text('Continue', style: context.body).responsive(),
)
```

Card title limited to two lines:

```dart
Text(
  product.name,
  style: context.h2,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
).responsive(minFontSize: 16)
```

## Tests

```dart
testWidgets('long name does not overflow at 2x text scale', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(textTheme: appTextTheme),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: UserTile(name: 'A very long name ' * 5),
            ),
          ),
        ),
      ),
    ),
  );

  expect(tester.takeException(), isNull);
});
```

## Do not

- Hardcode `fontSize`, `fontWeight`, or colors in a feature widget.
- Set a fixed `textScaler` to stop text from growing, or shrink text below the readable minimum.
- Use `FittedBox` or the fit helper on paragraphs, or as the fix for every overflow.
- Add a second responsive text package or duplicate the helper inside a feature.
