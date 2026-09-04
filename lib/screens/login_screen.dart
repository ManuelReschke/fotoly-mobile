import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_scope.dart';
import '../services/auth_service.dart';
import '../services/pixelfox_api_client.dart';
import '../widgets/pixelfox_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureApiKey = true;
  bool _showApiKey = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loginPassword() async {
    final auth = context.read<AuthService>();
    final ok = await auth.loginWithPassword(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    _showError(auth, ok);
  }

  Future<void> _loginApiKey() async {
    final auth = context.read<AuthService>();
    final ok = await auth.loginWithApiKey(_apiKeyController.text);
    if (!mounted) return;
    _showError(auth, ok);
  }

  Future<void> _loginProvider(AuthProviderInfo provider) async {
    final auth = context.read<AuthService>();
    final ok = await auth.loginWithProvider(provider.id);
    if (!mounted) return;
    _showError(auth, ok);
  }

  void _showError(AuthService auth, bool ok) {
    if (!ok && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: PixelfoxLogo(size: 88)),
                  const SizedBox(height: 16),
                  Text(
                    'PIXELFOX.CC',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    enabled: !auth.loading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: s.emailLabel,
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !auth.loading,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: s.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _loginPassword(),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.error!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.loading ? null : _loginPassword,
                    child: auth.loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(s.signIn),
                  ),
                  if (auth.providers.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(s.orDivider),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final provider in auth.providers) ...[
                      OutlinedButton.icon(
                        onPressed: auth.loading
                            ? null
                            : () => _loginProvider(provider),
                        icon: Icon(_providerIcon(provider.id)),
                        label: Text(s.signInWith(provider.name)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: auth.loading
                        ? null
                        : () => setState(() => _showApiKey = !_showApiKey),
                    child: Text(s.advancedApiKey),
                  ),
                  if (_showApiKey) ...[
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      enabled: !auth.loading,
                      decoration: InputDecoration(
                        labelText: s.apiKeyLabel,
                        hintText: s.apiKeyHint,
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loginApiKey(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: auth.loading ? null : _loginApiKey,
                      child: Text(s.connectToPixelfox),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    s.loginFooterNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
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

  IconData _providerIcon(String id) {
    switch (id) {
      case 'google':
        return Icons.g_mobiledata;
      case 'discord':
        return Icons.discord;
      case 'facebook':
        return Icons.facebook;
      case 'patreon':
        return Icons.favorite_outline;
      default:
        return Icons.login;
    }
  }
}
