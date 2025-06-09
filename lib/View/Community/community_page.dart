import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with TickerProviderStateMixin {
  late WebSocketChannel _channel;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isConnected = false;
  String _currentUserName = '';
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fetchUserProfile();
    _fetchPreviousMessages();
    _connectWebSocket();
  }

  Future<void> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';
    
    if (accessToken.isEmpty) {
      setState(() {
        _currentUserName = 'Unknown User';
      });
      return;
    }

    try {
      final url = Uri.parse(ApiConfig.driverProfileUrl);
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _currentUserName = data['name'] ?? 'Unknown User';
        });
      } else {
        setState(() {
          _currentUserName = 'Unknown User';
        });
      }
    } catch (e) {
      setState(() {
        _currentUserName = 'Unknown User';
      });
    }
  }

  Future<void> _fetchPreviousMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';
    
    if (accessToken.isEmpty) {
      setState(() {
        _messages.add({
          'message': 'Error: No access token found',
          'user_name': 'System',
          'timestamp': DateTime.now().toIso8601String(),
          'isSystem': true,
        });
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.driverCommunityUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print("Messages from backend: $data");
        
        final processedMessages = data.map<Map<String, dynamic>>((message) {
          final messageMap = Map<String, dynamic>.from(message);
          print("Individual message: $messageMap");
          
          if (!messageMap.containsKey('user_name') || 
              messageMap['user_name'] == null || 
              messageMap['user_name'].toString().trim().isEmpty) {
            
            messageMap['user_name'] = messageMap['sender_name']?.toString() ?? 
                                     messageMap['author']?.toString() ?? 
                                     messageMap['username']?.toString() ??
                                     messageMap['sender']?.toString() ??
                                     messageMap['user']?.toString() ??
                                     messageMap['driver_name']?.toString() ??
                                     'Anonymous User';
          }
          
          messageMap['isOwn'] = messageMap['user_name'] == _currentUserName;
          print("Processed message user_name: ${messageMap['user_name']}");
          return messageMap;
        }).toList();
        
        setState(() {
          _messages.addAll(processedMessages);
        });
        _scrollToBottom();
      } else {
        setState(() {
          _messages.add({
            'message': 'Failed to load previous messages: HTTP ${response.statusCode} - ${response.reasonPhrase}',
            'user_name': 'System',
            'timestamp': DateTime.now().toIso8601String(),
            'isSystem': true,
          });
        });
      }
    } catch (e) {
      print("Messages fetch error: $e");
      setState(() {
        _messages.add({
          'message': 'Error fetching messages: $e',
          'user_name': 'System',
          'timestamp': DateTime.now().toIso8601String(),
          'isSystem': true,
        });
      });
    }
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';
    
    if (accessToken.isEmpty) {
      setState(() {
        _isConnected = false;
        _messages.add({
          'message': 'Error: No access token for WebSocket',
          'user_name': 'System',
          'timestamp': DateTime.now().toIso8601String(),
          'isSystem': true,
        });
      });
      return;
    }

    try {
      final wsUrl = 'wss://taskova.co.uk:8091/ws/community/driver/?token=$accessToken';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
 
      setState(() {
        _isConnected = true;
      });
      _animationController.forward();

      _channel.stream.listen(
        (message) {
          try {
            final decodedMessage = jsonDecode(message) as Map<String, dynamic>;
            
            if (!_messages.any((msg) => msg['message_id'] == decodedMessage['message_id'])) {
              if (decodedMessage['user_name'] == null || decodedMessage['user_name'].isEmpty) {
                decodedMessage['user_name'] = _currentUserName;
              }
              decodedMessage['isOwn'] = decodedMessage['user_name'] == _currentUserName;
              setState(() {
                _messages.add(decodedMessage);
              });
              _scrollToBottom();
            }
          } catch (e) {
            print("Error decoding WebSocket message: $e");
          }
        },
        onError: (error) {
          print(error);
          print('8888888888888888888888888888888888888888888888888888888888888888888888888888888880');
          setState(() {
            _isConnected = false;
            _messages.add({
              'message': 'WebSocket error: $error',
              'user_name': 'System',
              'timestamp': DateTime.now().toIso8601String(),
              'isSystem': true,
            });
          });
          _animationController.reverse();
        },
        
        onDone: () {
          setState(() {
            _isConnected = false;
            _messages.add({
              'message': 'WebSocket connection closed',
              'user_name': 'System',
              'timestamp': DateTime.now().toIso8601String(),
              'isSystem': true,
            });
          });
          _animationController.reverse();
        },
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
        _messages.add({
          'message': 'Failed to connect WebSocket: $e',
          'user_name': 'System',
          'timestamp': DateTime.now().toIso8601String(),
          'isSystem': true,
        });
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

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty && _isConnected) {
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final message = {
        'message': _controller.text.trim(),
        'user_name': _currentUserName,
        'timestamp': DateTime.now().toIso8601String(),
        'message_id': messageId,
        'isOwn': true,
      };

      setState(() {
        _messages.add(Map<String, dynamic>.from(message));
        _isTyping = false;
      });

      _channel.sink.add(jsonEncode(message));
      _controller.clear();
      _scrollToBottom();
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final userName = message['user_name'] ?? 'Unknown User';
    final messageText = message['message'] ?? 'No message content';
    final timestamp = message['timestamp'] ?? '';
    final isOwn = message['isOwn'] ?? false;
    final isSystem = message['isSystem'] ?? false;
    
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: CupertinoColors.systemYellow.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CupertinoColors.systemYellow.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Text(
            messageText,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemOrange,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: CupertinoColors.systemBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              margin: EdgeInsets.only(
                bottom: index < _messages.length - 1 &&
                        _messages[index + 1]['user_name'] == userName &&
                        !(_messages[index + 1]['isSystem'] ?? false)
                    ? 2.0
                    : 8.0,
              ),
              decoration: BoxDecoration(
                color: isOwn ? CupertinoColors.systemBlue : CupertinoColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isOwn ? 18 : 6),
                  bottomRight: Radius.circular(isOwn ? 6 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isOwn ? null : Border.all(
                  color: CupertinoColors.systemGrey5,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOwn)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                    ),
                  Text(
                    messageText,
                    style: TextStyle(
                      fontSize: 16,
                      color: isOwn ? CupertinoColors.white : CupertinoColors.black,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isOwn 
                          ? CupertinoColors.white.withOpacity(0.8) 
                          : CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: const Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey5,
            width: 0.5,
          ),
        ),
        middle: Column(
          children: [
            const Text(
              'Community Chat',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.black,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected 
                            ? CupertinoColors.systemGreen 
                            : CupertinoColors.systemOrange,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'Online' : 'Connecting...',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isConnected 
                        ? CupertinoColors.systemGreen 
                        : CupertinoColors.systemOrange,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.chat_bubble_2,
                              size: 40,
                              color: CupertinoColors.systemBlue,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start the conversation!',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index], index);
                      },
                    ),
            ),
            // Message input area
            Container(
              decoration: const BoxDecoration(
                color: CupertinoColors.white,
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.systemGrey5,
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isConnected 
                              ? CupertinoColors.systemBlue.withOpacity(0.3)
                              : CupertinoColors.systemGrey4,
                          width: 1,
                        ),
                      ),
                      child: CupertinoTextField(
                        controller: _controller,
                        enabled: _isConnected,
                        maxLines: 4,
                        minLines: 1,
                        onChanged: (text) {
                          setState(() {
                            _isTyping = text.trim().isNotEmpty;
                          });
                        },
                        placeholder: _isConnected ? 'Type a message...' : 'Connecting...',
                        placeholderStyle: const TextStyle(
                          color: CupertinoColors.systemGrey2,
                          fontSize: 16,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                        ),
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      color: (_isConnected && _isTyping) 
                          ? CupertinoColors.systemBlue 
                          : CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(20),
                      onPressed: (_isConnected && _isTyping) ? _sendMessage : null,
                      child: Icon(
                        CupertinoIcons.arrow_up,
                        color: (_isConnected && _isTyping) 
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