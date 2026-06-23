import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/add_new_asset_modal.dart';

class AssetRegistryScreen extends StatelessWidget {
  const AssetRegistryScreen({super.key});

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
          'Asset Registry',
          style: TextStyle(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Georgia', // Serif font matching your design
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search assets...',
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
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
            const SizedBox(height: 16),

            // Dropdown Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: 'All Assets',
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'All Assets', child: Text('All Assets', style: TextStyle(color: Colors.black87, fontSize: 14))),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Asset Cards
            _buildAssetCard(
              title: 'Grand Ballroom A',
              type: 'Room',
              status: 'AVAILABLE',
              icon: Icons.door_front_door_outlined,
            ),
            _buildAssetCard(
              title: 'Toyota Hiace #02',
              type: 'Vehicle',
              status: 'BOOKED',
              icon: Icons.airport_shuttle_outlined,
            ),
            _buildAssetCard(
              title: 'Multimedia Projector X',
              type: 'Equipment',
              status: 'MAINTENA',
              icon: Icons.video_label_outlined,
            ),
            _buildAssetCard(
              title: 'Conference Room 102',
              type: 'Room',
              status: 'AVAILABLE',
              icon: Icons.door_front_door_outlined,
            ),
          ],
        ),
      ),
      // Custom Square FAB
        floatingActionButton: FloatingActionButton(
        onPressed: () {
          // UPDATED LOGIC TO SHOW THE BOTTOM SHEET
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent, // Important for the rounded corners
            builder: (context) => const AddNewAssetModal(),
          );
        },
        backgroundColor: AppTheme.primaryRed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildAssetCard({
    required String title,
    required String type,
    required String status,
    required IconData icon,
  }) {
    // Status Badge Logic
    Color badgeBgColor;
    Color badgeTextColor;

    if (status == 'AVAILABLE') {
      badgeBgColor = Colors.green.shade50;
      badgeTextColor = Colors.green.shade700;
    } else if (status == 'BOOKED') {
      badgeBgColor = AppTheme.primaryRed;
      badgeTextColor = Colors.white;
    } else {
      // MAINTENANCE
      badgeBgColor = Colors.grey.shade200;
      badgeTextColor = Colors.grey.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppTheme.primaryRed, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                          fontFamily: 'Georgia', // Serif font for titles
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 32), // Align under the text, not the icon
                    Text(
                      type,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Right side: Actions (Edit & Delete)
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, color: Colors.black54, size: 22),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.delete_outline, color: Colors.black54, size: 22),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}