import 'package:flutter/material.dart';
import 'dart:math';
import 'models/models.dart';
import 'services/gemini_service.dart';

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

class SkillTreeVisualization extends StatefulWidget {
  final SkillTreeResponse skillTree;
  final Function(SkillNode)? onNodeTap;

  const SkillTreeVisualization({
    Key? key,
    required this.skillTree,
    this.onNodeTap,
  }) : super(key: key);

  @override
  State<SkillTreeVisualization> createState() => _SkillTreeVisualizationState();
}

class _SkillTreeVisualizationState extends State<SkillTreeVisualization> {
  double _scale = 1.0;
  double _minScale = 0.1;
  double _maxScale = 5.0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  double _startScale = 1.0;
  final Map<Rect, SkillNode> _nodeRects = {};
  final Map<String, String> _iconCache = {};
  Offset? _pointerDownPosition;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _startOffset = _offset;
        _startScale = _scale;
        _pointerDownPosition = details.focalPoint;
        _isDragging = false;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_startScale * details.scale).clamp(_minScale, _maxScale);
          _offset = _startOffset + details.focalPointDelta;
        });
        if (_pointerDownPosition != null &&
            (details.focalPoint - _pointerDownPosition!).distance > 8) {
          _isDragging = true;
        }
      },
      onScaleEnd: (details) {
        _pointerDownPosition = null;
        _isDragging = false;
      },
      onTapUp: (details) {
        if (widget.onNodeTap == null) return;
        if (_isDragging) return;
        final tapX = (details.localPosition.dx - _offset.dx) / _scale;
        final tapY = (details.localPosition.dy - _offset.dy) / _scale;
        for (var entry in _nodeRects.entries) {
          if (entry.key.contains(Offset(tapX, tapY))) {
            widget.onNodeTap!(entry.value);
            return;
          }
        }
      },
      child: Container(
        color: Color(0xFF181A20),
        child: CustomPaint(
          size: Size.infinite,
          painter: SkillTreePainter(
            skillTree: widget.skillTree,
            scale: _scale,
            offset: _offset,
            onNodeTap: widget.onNodeTap,
            nodeRects: _nodeRects,
            iconCache: _iconCache,
            onRequestIcon: _fetchAndSetIcon,
          ),
        ),
      ),
    );
  }

  void _fetchAndSetIcon(String nodeName) async {
    if (_iconCache.containsKey(nodeName)) return;
    if (_geminiApiKey.isEmpty) return;
    final iconName = await fetchIconSuggestionFromGemini(nodeName, _geminiApiKey);
    setState(() {
      _iconCache[nodeName] = iconName;
    });
  }
}

class _RadialNodeLayout {
  final SkillNode node;
  final double angle;
  final double radius;
  final List<_RadialNodeLayout> children;
  _RadialNodeLayout(this.node, this.angle, this.radius, this.children);
}

class SkillTreePainter extends CustomPainter {
  final SkillTreeResponse skillTree;
  final double nodeWidth = 140.0;
  final double nodeHeight = 70.0;
  final double verticalSpacing = 120.0;
  final double horizontalSpacing = 50.0;
  final double scale;
  final Offset offset;
  final Function(SkillNode)? onNodeTap;
  final Map<Rect, SkillNode> nodeRects;
  final Map<String, String> iconCache;
  final void Function(String nodeName) onRequestIcon;
  final double baseRadius = 180.0;
  final double levelSpacing = 160.0;

  final List<Color> branchColors = [
    Color(0xFF5B8CFF),
    Color(0xFF6DD400),
    Color(0xFFFFA940),
    Color(0xFFB620E0),
    Color(0xFF00C6AE),
    Color(0xFFFF4D4F),
    Color(0xFF36CFC9),
    Color(0xFFFFC53D),
  ];

  SkillTreePainter({
    required this.skillTree,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.onNodeTap,
    required this.nodeRects,
    required this.iconCache,
    required this.onRequestIcon,
  });

  double _minRadiusForLevel(int numNodes, double nodeWidth) {
    if (numNodes <= 1) return baseRadius;
    double angle = pi / numNodes;
    return (nodeWidth / 2) / sin(angle) + baseRadius;
  }

  _RadialNodeLayout _layoutRadialTree(
    SkillNode node,
    double angle,
    int depth,
    double arc,
    List<int> siblingsPerLevel,
  ) {
    double nodeRadius = baseRadius;
    if (depth < siblingsPerLevel.length) {
      nodeRadius = _minRadiusForLevel(siblingsPerLevel[depth], nodeWidth);
    } else if (depth > 0) {
      nodeRadius = baseRadius + depth * levelSpacing;
    }
    if (node.subskills.isEmpty) {
      return _RadialNodeLayout(node, angle, nodeRadius, []);
    }
    List<double> childWidths = [];
    double totalWidth = 0;
    for (var child in node.subskills) {
      double w = _subtreeAngularWidth(child, depth + 1);
      childWidths.add(w);
      totalWidth += w;
    }
    double startAngle = angle - arc / 2;
    double currentAngle = startAngle;
    List<_RadialNodeLayout> children = [];
    for (int i = 0; i < node.subskills.length; i++) {
      double childArc = arc * (childWidths[i] / totalWidth);
      double childAngle = currentAngle + childArc / 2;
      children.add(_layoutRadialTree(
        node.subskills[i],
        childAngle,
        depth + 1,
        childArc,
        siblingsPerLevel,
      ));
      currentAngle += childArc;
    }
    return _RadialNodeLayout(node, angle, nodeRadius, children);
  }

  void _collectSiblingsPerLevel(SkillNode node, int depth, List<int> siblingsPerLevel) {
    if (siblingsPerLevel.length <= depth) {
      siblingsPerLevel.add(node.subskills.length);
    } else {
      siblingsPerLevel[depth] = max(siblingsPerLevel[depth], node.subskills.length);
    }
    for (var child in node.subskills) {
      _collectSiblingsPerLevel(child, depth + 1, siblingsPerLevel);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (skillTree.skills.isEmpty) return;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final paint = Paint()
      ..strokeWidth = 2.0 / scale
      ..style = PaintingStyle.stroke;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    double centerX = size.width / (2 * scale);
    double centerY = size.height / (2 * scale);
    List<int> siblingsPerLevel = [];
    _collectSiblingsPerLevel(
      SkillNode(
        name: skillTree.goal,
        estimatedTimeHours: 0,
        resources: [],
        subskills: skillTree.skills,
        description: '',
        tag: 'informal',
      ),
      0,
      siblingsPerLevel,
    );
    final rootLayout = _layoutRadialTree(
      SkillNode(
        name: skillTree.goal,
        estimatedTimeHours: 0,
        resources: [],
        subskills: skillTree.skills,
        description: '',
        tag: 'informal',
      ),
      0,
      0,
      2 * pi,
      siblingsPerLevel,
    );
    _drawRadialTree(canvas, centerX, centerY, rootLayout, paint, textPainter, 0);
    canvas.restore();
  }

  double _subtreeAngularWidth(SkillNode node, int depth) {
    if (node.subskills.isEmpty) return 1.0;
    double sum = 0;
    for (var child in node.subskills) {
      sum += _subtreeAngularWidth(child, depth + 1);
    }
    return sum;
  }

  void _drawRadialTree(
    Canvas canvas,
    double centerX,
    double centerY,
    _RadialNodeLayout layout,
    Paint paint,
    TextPainter textPainter,
    int colorIndex,
    [double? parentX, double? parentY]
  ) {
    double x = centerX + layout.radius * cos(layout.angle);
    double y = centerY + layout.radius * sin(layout.angle);
    if (parentX != null && parentY != null) {
      paint.color = branchColors[colorIndex % branchColors.length];
      canvas.drawLine(
        Offset(parentX, parentY),
        Offset(x, y),
        paint,
      );
    }
    if (layout.node.name == skillTree.goal) {
      _drawGoalNode(canvas, centerX, centerY, paint, textPainter);
    } else {
      int branchColor = colorIndex;
      if (layout.radius == baseRadius + levelSpacing) {
        branchColor = layout.children.isNotEmpty ? layout.children[0].angle.hashCode % branchColors.length : colorIndex;
      }
      _drawNode(canvas, layout.node, x, y, paint, textPainter, branchColor);
    }
    for (int i = 0; i < layout.children.length; i++) {
      final child = layout.children[i];
      _drawRadialTree(canvas, centerX, centerY, child, paint, textPainter, colorIndex, x, y);
    }
  }

  void _drawGoalNode(Canvas canvas, double x, double y, Paint paint, TextPainter textPainter) {
    final rect = Rect.fromLTWH(x - nodeWidth / 2, y - nodeHeight / 2, nodeWidth, nodeHeight);
    nodeRects[rect] = SkillNode(
      name: skillTree.goal,
      estimatedTimeHours: 0,
      resources: [],
      subskills: [],
      description: '',
      tag: 'informal',
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(18));
    final gradient = LinearGradient(
      colors: [Color(0xFF232526), Color(0xFF414345)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final paintFill = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paintFill);
    canvas.drawRRect(rrect, paint..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 3.0 / scale);
    textPainter.text = TextSpan(
      text: skillTree.goal,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16 / scale,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      ),
    );
    textPainter.layout(maxWidth: nodeWidth - 20);
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
    _drawIcon(canvas, Icons.star, x, y - nodeHeight / 2 + 22, 28, Colors.amberAccent);
  }

  void _drawNode(Canvas canvas, SkillNode node, double x, double y, Paint paint, TextPainter textPainter, int colorIndex) {
    final rect = Rect.fromLTWH(x - nodeWidth / 2, y - nodeHeight / 2, nodeWidth, nodeHeight);
    nodeRects[rect] = node;
    Color nodeColor = branchColors[colorIndex % branchColors.length];
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(14));
    final gradient = LinearGradient(
      colors: [nodeColor.withOpacity(0.85), nodeColor.withOpacity(0.55)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final paintFill = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paintFill);
    canvas.drawRRect(rrect, paint..style = PaintingStyle.stroke..color = Colors.white.withOpacity(0.7));
    String? iconName = iconCache[node.name];
    if (iconName == null) {
      onRequestIcon(node.name);
      iconName = 'star';
    }
    IconData iconData = _iconFromName(iconName);
    _drawIcon(canvas, iconData, x - nodeWidth / 2 + 28, y - 10, 24, Colors.white);
    canvas.save();
    canvas.clipRect(rect);
    double fontSize = 12.0 / scale;
    textPainter.text = TextSpan(
      text: node.name,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      ),
    );
    textPainter.layout(maxWidth: nodeWidth - 60);
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2 + 16, y - textPainter.height / 2 - 10),
    );
    fontSize = 10.0 / scale;
    textPainter.text = TextSpan(
      text: '${node.estimatedTimeHours} hrs',
      style: TextStyle(
        color: Colors.white70,
        fontSize: fontSize,
        fontFamily: 'Inter',
      ),
    );
    textPainter.layout(maxWidth: nodeWidth - 20);
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y + nodeHeight / 4),
    );
    canvas.restore();
    if (node.subskills.isNotEmpty) {
      double subRadius = 200.0;
      int totalSubskills = node.subskills.length;
      double parentAngle = atan2(y, x);
      double arc = min(2 * 3.14159, totalSubskills * (3.14159 / 2));
      double startAngle = parentAngle - arc / 2;
      for (int i = 0; i < totalSubskills; i++) {
        double angle = startAngle + arc * (i + 0.5) / totalSubskills;
        double subX = x + subRadius * cos(angle);
        double subY = y + subRadius * sin(angle);
        final path = Path()
          ..moveTo(x, y + nodeHeight / 2)
          ..quadraticBezierTo(
            x + (subX - x) * 0.5,
            y + (subY - y) * 0.5,
            subX,
            subY - nodeHeight / 2,
          );
        canvas.drawPath(
          path,
          paint..style = PaintingStyle.stroke..color = nodeColor.withOpacity(0.5),
        );
        _drawNode(canvas, node.subskills[i], subX, subY, paint, textPainter, colorIndex);
      }
    }
  }

  void _drawIcon(Canvas canvas, IconData icon, double x, double y, double size, Color color) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        color: color,
        package: icon.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - size / 2, y - size / 2));
  }

  IconData _iconFromName(String iconName) {
    switch (iconName) {
      case 'fire_extinguisher':
        return Icons.fire_extinguisher;
      case 'star':
        return Icons.star;
      case 'build':
        return Icons.build;
      case 'school':
        return Icons.school;
      case 'book':
        return Icons.book;
      case 'settings':
        return Icons.settings;
      case 'person':
        return Icons.person;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'computer':
        return Icons.computer;
      case 'science':
        return Icons.science;
      case 'bolt':
        return Icons.bolt;
      case 'psychology':
        return Icons.psychology;
      case 'language':
        return Icons.language;
      case 'group':
        return Icons.group;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'palette':
        return Icons.palette;
      case 'calculate':
        return Icons.calculate;
      case 'eco':
        return Icons.eco;
      case 'rocket':
        return Icons.rocket;
      case 'music_note':
        return Icons.music_note;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'attach_money':
        return Icons.attach_money;
      case 'business':
        return Icons.business;
      case 'public':
        return Icons.public;
      case 'engineering':
        return Icons.engineering;
      case 'handyman':
        return Icons.handyman;
      case 'directions_car':
        return Icons.directions_car;
      case 'flight':
        return Icons.flight;
      case 'restaurant':
        return Icons.restaurant;
      case 'code':
        return Icons.code;
      case 'map':
        return Icons.map;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'mic':
        return Icons.mic;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'theater_comedy':
        return Icons.theater_comedy;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'emoji_objects':
        return Icons.emoji_objects;
      case 'security':
        return Icons.security;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'directions_bike':
        return Icons.directions_bike;
      case 'spa':
        return Icons.spa;
      case 'pets':
        return Icons.pets;
      case 'emoji_nature':
        return Icons.emoji_nature;
      case 'emoji_people':
        return Icons.emoji_people;
      case 'emoji_transportation':
        return Icons.emoji_transportation;
      default:
        return Icons.star;
    }
  }

  @override
  bool shouldRepaint(covariant SkillTreePainter oldDelegate) {
    return oldDelegate.scale != scale ||
           oldDelegate.offset != offset ||
           oldDelegate.skillTree != skillTree ||
           oldDelegate.iconCache != iconCache;
  }
}
