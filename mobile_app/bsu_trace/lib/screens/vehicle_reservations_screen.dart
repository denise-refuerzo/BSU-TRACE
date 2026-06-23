import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/vehicle_reservation_modal.dart';

class VehicleReservationsScreen extends StatelessWidget {
  const VehicleReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg, // 0xFFFCF6F6
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
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Text
            const Text(
              'Vehicle Reservations',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage and track fleet requests',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search requestor or vehicle...',
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: AppTheme.scaffoldBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade100),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryRed),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Dropdown Filter
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'All Statuses',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reservation Cards
            _buildReservationCard(
              context: context,
              requestor: 'Varsity Sports Council',
              vehicle: 'TOYOTA COASTER #4',
              date: 'Dec 10, 2023 | 04:00 PM -\n07:00 PM',
              status: 'PENDING',
              icon: Icons.directions_car_outlined,
            ),
            _buildReservationCard(
              context: context,
              requestor: 'Admin Services Dept',
              vehicle: 'FORD TRANSIT #2',
              date: 'Dec 08, 2023 | 08:00 AM -\n12:00 PM',
              status: 'COMPLETED',
              icon: Icons.airport_shuttle_outlined, // Van Icon
            ),
            _buildReservationCard(
              context: context,
              requestor: 'Faculty of Arts',
              vehicle: 'MITSUBISHI XPANDER',
              date: 'Dec 12, 2023 | 10:00 AM -\n02:00 PM',
              status: 'PENDING',
              icon: Icons.directions_car_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard({
    required BuildContext context,
    required String requestor,
    required String vehicle,
    required String date,
    required String status,
    required IconData icon,
  }) {
    // Determine colors based on status
    final bool isPending = status == 'PENDING';
    
    final Color statusTextColor = isPending ? AppTheme.primaryRed : Colors.black54;
    final Color statusBgColor = isPending ? Colors.red.shade50 : Colors.grey.shade300;
    final Color statusBorderColor = isPending ? Colors.red.shade100 : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // Open details modal
          showDialog(
            context: context,
            builder: (context) => const VehicleReservationModal(),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Top Section: Icon, Info, Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppTheme.primaryRed),
                  ),
                  const SizedBox(width: 16),
                  
                  // Requestor & Vehicle Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2), // Minor alignment tweak
                        Text(
                          requestor,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1F2937), // Dark grey/blueish text
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'VEHICLE: $vehicle',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusBorderColor),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Bottom Section: Date & View Details Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            'VIEW',
                            style: TextStyle(
                              color: AppTheme.primaryRed,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'DETAILS',
                            style: TextStyle(
                              color: AppTheme.primaryRed,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppTheme.primaryRed,
                      )
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}