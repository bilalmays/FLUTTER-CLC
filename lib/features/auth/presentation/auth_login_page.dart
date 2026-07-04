import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:flutter/material.dart';

class AuthLoginPage extends StatefulWidget {
  const AuthLoginPage({required this.onLogin, super.key});

  final Future<void> Function(String code) onLogin;

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onLogin(_codeController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _AuthBackdrop()),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF050505),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 42,
                          offset: Offset(0, 22),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _AuthHeader(),
                          const SizedBox(height: 30),
                          TextField(
                            controller: _codeController,
                            autofocus: true,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            onChanged: (_) {
                              if (_error != null) {
                                setState(() => _error = null);
                              }
                            },
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              labelText: "CODE D'ACCES",
                              hintText: 'Code interne',
                              hintStyle: const TextStyle(color: Colors.white30),
                              filled: true,
                              fillColor: Colors.black,
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.accent,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0x1AFFFFFF),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.accent,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFFECACA),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          AppButton(
                            label: _loading ? 'Connexion...' : 'Se connecter',
                            icon: Icons.lock_open_rounded,
                            expanded: true,
                            onPressed: _loading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthLoadingPage extends StatelessWidget {
  const AuthLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _AuthBackdrop()),
            Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: const Text(
            'CL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'CAR ',
                  children: [
                    TextSpan(
                      text: 'LUXE',
                      style: TextStyle(color: AppColors.accent),
                    ),
                    TextSpan(text: ' CLEANING'),
                  ],
                ),
                style: TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Connexion CRM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.9),
          radius: 0.85,
          colors: [
            AppColors.accent.withValues(alpha: 0.16),
            const Color(0x00000000),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.95, 0.85),
            radius: 0.75,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              const Color(0x00000000),
            ],
          ),
        ),
      ),
    );
  }
}
