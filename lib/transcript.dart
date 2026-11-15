/// 한 번의 "세션" = 사용자가 입력한 명령 한 줄 + 그 명령에 대한 출력
class TranscriptBlock {
  final String command;
  StringBuffer output = StringBuffer();

  TranscriptBlock(this.command);

  /// 복사용 텍스트: "$ 명령" 다음 줄부터 출력
  String get text {
    final out = output.toString().trimRight();
    return command.isEmpty ? out : '\$ $command\n$out';
  }
}

/// 터미널 입출력을 세션(블록) 단위로 기록
class Transcript {
  final List<TranscriptBlock> blocks = [TranscriptBlock('')];
  final StringBuffer _line = StringBuffer(); // 현재 입력 중인 줄
  bool _inEscape = false;

  static final _ansi = RegExp(
    r'\x1B\[[0-9;?]*[ -/]*[@-~]' // CSI 시퀀스 (색상, 커서 이동 등)
    r'|\x1B\][^\x07]*(\x07|\x1B\\)' // OSC 시퀀스 (창 제목 등)
    r'|\x1B[()][A-Za-z0-9]|\x1B[=>78]', // 기타 짧은 시퀀스
  );

  /// 사용자가 보낸 입력(키보드, 특수키, 붙여넣기)을 받아 명령 줄을 만듦
  void onInput(String data) {
    for (final c in data.split('')) {
      if (_inEscape) {
        // 방향키 등 이스케이프 시퀀스는 줄에 넣지 않음
        if (c != '[' && c != 'O' && RegExp(r'[@-~]').hasMatch(c)) {
          _inEscape = false;
        }
        continue;
      }
      if (c == '\x1b') {
        _inEscape = true;
      } else if (c == '\r' || c == '\n') {
        _submitLine();
      } else if (c == '\x7f' || c == '\b') {
        final s = _line.toString();
        if (s.isNotEmpty) {
          _line
            ..clear()
            ..write(s.substring(0, s.length - 1));
        }
      } else if (c == '\t') {
        _line.write(c);
      } else if (c.codeUnitAt(0) >= 32) {
        _line.write(c);
      }
      // 그 밖의 제어문자(Ctrl+C 등)는 줄에 넣지 않음
    }
  }

  void _submitLine() {
    final cmd = _line.toString().trim();
    // 셸이 입력 중에 에코한 명령 글자는 이전 블록 출력 끝에서 제거
    if (cmd.isNotEmpty) {
      final prev = blocks.last;
      final s = prev.output.toString();
      final idx = s.lastIndexOf(cmd);
      if (idx >= 0) {
        prev.output = StringBuffer(s.substring(0, idx));
      }
    }
    _line.clear();
    blocks.add(TranscriptBlock(cmd));
  }

  /// 원격 서버에서 받은 출력을 현재 블록에 추가 (ANSI 제거)
  void onOutput(String data) {
    final clean = data.replaceAll(_ansi, '').replaceAll('\r', '');
    blocks.last.output.write(clean);
  }

  /// 전체 기록 텍스트
  String get fullText =>
      blocks.map((b) => b.text).where((t) => t.isNotEmpty).join('\n\n');
}
