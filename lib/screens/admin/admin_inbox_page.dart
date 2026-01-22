import 'package:flutter/material.dart';

class AdminInboxPage extends StatelessWidget {
  const AdminInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Inbox", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B5145),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _buildMessageTile(
            title: "New Support Ticket #1024",
            subtitle: "User Rahul reported a technical glitch with payment.",
            time: "10m ago",
            icon: Icons.support_agent,
            color: Colors.blue,
            isUnread: true,
          ),
          _buildMessageTile(
            title: "Driver Application Alert",
            subtitle: "5 new drivers are waiting for document verification.",
            time: "2h ago",
            icon: Icons.assignment_ind,
            color: Colors.orange,
            isUnread: true,
          ),
          _buildMessageTile(
            title: "System Maintenance",
            subtitle: "Scheduled server maintenance at 12:00 PM tonight.",
            time: "5h ago",
            icon: Icons.settings_suggest,
            color: Colors.grey,
            isUnread: false,
          ),
          _buildMessageTile(
            title: "User Report: Safety",
            subtitle: "User 'Anjali' reported a safety concern during a ride.",
            time: "1d ago",
            icon: Icons.report_problem,
            color: Colors.red,
            isUnread: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color color,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isUnread ? Border.all(color: Colors.green.shade100, width: 1.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal))),
            Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        onTap: () {},
      ),
    );
  }
}