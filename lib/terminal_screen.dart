import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'history_screen.dart';
import 'profile.dart';
import 'transcript.dart';

/// SSH 접속 후 터미널 화면
class TerminalScreen extends StatefulWidget {
  final SshProfile profile;
  const TerminalScreen({super.key, required this.profile});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  final Transcript _transcript = Transcript();
  SSHClient? _client;
  SSHSession? _session;
  String _status = '연결 중...';
  bool _connected = false;

  @override
  void initState() {
    super.initState();

    // 키보드 입력 -> SSH 세션으로 전송
    _terminal.onOutput = _send;

    // 화면 크기 변경 -> 원격 PTY 크기 동기화
    _terminal.onResize = (w, h, pw, ph) {
      _session?.resizeTerminal(w, h, pw, ph);
    };

    _connect();
  }

  /// 모든 입력의 단일 출구: 기록에 남기고 원격으로 전송
  void _send(String data) {
    _transcript.onInput(data);
    _session?.stdin.add(Uint8List.fromList(utf8.encode(data)));
  }

  /// 원격 출력: 터미널 화면과 기록 양쪽에 반영
  void _onRemoteText(String text) {
    _terminal.write(text);
    _transcript.onOutput(text);
  }

  Future<void> _connect() async {
    final p = widget.profile;
    try {
      _onRemoteText('${p.host}:${p.port} 에 연결 중...\r\n');
      final socket = await SSHSocket.connect(
        p.host,
        p.port,
        timeout: const Duration(seconds: 15),
      );

      List<SSHKeyPair>? identities;
      if (p.useKey && (p.privateKey?.trim().isNotEmpty ?? false)) {
        identities = SSHKeyPair.fromPem(p.privateKey!, p.passphrase);
      }

      _client = SSHClient(
        socket,
        username: p.username,
        identities: identities,
        onPasswordRequest: () => p.password ?? '',
        // TODO: 호스트 키 검증(known_hosts 방식) 추가 권장. 현재는 모든 키를 수락합니다.
        onVerifyHostKey: (type, fingerprint) => true,
      );

      await _client!.authenticated;

      _session = await _client!.shell(
        pty: const SSHPtyConfig(width: 80, height: 24),
      );
      _session!.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(_onRemoteText);
      _session!.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(_onRemoteText);

      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = p.address;
      });

      await _session!.done;
      _onDisconnected('연결이 종료되었습니다.');
    } catch (e) {
      _onRemoteText('\r\n[오류] $e\r\n');
      _onDisconnected('연결 실패');
    }
  }

  void _onDisconnected(String message) {
    _onRemoteText('\r\n[$message]\r\n');
    if (!mounted) return;
    setState(() {
      _connected = false;
      _status = message;
    });
  }

  /// 모바일 키보드에 없는 특수키를 보내는 버튼
  void _sendKey(String sequence) {
    if (_connected) _send(sequence);
  }

  /// 클립보드 내용을 원격 셸에 붙여넣기 (줄바꿈은 Enter로 변환)
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _toast('클립보드가 비어 있습니다.');
      return;
    }
    if (_connected) _send(text.replaceAll('\r\n', '\r').replaceAll('\n', '\r'));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  /// 터미널 길게 누름: 붙여넣기 / 전체 복사 / 세션 기록 메뉴
  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('붙여넣기'),
              onTap: () {
                Navigator.pop(ctx);
                _paste();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text('전체 기록 복사'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: _transcript.fullText));
                _toast('전체 기록을 복사했습니다.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('세션별 보기 / 복사'),
              onTap: () {
                Navigator.pop(ctx);
                _openHistory();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryScreen(transcript: _transcript)),
    );
  }

  @override
  void dispose() {
    _session?.close();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = <(String, String)>[
      ('Esc', '\x1b'),
      ('Tab', '\t'),
      ('Ctrl+C', '\x03'),
      ('Ctrl+D', '\x04'),
      ('Ctrl+Z', '\x1a'),
      ('Ctrl+L', '\x0c'),
      ('↑', '\x1b[A'),
      ('↓', '\x1b[B'),
      ('←', '\x1b[D'),
      ('→', '\x1b[C'),
      ('|', '|'),
      ('~', '~'),
      ('/', '/'),
      ('-', '-'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_status, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '세션 기록',
            icon: const Icon(Icons.history),
            onPressed: _openHistory,
          ),
          if (!_connected)
            IconButton(
              tooltip: '재연결',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _client?.close();
                setState(() => _status = '재연결 중...');
                _connect();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // 길게 누르면 붙여넣기/복사 메뉴
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: _showMenu,
                child: TerminalView(
                  _terminal,
                  autofocus: true,
                  textStyle: const TerminalStyle(fontSize: 14),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: keys.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final (label, seq) = keys[i];
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: _connected ? () => _sendKey(seq) : null,
                    child: Text(label),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
