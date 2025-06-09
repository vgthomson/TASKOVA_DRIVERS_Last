
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatPage extends StatefulWidget {
  final String driverId;
  final String chatRoomId;
  final String businessName;

  const ChatPage({
    Key? key,
    required this.driverId,
    required this.chatRoomId,
    required this.businessName,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  WebSocketChannel? _channel;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isConnected = false;
  bool _isLoading = true;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const String _baseUrl = 'http://192.168.20.29:8001';
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeChat();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isConnected) {
      _reconnectWebSocket();
    } else if (state == AppLifecycleState.paused) {
      _disconnectWebSocket();
    }
  }

  Future<void> _initializeChat() async {
    try {
      await _fetchMessageHistory();
      await _connectToWebSocket();
    } catch (e) {
      print('Failed to initialize chat: $e');
      _showErrorSnackBar('Failed to initialize chat');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMessageHistory() async {
    print('Fetching message history for chat room: ${widget.chatRoomId}');
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    
    if (accessToken == null) {
      throw Exception('No access token found');
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/chat-history/${widget.chatRoomId}/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> messages = jsonDecode(response.body);
        final processedMessages = messages
            .map((msg) => _processMessage(msg))
            .where((msg) => msg != null && msg['text'].toString().trim().isNotEmpty)
            .cast<Map<String, dynamic>>()
            .toList();
        
        setState(() {
          _messages.clear();
          _messages.addAll(processedMessages);
        });
        
        print('Loaded ${_messages.length} messages');
        _scrollToBottom();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout');
    } catch (e) {
      print('Error fetching message history: $e');
      rethrow;
    }
  }

  Map<String, dynamic>? _processMessage(Map<String, dynamic> msg) {
    try {
      final senderId = msg['sender']?['id']?.toString();
      final isMe = senderId == widget.driverId.toString();
      final messageText = msg['message']?.toString() ?? '';
      
      if (messageText.isEmpty) return null;
      
      return {
        'text': messageText,
        'isMe': isMe,
        'timestamp': _parseTimestamp(msg['timestamp']),
        'id': msg['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      };
    } catch (e) {
      print('Error processing message: $e');
      return null;
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    try {
      return DateTime.parse(timestamp.toString());
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<void> _connectToWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    
    if (accessToken == null) {
      throw Exception('No access token found');
    }

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.20.29:8001/ws/chat/${widget.chatRoomId}/?token=$accessToken'),
      );

      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClose,
      );

      await _channel!.ready.timeout(const Duration(seconds: 10));
      
      setState(() {
        _isConnected = true;
        _reconnectAttempts = 0;
      });
      
      print('WebSocket connected successfully');
    } catch (e) {
      print('WebSocket connection failed: $e');
      setState(() {
        _isConnected = false;
      });
      _scheduleReconnect();
      rethrow;
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final processedMessage = _processWebSocketMessage(data);
      
      if (processedMessage != null) {
        setState(() {
          _messages.removeWhere((msg) => 
              msg['text'] == processedMessage['text'] && 
              msg['isTemporary'] == true);
          
          final isDuplicate = _messages.any((msg) => 
              msg['text'] == processedMessage['text'] && 
              msg['isMe'] == processedMessage['isMe'] &&
              msg['isTemporary'] != true &&
              msg['timestamp'].difference(processedMessage['timestamp']).abs().inSeconds < 5);
          
          if (!isDuplicate) {
            _messages.add(processedMessage);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  Map<String, dynamic>? _processWebSocketMessage(Map<String, dynamic> data) {
    final messageText = data['message']?.toString();
    if (messageText == null || messageText.trim().isEmpty) return null;
    
    String? senderId;
    
    if (data['sender_id'] != null) {
      senderId = data['sender_id'].toString();
    } else if (data['sender'] != null) {
      if (data['sender'] is String) {
        senderId = data['sender'].toString();
      } else if (data['sender'] is Map && data['sender']['id'] != null) {
        senderId = data['sender']['id'].toString();
      }
    } else if (data['user_id'] != null) {
      senderId = data['user_id'].toString();
    } else if (data['from'] != null) {
      senderId = data['from'].toString();
    }
    
    print('WebSocket message data: $data');
    print('Extracted sender ID: $senderId');
    print('Current driver ID: ${widget.driverId}');
    
    final isMe = senderId == widget.driverId.toString();
    print('Is message from me: $isMe');
    
    return {
      'text': messageText,
      'isMe': isMe,
      'timestamp': DateTime.now(),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'senderId': senderId,
    };
  }

  void _handleWebSocketError(dynamic error) {
    print('WebSocket error: $error');
    setState(() {
      _isConnected = false;
    });
    _showErrorSnackBar('Connection error');
    _scheduleReconnect();
  }

  void _handleWebSocketClose() {
    print('WebSocket connection closed');
    setState(() {
      _isConnected = false;
    });
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _showErrorSnackBar('Failed to connect after multiple attempts');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(seconds: 2 * (_reconnectAttempts + 1)),
      _reconnectWebSocket,
    );
  }

  void _reconnectWebSocket() {
    if (_isConnected) return;
    
    _reconnectAttempts++;
    print('Attempting to reconnect (attempt $_reconnectAttempts)');
    
    _connectToWebSocket().catchError((e) {
      print('Reconnection failed: $e');
    });
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    setState(() {
      _isConnected = false;
    });
  }

  void _sendMessage() {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || !_isConnected) return;

    try {
      final tempMessage = {
        'text': messageText,
        'isMe': true,
        'timestamp': DateTime.now(),
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'isTemporary': true,
      };
      
      setState(() {
        _messages.add(tempMessage);
      });
      
      _channel?.sink.add(jsonEncode({
        'message': messageText,
        'sender': widget.driverId,
        'sender_id': widget.driverId,
        'user_id': widget.driverId,
        'type': 'chat_message',
      }));

      _messageController.clear();
      _scrollToBottom();
      
      Timer(const Duration(seconds: 5), () {
        setState(() {
          _messages.removeWhere((msg) => 
              msg['id'] == tempMessage['id'] && 
              msg['isTemporary'] == true);
        });
      });
      
    } catch (e) {
      print('Error sending message: $e');
      _showErrorSnackBar('Failed to send message');
      
      setState(() {
        _messages.removeWhere((msg) => 
            msg['text'] == messageText && 
            msg['isTemporary'] == true);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: CupertinoColors.destructiveRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildConnectionStatus() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CupertinoColors.systemYellow.withOpacity(0.1),
              CupertinoColors.systemOrange.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 12),
            Text(
              'Loading chat...',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemOrange,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isConnected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CupertinoColors.destructiveRed.withOpacity(0.1),
              CupertinoColors.systemRed.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.wifi_slash,
              size: 18,
              color: CupertinoColors.destructiveRed,
            ),
            SizedBox(width: 12),
            Text(
              _reconnectAttempts > 0 
                  ? 'Reconnecting... (${_reconnectAttempts}/$_maxReconnectAttempts)'
                  : 'Connection lost',
              style: TextStyle(
                color: CupertinoColors.destructiveRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isMe = message['isMe'] as bool;
    final timestamp = message['timestamp'] as DateTime;
    final isTemporary = message['isTemporary'] == true;
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [
                              Color(0xFF007AFF),
                              Color(0xFF0051D0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe 
                            ? Color(0xFF007AFF).withOpacity(0.3)
                            : CupertinoColors.systemGrey.withOpacity(0.2),
                        offset: Offset(0, 2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          message['text'].toString(),
                          style: TextStyle(
                            color: isMe ? CupertinoColors.white : CupertinoColors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (isTemporary) ...[
                        SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CupertinoActivityIndicator(radius: 6),
                        ),
                      ],
                    ],
                  ),
                ),
                if (index == _messages.length - 1 || 
                    _shouldShowTimestamp(message, index))
                  Padding(
                    padding: EdgeInsets.only(
                      top: 6,
                      left: isMe ? 0 : 12,
                      right: isMe ? 12 : 0,
                    ),
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowTimestamp(Map<String, dynamic> message, int index) {
    if (index == _messages.length - 1) return true;
    
    final currentTime = message['timestamp'] as DateTime;
    final nextTime = _messages[index + 1]['timestamp'] as DateTime;
    
    return nextTime.difference(currentTime).inMinutes > 5;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inHours > 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return 'Just now';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF007AFF).withOpacity(0.1),
                  Color(0xFF0051D0).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              CupertinoIcons.chat_bubble_2,
              size: 48,
              color: Color(0xFF007AFF),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start the conversation!\nSend your first message below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _disconnectWebSocket();
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Color(0xFFF8F9FA),
      child: SafeArea(
        child: Column(
          children: [
            // Custom Navigation Bar with Gradient
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF007AFF),
                    Color(0xFF0051D0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF007AFF).withOpacity(0.3),
                    offset: Offset(0, 2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.back,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.businessName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.destructiveRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          _isConnected ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Connection Status
            _buildConnectionStatus(),
            
            // Messages Area
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(radius: 16),
                          SizedBox(height: 16),
                          Text(
                            'Loading messages...',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) =>
                              _buildMessageBubble(_messages[index], index),
                        ),
            ),
            
            // Message Input Area
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.1),
                    offset: Offset(0, -2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Color(0xFFE5E5EA),
                          width: 1,
                        ),
                      ),
                      child: CupertinoTextField(
                        controller: _messageController,
                        placeholder: 'Type a message...',
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(),
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.black,
                        ),
                        placeholderStyle: TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 16,
                        ),
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: _isConnected
                          ? LinearGradient(
                              colors: [
                                Color(0xFF007AFF),
                                Color(0xFF0051D0),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: _isConnected ? null : CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: _isConnected ? [
                        BoxShadow(
                          color: Color(0xFF007AFF).withOpacity(0.3),
                          offset: Offset(0, 2),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ] : null,
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.all(14),
                      borderRadius: BorderRadius.circular(25),
                      onPressed: _isConnected ? _sendMessage : null,
                      child: Icon(
                        CupertinoIcons.paperplane_fill,
                        color: _isConnected 
                            ? CupertinoColors.white 
                            : CupertinoColors.systemGrey2,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}