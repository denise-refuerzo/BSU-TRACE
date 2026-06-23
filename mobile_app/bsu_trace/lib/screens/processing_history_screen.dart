// lib/screens/processing_history_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/document_scanner_modal.dart';

class ProcessingHistoryScreen extends StatelessWidget {
  const ProcessingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Processing History'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterDropdown(),
            const SizedBox(height: 24),
            
            // History Cards
            _buildHistoryCard('PR-2023-0892', 'Desktop Workstations', 'Procurement Form', 'COMPLETED', Colors.green),
            _buildHistoryCard('FAC-REV-2024', 'Dr. Elena Vance', 'Performance Review', 'PENDING SIGNATORY', Colors.orange),
            _buildHistoryCard('TRV-AUTH-55', 'Academic Conf Tokyo', 'Travel Authorization', 'IN REVIEW', Colors.blue),
            _buildHistoryCard('INV-990-2', 'Lab Supplies (Chemistry)', 'Procurement Form', 'COMPLETED', Colors.green),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const DocumentScannerModal(),
          );
        },
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() => TextField(
        decoration: InputDecoration(
          hintText: 'Search document',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      );

  Widget _buildFilterDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: 'All Statuses',
            items: ['All Statuses', 'Completed', 'In Review', 'Pending'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (_) {},
          ),
        ),
      );

  Widget _buildHistoryCard(String id, String title, String category, String status, Color dotColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade50)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- FIX: Wrap the Text in Expanded ---
              Expanded(
                child: Text(
                  '$id: $title', 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(width: 8), // Add spacing between text and icon
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
          const SizedBox(height: 8),
          Text(category, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          // ... rest of your code
        ],
      ),
    );
  }
}