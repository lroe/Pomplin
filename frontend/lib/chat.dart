import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homepage.dart';
import 'roadmap.dart';
import 'services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? _channel;
  bool _isTyping = false;
  int _selectedNav = 2; 
  final List<_Message> _messages = [];
  bool _isConnected = false;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bg          = Color(0xFF0D0D0D);
  static const Color _userBubble  = Color(0xFF2A1F35);
  static const Color _botBubble   = Color(0xFF1C1C1E);
  static const Color _inputBg     = Color(0xFF1C1C1E);
  static const Color _green       = Color(0xFF4CAF50);
  static const Color _pink        = Color(0xFFD4607A);
  static const Color _grey        = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    final wsUrl = "ws://localhost:8001/ws/chat?token=$token";
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen((message) {
      final data = json.decode(message);
      _handleIncomingMessage(data);
    }, onError: (error) {
      print("WS Error: $error");
      setState(() => _isConnected = false);
    }, onDone: () {
      print("WS Closed");
      setState(() => _isConnected = false);
    });

    setState(() => _isConnected = true);
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    if (data['role'] == 'model') {
      setState(() {
        _isTyping = false;
        
        // Add text message if present
        if (data['content'] != null && data['content'].toString().isNotEmpty) {
          _messages.add(_Message(
            text: data['content'],
            isUser: false,
            time: DateTime.now(),
          ));
        }

        // Handle tool results
        if (data.containsKey('tool_name')) {
          final toolName = data['tool_name'];
          final toolResult = data['tool_result'];

          if (toolName == 'propose_roadmap') {
            _messages.add(_Message(
              text: "I've generated a draft roadmap for you!",
              isUser: false,
              time: DateTime.now(),
              roadmapPreview: toolResult['roadmap'],
              goalTitle: toolResult['title'],
            ));
          } else if (toolName == 'confirm_and_create_goal') {
             _messages.add(_Message(
              text: "Goal confirmed and saved! You can see it in the Roadmap tab.",
              isUser: false,
              time: DateTime.now(),
            ));
          }
        }
      });
      _scrollToBottom();
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _channel == null) return;

    final payload = json.encode({"content": text});
    _channel!.sink.add(payload);

    setState(() {
      _messages.add(_Message(text: text, isUser: true, time: DateTime.now()));
      _controller.clear();
      _isTyping = true;
    });

    _scrollToBottom();
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

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (!_isConnected) 
            Container(
              color: Colors.redAccent,
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: const Text("Disconnected. Reconnecting...", textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
            ),
          Expanded(child: _buildMessageList()),
          if (_isTyping) _buildTypingIndicator(),
          _buildInputBar(),
          _buildBottomNav(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF111111),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF1C1C1E),
                backgroundImage: AssetImage('assets/pomplin_dp.png'),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _isConnected ? _green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF111111), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Text(
            'Pomplin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E1E1E)),
      ),
    );
  }

  Widget _buildMessageList() {
    return _messages.isEmpty 
      ? Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/pomplin_idea.png', height: 150),
            const SizedBox(height: 16),
            const Text("Start a conversation with Pomplin!", style: TextStyle(color: Colors.white54)),
          ],
        ))
      : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          itemCount: _messages.length,
          itemBuilder: (context, i) {
            final msg = _messages[i];
            final showAvatar = !msg.isUser && (i == 0 || _messages[i - 1].isUser);
            return _buildBubble(msg, showAvatar);
          },
        );
  }

  Widget _buildBubble(_Message msg, bool showAvatar) {
    final isUser = msg.isUser;
    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: 4, left: isUser ? 52 : 0, right: isUser ? 0 : 52),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: showAvatar
                  ? const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF1C1C1E),
                      backgroundImage: AssetImage('assets/pomplin_dp.png'),
                    )
                  : const SizedBox(width: 32),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? _userBubble : _botBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser ? Border.all(color: const Color(0xFF3D2550), width: 1) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
                      ),
                      if (msg.roadmapPreview != null) ...[
                        const SizedBox(height: 12),
                        _buildRoadmapPreview(msg.goalTitle ?? "Goal", msg.roadmapPreview!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(_formatTime(msg.time), style: const TextStyle(color: _grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapPreview(String title, Map<String, dynamic> roadmap) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            roadmap['summary'] ?? "Roadmap generated by Pomplin.",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // Send confirmation to backend
              _channel?.sink.add(json.encode({
                "content": "I like this plan! Let's go."
              }));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Confirm & Start", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 6),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF1C1C1E),
            backgroundImage: AssetImage('assets/pomplin_dp.png'),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: _botBubble, borderRadius: BorderRadius.circular(18)),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(26)),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Message Pomplin…',
                  hintStyle: TextStyle(color: Color(0xFF555555), fontSize: 15),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: _pink, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.swap_horiz_rounded, label: 'Roadmap'),
      _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
      _NavItem(icon: Icons.description_outlined, label: 'Community'),
    ];
    return Container(
      color: _bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final active = _selectedNav == i;
                return GestureDetector(
                  onTap: () {
                    if (i == 0) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                    } else if (i == 1) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoadmapScreen()));
                    }
                    setState(() => _selectedNav = i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].icon, color: active ? Colors.white : const Color(0xFF666666), size: 24),
                        if (items[i].label.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(items[i].label, style: TextStyle(color: active ? Colors.white : const Color(0xFF666666), fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  final DateTime time;
  final Map<String, dynamic>? roadmapPreview;
  final String? goalTitle;
  _Message({
    required this.text,
    required this.isUser,
    required this.time,
    this.roadmapPreview,
    this.goalTitle,
  });
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase : 1.0 - phase) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(opacity: 0.3 + opacity * 0.7, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
            );
          }),
        );
      },
    );
  }
}
