import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/permission_service.dart';
import 'home_screen.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final permService = context.watch<PermissionService>();

    // If all granted, auto-navigate to home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (permService.allGranted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Phubb-Free')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We need a few permissions to detect phubbing locally on your device.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            _PermissionTile(
              title: 'Usage Access',
              subtitle: 'To detect when you unlock and switch apps',
              icon: Icons.app_settings_alt,
              isGranted: permService.usageAccessGranted,
              onRequest: permService.requestUsageAccess,
            ),
            const SizedBox(height: 16),
            _PermissionTile(
              title: 'Notification Access',
              subtitle: 'To understand notification triggers (no content read)',
              icon: Icons.notifications,
              isGranted: permService.notificationAccessGranted,
              onRequest: permService.requestNotificationAccess,
            ),
            const SizedBox(height: 16),
            _PermissionTile(
              title: 'Bluetooth',
              subtitle: 'To detect when others are nearby',
              icon: Icons.bluetooth,
              isGranted: permService.bluetoothGranted,
              onRequest: permService.requestBluetooth,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isGranted;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32, color: isGranted ? Colors.green : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: isGranted 
          ? const Icon(Icons.check_circle, color: Colors.green)
          : ElevatedButton(
              onPressed: onRequest,
              child: const Text('Grant'),
            ),
      ),
    );
  }
}
