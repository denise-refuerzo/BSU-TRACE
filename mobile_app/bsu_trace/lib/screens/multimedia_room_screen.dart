import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/multimedia_reservation_modal.dart';

class MultimediaRoomScreen extends StatelessWidget {
  const MultimediaRoomScreen({super.key});

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
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Multimedia Room',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryRed, 
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage and approve AV facility reservations.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search requestor...',
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4), 
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
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

            // Reservation Cards
            _buildMultimediaCard(
              context: context, // <--- FIXED: Passed context here
              requestor: 'Digital Arts Guild',
              date: 'Dec 12, 2023',
              room: 'Multimedia Suite A',
              status: 'Pending',
              icon: Icons.people_alt_outlined, 
            ),
            _buildMultimediaCard(
              context: context, // <--- FIXED: Passed context here
              requestor: 'Faculty Union',
              date: 'Dec 14, 2023',
              room: 'Seminar Room 102',
              status: 'Approved',
              icon: Icons.school_outlined,
            ),
            _buildMultimediaCard(
              context: context, // <--- FIXED: Passed context here
              requestor: 'Varsity Sports Council',
              date: 'Dec 10, 2023',
              room: 'Main Theatre',
              status: 'Completed',
              icon: Icons.workspace_premium_outlined, 
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Added 'required BuildContext context' to the parameters
  Widget _buildMultimediaCard({
    required BuildContext context, 
    required String requestor,
    required String date,
    required String room,
    required String status,
    required IconData icon,
  }) {
    // Determine dynamic colors for the status badge
    Color badgeBgColor;
    Color badgeTextColor;
    Color dotColor;
    Color badgeBorderColor;

    if (status == 'Pending') {
      badgeBgColor = const Color(0xFFFFF9C4); // Light yellow
      badgeTextColor = const Color(0xFFF57F17); // Dark orange
      dotColor = const Color(0xFFF57F17);
      badgeBorderColor = const Color(0xFFFFE082);
    } else if (status == 'Approved') {
      badgeBgColor = const Color(0xFFE8F5E9); // Light green
      badgeTextColor = const Color(0xFF2E7D32); // Dark green
      dotColor = const Color(0xFF2E7D32);
      badgeBorderColor = const Color(0xFFA5D6A7);
    } else {
      // Completed
      badgeBgColor = const Color(0xFFFCE4EC); // Light reddish-grey
      badgeTextColor = const Color(0xFF5D4037); // Dark brownish
      dotColor = const Color(0xFF5D4037);
      badgeBorderColor = const Color(0xFFF8BBD0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon, Requestor, Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryRed),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestor,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Room Details
          const Text(
            'ROOM:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            room,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Status Badge with dot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeBorderColor, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button (Text on left, Icon on right)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const MultimediaReservationModal(),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppTheme.primaryRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: AppTheme.primaryRed,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.open_in_new, size: 16, color: AppTheme.primaryRed),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}