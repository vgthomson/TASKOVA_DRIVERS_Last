import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For icons and Colors not available in Cupertino
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/Model/postcode.dart';
import 'package:taskova_drivers/View/BottomNavigation/bottomnavigation.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';


class ProfileRegistrationPage extends StatefulWidget {
  @override
  _ProfileRegistrationPageState createState() =>
      _ProfileRegistrationPageState();
}

class _ProfileRegistrationPageState extends State<ProfileRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _customExperienceController = TextEditingController();

  bool _isBritishCitizen = false;
  bool _hasCriminalHistory = false;
  bool _hasDisability = false;
  File? _imageFile;
  File? _disabilityCertificateFile;
  final picker = ImagePicker();

  String? _selectedAddress;
  double? _latitude;
  double? _longitude;
  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  late AppLanguage appLanguage;
  String? _selectedHomeAddress;
  double? _homeLatitude;
  double? _homeLongitude;
  bool _formSubmittedSuccessfully = false;
  String? _selectedExperienceType;
  String? _selectedDrivingDuration;
  bool _isCustomExperienceSelected = false;

  // Experience types options based on Django model
  final List<Map<String, String>> _experienceTypeOptions = [
    {'value': 'food_delivery', 'label': 'Food delivery (Uber Eats, Just Eat, etc.)'},
    {'value': 'parcel_delivery', 'label': 'Parcel or courier delivery (Amazon, Evri, etc.)'},
    {'value': 'freelance', 'label': 'Freelance/delivery for local shops'},
    {'value': 'friends_family', 'label': 'I help friends and family with deliveries'},
    {'value': 'no_experience', 'label': 'No experience yet — but ready to roll!'},
    {'value': 'custom', 'label': 'Other (specify)'},
  ];

  // Driving duration options based on Django model
  final List<Map<String, String>> _drivingDurationOptions = [
    {'value': '0-1', 'label': 'Less than 1 year'},
    {'value': '1-2', 'label': '1–2 years'},
    {'value': '3-5', 'label': '3–5 years'},
    {'value': '5+', 'label': '5+ years'},
  ];

  // Updated color scheme
  final Color primaryBlue = Color(0xFF1565C0); // Deep blue
  final Color lightBlue = Color(0xFFE3F2FD); // Very light blue
  final Color whiteColor = Colors.white; // Pure white
  final Color accentBlue = Color(0xFF42A5F5); // Lighter blue for accents

  @override
  void initState() {
    super.initState();
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
    _loadSavedUserData();
  }

  Future<bool> _onWillPop() async {
    if (_formSubmittedSuccessfully) return true;

    final shouldExit = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Exit Profile Registration?'),
        content: Text(
          'Are you sure you want to exit? Your progress will be lost.',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            child: Text('Exit'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

     if (shouldExit ?? false) {
    await _clearAccessToken();
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
    return true;
  }
    return false;
  }

  Future<void> _loadSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('user_email');
    final savedName = prefs.getString('user_name');

    setState(() {
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
      if (savedName != null && savedName.isNotEmpty) {
        _nameController.text = savedName;
      }
      _phoneController.text = '+44 ';
    });
  }

  bool _isValidUKPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(' ', '').replaceAll('+44', '');
    if (cleanPhone.length < 10 || cleanPhone.length > 11) {
      return false;
    }
    return RegExp(r'^[0-9]+$').hasMatch(cleanPhone);
  }

 Future<void> _getImage(
  ImageSource source, {
  bool isDisabilityCertificate = false,
}) async {
  try {
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70, // This sets internal compression, still good to re-encode
    );

    if (pickedFile != null) {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        format: CompressFormat.jpeg,
        quality: 95,
      );

      if (compressedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final compressedFilePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final compressedFile = await File(compressedFilePath).writeAsBytes(compressedBytes);

        setState(() {
          if (isDisabilityCertificate) {
            _disabilityCertificateFile = compressedFile;
          } else {
            _imageFile = compressedFile;
          }
        });
      } else {
        print("Compression failed");
      }
    }
  } catch (e) {
    print('Error during image pick/compression: $e');
  }
}

  Future<void> _searchByPostcode(String postcode) async {
    if (postcode.isEmpty) return;

    setState(() {
      _isSearching = true;
      _selectedAddress = null;
      _latitude = null;
      _longitude = null;
    });

    try {
      List<Location> locations = await locationFromAddress(postcode);

      if (locations.isNotEmpty) {
        Location location = locations.first;
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks.first;
          setState(() {
            _selectedAddress =
                '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.postalCode}, ${placemark.country}';
            _latitude = location.latitude;
            _longitude = location.longitude;
          });
        }
      }
    } catch (e) {
      // Handle error silently or show a subtle message
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _submitMultipartForm() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final url = Uri.parse(ApiConfig.driverProfileUrl);
      final request = http.MultipartRequest('POST', url);

      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      });

      request.fields['name'] = _nameController.text;
      request.fields['phone_number'] = _phoneController.text;
      // request.fields['email'] = _emailController.text;
      request.fields['address'] = _selectedHomeAddress ?? '';
      request.fields['preferred_working_address'] = _selectedAddress ?? '';
      request.fields['latitude'] = _latitude!.toString();
      request.fields['longitude'] = _longitude!.toString();
      request.fields['is_british_citizen'] =
          _isBritishCitizen ? 'true' : 'false';
      request.fields['has_criminal_history'] =
          _hasCriminalHistory ? 'true' : 'false';
      request.fields['has_disability'] = _hasDisability ? 'true' : 'false';
      request.fields['experience_types'] = jsonEncode(
        _selectedExperienceType == 'custom'
            ? [_customExperienceController.text]
            : [_selectedExperienceType],
      );
      request.fields['driving_duration'] = _selectedDrivingDuration ?? '';

      if (_imageFile != null) {
        final fileName = _imageFile!.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        final multipartFile = await http.MultipartFile.fromPath(
          'profile_picture',
          _imageFile!.path,
          contentType: MediaType('image', extension),
          filename: fileName,
        );

        request.files.add(multipartFile);
      }
      if (_hasDisability && _disabilityCertificateFile != null) {
        final fileName = _disabilityCertificateFile!.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        final multipartFile = await http.MultipartFile.fromPath(
          'disability_certificate',
          _disabilityCertificateFile!.path,
          contentType: MediaType('image', extension),
          filename: fileName,
        );

        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Request timed out. Please check your connection.',
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text);

        setState(() {
          _formSubmittedSuccessfully = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => const MainWrapper()),
            (Route<dynamic> route) => false,
          );
        });
        _showSuccessDialog('Profile registered successfully!');
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
                    errors.isNotEmpty ? errors.join('\n') : 'Unknown error occurred';
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
          _errorMessage = 'Error: ${e.toString()}';
        }
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      if (_imageFile == null) {
        _showErrorDialog(appLanguage.get('select_profile_picture'));
        return;
      }

      if (_selectedAddress == null || _latitude == null || _longitude == null) {
        _showErrorDialog(appLanguage.get('select_working_area'));
        return;
      }

      if (_hasDisability && _disabilityCertificateFile == null) {
        _showErrorDialog(
          appLanguage.get('please_upload_disability_certificate'),
        );
        return;
      }

      if (_selectedExperienceType == null) {
        _showErrorDialog('Please select an experience type');
        return;
      }

      if (_selectedDrivingDuration == null) {
        _showErrorDialog('Please select driving duration');
        return;
      }

      await _submitMultipartForm();
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoTheme(
        data: CupertinoThemeData(brightness: Brightness.light),
        child: CupertinoAlertDialog(
          title: Text(
            appLanguage.get('Please submit all required fields'),
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
  void dispose() {
    if (!_formSubmittedSuccessfully) {
      _clearAccessToken();
    }
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _customExperienceController.dispose();
    super.dispose();
  }

  Future<void> _clearAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
    } catch (e) {
      print('Error clearing access token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: CupertinoPageScaffold(
        child: Container(
          color: whiteColor, // Solid white background
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: primaryBlue, // Solid blue header
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(
                            CupertinoIcons.back,
                            color: whiteColor,
                            size: 28,
                          ),
                          onPressed: () async {
                            if (await _onWillPop()) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            appLanguage.get('profile_registration'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: whiteColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isSubmitting
                    ? Container(
                        color: whiteColor,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: lightBlue,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: CupertinoActivityIndicator(
                                  color: primaryBlue,
                                  radius: 20,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                appLanguage.get('submitting_profile_information'),
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_errorMessage != null)
                                Container(
                                  padding: EdgeInsets.all(16),
                                  margin: EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.destructiveRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: CupertinoColors.destructiveRed.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: CupertinoColors.destructiveRed,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              Center(
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: whiteColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryBlue.withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          color: lightBlue,
                                          shape: BoxShape.circle,
                                          image: _imageFile != null
                                              ? DecorationImage(
                                                  image: FileImage(_imageFile!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: _imageFile == null
                                            ? Icon(
                                                CupertinoIcons.person_solid,
                                                size: 70,
                                                color: primaryBlue.withOpacity(0.7),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: accentBlue,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: whiteColor,
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: primaryBlue.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            padding: EdgeInsets.all(10),
                                            child: Icon(
                                              CupertinoIcons.camera_fill,
                                              color: whiteColor,
                                              size: 20,
                                            ),
                                          ),
                                          onPressed: () => _getImage(ImageSource.camera),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 40),
                              _buildFormField(
                                controller: _nameController,
                                placeholder: appLanguage.get('name'),
                                icon: CupertinoIcons.person_fill,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return appLanguage.get('please_enter_name');
                                  }
                                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                                    return appLanguage.get('name_must_contain_only_alphabets');
                                  }
                                  return null;
                                },
                                readOnly: false,
                              ),
                              SizedBox(height: 20),
                              _buildFormField(
                                controller: _emailController,
                                placeholder: appLanguage.get('email'),
                                icon: CupertinoIcons.mail_solid,
                                keyboardType: TextInputType.emailAddress,
                                readOnly: true,
                              ),
                              SizedBox(height: 20),
                              _buildFormField(
                                controller: _phoneController,
                                placeholder: appLanguage.get('phone_number'),
                                icon: CupertinoIcons.phone_fill,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return appLanguage.get('please_enter_phone_number');
                                  }
                                  if (!_isValidUKPhoneNumber(value)) {
                                    return 'Please enter a valid UK phone number';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  if (!value.startsWith('+44')) {
                                    _phoneController.text =
                                        '+44 ' + value.replaceAll('+44', '').trim();
                                    _phoneController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(offset: _phoneController.text.length),
                                    );
                                  }
                                },
                                readOnly: false,
                              ),
                              SizedBox(height: 24),
                              _buildSection(
                                title: appLanguage.get('home_address'),
                                icon: CupertinoIcons.home,
                                child: Column(
                                  children: [
                                    PostcodeSearchWidget(
                                      placeholderText: appLanguage.get('home_postcode'),
                                      onAddressSelected: (latitude, longitude, address) {
                                        setState(() {
                                          _selectedHomeAddress = address;
                                          _homeLatitude = latitude;
                                          _homeLongitude = longitude;
                                        });
                                      },
                                    ),
                                    if (_selectedHomeAddress != null) ...[
                                      SizedBox(height: 16),
                                      _buildSelectedAddressCard(
                                        title: appLanguage.get('selected_home_address'),
                                        address: _selectedHomeAddress!,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              _buildSection(
                                title: 'Delivery Experience',
                                icon: CupertinoIcons.car_detailed,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select one option',
                                      style: TextStyle(
                                        color: primaryBlue.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    ..._experienceTypeOptions.map((option) {
                                      final isSelected = _selectedExperienceType == option['value'];
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 12),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedExperienceType = option['value'];
                                              _isCustomExperienceSelected = option['value'] == 'custom';
                                              if (!_isCustomExperienceSelected) {
                                                _customExperienceController.clear();
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected ? lightBlue : whiteColor,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? primaryBlue
                                                    : primaryBlue.withOpacity(0.2),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isSelected
                                                      ? CupertinoIcons.checkmark_circle_fill
                                                      : CupertinoIcons.circle,
                                                  color: isSelected
                                                      ? primaryBlue
                                                      : primaryBlue.withOpacity(0.6),
                                                  size: 20,
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    option['label']!,
                                                    style: TextStyle(
                                                      color: primaryBlue,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    if (_isCustomExperienceSelected) ...[
                                      SizedBox(height: 12),
                                      _buildFormField(
                                        controller: _customExperienceController,
                                        placeholder: 'Specify other experience',
                                        icon: CupertinoIcons.textbox,
                                        validator: (value) {
                                          if (_selectedExperienceType == 'custom' &&
                                              (value == null || value.isEmpty)) {
                                            return 'Please specify custom experience';
                                          }
                                          return null;
                                        },
                                        readOnly: false,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              _buildSection(
                                title: 'Driving Experience',
                                icon: CupertinoIcons.time,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: whiteColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: primaryBlue.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              CupertinoIcons.time,
                                              color: primaryBlue,
                                              size: 22,
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _selectedDrivingDuration == null
                                                    ? 'Select driving duration'
                                                    : _drivingDurationOptions
                                                        .firstWhere((option) =>
                                                            option['value'] ==
                                                            _selectedDrivingDuration)['label']!,
                                                style: TextStyle(
                                                  color: _selectedDrivingDuration == null
                                                      ? primaryBlue.withOpacity(0.6)
                                                      : primaryBlue,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              CupertinoIcons.chevron_down,
                                              color: primaryBlue,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                      onPressed: () {
                                        showCupertinoModalPopup(
                                          context: context,
                                          builder: (context) => CupertinoActionSheet(
                                            title: Text(
                                              'Driving Experience',
                                              style: TextStyle(
                                                color: primaryBlue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            actions: _drivingDurationOptions
                                                .map(
                                                  (option) => CupertinoActionSheetAction(
                                                    child: Text(
                                                      option['label']!,
                                                      style: TextStyle(
                                                        color: primaryBlue,
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedDrivingDuration = option['value'];
                                                      });
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                )
                                                .toList(),
                                            cancelButton: CupertinoActionSheetAction(
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: CupertinoColors.destructiveRed,
                                                ),
                                              ),
                                              onPressed: () => Navigator.pop(context),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (_selectedDrivingDuration != null) ...[
                                      SizedBox(height: 12),
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: lightBlue,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: primaryBlue.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          _drivingDurationOptions.firstWhere((option) =>
                                              option['value'] == _selectedDrivingDuration)['label']!,
                                          style: TextStyle(
                                            color: primaryBlue,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              _buildToggleRow(
                                text: appLanguage.get('are_u_british'),
                                value: _isBritishCitizen,
                                icon: CupertinoIcons.flag,
                                onChanged: (value) {
                                  setState(() {
                                    _isBritishCitizen = value;
                                  });
                                },
                              ),
                              SizedBox(height: 16),
                              _buildToggleRow(
                                text: appLanguage.get('Have you ever been convicted of a criminal offence?'),
                                value: _hasCriminalHistory,
                                icon: CupertinoIcons.doc_checkmark,
                                onChanged: (value) {
                                  setState(() {
                                    _hasCriminalHistory = value;
                                  });
                                },
                              ),
                              SizedBox(height: 16),
                              _buildToggleRow(
                                text: appLanguage.get('Do you have a disability or accessibility need?'),
                                value: _hasDisability,
                                icon: CupertinoIcons.heart,
                                onChanged: (value) {
                                  setState(() {
                                    _hasDisability = value;
                                    if (!value) {
                                      _disabilityCertificateFile = null;
                                    }
                                  });
                                },
                              ),
                              if (_hasDisability) ...[
                                SizedBox(height: 20),
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: whiteColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: primaryBlue.withOpacity(0.3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryBlue.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.doc_text,
                                            color: primaryBlue,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            appLanguage.get('disability_certificate'),
                                            style: TextStyle(
                                              color: primaryBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      _disabilityCertificateFile != null
                                          ? Container(
                                              padding: EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: lightBlue,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: primaryBlue.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    CupertinoIcons.doc,
                                                    size: 40,
                                                    color: primaryBlue,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      _disabilityCertificateFile!.path.split('/').last,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: primaryBlue,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  CupertinoButton(
                                                    padding: EdgeInsets.zero,
                                                    child: Icon(
                                                      CupertinoIcons.trash,
                                                      color: CupertinoColors.destructiveRed,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _disabilityCertificateFile = null;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            )
                                          : CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              child: Container(
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: primaryBlue,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: primaryBlue.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      spreadRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                                padding: EdgeInsets.symmetric(vertical: 16),
                                                child: Text(
                                                  appLanguage.get('upload_certificate'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: whiteColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              onPressed: () => _getImage(
                                                ImageSource.gallery,
                                                isDisabilityCertificate: true,
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                              SizedBox(height: 24),
                              _buildSection(
                                title: appLanguage.get('working_area'),
                                icon: CupertinoIcons.location,
                                child: Column(
                                  children: [
                                    PostcodeSearchWidget(
                                      postcodeController: _postcodeController,
                                      placeholderText: appLanguage.get('postcode'),
                                      onAddressSelected: (latitude, longitude, address) {
                                        setState(() {
                                          _selectedAddress = address;
                                          _latitude = latitude;
                                          _longitude = longitude;
                                        });
                                      },
                                    ),
                                    if (_selectedAddress != null) ...[
                                      SizedBox(height: 16),
                                      _buildSelectedAddressCard(
                                        title: appLanguage.get('selected_working_area'),
                                        address: _selectedAddress!,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: 40),
                              Container(
                                decoration: BoxDecoration(
                                  color: primaryBlue,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CupertinoButton(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.checkmark_circle_fill,
                                        color: whiteColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        appLanguage.get('confirm').toUpperCase(),
                                        style: TextStyle(
                                          color: whiteColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onPressed: _submitForm,
                                ),
                              ),
                              SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    required bool readOnly,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: whiteColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CupertinoFormRow(
        child: CupertinoTextFormFieldRow(
          controller: controller,
          placeholder: placeholder,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefix: Container(
            margin: EdgeInsets.only(right: 12),
            child: Icon(icon, color: primaryBlue, size: 22),
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(
            color: primaryBlue,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          placeholderStyle: TextStyle(
            color: primaryBlue.withOpacity(0.6),
            fontSize: 16,
          ),
          decoration: BoxDecoration(color: Colors.transparent),
          validator: validator,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: whiteColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: whiteColor, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String text,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: whiteColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? primaryBlue.withOpacity(0.5) : primaryBlue.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: value ? primaryBlue : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: whiteColor, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.2),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: primaryBlue,
              trackColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAddressCard({
    required String title,
    required String address,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.location_solid, color: primaryBlue, size: 18),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            address,
            style: TextStyle(color: primaryBlue, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
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