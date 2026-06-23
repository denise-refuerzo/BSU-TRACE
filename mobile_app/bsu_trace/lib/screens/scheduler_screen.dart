import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; 
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/new_request_modal.dart';

class SchedulerScreen extends StatelessWidget {
  const SchedulerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Resource Scheduler', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
          actions: buildAppBarActions(context),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryRed,
            labelColor: AppTheme.primaryRed,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Vehicles'),
              Tab(text: 'Multimedia Room'),
              Tab(text: 'Gymnasium'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(
          children: [
            SchedulerContent(),
            SchedulerContent(),
            SchedulerContent(),
          ],
        ),
        // Update this in SchedulerScreen
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context, 
              builder: (context) => const NewRequestModal(),
            );
          },
          backgroundColor: AppTheme.primaryRed,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

class SchedulerContent extends StatelessWidget {
  const SchedulerContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Padding bottom set to 100 ensures content is never covered by the FAB
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendarHeader(),
          const SizedBox(height: 16),
          _buildCalendarGrid(),
          const SizedBox(height: 24),
          const Text('Scheduled Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildEventItem(context, 'MULTIMEDIA', '09:00 AM', 'Annual Faculty Conference', 'Academic Affairs'),
          _buildEventItem(context, 'GYMNASIUM', '02:00 PM', 'Varsity Practice', 'Athletics Dept'),
          const SizedBox(height: 24),
          _buildInventorySection(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('October 2023', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Row(children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
        ])
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: days.map((d) => Text(d, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))).toList()),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: 31,
          itemBuilder: (context, index) {
            int day = index + 1;
            bool isReserved = day == 1; 
            bool isConfirmed = day == 6; 
            return Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isReserved ? Colors.green.withOpacity(0.2) : (isConfirmed ? AppTheme.primaryRed.withOpacity(0.2) : Colors.transparent),
                border: isReserved ? Border.all(color: Colors.green) : (isConfirmed ? Border.all(color: AppTheme.primaryRed) : null),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$day', style: TextStyle(fontWeight: isReserved || isConfirmed ? FontWeight.bold : FontWeight.normal)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEventItem(BuildContext context, String type, String time, String title, String dept) {
    return GestureDetector(
      onTap: () {
        showDialog(context: context, builder: (context) => const EventDetailsDialog());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type, style: TextStyle(fontSize: 10, color: Colors.blue.shade300, fontWeight: FontWeight.bold)),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(dept, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Logistics Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInventoryBar('Folding Tables', 82, 120),
        const SizedBox(height: 12),
        _buildInventoryBar('Stackable Chairs', 145, 400),
      ],
    );
  }

  Widget _buildInventoryBar(String title, int current, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title), Text('$current / $total')]),
        LinearProgressIndicator(value: current / total, color: AppTheme.primaryRed, backgroundColor: Colors.grey.shade200),
      ],
    );
  }
}

// --- POPUP DIALOG WIDGET ---
class EventDetailsDialog extends StatelessWidget {
  const EventDetailsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Event Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Annual Faculty Conference", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text("Oct 6, 2023 • 09:00 AM", style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildDetailRow('REQUESTOR', 'Dr. Aris Thorne'),
                _buildDetailRow('DEPARTMENT', 'Academic Affairs'),
                _buildDetailRow('PURPOSE', 'Multimedia Room A'),
                _buildDetailRow('EQUIPMENT / NOTES', 'Conference Equipment, Catering'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white),
                    child: const Text('Acknowledge'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}