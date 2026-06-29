import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../config.dart';
import '../../services/session_manager.dart';

class NewDocumentModal extends StatefulWidget {
  const NewDocumentModal({super.key});

  @override
  State<NewDocumentModal> createState() => _NewDocumentModalState();
}

class _NewDocumentModalState extends State<NewDocumentModal> {
  final TextEditingController _titleController = TextEditingController();
  
  // EXACT OFFICES FROM bsu_trace.sql
  final List<Map<String, dynamic>> _offices = [
    {'id': 1, 'name': 'Office of the Chancellor'},
    {'id': 2, 'name': 'HRMO'},
    {'id': 3, 'name': 'GSO'},
    {'id': 4, 'name': 'Registrar'},
    {'id': 5, 'name': 'Health Services'},
    {'id': 6, 'name': 'Guidance and Counseling'},
    {'id': 7, 'name': 'OSAS'},
    {'id': 8, 'name': 'Campus Library'},
    {'id': 9, 'name': 'Cashiering'},
    {'id': 10, 'name': 'Accounting'},
    {'id': 11, 'name': 'CICS'},
    {'id': 12, 'name': 'CABEIHM'},
    {'id': 13, 'name': 'CAS'},
    {'id': 14, 'name': 'CE / CIT'},
  ];

  // Replaced TextEditingControllers with a list of integer IDs
  List<int?> _selectedStops = [];
  
  List<dynamic> _processTypes = [];
  int? _selectedProcessId;
  
  bool _isVerified = false;
  bool _isSubmitting = false;
  bool _isLoadingProcesses = true; 
  bool _isLoadingRoute = false; 
  
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProcessTypes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchProcessTypes() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types'));
      if (response.statusCode == 200) {
        setState(() {
          _processTypes = json.decode(response.body);
          _isLoadingProcesses = false;
        });
      } else {
        throw Exception('Server error');
      }
    } catch (e) {
      debugPrint('Error fetching process types: $e');
      setState(() {
        _isLoadingProcesses = false;
        _processTypes = [
          {'p_id': 1, 'process_name': 'Reimbursement of Expenses'},
          {'p_id': 2, 'process_name': 'Purchase Request (PR)'},
          {'p_id': 3, 'process_name': 'Liquidation of Cash Advances'}
        ];
      });
    }
  }

  Future<void> _fetchProcessRoute(int processId) async {
    setState(() => _isLoadingRoute = true);

    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types/$processId/route'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedStops = data['stops']; // Expected to be an array of integers (o_id)

        setState(() {
          _selectedStops.clear();
          for (var stop in fetchedStops) {
            if (stop != null) {
              int? parsedId = int.tryParse(stop.toString());
              // Only add if it's a valid ID matching our database list
              if (_offices.any((o) => o['id'] == parsedId)) {
                _selectedStops.add(parsedId);
              }
            }
          }
        });
      } else {
        throw Exception('Failed to load route');
      }
    } catch (e) {
      debugPrint('Error fetching process route: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _submitDocument() async {
    setState(() => _errorMessage = null);

    if (_titleController.text.trim().isEmpty || _selectedProcessId == null || !_isVerified) {
      setState(() {
        _errorMessage = 'Please fill all fields and verify the document.';
      });
      return;
    }

    // Filter out any nulls from the dropdowns to create a clean integer array
    List<int> customRoute = _selectedStops.where((stop) => stop != null).cast<int>().toList();

    if (customRoute.isEmpty) {
      setState(() {
        _errorMessage = 'Please define at least one stop for the route.';
      });
      return;
    }

    final userId = SessionManager().userId;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/documents'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'u_id': userId,
          'title': _titleController.text.trim(),
          'p_id': _selectedProcessId,
          // Transmit strictly as an array of integers (e.g. [10, 11])
          'route': customRoute, 
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document successfully routed!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        throw Exception(errorResponse['error'] ?? 'Server error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _getEstimatedDate() {
    final date = DateTime.now().add(const Duration(days: 7));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

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
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  _buildLabel('DOCUMENT TITLE'),
                  const SizedBox(height: 8),
                  _buildTextField('e.g. Curriculum Revision Request'),
                  const SizedBox(height: 20),
                  
                  _buildLabel('PROCESS TYPE'),
                  const SizedBox(height: 8),
                  _buildDropdown('Select Process Type'),
                  const SizedBox(height: 20),

                  // Routing Stops Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.shade50.withValues(alpha: 0.5), border: Border.all(color: Colors.red.shade100), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('MANUAL ROUTING STOPS', style: TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            if (_isLoadingRoute)
                               const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: AppTheme.primaryRed, strokeWidth: 2))
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        if (_selectedStops.isEmpty && !_isLoadingRoute && _selectedProcessId == null)
                          const Text('Select a process to view route', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                        
                        // Dynamically map routing stops via the integers list
                        ...List.generate(_selectedStops.length, (index) => _buildRoutingStop(index)),
                        
                        const SizedBox(height: 16),
                        
                        // Enforce max 7 stops (route table constraint)
                        if (_selectedStops.length < 7)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedStops.add(null);
                              });
                            },
                            child: Row(children: const [Icon(Icons.add_circle_outline, color: AppTheme.primaryRed, size: 16), SizedBox(width: 8), Text('Add Custom Stop', style: TextStyle(color: AppTheme.primaryRed, fontSize: 13, fontWeight: FontWeight.bold))])
                          )
                      ]
                    )
                  ),
                  const SizedBox(height: 20),
                  
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('EST. COMPLETION', style: TextStyle(color: Color(0xFF902020), fontSize: 10, fontWeight: FontWeight.bold)), Text(_getEstimatedDate(), style: const TextStyle(color: Color(0xFF902020), fontWeight: FontWeight.bold, fontSize: 13))])),
                  const SizedBox(height: 20),
                  
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
              
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDocument, 
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                  child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
                )
              )
            ])
          )
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(padding: const EdgeInsets.all(20.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('New Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.black54))]));
  
  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54));
  
  Widget _buildTextField(String hint) => TextField(controller: _titleController, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade100)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)), filled: true, fillColor: const Color(0xFFFFF9F9)));
  
  Widget _buildDropdown(String hint) {
    if (_isLoadingProcesses) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFFFF9F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
        child: const Text('Loading processes...', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
      decoration: BoxDecoration(color: const Color(0xFFFFF9F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)), 
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: Colors.black87)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          value: _selectedProcessId,
          items: _processTypes.map<DropdownMenuItem<int>>((dynamic process) {
            return DropdownMenuItem<int>(
              value: int.tryParse(process['p_id'].toString()),
              child: Text(process['process_name'].toString(), overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (int? val) {
            if (val != null && val != _selectedProcessId) {
              setState(() => _selectedProcessId = val);
              _fetchProcessRoute(val);
            }
          },
        )
      )
    );
  }
  
  Widget _buildRoutingStop(int index) {
    int number = index + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), 
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), 
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: AppTheme.primaryRed, child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), 
          const SizedBox(width: 16), 
          
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                hint: const Text('Select Office', style: TextStyle(color: Colors.grey, fontSize: 13)),
                value: _selectedStops[index],
                items: _offices.map((office) {
                  return DropdownMenuItem<int>(
                    value: office['id'],
                    child: Text(office['name'], style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedStops[index] = newValue;
                  });
                },
              ),
            ),
          ), 
          
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedStops.removeAt(index);
              });
            },
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 18)
          )
        ]
      )
    );
  }
}