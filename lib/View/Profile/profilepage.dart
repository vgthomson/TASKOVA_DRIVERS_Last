import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/Model/postcode.dart';
import 'package:taskova_drivers/View/Authentication/login.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';
import 'package:taskova_drivers/View/appliedjobs.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Define controllers for the editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _drivingDurationController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Other profile data
  String? _selectedAddress;
  double? _latitude;
  double? _longitude;

  // UI States
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Color scheme
  final Color primaryBlue = Color(0xFF1A5DC1);
  final Color lightBlue = Color(0xFFE6F0FF);
  final Color accentBlue = Color(0xFF0E4DA4);
  final Color whiteColor = CupertinoColors.white;

  late AppLanguage appLanguage;

  @override
  void initState() {
    super.initState();
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
    _loadProfileData();
  }

  // Load profile data from API/storage
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('user_email');
      final accessToken = prefs.getString('access_token');

      // Set email from SharedPreferences immediately
      setState(() {
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _emailController.text = savedEmail;
        }
      });

      if (accessToken == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final url = Uri.parse(ApiConfig.driverProfileUrl);
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone_number'] ?? '';
          _selectedAddress = data['preferred_working_address'] ?? '';
          _addressController.text = _selectedAddress ?? '';
          _drivingDurationController.text = data['driving_duration'] ?? '';

          if (data.containsKey('latitude') && data.containsKey('longitude')) {
            _latitude = double.tryParse(data['latitude'].toString());
            _longitude = double.tryParse(data['longitude'].toString());
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load profile data, but email is loaded from local storage.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      print('Validation failed'); // Debug print
      return;
    }

    if (_selectedAddress == null || _latitude == null || _longitude == null) {
      _showErrorDialog(appLanguage.get('select_working_area'));
      print('Address or coordinates missing'); // Debug print
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final url = Uri.parse(ApiConfig.driverProfileUrl);
      final request = http.MultipartRequest('PUT', url);

      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      });

      // Add form fields
      request.fields['name'] = _nameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['preferred_working_address'] = _selectedAddress!;
      request.fields['latitude'] = _latitude!.toString();
      request.fields['longitude'] = _longitude!.toString();
      request.fields['driving_duration'] = _drivingDurationController.text;

      print('Sending profile update request: ${request.fields}'); // Debug print

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Request timed out. Please check your connection.',
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}'); // Debug print
      print('Response body: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        // Refresh profile data
        await _loadProfileData();
        setState(() {
          _isEditing = false;
        });
        _showSuccessDialog(appLanguage.get('profile_updated_successfully'));
      } else {
        setState(() {
          try {
            final responseData = json.decode(response.body);
            if (responseData is Map<String, dynamic>) {
              if (responseData.containsKey('detail')) {
                _errorMessage = responseData['detail'];
              } else {
                final List<String> errors = [];
                responseData.forEach((key, value) {
                  if (value is List && value.isNotEmpty) {
                    errors.add('$key: ${value.join(', ')}');
                  } else if (value is String) {
                    errors.add('$key: $value');
                  }
                });
                _errorMessage =
                    errors.isNotEmpty
                        ? errors.join('\n')
                        : 'Unknown error occurred';
              }
            } else {
              _errorMessage = 'Server returned an unexpected response format';
            }
          } catch (e) {
            _errorMessage = 'Failed to parse server response: ${e.toString()}';
          }
        });
      }
    } catch (e) {
      setState(() {
        if (e is TimeoutException) {
          _errorMessage = e.message;
        } else {
          _errorMessage = 'Error updating profile: ${e.toString()}';
        }
      });
      print('Error during save: $e'); // Debug print
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  bool _isValidUKPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(' ', '').replaceAll('+44', '');
    if (cleanPhone.length < 10 || cleanPhone.length > 11) {
      return false;
    }
    return RegExp(r'^[0-9]+$').hasMatch(cleanPhone);
  }

  Future<void> logout(BuildContext context) async {
    try {
      await _googleSignIn.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text("Error"),
          content: Text("Logout failed"),
          actions: [
            CupertinoDialogAction(
              child: Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  void _showLogoutConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoTheme(
        data: CupertinoThemeData(brightness: Brightness.light),
        child: CupertinoAlertDialog(
          title: Text(
            appLanguage.get('logout_confirmation'),
            style: TextStyle(color: primaryBlue),
          ),
          content: Text(appLanguage.get('are_you_sure_you_want_to_logout')),
          actions: [
            CupertinoDialogAction(
              child: Text(
                appLanguage.get('cancel'),
                style: TextStyle(color: primaryBlue),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: Text(appLanguage.get('logout')),
              onPressed: () {
                Navigator.pop(context);
                logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoTheme(
        data: CupertinoThemeData(brightness: Brightness.light),
        child: CupertinoAlertDialog(
          title: Text(
            appLanguage.get('error'),
            style: TextStyle(color: CupertinoColors.destructiveRed),
          ),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: Text(
                appLanguage.get('ok'),
                style: TextStyle(color: primaryBlue),
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
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          appLanguage.get('success'),
          style: TextStyle(color: primaryBlue),
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(
              appLanguage.get('ok'),
              style: TextStyle(color: primaryBlue),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        middle: Text(
          appLanguage.get('profile'),
          style: TextStyle(
            color: CupertinoColors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: _isLoading
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: _isSaving
                    ? CupertinoActivityIndicator(radius: 10)
                    : Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? primaryBlue
                              : CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _isEditing
                              ? appLanguage.get('save')
                              : appLanguage.get('edit'),
                          style: TextStyle(
                            color: _isEditing
                                ? CupertinoColors.white
                                : primaryBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                onPressed: () {
                  setState(() {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      _isEditing = true;
                    }
                  });
                },
              ),
      ),
      child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(radius: 20),
                  SizedBox(height: 20),
                  Text(
                    appLanguage.get('loading_profile'),
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header Profile Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryBlue, accentBlue],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -20,
                                    top: -20,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 20,
                                    top: 40,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white
                                            .withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 80,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: CupertinoColors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: CupertinoColors.black
                                              .withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Icon(
                                        CupertinoIcons.person_solid,
                                        size: 40,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 5,
                                    right: 5,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: CupertinoColors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 50, 20, 20),
                          child: Column(
                            children: [
                              Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text
                                    : appLanguage.get('your_name'),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.location_solid,
                                    size: 14,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _selectedAddress ??
                                          appLanguage.get('set_location'),
                                      style: TextStyle(
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGreen
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: CupertinoColors.systemGreen
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.checkmark_seal_fill,
                                      color: CupertinoColors.systemGreen,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '${appLanguage.get('active')} • ${appLanguage.get('verified')}',
                                      style: TextStyle(
                                        color: CupertinoColors.systemGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Error Message
                if (_errorMessage != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.destructiveRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.destructiveRed.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: CupertinoColors.destructiveRed,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: CupertinoColors.destructiveRed,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Personal Information Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
                            child: Text(
                              appLanguage.get('personal_information'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.black,
                              ),
                            ),
                          ),
                          _buildModernFormField(
                            controller: _nameController,
                              placeholder: appLanguage.get('name'),
                              icon: CupertinoIcons.person,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return appLanguage.get('please_enter_name');
                                }
                                if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                                  return appLanguage.get(
                                    'name_must_contain_only_alphabets',
                                  );
                                }
                                return null;
                              },
                          ),
                          _buildModernFormField(
                            controller: _emailController,
                            placeholder: appLanguage.get('email'),
                            icon: CupertinoIcons.mail,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: true,
                          ),
                          _buildModernFormField(
                            controller: _phoneController,
                            placeholder: appLanguage.get('phone_number'),
                            icon: CupertinoIcons.phone_fill,
                            keyboardType: TextInputType.phone,
                            isLast: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return appLanguage.get('please_enter_phone_number');
                              }
                              if (!_isValidUKPhoneNumber(value)) {
                                return appLanguage.get('please_enter_valid_uk_phone_number');
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Working Area Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.location_solid,
                                color: primaryBlue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                appLanguage.get('preferred_working_address'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.black,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (_isEditing) ...[
                            PostcodeSearchWidget(
                              postcodeController: _postcodeController,
                              placeholderText: appLanguage.get('enter_postcode'),
                              onAddressSelected: (latitude, longitude, address) {
                                setState(() {
                                  _selectedAddress = address;
                                  _latitude = latitude;
                                  _longitude = longitude;
                                  _addressController.text = address;
                                });
                              },
                            ),
                            SizedBox(height: 16),
                          ],
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isEditing
                                  ? primaryBlue.withOpacity(0.05)
                                  : CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isEditing
                                    ? primaryBlue.withOpacity(0.2)
                                    : CupertinoColors.separator,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEditing
                                      ? appLanguage.get('selected_working_area')
                                      : appLanguage.get('current_working_area'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.systemGrey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _selectedAddress ??
                                      appLanguage.get('no_address_selected'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: CupertinoColors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Account Settings Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: Text(
                            appLanguage.get('account_settings'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.black,
                            ),
                          ),
                        ),
                        _buildModernSettingsItem(
                          icon: CupertinoIcons.briefcase,
                          title: appLanguage.get('Applied Jobs'),
                          subtitle: 'View jobs you’ve applied for.',
                          iconColor: const Color.fromARGB(255, 15, 159, 242),
                          isFirst: true,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context)=>AppliedJobsPage()));
                          },
                        ),
                        _buildModernSettingsItem(
                          icon: CupertinoIcons.person,
                          title: appLanguage.get('Support & Help'),
                          subtitle: 'Access help resources or contact support.',
                          iconColor: const Color.fromARGB(255, 103, 215, 154),
                          isFirst: true,
                          onTap: () {},
                        ),
                        _buildModernSettingsItem(
                          icon: CupertinoIcons.shield_fill,
                          title: appLanguage.get('Privacy Settings'),
                          subtitle:
                              'Adjust privacy options, such as location sharing or data usage',
                          iconColor: const Color.fromARGB(255, 230, 91, 45),
                          isFirst: true,
                          onTap: () {},
                        ),
                        _buildModernSettingsItem(
                          icon: CupertinoIcons.lock_fill,
                          title: appLanguage.get('change_password'),
                          subtitle: 'Update your account password',
                          iconColor: CupertinoColors.systemBlue,
                          onTap: () {
                            //  Navigator.push(context, MaterialPageRoute(builder: (context)=>ForgotPasswordScreen()));
                          },
                        ),
                        _buildModernSettingsItem(
                          icon: CupertinoIcons.globe,
                          title: appLanguage.get('language'),
                          subtitle: 'Choose your preferred language',
                          iconColor: CupertinoColors.systemPurple,
                          onTap: () {},
                        ),
                        _buildModernSettingsItem(
                          icon: CupertinoIcons.square_arrow_right,
                          title: appLanguage.get('logout'),
                          subtitle: 'Sign out of your account',
                          iconColor: CupertinoColors.destructiveRed,
                          isDestructive: true,
                          isLast: true,
                          onTap: _showLogoutConfirmation,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons
                if (_isEditing)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              color: CupertinoColors.systemGrey5,
                              borderRadius: BorderRadius.circular(12),
                              child: Text(
                                appLanguage.get('cancel'),
                                style: TextStyle(
                                  color: CupertinoColors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _loadProfileData();
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(12),
                              child: _isSaving
                                  ? CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                      radius: 12,
                                    )
                                  : Text(
                                      appLanguage.get('save'),
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                              onPressed: _isSaving ? null : _saveProfile,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildModernFormField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool isFirst = false,
    bool isLast = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: isFirst
              ? BorderSide.none
              : BorderSide(
                  color: CupertinoColors.separator.withOpacity(0.3),
                  width: 0.5,
                ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, isLast ? 20 : 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: readOnly
                    ? CupertinoColors.systemGrey5
                    : primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: readOnly ? CupertinoColors.systemGrey : primaryBlue,
                size: 18,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeholder,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGrey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  CupertinoTextFormFieldRow(
                    controller: controller,
                    placeholder: _isEditing || controller.text.isEmpty
                        ? 'Enter ${placeholder.toLowerCase()}'
                        : null,
                    keyboardType: keyboardType,
                    readOnly: readOnly || !_isEditing,
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: readOnly
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.black,
                    ),
                    placeholderStyle: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.placeholderText,
                    ),
                    validator: validator,
                  ),
                ],
              ),
            ),
            if (readOnly)
              Icon(
                CupertinoIcons.lock_fill,
                size: 14,
                color: CupertinoColors.systemGrey2,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: isFirst
              ? BorderSide.none
              : BorderSide(
                  color: CupertinoColors.separator.withOpacity(0.3),
                  width: 0.5,
                ),
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, isLast ? 20 : 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? CupertinoColors.destructiveRed.withOpacity(0.1)
                      : iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? CupertinoColors.destructiveRed : iconColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? CupertinoColors.destructiveRed
                            : CupertinoColors.black,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.systemGrey2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _drivingDurationController.dispose();
    super.dispose();
  }
}

class TimeoutException implements Exception {
  final String? message;
  TimeoutException(this.message);

  @override
  String toString() {
    return message ?? 'Request timed out';
  }
}