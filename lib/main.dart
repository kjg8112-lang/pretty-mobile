import 'package:flutter/material.dart';

import 'profile.dart';
import 'profile_editor.dart';
import 'terminal_screen.dart';

void main() {
  runApp(const PuttyMobileApp());
}

class PuttyMobileApp extends StatelessWidget {
  const PuttyMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuTTY Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SshProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final profiles = await ProfileStore.load();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _addOrEdit([SshProfile? existing]) async {
    final result = await Navigator.push<SshProfile>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditor(profile: existing)),
    );
    if (result == null || !mounted) return;
    setState(() {
      final i = _profiles.indexWhere((p) => p.id == result.id);
      if (i >= 0) {
        _profiles[i] = result;
      } else {
        _profiles.add(result);
      }
    });
    await ProfileStore.save(_profiles);
  }

  Future<void> _delete(SshProfile profile) async {
    setState(() => _profiles.removeWhere((p) => p.id == profile.id));
    await ProfileStore.save(_profiles);
  }

  void _connect(SshProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TerminalScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PuTTY Mobile')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(
                  child: Text('오른쪽 아래 + 버튼으로 접속 정보를 추가하세요.'),
                )
              : ListView.separated(
                  itemCount: _profiles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = _profiles[index];
                    return ListTile(
                      leading: const Icon(Icons.terminal),
                      title: Text(p.name),
                      subtitle: Text(p.address),
                      onTap: () => _connect(p),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _addOrEdit(p);
                          if (value == 'delete') _delete(p);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('편집')),
                          PopupMenuItem(value: 'delete', child: Text('삭제')),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
