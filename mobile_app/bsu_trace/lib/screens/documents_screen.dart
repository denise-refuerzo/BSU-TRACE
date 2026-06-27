// lib/screens/documents_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/document_scanner_modal.dart';
import '../widgets/modals/processor_document_details_modal.dart';
import '../config.dart'; // Import your global configuration

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<dynamic> documents = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    // Optionally set isLoading to true if you want a loading spinner on manual fetch calls, 
    // though RefreshIndicator handles its own loading animation.
    final String url = '${AppConfig.baseUrl}/documents';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        setState(() {
          documents = json.decode(response.body);
          isLoading = false;
          errorMessage = ''; // Clear any previous errors on successful fetch
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load documents: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching documents: $e");
      setState(() {
        errorMessage = 'Could not connect to server.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Documents'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : errorMessage.isNotEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => isLoading = true);
                          fetchDocuments();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              // Wrapped the scroll view in a RefreshIndicator
              : RefreshIndicator(
                  onRefresh: fetchDocuments, // Calls fetchDocuments when pulled down
                  color: AppTheme.primaryRed,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    // Crucial: AlwaysScrollableScrollPhysics ensures pull-to-refresh works 
                    // even if the list is too short to normally scroll
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _buildFilterDropdown(),
                        const SizedBox(height: 24),
                        
                        // Dynamically render cards based on API data
                        ...documents.map((doc) => _buildDocumentCard(
                          context,
                          doc, // Pass the entire map here
                        )),
                        
                        // Extra padding at the bottom so the FAB doesn't block the last card
                        const SizedBox(height: 80),
                      ],
                    ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), 
            borderSide: BorderSide.none
          ),
        ),
      );

  Widget _buildFilterDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(8)
        ),
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

Widget _buildDocumentCard(BuildContext context, Map<String, dynamic> document) {
    // Extract variables with fallbacks, including the tracking ID (QR code)
    final String trackingId = document['qr_code'] ?? document['tracking_id'] ?? 'N/A';
    final String title = document['title'] ?? 'No Title';
    final String form = document['form_type'] ?? 'N/A';
    final String origin = document['origin_office'] ?? 'N/A';
    final String status = document['status'] ?? 'Pending';
    final String time = 'Just now'; // You can format document['created_at'] here

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
              // REMOVED hardcoded 'DOC-REF-001' and const modifier
              // REPLACED with dynamic trackingId variable
              Text(trackingId, 
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
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
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true, 
                    backgroundColor: Colors.transparent, 
                    builder: (context) => ProcessorDocumentDetailsModal(
                      document: document,
                      onAdHocVerification: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Ad-hoc verification triggered")),
                        );
                      },
                      onDownloadDigitalCopy: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Downloading digital copy...")),
                        );
                      },
                    ),
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