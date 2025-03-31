import 'package:flutter/material.dart';

class UnlockAnimation extends StatefulWidget {
  final bool isUnlocking;
  final bool unlocked;
  
  const UnlockAnimation({
    super.key, 
    required this.isUnlocking,
    required this.unlocked,
  });

  @override
  State<UnlockAnimation> createState() => _UnlockAnimationState();
}

class _UnlockAnimationState extends State<UnlockAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 30,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeInOut),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UnlockAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnlocking && !oldWidget.isUnlocking) {
      _controller.repeat();
    } else if (widget.unlocked && !oldWidget.unlocked) {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.unlocked ? _scaleAnimation.value : 1.0,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 3.14,
            child: const Icon(
              Icons.lock_open,
              size: 48,
              color: Colors.blue,
            ),
          ),
        );
      },
    );
  }
}