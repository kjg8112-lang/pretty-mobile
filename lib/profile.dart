import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 하나의 SSH 접속 정보 (PuTTY의 "Saved Session"에 해당)
class SshProfile {
  final String id;
  String name;
  String host;
  int port;
  String username;
  String? password;
  bool useKey;
  String? privateKey; // PEM 형식 개인키 텍스트
  String? passphrase;

  SshProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.useKey = false,
    this.privateKey,
    this.passphrase,
  });

  String get address => '$username@$host:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'useKey': useKey,
        'privateKey': privateKey,
        'passphrase': passphrase,
      };

  factory SshProfile.fromJson(Map<String, dynamic> j) => SshProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        host: j['host'] as String,
        port: (j['port'] as num?)?.toInt() ?? 22,
        username: j['username'] as String,
        password: j['password'] as String?,
        useKey: j['useKey'] as bool? ?? false,
        privateKey: j['privateKey'] as String?,
        passphrase: j['passphrase'] as String?,
      );
}

/// 접속 정보 목록을 기기의 보안 저장소(Android Keystore / iOS Keychain)에 보관
class ProfileStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'putty_profiles_v1';

  static Future<List<SshProfile>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SshProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<SshProfile> profiles) {
    final raw = jsonEncode(profiles.map((p) => p.toJson()).toList());
    return _storage.write(key: _key, value: raw);
  }
}
