import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Authentication/reset_password.dart';

import 'dart:convert';

import 'package:taskova_drivers/View/Language/language_provider.dart';


// Define app colors (matching with NewPasswordScreen)
class AppColors {
  static const primaryBlue = Color(0xFF1E88E5); // Main blue color
  static const lightBlue = Color(0xFFBBDEFB);   // Light blue for backgrounds
  static const accentBlue = Color(0xFF0D47A1);  // Darker blue for emphasis
  static const white = CupertinoColors.white;
  static const grey = Color(0xFFE0E0E0);        // Light grey for borders
  static const textDark = Color(0xFF424242);    // Dark text color
  static const textLight = Color(0xFF757575);   // Light text color
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  late AppLanguage appLanguage;

  @override
  void initState() {
    super.initState();
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
  }

  Future<void> _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.forgotPasswordUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': _emailController.text}),
        );
        
        if (response.statusCode == 200) {
          _showSuccessDialog(appLanguage.get('OTP sent to your email'));
          Navigator.push(
            context, 
            CupertinoPageRoute(
              builder: (context) => NewPasswordScreen(email: _emailController.text),
            ),
          );
        } else {
          final responseData = jsonDecode(response.body);
          String errorMessage = responseData['message'] ?? 
              appLanguage.get('invalid_email');
          _showErrorDialog(errorMessage);
        }
      } catch (e) {
        _showErrorDialog('Network error: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoTheme(
      data: const CupertinoThemeData(
        brightness: Brightness.light, // Forces white background
      ),
      child: CupertinoAlertDialog(
        title: Text(
          'Invalid Email',
          style: TextStyle(color: AppColors.accentBlue),
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.primaryBlue),
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
        brightness: Brightness.light, // Ensures white background
      ),
      child: CupertinoAlertDialog(
        title: Text(
          'Success',
          style: TextStyle(color: AppColors.primaryBlue),
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.primaryBlue),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}


  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // backgroundColor: AppColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryBlue,
        middle: Text(
          appLanguage.get('forgot_password'),
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
        ),
        previousPageTitle: appLanguage.get('Back'),
        border: Border(bottom: BorderSide(color: AppColors.primaryBlue)),
      ),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.white,
                AppColors.lightBlue.withOpacity(0.3),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Logo
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        appLanguage.get('app_name'),
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Header text
                  Text(
                    appLanguage.get('reset_Password'),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Instruction text
                  Text(
                    appLanguage.get('forgot_password_instruction'),
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Email field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.lightBlue.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CupertinoFormRow(
                      child: CupertinoTextFormFieldRow(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        placeholder: appLanguage.get('email'),
                        style: TextStyle(color: AppColors.textDark),
                        placeholderStyle: TextStyle(color: AppColors.textLight),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            CupertinoIcons.mail,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return appLanguage.get('Please enter your email');
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return appLanguage.get('Please enter a valid email');
                          }
                          return null;
                        },
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Send OTP button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primaryBlue,
                      onPressed: _isLoading ? null : _sendOTP,
                      child: _isLoading
                          ? const CupertinoActivityIndicator(color: AppColors.white)
                          : Text(
                              appLanguage.get('send_otp'),
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Back to login - styled as a secondary button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryBlue, width: 1.5),
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.white,
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        appLanguage.get('Back to Login'),
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}