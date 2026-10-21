import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/recipe_store.dart';
import 'home_screen.dart';

/// Opening screen styled like the cover of a cloth-bound cookbook,
/// with a photo of a table full of dishes set into the cover.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3200), _open);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    if (_leaving) return;
    _leaving = true;
    final store = context.read<RecipeStore>();
    while (!store.loaded) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, _, _) => const HomeScreen(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(a), child: child),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF3D27A);
    return Scaffold(
      backgroundColor: const Color(0xFF3B0F0C),
      body: GestureDetector(
        onTap: _open,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          final spine = w * 0.075;
          return Stack(
            children: [
              // Cloth cover
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.2, -0.3),
                      radius: 1.3,
                      colors: [const Color(0xFF9E2A1E), const Color(0xFF6E1A13), const Color(0xFF3B0F0C)],
                    ),
                  ),
                  child: Image.asset('assets/images/linen.png',
                      repeat: ImageRepeat.repeat, color: Colors.white.withValues(alpha: 0.07), colorBlendMode: BlendMode.modulate),
                ),
              ),
              // Spine with stitching and hinge shadow
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: spine,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF240806),
                      const Color(0xFF5A1610),
                      const Color(0xFF2A0A07),
                    ], stops: const [0, 0.55, 1]),
                  ),
                ),
              ),
              Positioned(
                left: spine,
                top: 0,
                bottom: 0,
                width: 14,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0x99000000), Color(0x00000000)]),
                  ),
                ),
              ),
              // Gold border frame
              Positioned(
                left: spine + 18,
                right: 18,
                top: 22,
                bottom: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: gold.withValues(alpha: 0.85), width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: gold.withValues(alpha: 0.5), width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              Positioned(
                left: spine + 34,
                right: 34,
                top: 40,
                bottom: 36,
                child: Column(
                  children: [
                    SizedBox(height: h * 0.02),
                    Text('THE',
                        style: TextStyle(
                            fontFamily: 'PlayfairDisplay', color: gold, letterSpacing: 8, fontSize: w * 0.04)),
                    FittedBox(
                      child: Text(
                        appTitle,
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontWeight: FontWeight.w900,
                          fontSize: 64,
                          color: gold,
                          shadows: const [
                            Shadow(color: Colors.black54, offset: Offset(2, 3), blurRadius: 4),
                            Shadow(color: Color(0x55FFFFFF), offset: Offset(-1, -1)),
                          ],
                        ),
                      ),
                    ),
                    Text('Family  •  Friends  •  The World’s Kitchens',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Lora',
                            fontStyle: FontStyle.italic,
                            color: gold.withValues(alpha: 0.9),
                            fontSize: w * 0.036)),
                    SizedBox(height: h * 0.03),
                    // Photo of a table full of dishes, set into the cover like a tipped-in plate.
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: gold, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 8)),
                          ],
                        ),
                        child: Image.asset('assets/images/cover.jpg', fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                    SizedBox(height: h * 0.03),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 40, height: 1.5, color: gold),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.restaurant_menu, color: gold, size: w * 0.07),
                      ),
                      Container(width: 40, height: 1.5, color: gold),
                    ]),
                    const SizedBox(height: 8),
                    Text('Tap to open',
                        style: TextStyle(color: gold.withValues(alpha: 0.75), fontSize: 13, letterSpacing: 2)),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
