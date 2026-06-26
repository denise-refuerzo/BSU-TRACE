import 'package:flutter/material.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import 'multimedia_room_screen.dart';
import 'vehicle_reservations_screen.dart'; 
import 'gymnasium_reservations_screen.dart';
import 'logistics_history_screen.dart'; // ADDED IMPORT

class ProcurementHubScreen extends StatelessWidget {
  const ProcurementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurement Hub', style: TextStyle(fontSize: 16)),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Command Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            const Text(
              'Welcome back, Admin Services. Overview of current procurement requests and facility usage.',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4)
            ),
            const SizedBox(height: 24),
            
            _buildProcurementCard(
              icon: Icons.directions_car_outlined,
              title: 'Vehicle Reservations',
              subtitle: '4 requests pending approval',
              onViewAll: () {
                // UNCOMMENTED AND UPDATED NAVIGATION
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const VehicleReservationsScreen())
                );
              },
            ),
            _buildProcurementCard(
              icon: Icons.videocam_outlined,
              title: 'Multimedia Room',
              subtitle: 'Equipment & studio bookings',
              onViewAll: () {
                // UNCOMMENTED AND UPDATED NAVIGATION
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const MultimediaRoomScreen())
                );
              },
            ),
            _buildProcurementCard(
              icon: Icons.sports_basketball_outlined,
              title: 'Gymnasium Reservations',
              subtitle: 'Court #1 & Main Hall',
              onViewAll: () {
                // UNCOMMENTED AND UPDATED NAVIGATION
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const GymnasiumReservationsScreen())
                );
              },
            ),
            _buildProcurementCard(
              icon: Icons.history,
              title: 'Logistics History',
              subtitle: 'Past events and audits',
              onViewAll: () {
                // UNCOMMENTED AND UPDATED NAVIGATION
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const LogisticsHistoryScreen())
                );
              },
            ),
            
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFB01A22), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Procurement Health', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('System performance and fulfillment metrics.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                  const SizedBox(height: 24),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('98%', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1)),
                      SizedBox(width: 8),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('SLA Met', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ),
                  const SizedBox(height: 32),
                  
                  _buildMetricBar('Vehicles', '100%', 1.0),
                  const SizedBox(height: 20),
                  _buildMetricBar('Facility Usage', '92%', 0.92),
                  const SizedBox(height: 32),
                  
                  ElevatedButton.icon(
                    onPressed: (){},
                    icon: const Icon(Icons.insert_chart_outlined, color: Color(0xFFB01A22)),
                    label: const Text('Full Report', style: TextStyle(color: Color(0xFFB01A22), fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    )
                  )
                ]
              )
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProcurementCard({required IconData icon, required String title, required String subtitle, required VoidCallback onViewAll}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFB01A22)),
              ),
              ElevatedButton(
                onPressed: onViewAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB01A22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View All', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMetricBar(String label, String percentStr, double ratio) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(percentStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]
        ),
        const SizedBox(height: 8),
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3), 
            borderRadius: BorderRadius.circular(2)
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(2)
              )
            )
          )
        )
      ]
    );
  }
}