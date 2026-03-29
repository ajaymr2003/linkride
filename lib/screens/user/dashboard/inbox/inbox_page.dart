import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import '../../driver/ride_requests_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final Color primaryGreen = const Color(0xFF11A860);

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<String> _currentlyVisibleIds = [];

  Future<void> _deleteSelectedItems(String collectionPath) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Delete ${_selectedIds.length} items?"),
            content: const Text("This action cannot be undone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      final batch = FirebaseFirestore.instance.batch();
      for (var id in _selectedIds) {
        batch.delete(
          FirebaseFirestore.instance.collection(collectionPath).doc(id),
        );
      }
      await batch.commit();
      _exitSelectionMode();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _handleSelectAll() {
    setState(() {
      if (_selectedIds.length == _currentlyVisibleIds.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(_currentlyVisibleIds);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: TabBarView(
          children: [_buildMessagesTab(), _buildNotificationsTab()],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.red.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          "${_selectedIds.length} selected",
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _selectedIds.length == _currentlyVisibleIds.length
                  ? Icons.deselect
                  : Icons.select_all,
              color: Colors.red,
            ),
            onPressed: _handleSelectAll,
          ),
          Builder(
            builder: (context) {
              int tabIndex = DefaultTabController.of(context).index;
              return IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: () => _deleteSelectedItems(
                  tabIndex == 0 ? 'chats' : 'notifications',
                ),
              );
            },
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: const InputDecoration(
                hintText: "Search name or location...",
                border: InputBorder.none,
              ),
            )
          : const Text(
              "Inbox",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: Colors.black,
          ),
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) _searchQuery = "";
            _searchController.clear();
          }),
        ),
      ],
      bottom: TabBar(
        labelColor: primaryGreen,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primaryGreen,
        onTap: (_) => _exitSelectionMode(),
        tabs: const [
          Tab(text: "Messages"),
          Tab(text: "Notifications"),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('last_message_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data?.docs ?? [];
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String name =
                (uid == data['participants'][0]
                    ? data['passenger_name']
                    : data['driver_name']) ??
                "";
            String source = data['source']?['name'] ?? "";
            return name.toLowerCase().contains(_searchQuery) ||
                source.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          List<String> visibleIds = docs.map((d) => d.id).toList();
          if (_currentlyVisibleIds.toString() != visibleIds.toString()) {
            setState(() => _currentlyVisibleIds = visibleIds);
          }
        });

        if (docs.isEmpty)
          return _buildEmptyState(Icons.chat_bubble_outline, "No messages");

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var chat = doc.data() as Map<String, dynamic>;
            bool isSelected = _selectedIds.contains(doc.id);

            List participants = chat['participants'] ?? [];
            String otherUid = participants.firstWhere(
              (id) => id != uid,
              orElse: () => "",
            );
            bool isDriver = uid == chat['participants'][0];
            String otherUserName = isDriver
                ? (chat['passenger_name'] ?? "User")
                : (chat['driver_name'] ?? "Driver");

            String sourceName = chat['source']?['name'] ?? "Unknown";
            String destName = chat['destination']?['name'] ?? "Destination";

            // --- LOGIC FOR COMPLETED STATUS ---
            bool isCompleted = chat['status'] == 'completed';

            return ListTile(
              selected: isSelected,
              selectedTileColor: Colors.red.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: isSelected
                        ? Colors.red
                        : primaryGreen.withOpacity(0.1),
                    child: Text(
                      isSelected ? "" : otherUserName[0],
                      style: TextStyle(
                        color: isSelected ? Colors.white : primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Positioned.fill(
                      child: Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                ],
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    otherUserName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    chat['last_message_time'] != null
                        ? DateFormat('h:mm a').format(
                            (chat['last_message_time'] as Timestamp).toDate(),
                          )
                        : "",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_filled,
                        size: 12,
                        color: isCompleted ? Colors.grey : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          "$sourceName ➔ $destName",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isCompleted ? Colors.grey : primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "COMPLETED",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat['last_message'] ?? "No messages",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(doc.id);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chat['chatId'],
                        otherUserName: otherUserName,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () => _toggleSelection(doc.id),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsTab() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data?.docs ?? [];
        if (_searchQuery.isNotEmpty)
          docs = docs
              .where(
                (doc) => (doc['title'] as String).toLowerCase().contains(
                  _searchQuery,
                ),
              )
              .toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          List<String> visibleIds = docs.map((d) => d.id).toList();
          if (_currentlyVisibleIds.toString() != visibleIds.toString())
            setState(() => _currentlyVisibleIds = visibleIds);
        });

        if (docs.isEmpty)
          return _buildEmptyState(Icons.notifications_none, "No notifications");
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            bool isSelected = _selectedIds.contains(doc.id);
            return GestureDetector(
              onLongPress: () => _toggleSelection(doc.id),
              onTap: _isSelectionMode ? () => _toggleSelection(doc.id) : null,
              child: Stack(
                children: [
                  _buildNotificationCard(
                    context,
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ),
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> notif,
  ) {
    bool isUnread = notif['isRead'] == false;
    bool isRideRequest = notif['type'] == 'new_request';
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isUnread ? primaryGreen.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isUnread
              ? primaryGreen.withOpacity(0.3)
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: _isSelectionMode
            ? () => _toggleSelection(docId)
            : () {
                if (isUnread)
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(docId)
                      .update({'isRead': true});
                if (isRideRequest)
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RideRequestsPage()),
                  );
              },
        child: Row(
          children: [
            Icon(
              isRideRequest ? Icons.person_pin_circle : Icons.notifications,
              color: isRideRequest ? primaryGreen : Colors.blue,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['title'] ?? "",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    notif['message'] ?? "",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
}
