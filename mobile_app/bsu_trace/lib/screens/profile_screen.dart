import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _is2faEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), actions: buildAppBarActions(context)),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- HEADER SECTION ---
            _buildCard(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(width: 90, height: 90, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.person, size: 50, color: Colors.white)),
                      Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.white, size: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('John Doe', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(20)),
                    child: const Text('ORIGINATOR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const Text('Faculty • Academic Department', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)), child: const Text('Active Status', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- PERSONAL INFO SECTION ---
            _buildSection(
              title: 'Personal Information',
              actionText: 'Edit All',
              children: [
                _buildTextField('Full Name', 'John Doe', Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField('University Email', 'john.doe@bsu.edu', Icons.mail_outline),
              ],
            ),

            // --- INSTITUTIONAL DETAILS SECTION ---
            _buildSection(
              title: 'Institutional Details',
              children: [
                _buildInfoCard('Faculty ID', 'BSU-2024-0001'),
                const SizedBox(height: 12),
                _buildInfoCard('Department', 'College of Engineering'),
                const SizedBox(height: 16),
                const Text('Please contact the ICT Office to update institutional information.', style: TextStyle(color: Colors.black54, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),

            // --- SECURITY SECTION ---
            _buildSection(
              title: 'Account Security',
              children: [
                _buildSecurityTile('Change Password', Icons.history),
                const Divider(),
                SwitchListTile(
                  title: const Text('Two-Factor Authentication', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Enhanced protection for your portal access', style: TextStyle(fontSize: 12)),
                  value: _is2faEnabled,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) => setState(() => _is2faEnabled = val),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- ACTIONS ---
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 16),
                Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppTheme.primaryRed)), child: const Text('CANCEL', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)))),
              ],
            ),
            const SizedBox(height: 24),
            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.logout, color: AppTheme.primaryRed), label: const Text('LOGOUT', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE WIDGETS ---
  Widget _buildCard({required Widget child}) => Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)), child: child);

  Widget _buildSection({required String title, String? actionText, required List<Widget> children}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if(actionText != null) Text(actionText, style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12))]),
      const SizedBox(height: 16),
      _buildCard(child: Column(children: children)),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildTextField(String label, String value, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)), const SizedBox(height: 8), TextFormField(initialValue: value, decoration: InputDecoration(suffixIcon: Icon(icon, color: Colors.black54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))]);

  Widget _buildInfoCard(String title, String value) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]));

  Widget _buildSecurityTile(String title, IconData icon) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: AppTheme.primaryRed), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right));
}