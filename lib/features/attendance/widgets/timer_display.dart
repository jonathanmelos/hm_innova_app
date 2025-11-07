import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final Duration elapsed;
  const TimerDisplay({super.key, required this.elapsed});

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);

    return Text(
      '${_two(h)}:${_two(m)}:${_two(s)}',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
      textAlign: TextAlign.center,
    );
  }
}
