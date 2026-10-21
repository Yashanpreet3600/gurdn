import 'package:flutter/material.dart';

import 'pin_sheet.dart';

/// A plausible weather screen. A long-press on the temperature opens the
/// hidden passcode pad. Shows static sample data (no network needed, and
/// nothing to look wrong if offline).
class WeatherFace extends StatelessWidget {
  const WeatherFace({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF2B5876), Color(0xFF4E4376)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('Ludhiana', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
                  const Text('Partly cloudy', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 30),
                  Center(
                    child: GestureDetector(
                      // Hidden entry: long-press the big temperature.
                      onLongPress: () => PinSheet.show(context),
                      child: const Text('28°',
                          style: TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.w200)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Day('Mon', Icons.wb_sunny, '31°'),
                      _Day('Tue', Icons.cloud, '27°'),
                      _Day('Wed', Icons.grain, '24°'),
                      _Day('Thu', Icons.wb_cloudy, '29°'),
                    ],
                  ),
                  const Spacer(),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Stat('Humidity', '62%'),
                      _Stat('Wind', '8 km/h'),
                      _Stat('UV', 'Low'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day(this.day, this.icon, this.temp);
  final String day;
  final IconData icon;
  final String temp;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(day, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Icon(icon, color: Colors.white),
        const SizedBox(height: 6),
        Text(temp, style: const TextStyle(color: Colors.white)),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ]);
}
