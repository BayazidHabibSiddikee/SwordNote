import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui' as ui show ImageByteFormat, PictureRecorder;
import 'package:math_expressions/math_expressions.dart';
import '../../providers/model_providers.dart';
import '../../services/model/model_service.dart';
import '../../services/model/models.dart';

// ─── Data types ──────────────────────────────────────────────────────────────

enum ToolMode { pen, eraser }

class PenStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  PenStroke({required this.points, required this.color, required this.strokeWidth});
}

// ─── Custom painter ──────────────────────────────────────────────────────────

class StrokePainter extends CustomPainter {
  final List<PenStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;

  StrokePainter({
    required this.strokes,
    required this.currentPoints,
    this.currentColor = const Color(0xFF38BDF8),
    this.currentStrokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void draw(List<Offset> pts, Color c, double w) {
      if (pts.length < 2) return;
      final p = Paint()
        ..color = c
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (int i = 1; i < pts.length; i++) {
        canvas.drawLine(pts[i - 1], pts[i], p);
      }
    }

    for (final s in strokes) draw(s.points, s.color, s.strokeWidth);
    if (currentPoints.length >= 2) draw(currentPoints, currentColor, currentStrokeWidth);
  }

  @override
  bool shouldRepaint(StrokePainter old) =>
      strokes != old.strokes ||
      currentPoints != old.currentPoints ||
      currentColor != old.currentColor ||
      currentStrokeWidth != old.currentStrokeWidth;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CanvasScreen extends ConsumerStatefulWidget {
  const CanvasScreen({super.key});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  final List<PenStroke> _strokes = [];
  final List<Offset> _currentPoints = [];
  Color _currentColor = const Color(0xFF38BDF8);
  double _strokeWidth = 2.5;
  ToolMode _mode = ToolMode.pen;
  String? _recognitionResult;
  bool _isAnalyzing = false;
  List<FlSpot>? _plotSpots;
  String? _plotLatex;

  void _onPanStart(DragStartDetails details) {
    if (_mode == ToolMode.eraser) return;
    final offset = details.localPosition;
    if (mounted) setState(() => _currentPoints.clear());
    if (mounted) setState(() => _currentPoints.add(offset));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_mode == ToolMode.eraser) return;
    if (mounted) setState(() => _currentPoints.add(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) {
    if (_mode == ToolMode.eraser) {
      final pos = _currentPoints.isNotEmpty ? _currentPoints.last : details.localPosition;
      setState(() => _strokes.removeWhere((s) => _near(s.points, pos)));
      _currentPoints.clear();
      return;
    }
    if (_currentPoints.length < 2) { _currentPoints.clear(); return; }
    setState(() => _strokes.add(PenStroke(
      points: List.from(_currentPoints),
      color: _currentColor,
      strokeWidth: _strokeWidth,
    )));
    _currentPoints.clear();
  }

  bool _near(List<Offset> pts, Offset p) =>
      pts.any((o) => math.sqrt((o.dx - p.dx) * (o.dx - p.dx) + (o.dy - p.dy) * (o.dy - p.dy)) < 30);

  Future<void> _analyze() async {
    if (_strokes.isEmpty) return;
    setState(() { _isAnalyzing = true; _recognitionResult = null; _plotSpots = null; _plotLatex = null; });
    final service = ref.read(modelServiceProvider);
    final imageBytes = await _rasterize();
    final result = await service.recognizeContent(imageBytes);
    if (!mounted) return;
    setState(() { _isAnalyzing = false; _recognitionResult = result.text; });
  }

  Future<Uint8List> _rasterize() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    for (final s in _strokes) {
      if (s.points.length < 2) continue;
      final p = Paint()..color = s.color..strokeWidth = s.strokeWidth
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      for (int i = 1; i < s.points.length; i++) c.drawLine(s.points[i - 1], s.points[i], p);
    }
    final img = await rec.endRecording().toImage(800, 600);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  void _plotChart(String latex) {
    try {
      final clean = latex
          .replaceAll(RegExp(r'f\(x\)\s*=\s*'), '')
          .replaceAll(RegExp(r'[∫∂∑∏±√≈≠≤≥]'), '');
      final expr = GrammarParser().parse(clean);
      final spots = <FlSpot>[];
      for (double x = -10; x <= 10; x += 0.5) {
        try {
          final ctx = ContextModel()..bindVariableName('x', Number(x));
          final num y = expr.evaluate(EvaluationType.REAL, ctx);
          spots.add(FlSpot(x, y.toDouble()));
        } catch (_) {}
      }
      if (mounted) setState(() { _plotSpots = spots; _plotLatex = latex; });
    } catch (e) {
      debugPrint('Could not plot: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canvas'),
        actions: [
          _modeBtn(Icons.draw, ToolMode.pen),
          _modeBtn(Icons.format_clear, ToolMode.eraser),
          const SizedBox(width: 8),
          IconButton(
            icon: _isAnalyzing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            tooltip: 'Analyze with AI',
            onPressed: _isAnalyzing ? null : _analyze,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _StyleBar(
            color: _currentColor, width: _strokeWidth,
            onColorChanged: (c) => setState(() => _currentColor = c),
            onWidthChanged: (w) => setState(() => _strokeWidth = w),
            onClear: () => setState(() => _strokes.clear()),
          ),
          const Divider(height: 1),
          Expanded(
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                size: Size.infinite,
                painter: StrokePainter(
                  strokes: _strokes, currentPoints: _currentPoints,
                  currentColor: _currentColor, currentStrokeWidth: _strokeWidth,
                ),
              ),
            ),
          ),
          if (_recognitionResult != null || _plotSpots != null)
            _ResultPanel(result: _recognitionResult, spots: _plotSpots, latex: _plotLatex, onPlot: _plotChart),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _modeBtn(IconData icon, ToolMode mode) {
    return IconButton(
      icon: Icon(icon, color: _mode == mode ? Theme.of(context).colorScheme.primary : null),
      tooltip: mode.name,
      onPressed: () => setState(() => _mode = mode),
    );
  }
}

// ─── Style bar ───────────────────────────────────────────────────────────────

class _StyleBar extends StatelessWidget {
  final Color color;
  final double width;
  final void Function(Color) onColorChanged;
  final void Function(double) onWidthChanged;
  final VoidCallback onClear;
  const _StyleBar({required this.color, required this.width,
    required this.onColorChanged, required this.onWidthChanged, required this.onClear});

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF38BDF8), Color(0xFFA78BFA), Color(0xFF34D399),
                    Color(0xFFFBBF24), Color(0xFFF87171), Colors.white];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Text('Color:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Wrap(spacing: 6, children: colors.map((c) => _Dot(color: c, sel: color == c, onTap: () => onColorChanged(c))).toList()),
          const Spacer(),
          const Text('Width:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Slider(value: width, min: 1, max: 8, divisions: 7, onChanged: onWidthChanged)),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: onClear),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color; final bool sel; final VoidCallback onTap;
  const _Dot({required this.color, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 28, height: 28, decoration: BoxDecoration(
      color: color, shape: BoxShape.circle,
      border: Border.all(color: sel ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
    )),
  );
}

// ─── Result panel ────────────────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  final String? result;
  final List<FlSpot>? spots;
  final String? latex;
  final void Function(String) onPlot;
  const _ResultPanel({this.result, this.spots, this.latex, required this.onPlot});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (result != null) ...[
          const Text('Recognition:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(result!, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
          const SizedBox(height: 8),
        ],
        if (spots != null && spots!.isNotEmpty) ...[
          const Text('Plot:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(height: 200, child: LineChart(LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineBarsData: [LineChartBarData(spots: spots!, isCurved: true, curveSmoothness: 0.2,
              color: Theme.of(context).colorScheme.primary, barWidth: 2,
              dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: false))],
            minX: -10, maxX: 10,
            minY: spots!.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2,
            maxY: spots!.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2,
          ))),
          const SizedBox(height: 8),
        ],
        if (result != null && spots == null)
          FilledButton.icon(onPressed: () => onPlot(result!), icon: const Icon(Icons.trending_up, size: 18), label: const Text('Plot as graph')),
      ]),
    );
  }
}
