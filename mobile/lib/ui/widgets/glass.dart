import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Liquid Glass building blocks: frosted cards over a softly lit background.

/// Static blurred color spots under the content so glass surfaces have something to refract.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    Widget spot({
      double? left,
      double? right,
      required double top,
      required double w,
      required double h,
      required Color c,
    }) => Positioned(
      left: left,
      right: right,
      top: top,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
    );
    return ColoredBox(
      color: Brand.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45, tileMode: TileMode.decal),
                child: Stack(
                  children: [
                    spot(right: -90, top: -60, w: 300, h: 280, c: Brand.accent.withValues(alpha: 0.6)),
                    spot(
                      left: -150,
                      top: size.height * 0.36,
                      w: 320,
                      h: 320,
                      c: Brand.glowBlue.withValues(alpha: 0.55),
                    ),
                    spot(
                      right: -110,
                      top: size.height * 0.62,
                      w: 280,
                      h: 260,
                      c: Brand.glowCyan.withValues(alpha: 0.4),
                    ),
                    spot(
                      left: -90,
                      top: size.height * 0.86,
                      w: 260,
                      h: 200,
                      c: Brand.glowRoyal.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Frosted card: background blur, white 11% -> 4% fill and a 1px white 14% stroke.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = Brand.radiusCard,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.glow = false,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Radial accent glow in the top right corner (hero card).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: Brand.glassBlurSigma, sigmaY: Brand.glassBlurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: Brand.glassGradient,
            border: Border.all(color: Brand.glassStroke),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: glow
                  ? RadialGradient(
                      center: const Alignment(1.1, -1.1),
                      radius: 1.1,
                      colors: [Brand.accent.withValues(alpha: 0.27), Brand.accent.withValues(alpha: 0)],
                    )
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: shape,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round glass button (e.g. notifications). Keeps a 44×44 touch target.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 22,
    this.onTap,
    this.tooltip,
    this.dot = false,
  });
  final IconData icon;
  final double size, iconSize;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Small accent dot in the corner (e.g. unread notifications).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassCard(
            radius: size / 2,
            padding: EdgeInsets.zero,
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: iconSize, color: Brand.textPrimary),
            ),
          ),
          if (dot)
            Positioned(
              right: size * 0.2,
              top: size * 0.2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Brand.accent, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Colored square plate with an icon (44×44, radius 14 by default).
class IconPlate extends StatelessWidget {
  const IconPlate({
    super.key,
    required this.icon,
    this.color = Brand.blue,
    this.iconColor = Brand.blueIcon,
    this.size = 44,
  });
  final IconData icon;
  final Color color, iconColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(size * 0.32),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Icon(icon, color: iconColor, size: size / 2),
  );
}

/// Section title (20, bold) with an optional accent action or label on the right.
class GlassSectionHeader extends StatelessWidget {
  const GlassSectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionText = action == null
        ? null
        : Text(
            action!,
            style: const TextStyle(color: Brand.accent, fontSize: 15, fontWeight: FontWeight.w600),
          );
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Brand.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (actionText != null)
            onAction == null
                // Same inset as a TextButton so plain labels line up with tappable actions.
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: actionText)
                : TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: actionText,
                  ),
        ],
      ),
    );
  }
}

/// Capsule button with the brand gradient and white text.
class GradientPillButton extends StatelessWidget {
  const GradientPillButton({super.key, required this.label, this.icon, required this.onPressed, this.height = 46});
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => PressScale(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: Brand.buttonGradient,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [BoxShadow(color: Brand.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: Colors.white, size: 20)],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Glass capsule button; [onPressed] null renders it disabled with an optional [badge] (e.g. «скоро»).
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.badge,
    this.height = 46,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? badge;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? Brand.textPrimary : Brand.textTertiary;
    final button = Opacity(
      opacity: enabled ? 1 : 0.85,
      child: GlassCard(
        radius: height / 2,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: badge == null ? null : '$label, $badge',
      excludeSemantics: badge != null,
      child: badge == null
          ? button
          // The badge sits on the top edge so it does not take width from neighbouring buttons.
          : Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                button,
                Positioned(top: -8, right: 10, child: SoonBadge(badge!)),
              ],
            ),
    );
  }
}

/// Status capsule with a dot: tinted fill (12%), stroke (25%) and colored text.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, Color? textColor})
    : textColor = textColor ?? color;
  final String label;
  final Color color, textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Shrinks its child slightly while pressed (Liquid Glass press feedback).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (widget.enabled && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Small capsule label used as a «скоро» marker on disabled controls.
class SoonBadge extends StatelessWidget {
  const SoonBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C21),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Brand.glassStroke),
    ),
    child: Text(
      label,
      style: TextStyle(color: Brand.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

/// Segmented control: a 48 high glass capsule with an animated white 18% thumb under the selected segment.
class GlassSegmentedControl extends StatelessWidget {
  const GlassSegmentedControl({super.key, required this.segments, required this.index, required this.onChanged});
  final List<String> segments;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 24,
    padding: const EdgeInsets.all(4),
    child: SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == index) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    color: i == index ? Brand.textPrimary : Brand.textSecondary,
                                    fontSize: 15,
                                    fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                  child: Text(segments[i]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// Square-ish glass tile with a round colored icon and a caption; disabled when [onTap] is null.
class GlassActionTile extends StatelessWidget {
  const GlassActionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
    this.badge,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tile = Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 9),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(color: Brand.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: badge == null ? label : '$label, $badge',
      excludeSemantics: true,
      child: badge == null
          ? tile
          : Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                tile,
                Positioned(top: -7, right: 4, child: SoonBadge(badge!)),
              ],
            ),
    );
  }
}

/// Glass card holding rows separated by hairline dividers.
class GlassList extends StatelessWidget {
  const GlassList({super.key, required this.children, this.dividerIndent = 16});
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: dividerIndent,
              endIndent: 16,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          children[i],
        ],
      ],
    ),
  );
}

/// Pulsing glass placeholder in the shape of the card that is loading.
class GlassSkeleton extends StatefulWidget {
  const GlassSkeleton({super.key, required this.height, this.radius = Brand.radiusCard, this.width});
  final double height, radius;
  final double? width;

  @override
  State<GlassSkeleton> createState() => _GlassSkeletonState();
}

class _GlassSkeletonState extends State<GlassSkeleton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: Brand.glassGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
  );
}

/// Dark glass bottom sheet with a grab handle.
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: const Color(0xFF141418),
  showDragHandle: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Brand.radiusHero))),
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Brand.sidePadding, 0, Brand.sidePadding, 16),
      child: builder(context),
    ),
  ),
);

class GlassTabItem {
  const GlassTabItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon, activeIcon;
  final String label;
}

/// Floating Liquid Glass tab bar: capsule with dark glass, blur and an accent pill under the active tab.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.items, required this.index, required this.onSelected});
  final List<GlassTabItem> items;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    const radius = BorderRadius.all(Radius.circular(Brand.tabBarHeight / 2));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, Brand.tabBarBottom + (bottom > 0 ? bottom - 10 : 0)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: Brand.tabBarHeight,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2A2A30).withValues(alpha: 0.78),
                    const Color(0xFF16161A).withValues(alpha: 0.8),
                  ],
                ),
                border: Border.all(color: Brand.glassStroke),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _TabButton(item: items[i], selected: i == index, onTap: () => onSelected(i)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.item, required this.selected, required this.onTap});
  final GlassTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Brand.accent : Colors.white.withValues(alpha: 0.65);
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            color: selected ? Brand.accent.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(color: selected ? Brand.accent.withValues(alpha: 0.3) : Colors.transparent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? item.activeIcon : item.icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
