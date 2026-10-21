import 'package:flutter/material.dart';

import 'pin_sheet.dart';

/// A plausible photo gallery of coloured tiles (gradients, not real photos,
/// so nothing loads from the network). A long-press on the header opens the
/// hidden passcode pad.
class GalleryFace extends StatelessWidget {
  const GalleryFace({super.key});

  static const _gradients = [
    [Color(0xFFff9a9e), Color(0xFFfad0c4)],
    [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
    [Color(0xFF84fab0), Color(0xFF8fd3f4)],
    [Color(0xFFffecd2), Color(0xFFfcb69f)],
    [Color(0xFFa1c4fd), Color(0xFFc2e9fb)],
    [Color(0xFFd4fc79), Color(0xFF96e6a1)],
    [Color(0xFFfbc2eb), Color(0xFFa6c1ee)],
    [Color(0xFFfdcbf1), Color(0xFFe6dee9)],
    [Color(0xFFf6d365), Color(0xFFfda085)],
    [Color(0xFFe0c3fc), Color(0xFF8ec5fc)],
    [Color(0xFF4facfe), Color(0xFF00f2fe)],
    [Color(0xFF43e97b), Color(0xFF38f9d7)],
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light, useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GestureDetector(
                  onLongPress: () => PinSheet.show(context),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text('Photos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _gradients[i % _gradients.length]),
                      ),
                    ),
                    childCount: 36,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
