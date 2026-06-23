import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import 'asset_registry_screen.dart';
import '../widgets/modals/school_resource_reservation_modal.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  // Dates to highlight with red border
  final List<int> _blockedDates = [2, 6, 11, 20, 24, 30];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asset Admin'), actions: buildAppBarActions(context)),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            const Text('Operational Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Real-time resource tracking and logistical forecasts.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            
            // Manage Asset Registry
            ElevatedButton.icon(
              onPressed: () {
                // UPDATED NAVIGATION LOGIC
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AssetRegistryScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed, 
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Manage Asset Registry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),

            // Calendar Control Section
            _buildCalendarSection(),
            const SizedBox(height: 24),

            // Logistics Inventory
            _buildInventorySection(),
            const SizedBox(height: 24),

            // Resource Insights
            _buildInsightsCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        children: [
          const Text('Calendar Availability Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true, 
                value: 'Vehicle Fleet', 
                items: const [DropdownMenuItem(value: 'Vehicle Fleet', child: Text('Vehicle Fleet'))], 
                onChanged: (v) {}
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Block Dates Button
          ElevatedButton(
            onPressed: () {
              // UPDATED LOGIC TO SHOW THE DIALOG
              showDialog(
                context: context,
                builder: (context) => const SchoolResourceReservationModal(),
              );
            },
            // ... your existing button styling ...
            child: const Text('Block Dates'),
          ),
          const SizedBox(height: 20),
          const Text('October 2023', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryRed)),
          const SizedBox(height: 16),
          
          // Calendar Grid Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const ['SUN','MON','TUE','WED','THU','FRI','SAT'].map((e) => Text(e, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))).toList()),
          const SizedBox(height: 10),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: 35, // Days + padding
            itemBuilder: (context, index) {
              int day = index - 0; // Adjust index offset based on month start day
              if (day < 1 || day > 31) return const SizedBox();
              bool isBlocked = _blockedDates.contains(day);
              return Container(
                alignment: Alignment.center,
                decoration: isBlocked ? BoxDecoration(border: Border.all(color: AppTheme.primaryRed)) : null,
                child: Text('$day', style: TextStyle(fontWeight: isBlocked ? FontWeight.bold : FontWeight.normal)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Logistics Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Text('Update Stock', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 20),
          _buildInventoryBar('Folding Tables', 220, 250, '30 currently loaned to Library Dept.'),
          const SizedBox(height: 20),
          _buildInventoryBar('Stackable Chairs', 450, 1000, 'Low Stock: Large event in 3 days.'),
        ],
      ),
    );
  }

  Widget _buildInventoryBar(String title, int current, int total, String caption) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text('$current / $total', style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: current / total, color: AppTheme.primaryRed, backgroundColor: Colors.red.shade50, minHeight: 8),
      const SizedBox(height: 4),
      Text(caption, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF3E3632), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Resource Insights', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Predictive analysis suggests a 15% increase in auditorium seat requests next month.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white), child: const Text('View Full Forecast', style: TextStyle(color: Colors.black)))
      ]),
    );
  }
}