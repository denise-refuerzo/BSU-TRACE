// lib/widgets/modals/terms_and_conditions_modal.dart
import 'package:flutter/material.dart';

class TermsAndConditionsModal extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const TermsAndConditionsModal({
    Key? key,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing via back button
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
                ),
                child: Column(
                  children: const [
                    Text(
                      'BSU-Trace Terms & Conditions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B), // Red 800
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'SMART CAMPUS RESOURCE MANAGEMENT SYSTEM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        '1. Introduction and Scope',
                        'Welcome to BSU-Trace. By logging into and utilizing this system, you agree to comply with the terms and privacy notices outlined below. BSU-Trace is designed to optimize administrative document tracking, manage facility reservations (including the Multimedia Room and Assemblyman Rafael R. Recto Gymnasium), and coordinate van scheduling for Batangas State University - Lipa Campus staff.',
                      ),
                      const SizedBox(height: 16),
                      _buildSectionWithBullets(
                        '2. Data Collection and Privacy Notice',
                        'In accordance with institutional guidelines, BSU-Trace collects and processes specific administrative data to ensure operational efficiency:',
                        [
                          'Digital Audit Trail: The system utilizes a QR-hybrid tracking mechanism to monitor the physical movement of documents. Scanning events ("Receive" and "Release") are logged with timestamps to provide transparent tracking.',
                          'Data Integrity: Your interaction logs, routing configurations, and van scheduling requests are securely stored to facilitate institutional resource management.',
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionWithBullets(
                        '3. Analytical Processing and Usage',
                        'To continuously improve campus operations, BSU-Trace applies data-driven intelligence to historical administrative logs:',
                        [
                          'Bottleneck Analysis: The system conducts an analytical evaluation process on document "dwell times" at various offices. This identifies constraints and operational friction without automated intervention, allowing governance to address delays proactively.',
                          'Predictive Forecasting: Historical scheduling data is used to forecast peak demand for van scheduling and facility usage, ensuring optimal distribution of institutional assets.',
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionWithBullets(
                        '4. User Responsibilities and Limitations',
                        'As a user of BSU-Trace, you acknowledge the following constraints:',
                        [
                          'The system strictly handles official business for BSU staff; student-related requests fall outside its scope.',
                          'All digital resource reservations remain in a provisional state until hard-copy documents with required "wet signatures" are physically verified by the General Services Office (GSO).',
                          'Users are expected to provide accurate status updates and qualitative remarks when processing or returning documents for correction.',
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        '5. User Consent',
                        'By proceeding, you consent to the collection, processing, and analytical evaluation of your administrative transactions within the BSU-Trace ecosystem. If you decline, you will be securely logged out of the portal.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions (Decline / Accept Buttons)
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF991B1B), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF991B1B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF991B1B), width: 4),
            ),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF991B1B),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(fontSize: 13, color: Colors.black, height: 1.4),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  Widget _buildSectionWithBullets(String title, String subtitle, List<String> bullets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF991B1B), width: 4),
            ),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF991B1B),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.black, height: 1.4),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 6),
        ...bullets.map((bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(fontSize: 13, color: Colors.black, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}