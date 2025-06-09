import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Authentication/login.dart';

import 'dart:convert';

import 'package:taskova_drivers/View/Language/language_provider.dart';


// Define our app colors
class AppColors {
  static const primaryBlue = Color(0xFF1E88E5); // Main blue color
  static const lightBlue = Color(0xFFBBDEFB);   // Light blue for backgrounds
  static const accentBlue = Color(0xFF0D47A1);  // Darker blue for emphasis
  static const white = CupertinoColors.white;
  static const grey = Color(0xFFE0E0E0);        // Light grey for borders
  static const textDark = Color(0xFF424242);    // Dark text color
  static const textLight = Color(0xFF757575);   // Light text color
}

class NewPasswordScreen extends StatefulWidget {
  final String email;

  const NewPasswordScreen({Key? key, required this.email}) : super(key: key);

  @override
  _NewPasswordScreenState createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AppLanguage appLanguage;

  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final List<TextEditingController> _otpFieldControllers =
      List.generate(6, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      String otp = _otpFieldControllers.map((c) => c.text).join();

      if (otp.length != 6) {
        _showErrorDialog('Please enter the complete 6-digit OTP');
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorDialog(appLanguage.get('password_notmatch'));
        return;
      }

      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse(ApiConfig.resetPasswordUrl),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'email': widget.email,
            'code': otp,
            'new_password': _passwordController.text,
          }),
        );

        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          _showSuccessDialog(appLanguage.get('password_reset_done'));
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (context) => LoginPage()),
            (route) => false,
          );
        } else {
          final errorResponse = jsonDecode(response.body);
          String errorMessage = appLanguage.get('password_reset_fail');

          if (errorResponse is Map<String, dynamic>) {
            if (errorResponse.containsKey('email')) {
              errorMessage = errorResponse['email'][0];
            } else if (errorResponse.containsKey('code')) {
              errorMessage = errorResponse['code'][0];
            } else if (errorResponse.containsKey('new_password')) {
              errorMessage = errorResponse['new_password'][0];
            } else if (errorResponse.containsKey('detail')) {
              errorMessage = errorResponse['detail'];
            } else if (errorResponse.containsKey('non_field_errors')) {
              errorMessage = errorResponse['non_field_errors'][0];
            }
          }

          _showErrorDialog(errorMessage);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorDialog('Network error: ${e.toString()}');
      }
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Error', style: TextStyle(color: AppColors.accentBlue)),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK', style: TextStyle(color: AppColors.primaryBlue)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Success', style: TextStyle(color: AppColors.primaryBlue)),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK', style: TextStyle(color: AppColors.primaryBlue)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var controller in _otpFieldControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // backgroundColor: AppColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.primaryBlue,
        middle: Text( 
          appLanguage.get('reset_password'),
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
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 40),
                  // Header text
                  Text(
                    appLanguage.get('create_new_password'),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // OTP instruction text
                  Text(
                    '${appLanguage.get('enter_code')} ${widget.email}',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // OTP input fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (index) => SizedBox(
                        width: 48,
                        height: 56,
                        child: CupertinoTextField(
                          controller: _otpFieldControllers[index],
                          focusNode: _focusNodes[index],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          },
                          style: TextStyle(fontSize: 20, color: AppColors.primaryBlue),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primaryBlue.withOpacity(0.5),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lightBlue.withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // New password field
                  _buildPasswordField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    placeholder: appLanguage.get('new_password'),
                    toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return appLanguage.get('password_hint_new');
                      }
                      if (value.length < 8) {
                        return appLanguage.get('new_password_validation');
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  // Confirm password field
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    placeholder: appLanguage.get('confirm_password'),
                    toggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return appLanguage.get('please_confrm_password');
                      }
                      if (value != _passwordController.text) {
                        return appLanguage.get('passwords_do_not_match');
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 40),
                  // Reset password button
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
                      onPressed: _isLoading ? null : _resetPassword,
                      child: _isLoading
                          ? const CupertinoActivityIndicator(color: AppColors.white)
                          : Text(
                              appLanguage.get('confirm'),
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscureText,
    required String placeholder,
    required Function() toggleObscure,
    required String? Function(String?) validator,
  }) {
    return Container(
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
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            CupertinoTextFormFieldRow(
              controller: controller,
              obscureText: obscureText,
              style: TextStyle(color: AppColors.textDark),
              placeholder: placeholder,
              placeholderStyle: TextStyle(color: AppColors.textLight),
              prefix: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(
                  CupertinoIcons.lock,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              padding: const EdgeInsets.only(right: 48),
              validator: validator,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Positioned(
              right: 10,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                child: Icon(
                  obscureText
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
                onPressed: toggleObscure,
              ),
            ),
          ],
        ),
      ),
    );
  }
}