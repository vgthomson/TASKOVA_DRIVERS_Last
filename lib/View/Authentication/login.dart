import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Colors;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskova_drivers/Controller/Theme/theme.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/Model/apple_sign_in.dart';
import 'package:taskova_drivers/View/Authentication/forgot_password.dart';
import 'package:taskova_drivers/View/Authentication/otp.dart';
import 'package:taskova_drivers/View/Authentication/signup.dart';
import 'package:taskova_drivers/View/BottomNavigation/bottomnavigation.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';
import 'package:taskova_drivers/View/profile.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AppLanguage appLanguage;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AppleAuthService _appleAuthService = AppleAuthService();

  // Define blue theme colors
  final Color primaryBlue = Colors.blue;
  final Color darkmode = const Color(0xFF2F197D);
  final Color lightBlue = const Color(0xFF8A84FF);
  final Color backgroundColor = const Color(0xFFF8F7FF);

  @override
  void initState() {
    super.initState();
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
    checkTokenAndNavigate();
  }

  Future<void> _initializeNotificationService() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear any previous notification timestamps on fresh login
    await prefs.remove('last_notification_check');
  }

  Future<void> checkTokenAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => const MainWrapper()),
      );
    }
  }

  Future<void> _handleAppleLogin(BuildContext context, Function(bool) setLoadingState) async {
  final appleAuthService = AppleAuthService();
  await appleAuthService.signInWithApple(
    context: context,
    showSuccessDialog: (String message, BuildContext ctx) => _showSuccessDialog(message),
    showErrorDialog: (String message, BuildContext ctx) => _showErrorDialog(message),
    setLoadingState: setLoadingState,
  );
}

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> saveTokens(
    String accessToken,
    String refreshToken,
    String email,
    String name,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.light),
        child: CupertinoAlertDialog(
          title: const Text('Wrong Credentials'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.light),
        child: CupertinoAlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    try {
      setState(() => _isGoogleLoading = true); // Start loading
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isGoogleLoading = false); // Stop loading if cancelled
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.googleLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': account.email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String accessToken = data['tokens']['access'] ?? "";
        String refreshToken = data['tokens']['refresh'] ?? "";
        String name = data['name'] ?? "";
        String email = account.email;

        await saveTokens(accessToken, refreshToken, email, name);
        final profileResponse = await http.get(
          Uri.parse(ApiConfig.profileStatusUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        );
        if (profileResponse.statusCode == 200) {
          final profileData = jsonDecode(profileResponse.body);
          bool isProfileComplete = profileData['is_profile_complete'] ?? false;
          if (!isProfileComplete) {
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (context) => ProfileRegistrationPage()),
              (Route<dynamic> route) => false,
            );
          } else {
            _showSuccessDialog("Login successful!");
            await _initializeNotificationService();

            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(builder: (context) => const MainWrapper()),
              (Route<dynamic> route) => false,
            );
          }
        } else {
          _showErrorDialog("Could not verify profile status");
        }
      } else {
        _showErrorDialog(data['error'] ?? 'Google login failed');
      }
    } catch (e) {
      _showErrorDialog('Something went wrong during Google Sign-In');
    } finally {
      setState(() => _isGoogleLoading = false); // Stop loading
    }
  }

  Future<void> loginUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse(ApiConfig.loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _emailController.text,
            'password': _passwordController.text,
            'remember_me': true,
          }),
        );

        if (response.statusCode == 200) {
          Map<String, dynamic> responseData = jsonDecode(response.body);
          String accessToken = responseData['access'] ?? "";
          String refreshToken = responseData['refresh'] ?? "";
          String name = responseData['name'] ?? "";

          await saveTokens(
            accessToken,
            refreshToken,
            _emailController.text,
            name,
          );

          final profileResponse = await http.get(
            Uri.parse(ApiConfig.profileStatusUrl),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          );

          if (profileResponse.statusCode == 200) {
            final profileData = jsonDecode(profileResponse.body);
            bool isProfileComplete = profileData['is_profile_complete'] ?? false;
            bool isEmailVerified = profileData['is_email_verified'] ?? false;

            if (!isEmailVerified) {
              _showInfoDialog("Please verify your email");
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => OtpVerification(email: _emailController.text),
                ),
              );
            } else {
              _showSuccessDialog("Login successful!");
              await _initializeNotificationService();

              Navigator.pushAndRemoveUntil(
                context,
                CupertinoPageRoute(
                  builder: (context) => isProfileComplete ? const MainWrapper() : ProfileRegistrationPage(),
                ),
                (Route<dynamic> route) => false,
              );
            }
          } else {
            _showErrorDialog("Could not verify profile status");
          }
        } else {
          final responseData = jsonDecode(response.body);
          String errorMessage = responseData['detail'] ?? "Login failed. Please check your credentials.";
          _showErrorDialog(errorMessage);
        }
      } catch (e) {
        _showErrorDialog("Connection error. Please check your internet connection.");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Define gradient for dark mode
        final backgroundDecoration = themeProvider.isDarkMode
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    darkmode, // Starting color: 0xFF2F197D
                    const Color.fromARGB(255, 43, 33, 99), // Ending color for gradient
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : BoxDecoration(color: Colors.white);

        return CupertinoPageScaffold(
          backgroundColor: Colors.transparent, // Required for gradient to work
          child: Container(
            decoration: backgroundDecoration, // Apply gradient or solid color
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo Section
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: SizedBox(
                              height: 200,
                              width: 120,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Positioned Lottie at the bottom (under the image)
                                  Positioned(
                                    top: 0,
                                    child: SizedBox(
                                      height: 200,
                                      width: 120,
                                      child: Lottie.asset(
                                        'assets/lottietaskova.json',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  // Image positioned at the top
                                  Positioned(
                                    bottom: 0,
                                    child: SizedBox(
                                      height: 110, // Increased size for the Lottie
                                      width: 100,
                                      child: Image.asset(
                                        themeProvider.isDarkMode ? 'assets/white-logo.png' : 'assets/taskova-logo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 62),

                        // Title
                        Text(
                          appLanguage.get('login'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              appLanguage.get('dont_have_account'),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: themeProvider.isDarkMode ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => const Registration(),
                                  ),
                                );
                              },
                              child: Text(
                                appLanguage.get('sign_up'),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Email Field
                        Container(
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeProvider.isDarkMode ? CupertinoColors.systemGrey4 : CupertinoColors.systemGrey5,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemGrey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12), // Added for spacing
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.mail,
                                size: 20,
                                color: CupertinoColors.systemGrey,
                              ),
                              const SizedBox(width: 8), // Spacing between icon and text field
                              Expanded(
                                child: CupertinoTextFormFieldRow(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  placeholder: appLanguage.get('email_hint'),
                                  placeholderStyle: GoogleFonts.poppins(
                                    color: themeProvider.isDarkMode ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey,
                                    fontSize: 14,
                                  ),
                                  style: GoogleFonts.poppins(
                                    color: themeProvider.isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                                    fontSize: 14,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                                  decoration: const BoxDecoration(),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return appLanguage.get('enter_email');
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return appLanguage.get('email_required');
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Password Field
                        Container(
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeProvider.isDarkMode ? CupertinoColors.systemGrey4 : CupertinoColors.systemGrey5,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemGrey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Icon(
                                  CupertinoIcons.lock,
                                  color: themeProvider.isDarkMode ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey,
                                  size: 16,
                                ),
                              ),
                              Expanded(
                                child: CupertinoTextFormFieldRow(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  placeholder: appLanguage.get('password_hint'),
                                  placeholderStyle: GoogleFonts.poppins(
                                    color: themeProvider.isDarkMode ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey,
                                    fontSize: 14,
                                  ),
                                  style: GoogleFonts.poppins(
                                    color: themeProvider.isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                                    fontSize: 14,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  decoration: const BoxDecoration(),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return appLanguage.get('enter_password');
                                    }
                                    if (value.length < 6) {
                                      return appLanguage.get('password_required');
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: GestureDetector(
                                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                  child: Icon(
                                    _obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                                    color: themeProvider.isDarkMode ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Forgot Password Link
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              appLanguage.get('forgot_password'),
                              style: GoogleFonts.poppins(
                                color: primaryBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login Button
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryBlue, lightBlue],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(12),
                            onPressed: _isLoading ? null : loginUser,
                            child: _isLoading
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  )
                                : Text(
                                    appLanguage.get('login'),
                                    style: GoogleFonts.poppins(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Social Login Icons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Apple
                            GestureDetector(
  onTap: _isLoading || _isGoogleLoading
      ? null
      : () async {
          try {
            await _handleAppleLogin(context, (bool loading) {
              setState(() => _isLoading = loading);
            });
          } catch (e) {
            _showErrorDialog('Apple Sign-In failed: $e');
            setState(() => _isLoading = false);
          }
        },
  child: Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: CupertinoColors.black,
      borderRadius: BorderRadius.circular(18),
    ),
    child: _isLoading
        ? const CupertinoActivityIndicator(
            color: CupertinoColors.white,
            radius: 10,
          )
        : const Icon(
            Icons.apple,
            color: CupertinoColors.white,
            size: 18,
          ),
  ),
),
                            const SizedBox(width: 12),

                            // Facebook (Placeholder)
                            const SizedBox(width: 12),
                            // Google
                            GestureDetector(
                              onTap: _isLoading || _isGoogleLoading ? null : _handleGoogleLogin,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: themeProvider.isDarkMode ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: themeProvider.isDarkMode ? CupertinoColors.systemGrey4 : CupertinoColors.systemGrey5,
                                    width: 0.5,
                                  ),
                                ),
                                child: _isGoogleLoading
                                    ? const CupertinoActivityIndicator(
                                        color: CupertinoColors.systemGrey,
                                        radius: 10,
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Image.asset(
                                          'assets/google-logo.png',
                                          width: 20,
                                          height: 20,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}