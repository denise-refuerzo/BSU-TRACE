import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
// ADD THIS IMPORT AT THE TOP
import '../widgets/modals/history_gymnasium_modal.dart';

class LogisticsHistoryScreen extends StatefulWidget {
  const LogisticsHistoryScreen({super.key});

  @override
  State<LogisticsHistoryScreen> createState() => _LogisticsHistoryScreenState();
}

class _LogisticsHistoryScreenState extends State<LogisticsHistoryScreen> {
  bool _isLendingActive = true;

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
              'Logistics History',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                fontFamily: 'Georgia', 
              ),
            ),
            const SizedBox(height: 20),
            
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search requestor or asset...',
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.white, 
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryRed),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Lending / Return Segmented Control
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLendingActive = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isLendingActive ? AppTheme.primaryRed : Colors.transparent,
                          borderRadius: BorderRadius.circular(7), 
                        ),
                        child: Center(
                          child: Text(
                            'Lending',
                            style: TextStyle(
                              color: _isLendingActive ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLendingActive = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isLendingActive ? AppTheme.primaryRed : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(
                            'Return',
                            style: TextStyle(
                              color: !_isLendingActive ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // History Cards (Added Context)
            _buildHistoryCard(
              context: context, // <--- ADDED
              category: 'GYMNASIUM RESERVATION',
              requestor: 'Varsity Sports Council',
              assetIcon: Icons.sports_basketball,
              assetText: 'Court #1',
              date: 'Dec 10, 2023',
              time: '04:00 PM - 07:00 PM',
              status: 'PENDING CHECKLIST',
              actionText: 'View Details',
              isActionable: true,
            ),
            _buildHistoryCard(
              context: context, // <--- ADDED
              category: 'MULTIMEDIA LOAN',
              requestor: 'Engineering Society',
              assetIcon: Icons.videocam_outlined,
              assetText: 'Projector X2',
              date: 'Nov 28, 2023',
              time: '09:00 AM - 12:00 PM',
              status: 'COMPLETED',
              actionText: 'History Only',
              isActionable: false,
            ),
            _buildHistoryCard(
              context: context, // <--- ADDED
              category: 'LOGISTICS SUPPORT',
              requestor: 'Debate Club',
              assetIcon: Icons.inventory_2_outlined,
              assetText: 'Foldable Chairs (50)',
              date: 'Dec 15, 2023',
              time: '01:00 PM - 05:00 PM',
              status: 'ACTION REQUIRED',
              actionText: 'View Details',
              isActionable: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required BuildContext context, // <--- ADDED REQUIRED CONTEXT
    required String category,
    required String requestor,
    required IconData assetIcon,
    required String assetText,
    required String date,
    required String time,
    required String status,
    required String actionText,
    required bool isActionable,
  }) {
    Color badgeBgColor = Colors.red.shade50;
    Color badgeTextColor = const Color(0xFFC62828);
    
    if (status == 'COMPLETED') {
      badgeBgColor = Colors.red.shade50.withOpacity(0.5);
      badgeTextColor = Colors.black54;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Text(
            requestor,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(assetIcon, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                assetText,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                date,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade100, thickness: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: isActionable ? () {
                  // TRIGGER THE NEW MODAL HERE
                  showDialog(
                    context: context,
                    builder: (context) => const HistoryGymnasiumModal(),
                  );
                } : null,
                child: Row(
                  children: [
                    Text(
                      actionText,
                      style: TextStyle(
                        color: isActionable ? AppTheme.primaryRed : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isActionable) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primaryRed),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}