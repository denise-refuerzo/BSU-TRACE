import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; 
import 'package:http/http.dart' as http;

import '../widgets/app_bar_helper.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import '../services/session_manager.dart';
import '../config.dart';
import '../widgets/modals/new_document_modal.dart';
import 'document_details_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isLoading = true;
  bool _isLoadingLiveDoc = false;
  bool _isRouteExpanded = false; 
  
  List<dynamic> _recentDocuments = [];
  List<dynamic> _processTypes = [];
  Map<String, dynamic>? _liveDocument;
  
  List<String> _plannedRoute = [];
  List<dynamic> _docHistory = [];
  
  Timer? _syncTimer; 

  String _searchQuery = '';
  bool _sortAscending = false; 
  int _currentPage = 0;
  final int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchTrackingData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types'));
      if (res.statusCode == 200) {
        _processTypes = json.decode(res.body);
      }
    } catch (e) {
      debugPrint('Error fetching process types: $e');
    }
    await _fetchTrackingData();
  }

  Future<void> _fetchTrackingData({bool isBackground = false}) async {
    final userId = SessionManager().userId;
    if (userId == null) {
      if (!isBackground && mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/users/$userId/documents'));
      
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(response.body);
        
        setState(() {
          _recentDocuments = data;
          
          if (data.isNotEmpty) {
            Map<String, dynamic>? newLiveDoc;
            if (_liveDocument != null) {
              int index = data.indexWhere((d) => d['ini_id'] == _liveDocument!['ini_id']);
              if (index != -1) {
                newLiveDoc = data[index];
              } else {
                newLiveDoc = data.firstWhere((doc) => doc['status'] != 'Completed', orElse: () => data.first);
              }
            } else {
              newLiveDoc = data.firstWhere((doc) => doc['status'] != 'Completed', orElse: () => data.first);
            }

            if (newLiveDoc != null) {
              if (_liveDocument == null || _liveDocument!['ini_id'] != newLiveDoc['ini_id'] || !isBackground) {
                 _liveDocument = newLiveDoc;
                 _fetchLiveRoute(newLiveDoc);
              } else {
                 _fetchLiveRoute(newLiveDoc, isBackground: true);
              }
            } else {
               _liveDocument = null;
            }
          } else {
            _liveDocument = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching tracking data: $e');
    } finally {
      if (!isBackground && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchLiveRoute(Map<String, dynamic> doc, {bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoadingLiveDoc = true;
        _isRouteExpanded = false; 
      });
    }

    try {
      int? pId;
      String formType = doc['form_type'] ?? '';
      for (var p in _processTypes) {
        if (p['process_name'] == formType) {
          pId = int.tryParse(p['p_id'].toString());
          break;
        }
      }

      if (pId != null) {
        final routeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/process-types/$pId/route'));
        if (routeRes.statusCode == 200) {
          final routeData = json.decode(routeRes.body);
          _plannedRoute = List<String>.from(routeData['stops'] ?? []);
        }
      } else {
        _plannedRoute = [];
      }

      final detailRes = await http.get(Uri.parse('${AppConfig.baseUrl}/documents/${doc['ini_id']}/details'));
      if (detailRes.statusCode == 200) {
        final detailData = json.decode(detailRes.body);
        _docHistory = detailData['history'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching live route: $e');
    } finally {
      if (mounted && !isBackground) setState(() => _isLoadingLiveDoc = false);
    }
  }

  List<dynamic> get _processedDocuments {
    var filtered = _recentDocuments.where((doc) {
      final title = (doc['title'] ?? '').toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    if (_sortAscending) {
      filtered = filtered.reversed.toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Tracking'),
        actions: buildAppBarActions(context),
      ),
      drawer: const AppDrawer(),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
        : RefreshIndicator(
            color: AppTheme.primaryRed,
            onRefresh: () async {
              await _fetchTrackingData(isBackground: true);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(left: 20.0, top: 20.0, right: 20.0, bottom: 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrackingCard(),
                  const SizedBox(height: 24),
                  const Text('Recent Submissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildRecentSubmissionsTable(context),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(context: context, builder: (context) => const NewDocumentModal());
        },
        backgroundColor: const Color(0xFFB01A22),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _currentPage = 0; 
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by document title...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _sortAscending = !_sortAscending;
              _currentPage = 0; 
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward, 
              color: Colors.grey,
              size: 20
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingCard() {
    if (_liveDocument == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
        child: const Text('No active documents currently being tracked.', style: TextStyle(color: Colors.grey)),
      );
    }

    String title = _liveDocument!['title'] ?? 'Unknown Document';
    String status = _liveDocument!['status'] ?? 'pending';
    bool isCompleted = status == 'Completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start, // Fixed layout overflow
            children: [
              const Expanded( // Flex space safely avoids overflowing badge
                child: Text(
                  'Live Document Tracking', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: isCompleted ? Colors.green : AppTheme.primaryRed, borderRadius: BorderRadius.circular(4)), 
                child: Text(isCompleted ? 'COMPLETED' : 'IN PROGRESS', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          
          if (_isLoadingLiveDoc)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppTheme.primaryRed)))
          else
            _buildDynamicTimeline(),
        ],
      ),
    );
  }

  Widget _buildDynamicTimeline() {
    List<Map<String, dynamic>> nodeData = [];

    for (int i = 0; i < _docHistory.length; i++) {
      var histNode = _docHistory[i];
      String officeName = histNode['office_name'] ?? 'Unknown Office';
      String status = histNode['current_status'] ?? 'pending';

      bool isLastInHistory = (i == _docHistory.length - 1);
      bool isDocCompleted = _liveDocument?['status'] == 'Completed';

      bool isCompletedNode = !isLastInHistory || isDocCompleted || ['Completed', 'Verified', 'Approved', 'Signed'].contains(status);
      bool isActiveNode = isLastInHistory && !isCompletedNode;

      nodeData.add({
        'title': officeName.toUpperCase(),
        'subtitle': isCompletedNode ? 'Completed' : (isActiveNode ? 'In processing... ($status)' : status),
        'icon': isCompletedNode ? Icons.check_circle : (isActiveNode ? Icons.pending_actions : Icons.circle_outlined),
        'isPast': isCompletedNode,
        'isCompleted': isCompletedNode,
        'isActive': isActiveNode,
      });
    }

    int startIndex = _docHistory.length;
    if (_docHistory.isNotEmpty) {
      String lastVisited = _docHistory.last['office_name'] ?? '';
      int foundIdx = _plannedRoute.indexOf(lastVisited);
      if (foundIdx != -1) startIndex = foundIdx + 1;
    }

    for (int i = startIndex; i < _plannedRoute.length; i++) {
      nodeData.add({
        'title': _plannedRoute[i].toUpperCase(),
        'subtitle': 'Pending',
        'icon': Icons.circle_outlined,
        'isPast': false,
        'isCompleted': false,
        'isActive': false,
      });
    }

    if (nodeData.isEmpty) {
      nodeData.add({
        'title': 'INITIALIZING ROUTE',
        'subtitle': 'Pending',
        'icon': Icons.circle_outlined,
        'isPast': false,
        'isCompleted': false,
        'isActive': false,
      });
    }

    List<Map<String, dynamic>> displayData = [];
    if (_isRouteExpanded || nodeData.length <= 4) {
      displayData = nodeData;
    } else {
      int activeIndex = nodeData.indexWhere((n) => n['isActive'] == true);
      if (activeIndex == -1) activeIndex = nodeData.length - 1; 

      int start = activeIndex;
      int end = activeIndex + 1;

      if (end >= nodeData.length) {
        end = nodeData.length - 1;
        start = end > 0 ? end - 1 : 0;
      }

      if (start > 0) {
        displayData.add({
          'title': 'PREVIOUS STEPS',
          'subtitle': '$start completed step(s) hidden',
          'icon': Icons.more_vert,
          'isPast': true,
          'isCompleted': true, 
          'isActive': false,
        });
      }

      for (int i = start; i <= end; i++) {
        displayData.add(nodeData[i]);
      }

      if (end < nodeData.length - 1) {
        displayData.add({
          'title': 'FUTURE STEPS',
          'subtitle': '${nodeData.length - 1 - end} pending step(s) hidden',
          'icon': Icons.more_vert,
          'isPast': false,
          'isCompleted': false,
          'isActive': false,
        });
      }
    }

    List<Widget> timelineWidgets = [];
    for (int i = 0; i < displayData.length; i++) {
      var data = displayData[i];
      timelineWidgets.add(_buildTimelineNode(
        data['title'],
        data['subtitle'],
        data['icon'],
        data['isPast'],
        data['isCompleted'],
        isActive: data['isActive'],
        isLast: i == displayData.length - 1
      ));
    }

    if (nodeData.length > 4) {
      timelineWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isRouteExpanded = !_isRouteExpanded;
                });
              },
              icon: Icon(_isRouteExpanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.primaryRed),
              label: Text(_isRouteExpanded ? 'Hide Full Route' : 'Show Full Route', style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
            ),
          ),
        )
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: timelineWidgets,
    );
  }

  Widget _buildTimelineNode(String title, String subtitle, IconData icon, bool isPast, bool isCompleted, {bool isActive = false, bool isLast = false}) {
    Color activeColor = AppTheme.primaryRed;
    Color inactiveColor = Colors.grey.shade300;
    Color currentColor = isCompleted || isActive ? activeColor : inactiveColor;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32, height: 32, 
                decoration: BoxDecoration(
                  color: isCompleted ? activeColor : (isActive ? Colors.red.shade50 : Colors.white), 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: currentColor, width: 2)
                ), 
                child: Icon(icon, color: isCompleted ? Colors.white : currentColor, size: 16)
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: isCompleted ? activeColor : inactiveColor, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: currentColor, fontSize: 12)), 
            const SizedBox(height: 4), 
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)), 
            const SizedBox(height: 24)
          ])),
        ],
      ),
    );
  }

  Widget _buildRecentSubmissionsTable(BuildContext context) {
    final processedDocs = _processedDocuments;
    int totalItems = processedDocs.length;
    int totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    } else if (totalPages == 0) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * _itemsPerPage;
    final paginatedDocs = processedDocs.skip(startIndex).take(_itemsPerPage).toList();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade100)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                child: Row(children: const [Expanded(child: Text('DOCUMENT NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))), Expanded(child: Text('CURRENT LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))]),
              ),
              if (paginatedDocs.isEmpty)
                const Padding(padding: EdgeInsets.all(16.0), child: Text("No documents found.", style: TextStyle(color: Colors.grey))),
              
              ...paginatedDocs.map((doc) => _buildSubmissionRow(context, doc)),
            ],
          ),
        ),
        
        if (totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0 
                    ? () => setState(() => _currentPage--) 
                    : null,
              ),
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < totalPages - 1 
                    ? () => setState(() => _currentPage++) 
                    : null,
              ),
            ],
          )
        ]
      ],
    );
  }

  Widget _buildSubmissionRow(BuildContext context, Map<String, dynamic> doc) {
    String name = doc['title'] ?? 'Unknown';
    String location = doc['current_location'] ?? 'Pending Route';
    String displayName = name.length > 18 ? '${name.substring(0, 15)}...' : name;

    bool isSelected = _liveDocument != null && _liveDocument!['ini_id'] == doc['ini_id'];

    return InkWell(
      onTap: () {
        setState(() {
          _liveDocument = doc;
        });
        _fetchLiveRoute(doc);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade50.withOpacity(0.4) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.red.shade50))
        ),
        child: Row(
          children: [
            Expanded(child: Text(displayName, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
            Expanded(child: Text(location, style: const TextStyle(fontSize: 13, color: Colors.black54))),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => DocumentDetailsScreen(docId: doc['ini_id'])
              )),
              child: const Icon(Icons.remove_red_eye_outlined, color: AppTheme.primaryRed, size: 20),
            )
          ],
        ),
      ),
    );
  }
}