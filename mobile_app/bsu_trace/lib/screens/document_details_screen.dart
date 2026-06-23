import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DocumentDetailsScreen extends StatefulWidget {
  const DocumentDetailsScreen({super.key});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  bool _isQrExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BSU Institutional Portal'),
        iconTheme: const IconThemeData(color: AppTheme.primaryRed),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  
                  // Requestor & Form Type
                  Row(children: [
                    Expanded(child: _buildInfoBox('Requestor', 'Dean Amelia Thorne', Icons.person_outline)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildInfoBox('Form Type', 'Administrative', Icons.account_balance)),
                  ]),
                  const SizedBox(height: 16),

                  // Estimated Completion Card
                  _buildCompletionCard('Oct 24, 2023', 'In Review'),
                  const SizedBox(height: 16),

                  // Collapsible QR Section
                  _buildCollapsibleQrSection(),
                  const SizedBox(height: 16),

                  // Processing Route (Always visible)
                  _buildProcessingRoute(),
                ],
              ),
            ),
          ),
          
          // Sticky Footer
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, color: AppTheme.primaryRed),
              label: const Text('Download QR Code', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: AppTheme.primaryRed)),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('DOCUMENT TITLE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Quarterly Financial Report Q3', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('🛡 BSU-2023-TR-8842', style: TextStyle(color: Colors.grey))
    ])
  );

  Widget _buildInfoBox(String title, String val, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 8),
      Text(val, style: const TextStyle(fontWeight: FontWeight.bold))
    ])
  );

  Widget _buildCompletionCard(String date, String status) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Estimated Completion', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(4)),
          child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        )
      ],
    ),
  );

  Widget _buildCollapsibleQrSection() => Column(
    children: [
      InkWell(
        onTap: () => setState(() => _isQrExpanded = !_isQrExpanded),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_isQrExpanded ? 'Hide QR Code' : 'View QR Code', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(_isQrExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white)
          ])
        ),
      ),
      if (_isQrExpanded) Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
        child: Column(children: [
          Container(height: 150, width: 150, color: Colors.grey.shade100, child: const Center(child: Text("QR Code"))),
          const SizedBox(height: 16),
          const Text('Scan this code at any BSU kiosk to instantly view document status or verify authenticity.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13))
        ]),
      )
    ],
  );

  Widget _buildProcessingRoute() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Processing Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 16),
      _buildRouteStep('Department Head', 'Approved on Oct 12, 09:15 AM', true),
      _buildRouteStep('Dean\'s Office', 'Approved on Oct 14, 02:30 PM', true),
      _buildRouteStep('Registrar', 'Current Status: Document Validation', false, isCurrent: true),
      _buildRouteStep('Finance Office', 'Pending clearance', false, isLast: true),
    ]),
  );

  Widget _buildRouteStep(String title, String subtitle, bool isDone, {bool isCurrent = false, bool isLast = false}) => IntrinsicHeight(
    child: Row(children: [
      Column(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: isDone ? AppTheme.primaryRed : (isCurrent ? AppTheme.primaryRed : Colors.grey.shade300), shape: BoxShape.circle)), if (!isLast) Expanded(child: Container(width: 2, color: Colors.red.shade200, margin: const EdgeInsets.symmetric(vertical: 4)))]),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.black : AppTheme.primaryRed)), Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 16)]))
    ]),
  );
}