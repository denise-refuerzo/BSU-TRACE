import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // Added for Auto-Reload Timer
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar_helper.dart';
import '../../../widgets/app_drawer.dart';
import '../../../config.dart';
import '../../../widgets/modals/add_user_modal.dart';
import 'manage_account_screen.dart';

class IctAdminAccountsScreen extends StatefulWidget {
  const IctAdminAccountsScreen({super.key});

  @override
  State<IctAdminAccountsScreen> createState() => _IctAdminAccountsScreenState();
}

class _IctAdminAccountsScreenState extends State<IctAdminAccountsScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  
  // Pagination State
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  // Auto-Reload Timer
  Timer? _autoReloadTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    
    // Set up Auto-Reload to fetch new data silently every 30 seconds
    _autoReloadTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchUsers();
    });
  }

  @override
  void dispose() {
    // Prevent memory leaks by cancelling the timer when leaving the screen
    _autoReloadTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/users'));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _users = json.decode(response.body);
            // Reset to page 1 if the current page exceeds new total pages
            final int totalPages = (_users.length / _itemsPerPage).ceil();
            if (_currentPage > totalPages && totalPages > 0) {
              _currentPage = totalPages;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted && _isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load users')));
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted && _isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = (_users.length / _itemsPerPage).ceil();
    final List<dynamic> displayedUsers = _users.isEmpty 
        ? [] 
        : _users.skip((_currentPage - 1) * _itemsPerPage).take(_itemsPerPage).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: _isLoading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          
          // ADDED: RefreshIndicator for Pull-Down to Refresh
          : RefreshIndicator(
              color: AppTheme.primaryRed,
              backgroundColor: Colors.white,
              onRefresh: _fetchUsers,
              
              child: SingleChildScrollView(
                // ADDED: AlwaysScrollableScrollPhysics ensures the pull-down works even if the list is short
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('User Accounts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Manage system access, roles, and user details across the university.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 20),
                    
                    _buildSearchAndFilter(),
                    const SizedBox(height: 24),
                    
                    if (_users.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32.0),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                        child: const Center(child: Text('No users found', style: TextStyle(color: Colors.grey))),
                      ),

                    ...displayedUsers.map((user) => _buildUserTile(user)),

                    if (totalPages > 1) 
                      _buildPaginationControls(totalPages),
                      
                    // Added a little bottom padding so the last item isn't blocked by the FAB
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
            
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AddUserModal(),
          );
          // Instant Auto-Reload when returning from adding a user
          if (result == true) {
            _fetchUsers();
          }
        },
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Add User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, email, or faculty ID...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade100)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
          child: IconButton(icon: const Icon(Icons.filter_list, color: AppTheme.primaryRed), onPressed: () {}),
        )
      ],
    );
  }

  Widget _buildUserTile(dynamic user) {
    final String name = user['full_name'] ?? 'Unknown User';
    final String email = user['uni_email'] ?? 'No Email';
    final String role = user['role'] ?? 'Unassigned';
    final String department = user['department'] ?? 'No Dept';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [BoxShadow(color: Colors.red.shade50.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.red.shade50, child: Text(initial, style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                    Text(email, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(role, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.domain, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(department, style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageAccountScreen(user: user)),
                );
                // Instant Auto-Reload when returning from Managing a user
                if (result == true) {
                  _fetchUsers();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryRed,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Manage Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: _currentPage > 1 ? AppTheme.primaryRed : Colors.grey.shade400),
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(8)),
            child: Text('Page $_currentPage of $totalPages', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chevron_right, color: _currentPage < totalPages ? AppTheme.primaryRed : Colors.grey.shade400),
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }
}