import 'package:flutter/material.dart';
// import 'package:flutter/gestures.dart';

class DraggableDivider extends StatefulWidget {
  final double width;
  final Color color;
  final Color hoverColor;
  final Function(double) onDragUpdate;
  final Color? leftBackgroundColor; // 左侧背景色
  final Color? rightBackgroundColor; // 右侧背景色

  const DraggableDivider({
    super.key,
    this.width = 8.0,
    required this.color,
    required this.hoverColor,
    required this.onDragUpdate,
    this.leftBackgroundColor,
    this.rightBackgroundColor,
  });

  @override
  State<DraggableDivider> createState() => _DraggableDividerState();
}

class _DraggableDividerState extends State<DraggableDivider> {
  bool _isHovering = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          widget.onDragUpdate(details.delta.dx);
        },
        child: Container(
          width: widget.width,
          color: _isHovering ? widget.hoverColor : Colors.transparent,
          child: Center(
            child: Stack(
              children: [
                // 左侧背景
                if (widget.leftBackgroundColor != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.width / 2,
                    child: Container(
                      color: widget.leftBackgroundColor,
                    ),
                  ),
                // 右侧背景
                if (widget.rightBackgroundColor != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.width / 2,
                    child: Container(
                      color: widget.rightBackgroundColor,
                    ),
                  ),
                // 悬停时的高亮背景
                // if (_isHovering)
                //   Container(
                //     width: double.infinity,
                //     height: double.infinity,
                //     color: widget.hoverColor,
                //   ),
                // 分割线
                Center(
                  child: Container(
                    width: 1,
                    height: double.infinity,
                    color: _isHovering ? Colors.transparent : widget.color,
                  ),
                ),
              ],
            ),
            // child: Container(
            //   width: 1,
            //   height: double.infinity,
            //   color: _isHovering ? Colors.transparent : widget.color,
            // ),
          ),
        ),
      ),
    );
  }
}