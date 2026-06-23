import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AddNewAssetModal extends StatelessWidget {
  const AddNewAssetModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // This ensures the modal moves up when the keyboard opens
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- MODAL DRAG HANDLE ---
              Center(
                child: Container(
                  width: 40, 
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.red.shade200, 
                    borderRadius: BorderRadius.circular(2)
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Asset', 
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: AppTheme.primaryRed,
                      fontFamily: 'Georgia', // Serif font to match your design
                    ), 
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.black54, size: 20),
                  )
                ],
              ),
              const SizedBox(height: 32),

              // --- FORM FIELDS ---
              _buildFormLabel('Asset Name'),
              const SizedBox(height: 8),
              _buildTextField('e.g. Multi-Purpose Hall'),
              const SizedBox(height: 24),

              _buildFormLabel('Asset Type'),
              const SizedBox(height: 8),
              _buildDropdown('Select Category'),
              const SizedBox(height: 24),

              _buildFormLabel('Department Assigned'),
              const SizedBox(height: 8),
              _buildTextField('General Services Office'),
              const SizedBox(height: 40),
              
              // --- FOOTER BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.primaryRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Cancel', 
                        style: TextStyle(
                          color: AppTheme.primaryRed, 
                          fontSize: 14, 
                          fontFamily: 'Georgia'
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Submit logic here
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Register Asset', 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 14, 
                          fontFamily: 'Georgia'
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE FORM WIDGETS ---

  Widget _buildFormLabel(String text) {
    return Text(
      text, 
      style: const TextStyle(
        fontSize: 12, 
        fontWeight: FontWeight.bold, 
        color: Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        filled: true,
        fillColor: Colors.red.shade50.withOpacity(0.5), // Light pink fill
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryRed),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hint, 
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
        ],
      ),
    );
  }
}