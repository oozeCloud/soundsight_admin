import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load users: ${snapshot.error}'));
          }

          final users = snapshot.data?.docs ?? [];
          users.sort((a, b) => '${a.data()['email'] ?? ''}'
              .compareTo('${b.data()['email'] ?? ''}'));
          if (users.isEmpty) return const Center(child: Text('No users found.'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = users[index].data();
              final imageUrl = data['profileImageUrl'] as String?;
              final name = '${data['displayName'] ?? data['name'] ?? data['email'] ?? 'Unknown user'}';
              final role = '${data['role'] ?? 'User'}';
              final level = '${data['skillLevel'] ?? 'Not assessed'}';

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: imageUrl?.isNotEmpty == true
                      ? NetworkImage(imageUrl!)
                      : null,
                  child: imageUrl?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person_outline),
                ),
                title: Text(name),
                subtitle: Text(
                  '${data['email'] ?? 'No email'}\nRole: $role · Level: $level',
                ),
                isThreeLine: true,
                onTap: () => _showDetails(context, data),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${data['displayName'] ?? data['name'] ?? data['email'] ?? 'User'}'),
        content: SingleChildScrollView(
          child: SelectableText(data.entries
              .where((entry) => entry.key != 'profileImageUrl')
              .map((entry) => '${entry.key}: ${entry.value ?? '—'}')
              .join('\n')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
