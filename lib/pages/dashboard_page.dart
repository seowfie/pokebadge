import 'package:flutter/material.dart';
import 'add_monster_page.dart';
import 'display_rankings_page.dart';
import 'map_page.dart';
import 'catch_monster_page.dart';
import 'edit_monsters_page.dart';
import 'delete_monster_page.dart';
import 'manage_users_page.dart';
import 'login_page.dart';
import 'my_monsters_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monster Control Center'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Monster Admin"),
              accountEmail: const Text("monster@app.local"),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.catching_pokemon, size: 32),
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Dashboard"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ExpansionTile(
              leading: const Icon(Icons.edit_note),
              title: const Text("Manage Monsters"),
              children: [
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text("Add Monster"),
                  onTap: () {
                    Navigator.pop(context);
                    _open(context, const AddMonsterPage());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text("Edit Monsters"),
                  onTap: () {
                    Navigator.pop(context);
                    _open(context, const EditMonstersPage());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text("Delete Monsters"),
                  onTap: () {
                    Navigator.pop(context);
                    _open(context, const DeleteMonsterPage());
                  },
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text("Manage Account"),
              onTap: () {
                Navigator.pop(context);
                _open(context, const ManageUsersPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text("View Top Monster Hunters"),
              onTap: () {
                Navigator.pop(context);
                _open(context, const MonsterListPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.catching_pokemon),
              title: const Text("Catch Monsters"),
              onTap: () {
                Navigator.pop(context);
                _open(context, const CatchMonsterPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.pets),
              title: const Text("My Caught Monsters"),
              onTap: () {
                Navigator.pop(context);
                _open(context, const MyMonstersPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text("Show Monster Map"),
              onTap: () {
                Navigator.pop(context);
                _open(context, const MapPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Monster Control Center",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Manage monster records, catch monsters, and view monster areas.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _DashboardCard(
                    icon: Icons.add_circle,
                    label: "Add Monsters",
                    onTap: () => _open(context, const AddMonsterPage()),
                  ),
                  _DashboardCard(
                    icon: Icons.catching_pokemon,
                    label: "Catch Monsters",
                    onTap: () => _open(context, const CatchMonsterPage()),
                  ),
                  _DashboardCard(
                    icon: Icons.pets,
                    label: "My Caught Monsters",
                    onTap: () => _open(context, const MyMonstersPage()),
                  ),
                  _DashboardCard(
                    icon: Icons.edit,
                    label: "Edit Monsters",
                    onTap: () => _open(context, const EditMonstersPage()),
                  ),
                  _DashboardCard(
                    icon: Icons.delete_forever,
                    label: "Delete Monsters",
                    onTap: () => _open(context, const DeleteMonsterPage()),
                  ),
                  _DashboardCard(
                    icon: Icons.list_alt,
                    label: "View Top Monster Hunters",
                    onTap: () => _open(context, const MonsterListPage()),
                  ),
                  _DashboardCard(
                    icon: Icons.manage_accounts,
                    label: "Manage Account",
                    onTap: () => _open(context, const ManageUsersPage()),
                  ),
                  _DashboardCard(
                    icon: Icons.map,
                    label: "Show Monster Map",
                    onTap: () => _open(context, const MapPage()),
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

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9C27B0),
            Color(0xFFFF4081),
            Color(0xFF00E5FF),
            Color(0xFFFFD740),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Material(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
