import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'app_language.dart';
import 'app_theme.dart';
import 'home_screen.dart';
import 'push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotifications.initialize();
  runApp(const TaxiApp());
}

class TaxiApp extends StatefulWidget {
  const TaxiApp({super.key});
  @override
  State<TaxiApp> createState() => _TaxiAppState();
}

class _TaxiAppState extends State<TaxiApp> {
  String? token;
  Map<String, dynamic>? user;
  String? selectedRole;
  String language = 'en';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language');
    if (savedLanguage == 'my' && mounted) setState(() => language = 'my');
    final saved = prefs.getString('token');
    if (saved != null) {
      try {
        final account = await Api(saved).get('/me');
        if (mounted) {
          setState(() {
            token = saved;
            user = account;
            selectedRole = account['role'] as String?;
          });
        }
      } catch (_) {
        await prefs.remove('token');
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _signedIn(String value, Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', value);
    setState(() {
      token = value;
      user = account;
      selectedRole = account['role'] as String?;
    });
  }

  Future<void> _signOut() async {
    final api = Api(token);
    try {
      await PushNotifications.unregister(api);
      await api.post('/logout', {});
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    setState(() {
      token = null;
      user = null;
      selectedRole = null;
    });
  }

  Future<void> _changeLanguage(String value) async {
    if (value != 'en' && value != 'my') return;
    setState(() => language = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
  }

  void _updateUser(Map<String, dynamic> updated) {
    setState(() => user = updated);
  }

  @override
  Widget build(BuildContext context) => AppLanguage(
    code: language,
    onChange: _changeLanguage,
    child: MaterialApp(
      title: 'Good Day Kilo Taxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: taxiBlue,
          primary: taxiBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: taxiBlue,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD5E5F5)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: taxiYellow,
            foregroundColor: ink,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : selectedRole == null
          ? RoleChoiceScreen(
              onSelect: (role) => setState(() => selectedRole = role),
            )
          : token != null && user?['role'] == selectedRole
          ? HomeScreen(
              key: ValueKey(token),
              token: token!,
              user: user!,
              onSignOut: _signOut,
              onUserUpdated: _updateUser,
            )
          : AuthScreen(
              role: selectedRole!,
              onBack: () => setState(() => selectedRole = null),
              onSuccess: _signedIn,
            ),
    ),
  );
}

class RoleChoiceScreen extends StatelessWidget {
  const RoleChoiceScreen({super.key, required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: LanguageToggle(),
                ),
                Center(
                  child: Image.asset(
                    'assets/logo-stacked.png',
                    width: 205,
                    height: 154,
                    fit: BoxFit.contain,
                    semanticLabel: 'Good Day Kilo Taxi logo',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLanguage.text(context, 'How will you use the app today?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                _roleCard(
                  'passenger',
                  AppLanguage.text(context, 'I am a passenger'),
                  AppLanguage.text(
                    context,
                    'Find a ride and see the fare before booking',
                  ),
                  Icons.person_rounded,
                ),
                const SizedBox(height: 12),
                _roleCard(
                  'driver',
                  AppLanguage.text(context, 'I am a driver'),
                  AppLanguage.text(
                    context,
                    'Go online and accept nearby requests',
                  ),
                  Icons.local_taxi_rounded,
                ),
                const SizedBox(height: 22),
                Text(
                  AppLanguage.text(
                    context,
                    'Yangon pilot · Cash rides in Myanmar kyats',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _roleCard(String role, String title, String detail, IconData icon) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => onSelect(role),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD9E9F8)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: role == 'passenger'
                      ? taxiYellow
                      : const Color(0xFFE4F3FF),
                  child: Icon(icon, color: ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: muted),
              ],
            ),
          ),
        ),
      );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.role,
    required this.onBack,
    required this.onSuccess,
  });
  final String role;
  final VoidCallback onBack;
  final Future<void> Function(String, Map<String, dynamic>) onSuccess;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final plate = TextEditingController();
  bool register = false;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      final result = register
          ? await Api(null).post('/register', {
              'name': name.text.trim(),
              'email': email.text.trim(),
              'phone': phone.text.trim(),
              'password': password.text,
              'role': widget.role,
              if (widget.role == 'driver') 'vehicle_plate': plate.text.trim(),
            })
          : await Api(null).post('/login', {
              'email': email.text.trim(),
              'password': password.text,
            });
      if (!mounted) return;
      final account = result['user'] as Map<String, dynamic>;
      if (account['role'] != widget.role) {
        final message = AppLanguage.text(
          context,
          'This account is a ${account['role']}. Choose that role to sign in.',
        );
        try {
          await Api(result['token'] as String).post('/logout', {});
        } catch (_) {}
        throw ApiException(message);
      }
      await widget.onSuccess(result['token'] as String, account);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLanguage.text(context, '$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(AppLanguage.text(context, 'Change role')),
                ),
                const Align(
                  alignment: Alignment.centerRight,
                  child: LanguageToggle(),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Image.asset(
                    'assets/logo-stacked.png',
                    width: 180,
                    height: 135,
                    fit: BoxFit.contain,
                    semanticLabel: 'Good Day Kilo Taxi logo',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLanguage.text(
                    context,
                    register
                        ? 'Create your ${widget.role} account.'
                        : 'Sign in as a ${widget.role}.',
                  ),
                  style: const TextStyle(color: muted, fontSize: 16),
                ),
                const SizedBox(height: 26),
                if (register) ...[
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: AppLanguage.text(context, 'Full name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLanguage.text(context, 'Email'),
                  ),
                ),
                const SizedBox(height: 12),
                if (register) ...[
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: AppLanguage.text(context, 'Phone number'),
                      hintText: '09 123 456 789',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppLanguage.text(context, 'Password'),
                  ),
                ),
                if (register && widget.role == 'driver') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: plate,
                    decoration: InputDecoration(
                      labelText: AppLanguage.text(context, 'Vehicle plate'),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          AppLanguage.text(
                            context,
                            register ? 'Create account' : 'Sign in',
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => register = !register),
                    child: Text(
                      AppLanguage.text(
                        context,
                        register
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
