import 'package:flutter/material.dart';

import 'api.dart';
import 'app_language.dart';
import 'app_theme.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.api,
    required this.user,
    required this.onSignOut,
  });

  final Api api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late final TextEditingController name = TextEditingController(
    text: widget.user['name']?.toString() ?? '',
  );
  late final TextEditingController phone = TextEditingController(
    text: widget.user['phone']?.toString() ?? '',
  );
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  bool obscurePasswords = true;

  String _t(String value) => AppLanguage.text(context, value);

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (newPassword.text.isNotEmpty && newPassword.text != confirmation.text) {
      _message(_t('New passwords do not match.'));
      return;
    }
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        if (newPassword.text.isNotEmpty) ...{
          'current_password': currentPassword.text,
          'password': newPassword.text,
          'password_confirmation': confirmation.text,
        },
      };
      final response = await widget.api.put('/me', body);
      if (!mounted) return;
      Navigator.pop(context, response['user'] as Map<String, dynamic>);
    } catch (error) {
      _message(_t('$error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _signOut() async {
    Navigator.pop(context);
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t('My account'))),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDCEAF4)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 27,
                        backgroundColor: Color(0xFFFFE37A),
                        child: Icon(Icons.person_rounded, color: ink, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user['email']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _t(
                                widget.user['role'] == 'driver'
                                    ? 'Driver account'
                                    : 'Passenger account',
                              ),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _t('Full name'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _t('Phone number'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  _t('Change password'),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _t('Leave these fields empty to keep your current password.'),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                for (final field in [
                  (currentPassword, 'Current password'),
                  (newPassword, 'New password'),
                  (confirmation, 'Confirm new password'),
                ]) ...[
                  TextField(
                    controller: field.$1,
                    obscureText: obscurePasswords,
                    decoration: InputDecoration(
                      labelText: _t(field.$2),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => obscurePasswords = !obscurePasswords,
                        ),
                        icon: Icon(
                          obscurePasswords
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: busy ? null : _save,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_t('Save account')),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: busy ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(_t('Sign out')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
