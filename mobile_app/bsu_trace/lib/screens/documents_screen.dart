import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/document_scanner_modal.dart';
import '../widgets/modals/processor_document_details_modal.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Documents'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- SEARCH & FILTER ---
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterDropdown(),
            const SizedBox(height: 24),

            // --- DOCUMENT LIST ---
            _buildDocumentCard(
              context,
              'Official Transcript Request',
              'Form 137-A',
              'Registrar Office',
              'Incoming',
              '2 hours ago',
            ),
            _buildDocumentCard(
              context,
              'Graduation Clearance',
              'Final Evaluation',
              'Dean\'s Office',
              'In Verification',
              '5 hours ago',
            ),
            _buildDocumentCard(
              context,
              'ID Card Replacement',
              'Form 22-B',
              'Student Affairs',
              'Pending',
              'Yesterday',
            ),

            const SizedBox(height: 24),

            // --- FOOTER ---
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryRed),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Load More Documents', 
                  style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const Text('Showing 3 of 124 documents', 
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 80),
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
          hintText: 'Search Documents...',
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
            value: 'All Status',
            items: ['All Status', 'Incoming', 'In Verification', 'Pending'].map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (_) {},
          ),
        ),
      );

  Widget _buildDocumentCard(
      BuildContext context, String title, String form, String origin, String status, String time) {
    
    // Assign specific colors for statuses
    Color statusColor = status == 'Incoming' 
        ? Colors.red.shade100 
        : (status == 'Pending' ? Colors.orange.shade100 : Colors.blue.shade100);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(8), 
          border: Border.all(color: Colors.red.shade50)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TR-2023-00412', 
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)), 
                  child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Form: $form', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text('Origin: $origin', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ProcessorDocumentDetailsModal(), // Uses specific Processor modal
                  );
                },
                child: const Text('View Details >', 
                    style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}