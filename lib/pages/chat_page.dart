import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; 

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Color kPrimary = Color(0xFF2E7D32);
  static const double kMaxWidth = 640;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  final List<_Msg> _messages = [
    _Msg.fromBot('안녕하세요! 무엇을 도와드릴까요?'),
  ];

  bool _botTyping = false;

  String? _caseId;             
  bool _caseIdInitialized = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (_caseId == null) {
      // caseId 없으면 요청을 보내도 의미가 없음
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진단 정보(caseId)가 없습니다. 먼저 진단을 진행해 주세요.')),
      );
      return;
    }

    setState(() {
      _messages.add(_Msg.fromMe(trimmed));
      _controller.clear();
      _botTyping = true;
    });

    _jumpToBottomSoon();

    try {
      final uri = Uri.parse('http://localhost:8000/chat');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'case_id': _caseId,       
          'message': trimmed,
          'answer_mode': 'brief',   // 추후 'detail'로 바꿀 수 있음
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        final botText = data['answer']?.toString() ?? '응답을 이해하지 못했어요.';

        if (!mounted) return;
        setState(() {
          _messages.add(_Msg.fromBot(botText));
          _botTyping = false;
        });
        _jumpToBottomSoon();
      } else {
        if (!mounted) return;
        setState(() {
          _messages.add(
            _Msg.fromBot('서버 오류가 발생했어요. (${response.statusCode})'),
          );
          _botTyping = false;
        });
        _jumpToBottomSoon();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg.fromBot('요청 중 오류가 발생했어요: $e'));
        _botTyping = false;
      });
      _jumpToBottomSoon();
    }
  }

  void _jumpToBottomSoon() {
    // 프레임 끝난 뒤 스크롤 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0, // reverse:true 이므로 0이 바닥
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_caseIdInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['caseId'] is String) {
        _caseId = args['caseId'] as String;
        debugPrint('ChatPage received caseId = $_caseId');
      }
      _caseIdInitialized = true;
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                // 상단 바: 홈 + 중앙 로고
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 26),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      // onPressed: () {
                      //   Navigator.pushNamedAndRemoveUntil(
                      //     context, '/result', (route) => false,
                      //   );
                      // },
                    ),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/logo_img.png',
                          height: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // 아이콘 균형용
                  ],
                ),
                const SizedBox(height: 6),

                // 추천 칩
                _SuggestionChips(
                  onPick: (q) {
                    _controller.text = q;
                    _focus.requestFocus();
                  },
                ),
                const SizedBox(height: 8),

                // 대화 영역
                Expanded(
                  child: _ChatList(
                    messages: _messages,
                    controller: _scroll,
                    botTyping: _botTyping,
                  ),
                ),

                // 입력 바
                _InputBar(
                  controller: _controller,
                  focusNode: _focus,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------------- 위젯들 ------------------------- */

class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.messages,
    required this.controller,
    required this.botTyping,
  });

  final List<_Msg> messages;
  final ScrollController controller;
  final bool botTyping;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      reverse: true, // 최신이 하단
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      itemBuilder: (context, i) {
        // reverse:true라 인덱스 뒤집기
        if (i == 0 && botTyping) {
          return const _TypingBubble();
        }
        final msg = messages[messages.length - 1 - (botTyping ? i - 1 : i)];
        return _Bubble(msg: msg);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemCount: messages.length + (botTyping ? 1 : 0),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final bg = isMe ? const Color(0xFF2E7D32) : Colors.white; // Deep Green for me
    final fg = isMe ? Colors.white : Colors.black87;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Row(
      mainAxisAlignment:
      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: align,
              children: [
                Text(msg.text, style: TextStyle(color: fg, height: 1.4, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  msg.timeLabel,
                  style: TextStyle(
                    color: fg.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value; // 0..1
              int dots = 1 + (t * 3).floor() % 3;
              return Text('AI가 생각하고 있어요' + '.' * dots,
                  style: const TextStyle(color: Colors.black87, fontSize: 15));
            },
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              decoration: const InputDecoration(
                hintText: '무엇이든 물어보세요...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
              onPressed: () => onSend(controller.text),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final items = [
      '결막염이 뭐예요?',
      '가정에서 할 수 있는 조치는?',
      '동물병원 추천해줘',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: items.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(s),
              labelStyle: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFC8E6C9), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => onPick(s),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* ------------------------- 모델 ------------------------- */

class _Msg {
  _Msg({required this.text, required this.isMe, required this.timeLabel});

  factory _Msg.fromMe(String t) =>
      _Msg(text: t, isMe: true, timeLabel: _nowLabel());
  factory _Msg.fromBot(String t) =>
      _Msg(text: t, isMe: false, timeLabel: _nowLabel());

  final String text;
  final bool isMe;
  final String timeLabel;

  static String _nowLabel() {
    final n = DateTime.now();
    final hh = n.hour.toString().padLeft(2, '0');
    final mm = n.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
    // 필요하면 날짜 구분선도 넣을 수 있어요.
  }
}
