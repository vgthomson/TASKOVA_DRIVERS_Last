import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, BoxDecoration, BorderRadius, Colors, BoxShadow, Gradient, LinearGradient, Offset;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Authentication/login.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';



class OtpVerification extends StatefulWidget {
  final String email;

  const OtpVerification({super.key, required this.email});

  @override
  State<OtpVerification> createState() => _OtpVerificationState();
}

class _OtpVerificationState extends State<OtpVerification> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  bool _isLoading = false;
  bool _isResending = false;
  String _errorMessage = '';
  String _successMessage = '';
  int _resendCountdown = 30;
  bool _showResendButton = false;
  late AppLanguage appLanguage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Define the blue and white theme colors (same as registration page)
  final Color primaryBlue = const Color(0xFF2D6CDF);
  final Color lightBlue = const Color(0xFF5B9DF5);
  final Color accentBlue = const Color(0xFF1A4AAF);
  final Color backgroundWhite = const Color(0xFFF9FBFF);
  final Color cardWhite = Colors.white;
  final Color textDarkBlue = const Color(0xFF0A2463);
  final Color textLightGrey = const Color(0xFF8D9AB3);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _showResendButton = false;
    _resendCountdown = 30;
    const oneSec = Duration(seconds: 1);
    Timer.periodic(oneSec, (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
        setState(() {
          _showResendButton = true;
        });
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    final otp = _getOtpCode();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = appLanguage.get('otp_required');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"email": widget.email, "code": otp}),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog(appLanguage.get('email_verification_suc'));
        
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        });
      } else {
        final errorResponse = jsonDecode(response.body);
        _showErrorDialog(errorResponse['detail'] ?? 
            appLanguage.get('email_verification_fail'));
      }
    } catch (e) {
      _showErrorDialog(appLanguage.get('connection_error'));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resendOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"email": widget.email}),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog(appLanguage.get('otp_sent'));
        _startResendTimer();
      } else {
        final errorResponse = jsonDecode(response.body);
        _showErrorDialog(errorResponse['detail'] ?? 
            appLanguage.get('otp_sent_fail'));
      }
    } catch (e) {
      _showErrorDialog(appLanguage.get('connection_error'));
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  void _showErrorDialog(String message) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoTheme(
      data: const CupertinoThemeData(
        brightness: Brightness.light, // Ensures white background
      ),
      child: CupertinoAlertDialog(
        title: Text(
          'Incorrect OTP',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black, // Changed to black for contrast on white
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: textDarkBlue,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
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
      data: const CupertinoThemeData(
        brightness: Brightness.light, // Forces white background
      ),
      child: CupertinoAlertDialog(
        title: Text(
          'Success',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: textDarkBlue,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: textDarkBlue,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: backgroundWhite,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: cardWhite,
        border: Border(
          bottom: BorderSide(
            color: Colors.blue.shade50,
            width: 0.5,
          ),
        ),
        middle: Text(
          appLanguage.get('verification_code'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: textDarkBlue,
          ),
        ),
        previousPageTitle: appLanguage.get('Back'),
      ),
      child: SafeArea(
        // Use a SingleChildScrollView to handle keyboard overflow
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            // Add physics for better scrolling behavior
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top -
                          44.0, // Standard Cupertino navigation bar height
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        
                        // Verification icon with gradient
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryBlue,
                                lightBlue,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.mail,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Title
                        Text(
                          appLanguage.get('verification_code'),
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: textDarkBlue,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                color: textLightGrey,
                                fontSize: 15,
                              ),
                              children: [
                                TextSpan(text: appLanguage.get('otp_snackbar')),
                                TextSpan(
                                  text: " ${widget.email}",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: textDarkBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // OTP input fields
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              6,
                              (index) => _buildOtpDigitField(index),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Error message
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_circle,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: GoogleFonts.poppins(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Success message
                        if (_successMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_alt_circle,
                                  color: Colors.green.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _successMessage,
                                    style: GoogleFonts.poppins(
                                      color: Colors.green.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 40),

                        // Verify button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                primaryBlue,
                                lightBlue,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(16),
                            onPressed: _isLoading ? null : _verifyOtp,
                            child: _isLoading
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : Text(
                                  appLanguage.get('verfy_code').toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                    color: Colors.white,
                                  ),
                                ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Resend code section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.shade100,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                appLanguage.get('didnt_receive_code'),
                                style: GoogleFonts.poppins(
                                  color: textDarkBlue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _showResendButton
                                  ? CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      child: _isResending
                                          ? CupertinoActivityIndicator(color: primaryBlue)
                                          : Text(
                                              appLanguage.get('resend_code'),
                                              style: GoogleFonts.poppins(
                                                color: primaryBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                      onPressed: _isResending ? null : _resendOtp,
                                    )
                                  : Text(
                                      "${appLanguage.get('Resend in')} $_resendCountdown s",
                                      style: GoogleFonts.poppins(
                                        color: primaryBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpDigitField(int index) {
    return SizedBox(
      width: 45,
      height: 55,
      child: CupertinoTextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textDarkBlue,
        ),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}