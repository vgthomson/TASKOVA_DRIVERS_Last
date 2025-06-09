import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Authentication/login.dart';
import 'package:taskova_drivers/View/BottomNavigation/bottomnavigation.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';
import 'package:taskova_drivers/View/profile.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late String selectedLanguage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final appLanguage = Provider.of<AppLanguage>(context, listen: false);
    selectedLanguage = appLanguage.currentLanguage;
  }

  Future<void> saveLanguageAndNavigate() async {
    final appLanguage = Provider.of<AppLanguage>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    // Save the selected language
    await appLanguage.changeLanguage(selectedLanguage);
    await prefs.setString('language_code', selectedLanguage);

    if (accessToken != null && accessToken.isNotEmpty) {
      // Check profile completion status
      final isProfileComplete = await checkProfileStatus(accessToken);
      if (isProfileComplete) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MainWrapper()),
        );
      } else {
         Navigator.of(context).pushAndRemoveUntil(
    CupertinoPageRoute(builder: (context) => ProfileRegistrationPage()),
    (Route<dynamic> route) => false,
  );
      }
    } else {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<bool> checkProfileStatus(String accessToken) async {
    try {
      final profileResponse = await http.get(
        Uri.parse(ApiConfig.profileStatusUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (profileResponse.statusCode == 200) {
        final responseData = jsonDecode(profileResponse.body);
        return responseData['is_profile_complete'] == true;
      } else {
        // Handle API error by assuming profile is incomplete
        return false;
      }
    } catch (e) {
      // Handle network or other errors by assuming profile is incomplete
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLanguage = Provider.of<AppLanguage>(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(appLanguage.get('Select Language')),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // App Logo
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Image.asset(
                  'assets/app_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (context, error, stackTrace) => Icon(
                        CupertinoIcons.globe,
                        size: 60,
                        color: CupertinoColors.white,
                      ),
                ),
              ),
              const SizedBox(height: 20),
              // App Name
              Text(
                appLanguage.get('app_name'),
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.systemBlue,
                ),
              ),
              const SizedBox(height: 8),
              // Instruction Text
              Text(
                appLanguage.get('Choose your preferred language'),
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 40),
              // Language Options
              Expanded(
                child: ListView.builder(
                  itemCount: appLanguage.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final language = appLanguage.supportedLanguages[index];
                    final isSelected = language['code'] == selectedLanguage;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedLanguage = language['code']!;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? CupertinoColors.systemBlue.withOpacity(
                                        0.1,
                                      )
                                    : CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? CupertinoColors.systemBlue
                                      : CupertinoColors.systemGrey4,
                            ),
                          ),
                          child: CupertinoListTile(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBlue.withOpacity(
                                  0.2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  language['code']!.toUpperCase(),
                                  style: TextStyle(
                                    color: CupertinoColors.systemBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              language['name']!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: const Color.fromARGB(255, 4, 40, 199),
                              ),
                            ),
                            subtitle: Text(
                              language['nativeName']!,
                              style: TextStyle(
                                color: const Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                            trailing:
                                isSelected
                                    ? Icon(
                                        CupertinoIcons.checkmark_alt_circle_fill,
                                        color: CupertinoColors.systemBlue,
                                      )
                                    : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Continue Button
              CupertinoButton.filled(
                onPressed:
                    isLoading
                        ? null
                        : () async {
                            setState(() {
                              isLoading = true;
                            });
                            await saveLanguageAndNavigate();
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          },
                child:
                    isLoading
                        ? const CupertinoActivityIndicator()
                        : Text(appLanguage.get('continue_text')),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}