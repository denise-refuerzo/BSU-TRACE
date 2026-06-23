import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NewDocumentModal extends StatefulWidget {
  const NewDocumentModal({super.key});

  @override
  State<NewDocumentModal> createState() => _NewDocumentModalState();
}

class _NewDocumentModalState extends State<NewDocumentModal> {
  bool _isVerified = false;
  List<String> _stops = ['Department Head', 'Dean\'s Office'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFCF6F6),
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          Divider(color: Colors.red.shade100, height: 1),
          
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('DOCUMENT TITLE'),
                  const SizedBox(height: 8),
                  _buildTextField('e.g. Curriculum Revision Request'),
                  const SizedBox(height: 20),
                  
                  _buildLabel('PROCESS TYPE'),
                  const SizedBox(height: 8),
                  _buildDropdown('Academic Policy'),
                  const SizedBox(height: 20),

                  // Routing Stops Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.shade50.withOpacity(0.5), border: Border.all(color: Colors.red.shade100), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MANUAL ROUTING STOPS', style: TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        ...List.generate(_stops.length, (index) => _buildRoutingStop(index + 1, _stops[index])),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => setState(() => _stops.add('New Office')),
                          child: Row(children: const [Icon(Icons.add_circle_outline, color: AppTheme.primaryRed, size: 16), SizedBox(width: 8), Text('Add Custom Stop', style: TextStyle(color: AppTheme.primaryRed, fontSize: 13, fontWeight: FontWeight.bold))])
                        )
                      ]
                    )
                  ),
                  const SizedBox(height: 20),
                  
                  // Estimated Completion
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('EST. COMPLETION', style: TextStyle(color: Color(0xFF902020), fontSize: 10, fontWeight: FontWeight.bold)), Text('Oct 24, 2023', style: TextStyle(color: Color(0xFF902020), fontWeight: FontWeight.bold, fontSize: 13))])),
                  const SizedBox(height: 20),
                  
                  // Verification
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 24, height: 24, child: Checkbox(value: _isVerified, activeColor: AppTheme.primaryRed, side: BorderSide(color: Colors.grey.shade400), onChanged: (value) { setState(() { _isVerified = value ?? false; }); })), const SizedBox(width: 12), const Expanded(child: Text('I verify that all attached information is accurate and follows institutional guidelines.', style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4)))])
                ],
              ),
            ),
          ),
          Divider(color: Colors.red.shade100, height: 1),
          Padding(
            padding: const EdgeInsets.all(20.0), 
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)))), 
              const SizedBox(width: 16), 
              Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Submit Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))))
            ])
          )
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(padding: const EdgeInsets.all(20.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('New Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.black54))]));
  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54));
  Widget _buildTextField(String hint) => TextField(decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade100)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)), filled: true, fillColor: const Color(0xFFFFF9F9)));
  Widget _buildDropdown(String hint) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: const Color(0xFFFFF9F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(hint, style: const TextStyle(color: Colors.black87)), const Icon(Icons.keyboard_arrow_down, color: Colors.black54)]));
  Widget _buildRoutingStop(int number, String label) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), child: Row(children: [CircleAvatar(radius: 12, backgroundColor: AppTheme.primaryRed, child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 16), Expanded(child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 13))), const Icon(Icons.delete_outline, color: Colors.black54, size: 18)]));
}