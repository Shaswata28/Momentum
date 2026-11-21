import 'package:flutter/material.dart';

/// Exposes the tab-entrance animation from the main shell so cards can
/// stagger in on every tab switch instead of only on their first build.
class TabEntranceAnimation extends InheritedWidget {
  final Animation<double> animation;

  const TabEntranceAnimation({
    super.key,
    required this.animation,
    required super.child,
  });

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabEntranceAnimation>()
          ?.animation;

  @override
  bool updateShouldNotify(TabEntranceAnimation oldWidget) =>
      animation != oldWidget.animation;
}

/// Fade + rise entrance shared by the Today, Wallet, and Insights screens.
///
/// While a [TabEntranceAnimation] is in scope and still running, the card
/// follows the shared cascade — replaying on every tab switch. Otherwise
/// (dynamic insertions, bottom sheets, standalone screens) it falls back to a
/// one-shot entrance on first build.
class StaggeredCard extends StatefulWidget {
  final Widget child;
  final int index;

  const StaggeredCard({super.key, required this.child, required this.index});

  @override
  State<StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<StaggeredCard> {
  Animation<double>? _entrance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final entrance = TabEntranceAnimation.maybeOf(context);
    if (entrance != null && entrance.status != AnimationStatus.completed) {
      _entrance = entrance;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final entrance = _entrance;
    if (entrance != null) {
      final start = (widget.index * 0.055).clamp(0.0, 0.35);
      final interval = Interval(start, (start + 0.65).clamp(0.0, 1.0));
      return AnimatedBuilder(
        animation: entrance,
        builder: (context, _) {
          final value = Curves.easeOutCubic
              .transform(interval.transform(entrance.value))
              .clamp(0.0, 1.0);
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: widget.child,
            ),
          );
        },
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 360 + (widget.index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1.0 - value)),
            child: widget.child,
          ),
        );
      },
    );
  }
}
