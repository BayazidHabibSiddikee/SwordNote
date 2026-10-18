import 'dart:typed_data';

/// Model output: recognized text plus optional chart data
class RecognitionResult {
  final String text;
  final ChartOutput? chart;
  const RecognitionResult({required this.text, this.chart});
}

/// Data class for rendered chart output
class ChartOutput {
  final List<ChartSpot> spots;
  final String latex;
  const ChartOutput({required this.spots, required this.latex});
}

/// Minimal (x, y) point — avoids depending on fl_chart in the service layer.
class ChartSpot {
  final double x;
  final double y;
  const ChartSpot(this.x, this.y);
}
