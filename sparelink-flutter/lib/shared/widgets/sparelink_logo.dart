import 'package:flutter/material.dart';

/// SpareLink Logo - Camera focus with bracket shapes
/// 
/// Design: Center circle with four [ bracket shapes facing inward
/// - Top: ] facing down toward circle
/// - Bottom: [ facing up toward circle
/// - Left: ] facing right toward circle  
/// - Right: [ facing left toward circle
class SpareLinkLogo extends StatelessWidget {
  final double size;
  final Color color;

  const SpareLinkLogo({
    super.key,
    this.size = 40,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SpareLinkLogoPainter(color: color),
    );
  }
}

class _SpareLinkLogoPainter extends CustomPainter {
  final Color color;

  _SpareLinkLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double strokeWidth = s * 0.065;
    final double center = s / 2;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // === CENTER CIRCLE ===
    final double circleRadius = s * 0.10;
    canvas.drawCircle(
      Offset(center, center),
      circleRadius,
      fillPaint,
    );

    // === FOUR BRACKET [ ] SHAPES FACING INWARD ===
    final double bracketHeight = s * 0.28;    // Height of the bracket
    final double bracketWidth = s * 0.10;     // Width (depth) of the bracket arms
    final double edgeOffset = s * 0.10;       // Distance from canvas edge

    // TOP bracket: ] shape facing DOWN toward circle
    // Positioned above center, opens downward
    Path topBracket = Path();
    topBracket.moveTo(center - bracketHeight/2, edgeOffset);                    // top-left
    topBracket.lineTo(center - bracketHeight/2, edgeOffset + bracketWidth);     // down
    topBracket.moveTo(center - bracketHeight/2, edgeOffset);                    // back to top-left
    topBracket.lineTo(center + bracketHeight/2, edgeOffset);                    // across to top-right
    topBracket.lineTo(center + bracketHeight/2, edgeOffset + bracketWidth);     // down
    canvas.drawPath(topBracket, paint);

    // BOTTOM bracket: [ shape facing UP toward circle
    Path bottomBracket = Path();
    bottomBracket.moveTo(center - bracketHeight/2, s - edgeOffset);                    // bottom-left
    bottomBracket.lineTo(center - bracketHeight/2, s - edgeOffset - bracketWidth);     // up
    bottomBracket.moveTo(center - bracketHeight/2, s - edgeOffset);                    // back
    bottomBracket.lineTo(center + bracketHeight/2, s - edgeOffset);                    // across
    bottomBracket.lineTo(center + bracketHeight/2, s - edgeOffset - bracketWidth);     // up
    canvas.drawPath(bottomBracket, paint);

    // LEFT bracket: ] shape facing RIGHT toward circle
    Path leftBracket = Path();
    leftBracket.moveTo(edgeOffset, center - bracketHeight/2);                    // top
    leftBracket.lineTo(edgeOffset + bracketWidth, center - bracketHeight/2);     // right
    leftBracket.moveTo(edgeOffset, center - bracketHeight/2);                    // back
    leftBracket.lineTo(edgeOffset, center + bracketHeight/2);                    // down
    leftBracket.lineTo(edgeOffset + bracketWidth, center + bracketHeight/2);     // right
    canvas.drawPath(leftBracket, paint);

    // RIGHT bracket: [ shape facing LEFT toward circle
    Path rightBracket = Path();
    rightBracket.moveTo(s - edgeOffset, center - bracketHeight/2);                    // top
    rightBracket.lineTo(s - edgeOffset - bracketWidth, center - bracketHeight/2);     // left
    rightBracket.moveTo(s - edgeOffset, center - bracketHeight/2);                    // back
    rightBracket.lineTo(s - edgeOffset, center + bracketHeight/2);                    // down
    rightBracket.lineTo(s - edgeOffset - bracketWidth, center + bracketHeight/2);     // left
    canvas.drawPath(rightBracket, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full SpareLink logo with icon and text
class SpareLinkFullLogo extends StatelessWidget {
  final double iconSize;
  final Color color;
  final bool showSubtitle;

  const SpareLinkFullLogo({
    super.key,
    this.iconSize = 40,
    this.color = Colors.white,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpareLinkLogo(size: iconSize, color: color),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SpareLink',
              style: TextStyle(
                color: color,
                fontSize: iconSize * 0.6,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (showSubtitle)
              Text(
                'Mechanics',
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: iconSize * 0.4,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Alias for backward compatibility
typedef SpareLinkIcon = SpareLinkLogo;
