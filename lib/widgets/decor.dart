import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scatters ingredient illustrations in the four corners behind [child].
class IngredientCorners extends StatelessWidget {
  final Widget child;
  final double size;
  final double opacity;
  const IngredientCorners({super.key, required this.child, this.size = 64, this.opacity = 0.9});

  static const _tl = ['tomato', 'basil', 'garlic'];
  static const _tr = ['lemon', 'chili', 'mushroom'];
  static const _bl = ['carrot', 'onion', 'cheese'];
  static const _br = ['egg', 'corn', 'bread'];

  Widget _cluster(List<String> names, bool left, bool top, double baseAngle) {
    // distance from the two corner edges for each item (negative = partly off-screen)
    final pos = [
      Offset(-size * 0.22, -size * 0.22),
      Offset(size * 0.70, -size * 0.30),
      Offset(-size * 0.30, size * 0.68),
    ];
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (var i = 0; i < names.length; i++)
          Positioned(
            left: left ? pos[i].dx : null,
            right: left ? null : pos[i].dx,
            top: top ? pos[i].dy : null,
            bottom: top ? null : pos[i].dy,
            child: Transform.rotate(
              angle: baseAngle + i * 0.45,
              child: Opacity(
                opacity: opacity,
                child: Image.asset('assets/decor/${names[i]}.png',
                    width: size * (i == 0 ? 1.0 : 0.72), height: size * (i == 0 ? 1.0 : 0.72)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(children: [
                Positioned.fill(child: _cluster(_tl, true, true, -0.3)),
                Positioned.fill(child: _cluster(_tr, false, true, 0.3)),
                Positioned.fill(child: _cluster(_bl, true, false, math.pi / 8)),
                Positioned.fill(child: _cluster(_br, false, false, -math.pi / 8)),
              ]),
            ),
          ),
          child,
        ],
      );
}

/// A colorful rounded button tile used on the home page and category grids.
class CategoryTile extends StatelessWidget {
  final String label;
  final String? emoji;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback onTap;
  final bool compact;

  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.emoji,
    this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.18)!;
    final deep = Color.lerp(color, Colors.black, 0.18)!;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [light, deep], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: deep.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Stack(
              children: [
                Positioned(
                  right: -6,
                  bottom: -10,
                  child: Icon(icon, size: compact ? 54 : 74, color: Colors.white.withValues(alpha: 0.16)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji ?? '', style: TextStyle(fontSize: compact ? 26 : 32)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: compact ? 15 : 17,
                                height: 1.1,
                                shadows: const [Shadow(blurRadius: 3, color: Colors.black38)])),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header with a little colored bar.
class SectionHeader extends StatelessWidget {
  final String text;
  final Color? color;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.color, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(
          children: [
            Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                    color: color ?? Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22))),
            ?trailing,
          ],
        ),
      );
}
