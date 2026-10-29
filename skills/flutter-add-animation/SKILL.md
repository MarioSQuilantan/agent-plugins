---
name: flutter-add-animation
description: Adds Flutter animations at the lowest level that works, from implicit widgets to AnimationController, page transitions, Hero, and animated painters, driven by Cubit state and respecting reduced motion. Use when animating a widget, a state change, a list, a route transition, or a custom drawing.
metadata:
  model: manual
  last_modified: Sun, 25 Oct 2026 22:50:00 GMT
---
# Adding Animations

Follow the Flutter Architecture rule. Animation state is UI state that never leaves the widget, so an `AnimationController` lives in a `StatefulWidget`, never in a Cubit. The Cubit decides what to show; the widget decides how it moves.

## Workflow

- [ ] **1. Inspect.** Read the nearest feature and `core/theme/`. Reuse existing motion constants, transition builders, and animation packages (Lottie, Rive) before adding anything.
- [ ] **2. Level.** Pick the lowest level from the table below that expresses the motion.
- [ ] **3. Implement.** Colors come from `Theme.of(context).colorScheme`, durations from `Durations`, and curves from `Easing` or `Curves`, unless the project defines its own motion constants in `core/theme/`.
- [ ] **4. Reduced motion.** When `MediaQuery.disableAnimationsOf(context)` is true, skip decorative motion, stop repeating animations, and use `Duration.zero` or a plain fade for transitions.
- [ ] **5. Test.** Use `pump(duration)` to step through the animation. Never call `pumpAndSettle` while a repeating animation runs; it throws "pumpAndSettle timed out".
- [ ] **6. Checks.** Run the formatter, `dart analyze`, and the relevant tests. Profile in profile mode with DevTools when the animation runs every frame. Report which commands ran.

## Choosing a level

| Need | Use |
|---|---|
| A property moves to a new value (size, color, padding, opacity, alignment) | An `Animated*` widget: `AnimatedContainer`, `AnimatedOpacity`, `AnimatedAlign`, `AnimatedPadding` |
| Scale, rotation, or offset without relayout | `AnimatedScale`, `AnimatedRotation`, `AnimatedSlide` |
| One widget replaces another (Cubit state change) | `AnimatedSwitcher` with a key per state |
| A value with no `Animated*` widget | `TweenAnimationBuilder` |
| Play, pause, reverse, repeat, or sync several properties | `AnimationController` with `SingleTickerProviderStateMixin` |
| Items entering in sequence | One controller with an `Interval` per item |
| Route transition | `CustomTransitionPage` in the GoRouter route |
| Shared element between routes | `Hero` |
| Custom drawing every frame | `CustomPainter` with `repaint:` and a `RepaintBoundary` |

## Rules

- Dispose every `AnimationController` and every `CurvedAnimation` you create, in `dispose()`. A controller still ticking at dispose throws "was disposed with an active Ticker".
- Use `SingleTickerProviderStateMixin` for one controller and `TickerProviderStateMixin` for several. `vsync: this` lets an ancestor `TickerMode` mute the ticker, for example on a covered route.
- Create animations in `initState`, never in `build`. Derive an animation with `controller.drive(...)` or `Tween.animate` once.
- Give each `AnimatedSwitcher` child a key that changes with the content (`ValueKey`), or it will not animate.
- Never animate by calling `setState` from a timer or a loop.
- Keep UI transitions between `Durations.short4` and `Durations.medium4` (200 to 400 ms).
- A `Hero` tag is unique within a route. In a list, include the item id in the tag.
- Do not put an `AnimationController`, `Animation`, or duration in a Cubit state. To react to a state change, pass the value to the animated widget and act in `didUpdateWidget`, or trigger it from the page's `BlocListener`.

## Examples

State change in a view, driven by the Cubit state the page passes in:

```dart
AnimatedSwitcher(
  duration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Durations.medium2,
  child: switch (state) {
    ProfileInitial() || ProfileLoading() =>
      const CircularProgressIndicator(key: ValueKey('loading')),
    ProfileLoaded(:final user) => UserCard(key: ValueKey(user.id), user: user),
    ProfileFailure(:final failure) =>
      ErrorMessage(key: const ValueKey('failure'), failure: failure, onRetry: onRetry),
  },
)
```

One-shot animation when a value changes, without reading a Cubit:

```dart
class ShakeOnFailure extends StatefulWidget {
  const ShakeOnFailure({super.key, required this.failure, required this.child});

  final Failure? failure;
  final Widget child;

  @override
  State<ShakeOnFailure> createState() => _ShakeOnFailureState();
}

class _ShakeOnFailureState extends State<ShakeOnFailure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: Durations.medium2);
  late final Animation<double> _offset = _controller.drive(
    TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]),
  );

  @override
  void didUpdateWidget(ShakeOnFailure oldWidget) {
    super.didUpdateWidget(oldWidget);
    final failed = widget.failure != null && widget.failure != oldWidget.failure;
    if (failed && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _offset,
        builder: (context, child) =>
            Transform.translate(offset: Offset(_offset.value, 0), child: child),
        child: widget.child,
      );
}
```

Repeating animation that stops under reduced motion:

```dart
class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: Durations.long2);
  late final Animation<double> _scale = _controller
      .drive(CurveTween(curve: Easing.standard))
      .drive(Tween(begin: 0.8, end: 1.2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(dimension: 16),
        ),
      );
}
```

`_controller.value = 0.5` stops the repeat and shows the dot at its resting size.

Staggered items, with each interval built once:

```dart
class _StaggeredListState extends State<StaggeredList>
    with SingleTickerProviderStateMixin {
  static const _maxStaggered = 8;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: Durations.long2)..forward();
  late final List<Animation<double>> _items = List.generate(
    _maxStaggered,
    (index) => _controller.drive(
      CurveTween(
        curve: Interval(
          index / (_maxStaggered + 1),
          (index + 2) / (_maxStaggered + 1),
          curve: Easing.emphasizedDecelerate,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final tile = ListTile(title: Text(widget.items[index]));
          if (index >= _maxStaggered) return tile;
          final animation = _items[index];
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(0, 0.1), end: Offset.zero),
              ),
              child: tile,
            ),
          );
        },
      );
}
```

Only the first items stagger, so the total duration stays the same for long lists.

Route transition with GoRouter:

```dart
GoRoute(
  path: '/products/:id',
  pageBuilder: (context, state) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Durations.medium2;
    return CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      child: ProductDetailPage(id: state.pathParameters['id']!),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
        opacity: animation.drive(CurveTween(curve: Easing.emphasizedDecelerate)),
        child: child,
      ),
    );
  },
)
```

Shared element, with the item id in the tag:

```dart
InkWell(
  onTap: () => context.push('/products/${product.id}'),
  child: Hero(
    tag: 'product-image-${product.id}',
    child: Image.network(product.imageUrl, fit: BoxFit.cover),
  ),
)
```

The destination uses the same tag and a child with the same shape, so the flight does not jump.

Painter that repaints from the animation without rebuilding widgets:

```dart
import 'dart:math';

class WavePainter extends CustomPainter {
  WavePainter({required this.progress, required this.color})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x++) {
      final phase = (x / size.width + progress.value) * 2 * pi;
      path.lineTo(x, size.height / 2 + sin(phase) * 20);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// In the State that owns the controller:
RepaintBoundary(
  child: CustomPaint(
    size: const Size(double.infinity, 100),
    painter: WavePainter(
      progress: _controller,
      color: Theme.of(context).colorScheme.primary,
    ),
  ),
)
```

## Tests

```dart
testWidgets('shakes when a failure arrives', (tester) async {
  Widget build(Failure? failure) => MaterialApp(
        theme: appTheme,
        home: ShakeOnFailure(failure: failure, child: const Text('Form')),
      );

  await tester.pumpWidget(build(null));
  await tester.pumpWidget(build(const NetworkFailure()));
  await tester.pump(Durations.short4);

  final transform = tester.widget<Transform>(
    find.ancestor(of: find.text('Form'), matching: find.byType(Transform)).first,
  );
  expect(transform.transform.getTranslation().x, isNot(0));

  await tester.pumpAndSettle();
});

testWidgets('reduced motion skips the shake', (tester) async {
  Widget build(Failure? failure) => MaterialApp(
        theme: appTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ShakeOnFailure(failure: failure, child: const Text('Form')),
        ),
      );

  await tester.pumpWidget(build(null));
  await tester.pumpWidget(build(const NetworkFailure()));

  expect(tester.hasRunningAnimations, isFalse);
});
```

For a repeating animation, assert after `pump(duration)` and let the widget be disposed at the end of the test; do not call `pumpAndSettle`.
