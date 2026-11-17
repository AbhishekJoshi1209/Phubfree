import 'package:flutter/material.dart';
import '../../services/mock_sensor_feed.dart';
import '../../models/sensor_event.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MockSensorFeed _sensorFeed = MockSensorFeed();
  final List<SensorEvent> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _sensorFeed.start();
    _sensorFeed.eventStream.listen((event) {
      setState(() {
        _recentEvents.insert(0, event);
        if (_recentEvents.length > 15) {
          _recentEvents.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _sensorFeed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.blur_circular, color: AppTheme.accentCyan, size: 32),
                      const SizedBox(width: 12),
                      Text('Phubb-Free', style: Theme.of(context).appBarTheme.titleTextStyle),
                    ],
                  ),
                  const CircleAvatar(
                    backgroundColor: AppTheme.surfaceHighlight,
                    child: Icon(Icons.person, color: AppTheme.textSecondary),
                  )
                ],
              ),
              const SizedBox(height: 32),
              
              // Top Dashboard Cards
              const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildProgressCard(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildSmallMetricCard('Time Saved', '4h 12m', Icons.timer, AppTheme.accentCyan),
                        const SizedBox(height: 16),
                        _buildSmallMetricCard('Focus Score', 'Excellent', Icons.star, AppTheme.accentPurple),
                      ],
                    ),
                  )
                ],
              ),
              
              const SizedBox(height: 32),
              const Text('LIVE SENSOR FEED', style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w600, 
                color: AppTheme.textSecondary,
                letterSpacing: 1.2
              )),
              const SizedBox(height: 12),
              
              // Event List
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _recentEvents.length,
                  itemBuilder: (context, index) {
                    return _buildEventTile(_recentEvents[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceHighlight, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface,
            AppTheme.surface.withOpacity(0.5),
          ]
        )
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TODAY'S PROGRESS", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text("Digital Harmony", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Center(
            child: SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 0.84,
                    strokeWidth: 8,
                    backgroundColor: AppTheme.surfaceHighlight,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accentPurple),
                  ),
                  const Center(
                    child: Text('84%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSmallMetricCard(String title, String value, IconData icon, Color accent) {
    return Container(
      width: double.infinity,
      height: 102,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceHighlight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEventTile(SensorEvent event) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (event.type) {
      case SensorEventType.unlock:
        icon = Icons.lock_open;
        color = Colors.orangeAccent;
        title = "Unlock Detected";
        subtitle = "Screen activated";
        break;
      case SensorEventType.appSwitch:
        icon = Icons.layers;
        color = AppTheme.accentCyan;
        title = "App Switch";
        subtitle = "Switched to ${event.data['app_name']}";
        break;
      case SensorEventType.notification:
        icon = Icons.notifications;
        color = Colors.redAccent;
        title = "Notification Activity";
        subtitle = "Responded in ${event.data['response_latency_sec']}s";
        break;
      case SensorEventType.proximity:
        icon = Icons.bluetooth;
        color = AppTheme.accentPurple;
        title = "Bluetooth Proximity";
        subtitle = "Peer detected (RSSI: ${event.data['rssi']})";
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceHighlight, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("Just now", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}
