import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PowerControlApp());
}

class PowerControlApp extends StatelessWidget {
  const PowerControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Power Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),

      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('power_control/actions');

  String _status = '';
  bool _isAdmin = false;
  bool _isOwner = false;
  bool _isAccessibility = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndPromptAdmin();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAdminStatus();
    }
  }

  Future<void> _initAndPromptAdmin() async {
    await _refreshAdminStatus();
    if (!_isAdmin) {
      await _requestAdmin();
    }
  }

  Future<void> _refreshAdminStatus() async {
    try {
      final bool isAdmin =
          await _channel.invokeMethod('isDeviceAdmin') ?? false;
      final bool isOwner =
          await _channel.invokeMethod('isDeviceOwner') ?? false;
      final bool isAccessibility =
          await _channel.invokeMethod('isAccessibilityEnabled') ?? false;
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isOwner = isOwner;
          _isAccessibility = isAccessibility;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _status = 'Check failed: ${e.message}');
      }
    }
  }

  Future<void> _requestAdmin() async {
    try {
      await _channel.invokeMethod('requestDeviceAdmin');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _status = 'Request failed: ${e.message}');
      }
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _status = 'Failed to open settings: ${e.message}');
      }
    }
  }

  Future<void> _lockScreen() async {
    try {
      await _channel.invokeMethod('lockScreen');
      setState(() => _status = 'Screen locked.');
    } on PlatformException catch (e) {
      setState(() => _status = 'Lock failed: ${e.message}');
    }
  }

  Future<void> _restart() async {
    try {
      await _channel.invokeMethod('restart');
      setState(() => _status = 'Restart command sent.');
    } on PlatformException catch (e) {
      setState(() => _status = '${e.message}');
    }
  }

  Future<void> _shutdown() async {
    try {
      await _channel.invokeMethod('shutdown');
      setState(() => _status = 'Power Off command sent.');
    } on PlatformException catch (e) {
      setState(() => _status = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final successColor = isDark ? Colors.greenAccent : Colors.green.shade700;
    final warningColor = isDark ? Colors.orangeAccent : Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(title: const Text('Power Control'), centerTitle: true),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  (_isAdmin || _isAccessibility)
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 64,
                  color: (_isAdmin || _isAccessibility)
                      ? successColor
                      : warningColor,
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAccessibility
                          ? 'Power Menu Service: Enabled ✅'
                          : 'Power Menu Service: Not Enabled ⚠️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _isAccessibility ? successColor : warningColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isAdmin
                          ? 'Device Admin (Lock): Enabled ✅'
                          : 'Device Admin (Lock): Not Enabled ⚠️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _isAdmin ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: _isAdmin ? successColor : warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_isAccessibility)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.teal
                            : Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openAccessibilitySettings,
                      icon: const Icon(Icons.accessibility_new),
                      label: const Text('Enable Power Service in Settings'),
                    ),
                  ),
                if (!_isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: _requestAdmin,
                      icon: const Icon(Icons.security),
                      label: const Text('Enable Device Admin (Lock)'),
                    ),
                  ),
                const SizedBox(height: 4),
                if (!_isAccessibility)
                  Text(
                    'Settings > Accessibility > Power Control > ON',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                const Divider(height: 32),
                _ActionButton(
                  title: 'Lock Screen',
                  label: 'Lock Screen',
                  icon: Icons.lock,
                  color: Colors.indigo,
                  onPressed: _lockScreen,
                ),
                _ActionButton(
                  title: 'Restart',
                  label: 'Restart',
                  icon: Icons.restart_alt,
                  color: Colors.orange,
                  onPressed: _restart,
                ),
                _ActionButton(
                  title: 'Power Off',
                  label: 'Power Off',
                  icon: Icons.power_settings_new,
                  color: Colors.redAccent,
                  onPressed: _shutdown,
                ),
                const SizedBox(height: 24),
                if (_status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? Colors.amberAccent
                            : Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
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

class _ActionButton extends StatelessWidget {
  final String label;
  final String? title;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final labelColor = isDark ? Colors.white : color;
    final iconColor = isDark ? Colors.white : color;

    final badgeBackground = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : color.withValues(alpha: 0.12);
    final badgeBorder = isDark
        ? Colors.white.withValues(alpha: 0.20)
        : color.withValues(alpha: 0.25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          const SizedBox(height: 16),
          Text(
            title!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: 300,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.35),
                            color.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.90),
                            color.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.70),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.95),
                    width: isDark ? 1.2 : 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    splashColor: color.withValues(alpha: isDark ? 0.35 : 0.18),
                    highlightColor: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.08),
                    onTap: onPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: badgeBackground,
                              border: Border.all(
                                color: badgeBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Icon(icon, size: 20, color: iconColor),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
