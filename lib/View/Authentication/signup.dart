import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show BoxDecoration, BorderRadius, Colors, BoxShadow, LinearGradient, Offset;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:taskova_drivers/Controller/Theme/theme.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Authentication/login.dart';
import 'package:taskova_drivers/View/Authentication/otp.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:lottie/lottie.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  late final AppLanguage _appLanguage;

  static const Color _darkmode = Color.fromARGB(255, 46, 15, 149);
  static const Color _darkGradientEnd = Color.fromARGB(255, 43, 33, 99);

  @override
  void initState() {
    super.initState();
    _appLanguage = context.read<AppLanguage>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearFormState();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _clearFormState() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPassController.clear();
    _formKey.currentState?.reset();
    setState(() {
      _errorMessage = '';
      _obscurePassword = true;
      _obscureConfirmPassword = true;
    });
  }

  Future<void> _registerUser() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.registerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "email": _emailController.text.trim(),
              "password": _passwordController.text,
              "role": "DRIVER",
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        if (response.statusCode == 201) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder:
                  (context) =>
                      OtpVerification(email: _emailController.text.trim()),
            ),
          );
        } else {
          final responseBody =
              jsonDecode(response.body) as Map<String, dynamic>;
          setState(() {
            _errorMessage =
                responseBody['detail']?.toString() ??
                _appLanguage.get('registration_failed');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _appLanguage.get('connection_error');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _navigateToLogin() {
    _clearFormState();
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (context) => const LoginPage(),
        settings: const RouteSettings(name: '/login'),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _appLanguage.get('enter_email');
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return _appLanguage.get('email_required');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _appLanguage.get('enter_password');
    }
    if (value.length < 6) {
      return _appLanguage.get('password_length_error');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _appLanguage.get('signup_confrm_password');
    }
    if (value != _passwordController.text) {
      return _appLanguage.get('passwords_do_not_match');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            key: const ValueKey('registration_container'),
            decoration:
                themeProvider.isDarkMode
                    ? const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_darkmode, _darkGradientEnd],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    )
                    : const BoxDecoration(color: Colors.white),
            child: SafeArea(
              child: SingleChildScrollView(
                key: const ValueKey('registration_scroll'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        20,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LogoSection(isDarkMode: themeProvider.isDarkMode),
                        const SizedBox(height: 40),
                        _TitleSection(
                          appLanguage: _appLanguage,
                          isDarkMode: themeProvider.isDarkMode,
                          onLoginTap: _navigateToLogin,
                        ),
                        const SizedBox(height: 24),
                        _InputField(
                          key: const ValueKey('registration_email_field'),
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          placeholder: _appLanguage.get('Email address'),
                          icon: CupertinoIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          isDarkMode: themeProvider.isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _InputField(
                          key: const ValueKey('registration_password_field'),
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          placeholder: _appLanguage.get('Create password'),
                          icon: CupertinoIcons.lock,
                          obscureText: _obscurePassword,
                          showVisibilityToggle: true,
                          onVisibilityToggle: _togglePasswordVisibility,
                          validator: _validatePassword,
                          isDarkMode: themeProvider.isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _InputField(
                          key: const ValueKey(
                            'registration_confirm_password_field',
                          ),
                          controller: _confirmPassController,
                          focusNode: _confirmPasswordFocusNode,
                          placeholder: _appLanguage.get('confirm_password'),
                          icon: CupertinoIcons.lock_shield,
                          obscureText: _obscureConfirmPassword,
                          showVisibilityToggle: true,
                          onVisibilityToggle: _toggleConfirmPasswordVisibility,
                          validator: _validateConfirmPassword,
                          isDarkMode: themeProvider.isDarkMode,
                        ),
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _ErrorMessage(message: _errorMessage),
                        ],
                        const SizedBox(height: 24),
                        _RegisterButton(
                          isLoading: _isLoading,
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _registerUser();
                            }
                          },
                          appLanguage: _appLanguage,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  final bool isDarkMode;

  const _LogoSection({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 180,
        width: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 140,
              child: Lottie.asset(
                'assets/lottietaskova.json',
                fit: BoxFit.contain,
                repeat: true,
                frameRate: FrameRate(30),
              ),
            ),
            Positioned(
              bottom: 0,
              child: SizedBox(
                height: 40,
                width: 80,
                child: Image.asset(
                  isDarkMode
                      ? 'assets/white-logo.png'
                      : 'assets/taskova-logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  final AppLanguage appLanguage;
  final bool isDarkMode;
  final VoidCallback onLoginTap;

  const _TitleSection({
    required this.appLanguage,
    required this.isDarkMode,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          appLanguage.get('Join Taskova'),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              appLanguage.get('already_have_account'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color:
                    isDarkMode
                        ? CupertinoColors.systemGrey2
                        : CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onLoginTap,
              child: Text(
                appLanguage.get('login'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final bool showVisibilityToggle;
  final VoidCallback? onVisibilityToggle;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool isDarkMode;

  const _InputField({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.icon,
    required this.isDarkMode,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.onVisibilityToggle,
    this.validator,
    this.keyboardType = TextInputType.text,
  }) : super(key: key);

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            widget.isDarkMode
                ? CupertinoColors.darkBackgroundGray
                : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _hasError
                  ? Colors.red
                  : _isFocused
                  ? Colors.blue
                  : widget.isDarkMode
                  ? CupertinoColors.systemGrey4
                  : CupertinoColors.systemGrey5,
          width: _isFocused ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _isFocused
                    ? Colors.blue.withOpacity(0.1)
                    : CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: _isFocused ? 8 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              widget.icon,
              size: 18, // Reduced icon size to match smaller text
              color:
                  _isFocused
                      ? Colors.blue
                      : widget.isDarkMode
                      ? CupertinoColors.systemGrey2
                      : CupertinoColors.systemGrey,
            ),
          ),
          Expanded(
            child: CupertinoTextFormFieldRow(
              controller: widget.controller,
              focusNode: widget.focusNode,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              placeholder: widget.placeholder,
              placeholderStyle: GoogleFonts.poppins(
                color:
                    widget.isDarkMode
                        ? CupertinoColors.systemGrey2
                        : CupertinoColors.systemGrey,
                fontSize: 12, // Reduced font size
              ),
              style: GoogleFonts.poppins(
                color:
                    widget.isDarkMode
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                fontSize: 12, // Reduced font size
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ), // Adjusted padding
              decoration: const BoxDecoration(),
              validator: (value) {
                final result = widget.validator?.call(value);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _hasError = result != null;
                    });
                  }
                });
                return result;
              },
            ),
          ),
          if (widget.showVisibilityToggle)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: widget.onVisibilityToggle,
                child: Icon(
                  widget.obscureText
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  color:
                      widget.isDarkMode
                          ? CupertinoColors.systemGrey2
                          : CupertinoColors.systemGrey,
                  size: 16, // Reduced visibility toggle icon size
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Colors.red,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final AppLanguage appLanguage;

  const _RegisterButton({
    required this.isLoading,
    required this.onPressed,
    required this.appLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, // Reduced button height to match smaller font
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Color(0xFF8A84FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(12),
        onPressed: isLoading ? null : onPressed,
        child:
            isLoading
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : Text(
                  appLanguage.get('create_account').toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14, // Reduced font size
                  ),
                ),
      ),
    );
  }
}