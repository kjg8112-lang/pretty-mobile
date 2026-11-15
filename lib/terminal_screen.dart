import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'profile.dart';

/// SSH 접속 후 터미널 화면
class TerminalScreen extends StatefulWidget {
  final SshProfile profile;
  const TerminalScreen({super.key, required this.profile});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  SSHClient? _client;
  SSHSession? _session;
  String _status = '연결 중...';
  bool _connected = false;

  @override
  void initState() {
    super.initState();

    // 키보드 입력 -> SSH 세션으로 전송
    _terminal.onOutput = (data) {
      _session?.stdin.add(Uint8List.fromList(utf8.encode(data)));
    };

    // 화면 크기 변경 -> 원격 PTY 크기 동기화
    _terminal.onResize = (w, h, pw, ph) {
      _session?.resizeTerminal(w, h, pw, ph);
    };

    _connect();
  }

  Future<void> _connect() async {
    final p = widget.profile;
    try {
      _terminal.write('${p.host}:${p.port} 에 연결 중...\r\n');
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
          .listen(_terminal.write);
      _session!.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(_terminal.write);

      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = p.address;
      });

      await _session!.done;
      _onDisconnected('연결이 종료되었습니다.');
    } catch (e) {
      _terminal.write('\r\n[오류] $e\r\n');
      _onDisconnected('연결 실패');
    }
  }

  void _onDisconnected(String message) {
    _terminal.write('\r\n[$message]\r\n');
    if (!mounted) return;
    setState(() {
      _connected = false;
      _status = message;
    });
  }

  /// 모바일 키보드에 없는 특수키를 보내는 버튼
  void _sendKey(String sequence) {
    _session?.stdin.add(Uint8List.fromList(utf8.encode(sequence)));
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
              child: TerminalView(
                _terminal,
                autofocus: true,
                textStyle: const TerminalStyle(fontSize: 14),
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
