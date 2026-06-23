import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_helper.dart';

class OperationalAnalyticsScreen extends StatelessWidget {
  const OperationalAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Operational Analytics',
          style: TextStyle(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: buildAppBarActions(context),
        iconTheme: const IconThemeData(color: AppTheme.primaryRed),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- BOTTLENECK HEATMAP ---
            _buildHeatmapCard(),
            const SizedBox(height: 20),

            // --- EQUIPMENT STOCK LEVEL ---
            _buildStockLevelCard(),
            const SizedBox(height: 20),

            // --- SYSTEM INSIGHT ---
            _buildSystemInsightCard(),
            const SizedBox(height: 20),

            // --- PEAK RESOURCE DEMAND TRENDS ---
            _buildTrendsCard(),
            const SizedBox(height: 100), // Padding for sticky bottom button
          ],
        ),
      ),
      
      // --- STICKY BOTTOM BUTTON ---
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldBg,
          border: Border(top: BorderSide(color: Colors.red.shade100)),
        ),
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.description_outlined, color: Colors.white),
          label: const Text(
            'Generate Full Audit Report',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRed,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET BUILDERS
  // ==========================================

  Widget _buildHeatmapCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bottleneck Heatmap',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                child: const Text('Live Updates', style: TextStyle(color: AppTheme.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Heatmap Grid
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Headers
              TableRow(
                children: [
                  _buildHeatmapHeader('Office', isLeftAligned: true),
                  _buildHeatmapHeader('Procurement'),
                  _buildHeatmapHeader('Enrollment'),
                  _buildHeatmapHeader('Requests'),
                  _buildHeatmapHeader('Audit'),
                ]
              ),
              const TableRow(children: [SizedBox(height: 12), SizedBox(), SizedBox(), SizedBox(), SizedBox()]), // Spacing
              
              // Row 1: GSO Main
              _buildHeatmapRow('GSO Main', [1.2, 4.5, 0.8, 12.4]),
              // Row 2: Accounting
              _buildHeatmapRow('Accounting', [15.1, 1.5, 3.2, 1.1]),
              // Row 3: ICT Dept.
              _buildHeatmapRow('ICT Dept.', [0.5, 0.9, 18.2, 5.0]),
              // Row 4: Cashier
              _buildHeatmapRow('Cashier', [6.4, 22.1, 1.2, 0.7]),
            ],
          ),
          
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Avg. Processing Delay (Hours)',
              style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStockLevelCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Equipment Stock Level',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          _buildStockItem('FOLDING TABLES', 142, 200, 71.0),
          const SizedBox(height: 24),
          _buildStockItem('MONOBLOC CHAIRS', 850, 1200, 70.8),
        ],
      ),
    );
  }

  Widget _buildSystemInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF62727B), // Slate Grey
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'System Insight',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Stock levels are sufficient for the upcoming '),
                const TextSpan(
                  text: 'University Foundation Week',
                  style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
                const TextSpan(text: " based on previous year's consumption models."),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Dismiss Tip', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTrendsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peak Resource Demand Trends',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          
          // Chart Area
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: SmoothTrendChartPainter(),
            ),
          ),
          
          const SizedBox(height: 16),
          // X-Axis Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Week 1', style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('Week 2', style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('Week 3', style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('Week 4', style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('Week 5 (Forecast)', style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Vehicles', AppTheme.primaryRed),
              _buildLegendItem('Multimedia', Colors.grey.shade400),
              _buildLegendItem('Gymnasium', const Color(0xFF62727B)),
            ],
          )
        ],
      ),
    );
  }

  // ==========================================
  // HELPERS
  // ==========================================

  Widget _buildHeatmapHeader(String title, {bool isLeftAligned = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        textAlign: isLeftAligned ? TextAlign.left : TextAlign.center,
        style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  TableRow _buildHeatmapRow(String rowHeader, List<double> values) {
    return TableRow(
      children: [
        // Row Title
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            rowHeader,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
          ),
        ),
        // Data Cells
        ...values.map((v) => _buildHeatmapCell(v)).toList(),
      ],
    );
  }

  Widget _buildHeatmapCell(double value) {
    // Determine Color based on delay value
    Color bgColor;
    Color textColor = Colors.black87;

    if (value < 1.0) {
      bgColor = const Color(0xFFFFF9C4); // Lightest yellow
    } else if (value < 5.0) {
      bgColor = const Color(0xFFFFE082); // Light orange
    } else if (value < 10.0) {
      bgColor = const Color(0xFFFFB74D); // Orange
    } else {
      bgColor = const Color(0xFFE57373); // Red
      textColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.all(4.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${value}h',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
      ),
    );
  }

  Widget _buildStockItem(String title, int current, int max, double util) {
    double ratio = current / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
            Text('$current / $max', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryRed)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor: Colors.red.shade50,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$util% Utilization',
            style: const TextStyle(fontSize: 10, color: Colors.black54, fontStyle: FontStyle.italic),
          ),
        )
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}

// ==========================================
// CUSTOM PAINTER FOR TRENDS CHART
// ==========================================

class SmoothTrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Grid lines (horizontal dotted/dashed lines)
    Paint gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    _drawDashedLine(canvas, Offset(0, h * 0.25), Offset(w, h * 0.25), gridPaint);
    _drawDashedLine(canvas, Offset(0, h * 0.5), Offset(w, h * 0.5), gridPaint);
    _drawDashedLine(canvas, Offset(0, h * 0.75), Offset(w, h * 0.75), gridPaint);
    canvas.drawLine(Offset(0, h), Offset(w, h), Paint()..color = Colors.grey.shade400..strokeWidth = 1);

    // Paints for lines
    Paint redLine = Paint()..color = AppTheme.primaryRed..strokeWidth = 3..style = PaintingStyle.stroke;
    Paint greyLine = Paint()..color = Colors.grey.shade400..strokeWidth = 3..style = PaintingStyle.stroke;
    Paint darkDottedLine = Paint()..color = const Color(0xFF62727B)..strokeWidth = 3..style = PaintingStyle.stroke;

    // Data Points (approximated from visual image)
    List<Offset> redPoints = [
      Offset(0, h * 0.8),
      Offset(w * 0.25, h * 0.6),
      Offset(w * 0.5, h * 0.25),
      Offset(w * 0.75, h * 0.3),
      Offset(w, h * 0.05),
    ];

    List<Offset> greyPoints = [
      Offset(0, h * 0.9),
      Offset(w * 0.25, h * 0.85),
      Offset(w * 0.5, h * 0.4),
      Offset(w * 0.75, h * 0.6),
      Offset(w, h * 0.15),
    ];

    List<Offset> darkPoints = [
      Offset(0, h * 0.85),
      Offset(w * 0.25, h * 0.75),
      Offset(w * 0.5, h * 0.75),
      Offset(w * 0.75, h * 0.8),
      Offset(w, h * 0.65),
    ];

    // Draw Smooth Lines
    Path redPath = _createSmoothPath(redPoints);
    Path greyPath = _createSmoothPath(greyPoints);
    Path darkPath = _createSmoothPath(darkPoints);

    canvas.drawPath(greyPath, greyLine);
    _drawDashedPath(canvas, darkPath, darkDottedLine);
    canvas.drawPath(redPath, redLine);

    // Draw small highlight dot on the red line at Week 4
    Paint dotPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    Paint dotBorder = Paint()..color = AppTheme.primaryRed..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawCircle(redPoints[3], 4, dotPaint);
    canvas.drawCircle(redPoints[3], 4, dotBorder);
  }

  Path _createSmoothPath(List<Offset> points) {
    Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      var p1 = points[i];
      var p2 = points[i + 1];
      var midX = (p1.dx + p2.dx) / 2;
      // Cubic bezier curve for smoothness
      path.cubicTo(midX, p1.dy, midX, p2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    double dashWidth = 5, dashSpace = 5, startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(Offset(startX, p1.dy), Offset(startX + dashWidth, p1.dy), paint);
      startX += dashWidth + dashSpace;
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    // Extract path metrics to construct a dashed line
    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        Path dashPath = measurePath.extractPath(distance, distance + 6.0); // Dash length
        canvas.drawPath(dashPath, paint);
        distance += 6.0 + 4.0; // Dash length + space
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}