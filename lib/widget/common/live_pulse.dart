import 'package:flutter/material.dart';

class LivePulse extends StatefulWidget {
  final Color color;
  final double size;

  const LivePulse({super.key, this.color = const Color(0xFF4CAF50), this.size = 8});

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _anim,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: widget.color.withAlpha(120), blurRadius: 6)]),
          ),
        ),
        const SizedBox(width: 5),
        Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.color, letterSpacing: 1)),
      ],
    );
  }
}
