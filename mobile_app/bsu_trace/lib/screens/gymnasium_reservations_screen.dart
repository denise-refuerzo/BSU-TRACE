import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
// ADDED IMPORT FOR THE NEW MODAL
import '../widgets/modals/gymnasium_reservation_modal.dart'; 

class GymnasiumReservationsScreen extends StatelessWidget {
  const GymnasiumReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryRed),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Procurement Hub',
          style: TextStyle(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Georgia', 
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gymnasium Reservations',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                fontFamily: 'Georgia', 
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage and approve court booking requests for university events.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            
            // Search and Filter Section
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by requestor...',
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.red.shade50.withOpacity(0.5), 
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.red.shade100),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppTheme.primaryRed),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withOpacity(0.5), 
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'All Statuses',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reservation Cards (Context added)
            _buildGymCard(
              context: context,
              requestor: 'Varsity Sports Council',
              details: 'Court #1 | Dec 10, 2023',
              status: 'PENDING',
              icon: Icons.sports_basketball,
              iconColor: AppTheme.primaryRed,
              iconBgColor: Colors.red.shade50,
            ),
            _buildGymCard(
              context: context,
              requestor: 'Student Union Gala',
              details: 'Main Arena | Dec 15, 2023',
              status: 'PROCESSING',
              icon: Icons.groups,
              iconColor: Colors.blueGrey.shade700,
              iconBgColor: Colors.blueGrey.shade50,
            ),
            _buildGymCard(
              context: context,
              requestor: 'Alumni Invitational',
              details: 'Court #2 | Dec 20, 2023',
              status: 'PENDING',
              icon: Icons.sports_volleyball,
              iconColor: AppTheme.primaryRed,
              iconBgColor: Colors.red.shade50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymCard({
    required BuildContext context, // <--- ADDED REQUIRED CONTEXT
    required String requestor,
    required String details,
    required String status,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    Color statusBgColor;
    Color statusTextColor;

    if (status == 'PENDING') {
      statusBgColor = Colors.red.shade50;
      statusTextColor = AppTheme.primaryRed;
    } else {
      statusBgColor = Colors.lightBlue.shade50;
      statusTextColor = Colors.blue.shade900;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestor,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                        fontFamily: 'Georgia', 
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              
              ElevatedButton(
                onPressed: () {
                  // LOGIC TO SHOW THE NEW MODAL
                  showDialog(
                    context: context,
                    builder: (context) => const GymnasiumReservationModal(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}