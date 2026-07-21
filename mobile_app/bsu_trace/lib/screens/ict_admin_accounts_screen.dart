import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; 
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
  
  // Search and Sort State
  String _searchQuery = '';
  String _sortBy = 'Name (A-Z)'; 
  final TextEditingController _searchController = TextEditingController();

  // Pagination State
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  // Auto-Reload Timer
  Timer? _autoReloadTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    
    _autoReloadTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchUsers();
    });
  }

  @override
  void dispose() {
    _autoReloadTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/users'));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _users = json.decode(response.body);
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

  // ==========================================
  // SEARCH & SORT LOGIC
  // ==========================================
  List<dynamic> get _filteredAndSortedUsers {
    // 1. Filter based on Search Query
    List<dynamic> filtered = _users.where((user) {
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final email = (user['uni_email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final dept = (user['department'] ?? '').toString().toLowerCase();
      final search = _searchQuery.toLowerCase();

      return name.contains(search) || 
             email.contains(search) || 
             role.contains(search) || 
             dept.contains(search);
    }).toList();

    // 2. Sort the Filtered List
    filtered.sort((a, b) {
      final nameA = (a['full_name'] ?? '').toString().toLowerCase();
      final nameB = (b['full_name'] ?? '').toString().toLowerCase();
      final roleA = (a['role'] ?? '').toString().toLowerCase();
      final roleB = (b['role'] ?? '').toString().toLowerCase();
      final deptA = (a['department'] ?? '').toString().toLowerCase();
      final deptB = (b['department'] ?? '').toString().toLowerCase();

      switch (_sortBy) {
        case 'Name (Z-A)':
          return nameB.compareTo(nameA);
        case 'Role':
          int roleCompare = roleA.compareTo(roleB);
          if (roleCompare == 0) return nameA.compareTo(nameB);
          return roleCompare;
        case 'Department':
          int deptCompare = deptA.compareTo(deptB);
          if (deptCompare == 0) return nameA.compareTo(nameB);
          return deptCompare;
        case 'Name (A-Z)':
        default:
          return nameA.compareTo(nameB);
      }
    });

    return filtered;
  }

  void _showSortFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...['Name (A-Z)', 'Name (Z-A)', 'Role', 'Department'].map((sortOption) {
                    return RadioListTile<String>(
                      title: Text(sortOption),
                      value: sortOption,
                      groupValue: _sortBy,
                      activeColor: AppTheme.primaryRed,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => _sortBy = value);
                          setState(() {
                            _sortBy = value;
                            _currentPage = 1; // Reset to first page on sort change
                          });
                          Navigator.pop(context);
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Apply filters and sorting before paginating
    final List<dynamic> processedUsers = _filteredAndSortedUsers;
    
    int totalPages = (processedUsers.length / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    // Safety check if search reduces total pages below current page
    if (_currentPage > totalPages) {
      _currentPage = 1;
    }

    final List<dynamic> displayedUsers = processedUsers.isEmpty 
        ? [] 
        : processedUsers.skip((_currentPage - 1) * _itemsPerPage).take(_itemsPerPage).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: _isLoading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : RefreshIndicator(
              color: AppTheme.primaryRed,
              backgroundColor: Colors.white,
              onRefresh: _fetchUsers,
              child: SingleChildScrollView(
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
                    
                    if (processedUsers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32.0),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                        child: const Center(child: Text('No users found matching your search.', style: TextStyle(color: Colors.grey))),
                      ),

                    ...displayedUsers.map((user) => _buildUserTile(user)),

                    if (processedUsers.isNotEmpty && totalPages > 1) 
                      _buildPaginationControls(totalPages),
                      
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
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _currentPage = 1; // Reset to page 1 on new search
              });
            },
            decoration: InputDecoration(
              hintText: 'Search name, email, role, or dept...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade100)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _currentPage = 1;
                      });
                    },
                  ) 
                : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
          child: IconButton(
            icon: const Icon(Icons.filter_list, color: AppTheme.primaryRed), 
            onPressed: _showSortFilterModal
          ),
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(role, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.domain, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(department, style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
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