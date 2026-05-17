import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';
import '../services/auth_service.dart';

class AiChatbotWidget extends StatefulWidget {
  const AiChatbotWidget({super.key});

  @override
  State<AiChatbotWidget> createState() => _AiChatbotWidgetState();
}

class _AiChatbotWidgetState extends State<AiChatbotWidget>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  bool _loading = false;
  final _bot = ChatbotService();
  final _auth = AuthService();
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _loadHistory();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    await _bot.loadHistory();
    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(_bot.localHistory);
      });
      if (_messages.isEmpty) _addWelcome();
      _scrollBottom();
    }
  }

  void _addWelcome() {
    final user = _auth.currentUser;
    final name = user?.fullName.split(' ').first ?? 'there';
    _messages.add(ChatMessage(
      id: 'welcome',
      text:
          'Hi $name! 👋 I\'m your EventFlow AI Assistant. Ask me anything about events, venues, bookings, or how to use the platform!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _toggleChat() {
    setState(() => _open = !_open);
    if (_open) {
      _animCtrl.forward();
      Future.delayed(const Duration(milliseconds: 100), _scrollBottom);
    } else {
      _animCtrl.reverse();
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    _msgCtrl.clear();

    setState(() {
      _messages.add(ChatMessage(
        id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _loading = true;
    });
    _scrollBottom();

    final reply = await _bot.sendMessage(text);
    if (mounted) {
      setState(() {
        _messages.add(reply);
        _loading = false;
      });
      _scrollBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_open) _buildPanel(),
        Positioned(
          bottom: 24,
          right: 24,
          child: _buildFab(),
        ),
      ],
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      heroTag: 'ai_chatbot_fab',
      onPressed: _toggleChat,
      backgroundColor: const Color(0xFFC46A3D),
      elevation: 4,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _open
            ? const Icon(Icons.close, color: Colors.white, key: ValueKey('close'))
            : const Icon(Icons.smart_toy_outlined, color: Colors.white, key: ValueKey('bot')),
      ),
    );
  }

  Widget _buildPanel() {
    return Positioned(
      bottom: 88,
      right: 24,
      child: ScaleTransition(
        scale: _scaleAnim,
        alignment: Alignment.bottomRight,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: Container(
            width: 340,
            height: 480,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9E1D6)),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessages()),
                _buildInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFC46A3D),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EventFlow AI',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('Always here to help',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11)),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text('Online',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (_loading && i == _messages.length) {
          return _buildTyping();
        }
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFC46A3D),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFFC46A3D)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1F1A17),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFC46A3D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE9E1D6))),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE9E1D6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE9E1D6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFC46A3D)),
                ),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFC46A3D),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_anim.value - i * 0.2).clamp(0.0, 1.0);
            final opacity =
                (0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6E6258),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
