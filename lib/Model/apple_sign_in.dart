import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Authentication/signup.dart';
import 'package:taskova_drivers/View/BottomNavigation/bottomnavigation.dart';
import 'package:taskova_drivers/View/profile.dart';

class AppleAuthService {
  /// Check if Apple Sign In is available on this device
  static Future<bool> isAppleSignInAvailable() async {
    return await SignInWithApple.isAvailable();
  }

  /// Handle Apple Sign In process
  Future<void> signInWithApple({
    required BuildContext context,
    required Function(String, BuildContext) showSuccessDialog,
    required Function(String, BuildContext) showErrorDialog,
    required Function(bool) setLoadingState,
  }) async {
    try {
      setLoadingState(true);

      // Check if Apple Sign In is available
      if (!await isAppleSignInAvailable()) {
        showErrorDialog('Apple Sign In is not available on this device', context);
        setLoadingState(false);
        return;
      }

      // Request Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.driversapp.taskovadriver',
          redirectUri: Uri.parse('https://taskovaapp.firebaseapp.com/__/auth/handler'),
        ),
      );

      // Extract user information
      String? identityToken = credential.identityToken;
      String? authorizationCode = credential.authorizationCode;
      String? email = credential.email;
      String? givenName = credential.givenName;
      String? familyName = credential.familyName;

      if (identityToken == null) {
        showErrorDialog('Apple Sign In failed: No identity token received', context);
        setLoadingState(false);
        return;
      }

      // Create full name from given and family names
      String fullName = '';
      if (givenName != null || familyName != null) {
        fullName = '${givenName ?? ''} ${familyName ?? ''}'.trim();
      }

      // Send to backend
      await _sendAppleTokenToBackend(
        context: context,
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        email: email,
        fullName: fullName,
        showSuccessDialog: showSuccessDialog,
        showErrorDialog: showErrorDialog,
        setLoadingState: setLoadingState,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      setLoadingState(false);
      _handleAppleSignInError(e, showErrorDialog, context);
    } catch (e, stackTrace) {
      setLoadingState(false);
      print('Apple Sign In error: $e');
      print('Stack Trace: $stackTrace');
      showErrorDialog('Apple Sign In failed: ${e.toString()}', context);
    }
  }

  /// Enhanced Apple backend authentication with comprehensive debugging
  Future<void> _sendAppleTokenToBackend({
    required BuildContext context,
    required String identityToken,
    String? authorizationCode,
    String? email,
    String? fullName,
    required Function(String, BuildContext) showSuccessDialog,
    required Function(String, BuildContext) showErrorDialog,
    required Function(bool) setLoadingState,
  }) async {
    try {
      print('=== Starting Apple Backend Authentication ===');
      print('Identity Token Length: ${identityToken.length}');
      print('Authorization Code: ${authorizationCode ?? "NULL"}');
      print('Email: ${email ?? "NULL"}');
      print('Full Name: ${fullName ?? "NULL"}');
      print('API URL: ${ApiConfig.baseUrl}/social_auth/apple/');

      final requestBody = {
        'identity_token': identityToken,
        'authorization_code': authorizationCode,
        'role': 'DRIVER',
        if (email != null) 'email': email,
        if (fullName != null) 'full_name': fullName,
      };

      print('Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/social_auth/apple/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Backend Response Status: ${response.statusCode}');
      print('Backend Response Headers: ${response.headers}');
      print('Backend Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ Backend authentication successful');

        // Extract tokens and user data with validation
        final tokens = responseData['tokens'];
        final user = responseData['user'];

        if (tokens == null) {
          print('❌ ERROR: No tokens in response');
          showErrorDialog('Authentication failed: No tokens received', context);
          setLoadingState(false);
          return;
        }

        if (user == null) {
          print('❌ ERROR: No user data in response');
          showErrorDialog('Authentication failed: No user data received', context);
          setLoadingState(false);
          return;
        }

        String accessToken = tokens['access'] ?? '';
        String refreshToken = tokens['refresh'] ?? '';
        String userId = user['id']?.toString() ?? '';
        String username = user['username'] ?? user['name'] ?? fullName ?? 'User';
        String userEmail = user['email'] ?? email ?? '';
        String role = user['role'] ?? 'DRIVER';
        bool isNewUser = responseData['is_new_user'] ?? false;

        print('Extracted Data:');
        print('- Access Token Length: ${accessToken.length}');
        print('- Refresh Token Length: ${refreshToken.length}');
        print('- User ID: $userId');
        print('- Username: $username');
        print('- Email: $userEmail');
        print('- Role: $role');
        print('- Is New User: $isNewUser');

        // Validate required fields
        if (accessToken.isEmpty) {
          print('❌ ERROR: Empty access token');
          showErrorDialog('Authentication failed: Invalid access token', context);
          setLoadingState(false);
          return;
        }

        if (refreshToken.isEmpty) {
          print('❌ ERROR: Empty refresh token');
          showErrorDialog('Authentication failed: Invalid refresh token', context);
          setLoadingState(false);
          return;
        }

        if (userId.isEmpty) {
          print('❌ ERROR: Empty user ID');
          showErrorDialog('Authentication failed: Invalid user ID', context);
          setLoadingState(false);
          return;
        }

        // Save user data to SharedPreferences
        print('💾 Saving user data to SharedPreferences...');
        await _saveAppleUserData(
          accessToken: accessToken,
          refreshToken: refreshToken,
          email: userEmail,
          username: username,
          userId: userId,
          role: role,
        );

        // Verify data was saved correctly
        print('🔍 Verifying saved data...');
        final prefs = await SharedPreferences.getInstance();
        final savedToken = prefs.getString('access_token');
        final savedUserId = prefs.getString('user_id');
        final savedEmail = prefs.getString('user_email');

        print('Verification Results:');
        print('- Saved Token Match: ${savedToken == accessToken}');
        print('- Saved User ID Match: ${savedUserId == userId}');
        print('- Saved Email Match: ${savedEmail == userEmail}');

        if (savedToken != accessToken || savedUserId != userId) {
          print('❌ ERROR: Data verification failed');
          showErrorDialog('Failed to save authentication data', context);
          setLoadingState(false);
          return;
        }

        // Show success message
        showSuccessDialog(responseData['message'] ?? 'Apple Sign In successful!', context);

        // Add a delay to ensure data is fully persisted
        await Future.delayed(Duration(milliseconds: 500));

        // Check profile status
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

          if (isNewUser || !isProfileComplete) {
            print('🆕 New user or incomplete profile - navigating to registration');
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (context) => ProfileRegistrationPage()),
              (Route<dynamic> route) => false,
            );
            
          } else {
            print('👤 Existing user with complete profile - navigating to main wrapper');
            await _initializeNotificationService();

            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(builder: (context) => const MainWrapper()),
              (Route<dynamic> route) => false,
            );
          }
        } else {
          print('❌ ERROR: Failed to verify profile status');
          showErrorDialog('Could not verify profile status', context);
          setLoadingState(false);
          await _clearUserData();
        }
      } else {
        setLoadingState(false);
        print('❌ Backend authentication failed');
        try {
          final errorData = jsonDecode(response.body);
          String errorMessage = errorData['error'] ??
              errorData['detail'] ??
              errorData['message'] ??
              'Apple Sign In failed';
          print('Error Message: $errorMessage');
          showErrorDialog(errorMessage, context);
        } catch (e) {
          print('Could not parse error response: $e');
          showErrorDialog('Apple Sign In failed with status ${response.statusCode}', context);
        }
      }
    } catch (e, stackTrace) {
      setLoadingState(false);
      print('❌ EXCEPTION in Apple backend authentication: $e');
      print('Stack Trace: $stackTrace');
      showErrorDialog('Connection error during Apple Sign In: ${e.toString()}', context);
    }
  }

  /// Enhanced save method with better logging
  Future<void> _saveAppleUserData({
    required String accessToken,
    required String refreshToken,
    required String email,
    required String username,
    required String userId,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    print('💾 Saving Apple user data...');
    print('- Access Token Length: ${accessToken.length}');
    print('- Refresh Token Length: ${refreshToken.length}');
    print('- Email: $email');
    print('- Username: $username');
    print('- User ID: $userId');
    print('- Role: $role');

    try {
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', username);
      await prefs.setString('user_id', userId);
      await prefs.setString('user_role', role);
      await prefs.setString('logged_in_email', email);
      await prefs.setString('login_method', 'apple');

      print('✅ All data saved successfully');
    } catch (e) {
      print('❌ ERROR saving data: $e');
      throw e;
    }
  }
 Future<void> _initializeNotificationService() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear any previous notification timestamps on fresh login
    await prefs.remove('last_notification_check');
  }
  /// Debug SharedPreferences data
  Future<void> _debugSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    print('=== SharedPreferences Debug ===');
    for (String key in keys) {
      final value = prefs.get(key);
      if (key.contains('token')) {
        print('$key: ${value.toString().substring(0, 20)}...');
      } else {
        print('$key: $value');
      }
    }
    print('===============================');
  }

  /// Clear user data helper
  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('logged_in_email');
    await prefs.remove('login_method');
    print('🧹 Cleared all user data');
  }

  /// Handle Apple Sign In specific errors
  void _handleAppleSignInError(
    SignInWithAppleAuthorizationException error,
    Function(String, BuildContext) showErrorDialog,
    BuildContext context,
  ) {
    print('Apple Sign In Error: Code=${error.code}, Message=${error.message}');
    switch (error.code) {
      case AuthorizationErrorCode.canceled:
        showErrorDialog('Apple Sign In was canceled', context);
        break;
      case AuthorizationErrorCode.failed:
        showErrorDialog('Apple Sign In failed', context);
        break;
      case AuthorizationErrorCode.invalidResponse:
        showErrorDialog('Invalid response from Apple', context);
        break;
      case AuthorizationErrorCode.notHandled:
        showErrorDialog('Apple Sign In not handled', context);
        break;
      case AuthorizationErrorCode.unknown:
        showErrorDialog('Unknown Apple Sign In error: ${error.message}', context);
        break;
      default:
        showErrorDialog('Apple Sign In error: ${error.message}', context);
    }
  }
}