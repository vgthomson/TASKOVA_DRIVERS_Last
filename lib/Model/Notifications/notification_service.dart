// notification_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_helper.dart';

class NotificationService {
  static const String _lastCheckedKey = 'last_notification_check';
  Timer? _timer;
  
  // Start periodic notification checking
  void startNotificationService() {
    // Check every 30 seconds (adjust as needed)
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkForNewNotifications();
    });
  }
  
  // Stop the notification service
  void stopNotificationService() {
    _timer?.cancel();
  }
  
  // Check for new notifications
  Future<void> _checkForNewNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      // Only check if user is logged in
      if (token == null) return;
      
      final response = await http.get(
        Uri.parse('http://192.168.20.29:8001/api/notifications/'), // Replace with your API URL
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> notifications = jsonDecode(response.body);
        
        // Get last checked timestamp
        final lastChecked = prefs.getString(_lastCheckedKey);
        
        // Filter new notifications
        List<Map<String, dynamic>> newNotifications = [];
        
        for (var notification in notifications) {
          final createdAt = notification['created_at'];
          
          if (lastChecked == null || createdAt.compareTo(lastChecked) > 0) {
            newNotifications.add(notification);
          }
        }
        
        // Show notifications for new job posts
        for (var notification in newNotifications) {
          if (!notification['is_read']) {
            _showSystemNotification(notification);
          }
        }
        
        // Update last checked timestamp
        if (notifications.isNotEmpty) {
          final latestTimestamp = notifications.first['created_at'];
          await prefs.setString(_lastCheckedKey, latestTimestamp);
        }
      }
    } catch (e) {
      print('Error checking notifications: $e');
    }
  }
  
  // Show system notification
  void _showSystemNotification(Map<String, dynamic> notification) {
    final companyName = _extractCompanyName(notification['message']);
    NotificationHelper.showJobNotification(
      companyName: companyName,
      notificationId: notification['id'],
    );
  }
  
  // Extract company name from message
  String _extractCompanyName(String message) {
    final regex = RegExp(r'A new job has been posted by (.+)\.');
    final match = regex.firstMatch(message);
    return match?.group(1) ?? 'Unknown Company';
  }
  
  // Mark notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) return;
      
      await http.post(
        Uri.parse('YOUR_API_URL/notifications/$notificationId/mark-read/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}