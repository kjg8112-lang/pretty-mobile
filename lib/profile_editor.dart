import 'package:flutter/material.dart';

import 'profile.dart';

/// 접속 정보 추가/편집 화면
class ProfileEditor extends StatefulWidget {
  final SshProfile? profile;
  const ProfileEditor({super.key, this.profile});

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _privateKey;
  late final TextEditingController _passphrase;
  late bool _useKey;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: (p?.port ?? 22).toString());
    _username = TextEditingController(text: p?.username ?? '');
    _password = TextEditingController(text: p?.password ?? '');
    _privateKey = TextEditingController(text: p?.privateKey ?? '');
    _passphrase = TextEditingController(text: p?.passphrase ?? '');
    _useKey = p?.useKey ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _host,
      _port,
      _username,
      _password,
      _privateKey,
      _passphrase,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final profile = SshProfile(
      id: widget.profile?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? _host.text.trim() : _name.text.trim(),
      host: _host.text.trim(),
      port: int.parse(_port.text.trim()),
      username: _username.text.trim(),
      useKey: _useKey,
      password: _useKey ? null : _password.text,
      privateKey: _useKey ? _privateKey.text : null,
      passphrase: _useKey && _passphrase.text.isNotEmpty ? _passphrase.text : null,
    );
    Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? '새 접속' : '접속 편집'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '세션 이름 (선택)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(labelText: '호스트 (IP 또는 도메인)'),
              keyboardType: TextInputType.url,
              autocorrect: false,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '호스트를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _port,
              decoration: const InputDecoration(labelText: '포트'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return (n == null || n < 1 || n > 65535) ? '1~65535 사이의 포트' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: '사용자명'),
              autocorrect: false,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '사용자명을 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('개인키(Private Key) 인증 사용'),
              value: _useKey,
              onChanged: (v) => setState(() => _useKey = v),
            ),
            if (!_useKey)
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              )
            else ...[
              TextFormField(
                controller: _privateKey,
                maxLines: 6,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '개인키 (PEM 텍스트 붙여넣기)',
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '개인키를 입력하세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passphrase,
                obscureText: true,
                decoration: const InputDecoration(labelText: '키 암호 (없으면 비워두기)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
