import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show  Colors;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Homepage/admin_approval.dart';
import 'package:taskova_drivers/View/Staticpages/britishpassport.dart';
import 'package:taskova_drivers/View/Staticpages/driver_licence.dart';
import 'package:taskova_drivers/View/Staticpages/dvls.dart';
import 'package:taskova_drivers/View/Staticpages/proof_of_address.dart';
import 'package:taskova_drivers/View/Staticpages/proof_of_identity.dart';
import 'package:taskova_drivers/View/Staticpages/right_to_work.dart';
import 'package:taskova_drivers/View/Staticpages/vehicle_insurance.dart';



class DocumentRegistrationPage extends StatefulWidget {
  const DocumentRegistrationPage({Key? key}) : super(key: key);

  @override
  State<DocumentRegistrationPage> createState() =>
      _DocumentRegistrationPageState();
}

class _DocumentRegistrationPageState extends State<DocumentRegistrationPage> {
  final ImagePicker _picker = ImagePicker();
  bool? _isBritishCitizen;
  bool _isLoading = false;

  // Store image files
  File? _idFront;
  File? _idBack;
  File? _passportFront;
  File? _passportBack;
  File? _rightToWorkUKFront;
  File? _rightToWorkUKBack;
  File? _addressProofFront;
  File? _addressProofBack;
  File? _vehicleInsuranceFront;
  File? _vehicleInsuranceBack;
  File? _drivingLicenseFront;
  File? _drivingLicenseBack;
  File? _dvlsFront;
  File? _dvlsBack;

  // Text controllers for document details
  final TextEditingController _identityDetailsController =
      TextEditingController();
  final TextEditingController _rightToWorkDetailsController =
      TextEditingController();
  final TextEditingController _addressDetailsController =
      TextEditingController();
  final TextEditingController _insuranceDetailsController =
      TextEditingController();
  final TextEditingController _licenseDetailsController =
      TextEditingController();
  final TextEditingController _dvlaController = TextEditingController();

  // Track completion status
  Map<String, bool> _documentStatus = {
    'identity': false,
    'citizenship': false,
    'address': false,
    'insurance': false,
    'license': false,
    'dvla': false,
  };

  // Professional Color Scheme
  final Color _primaryColor = const Color(0xFF0A66C2); // LinkedIn blue
  final Color _backgroundColor = CupertinoColors.systemGroupedBackground;
  final Color _cardColor = CupertinoColors.white;
  final Color _successColor = const Color(0xFF057642); // Professional green
  final Color _warningColor = const Color(0xFFE16F24); // Professional orange
  final Color _textPrimary = const Color(0xFF000000);
  final Color _textSecondary = const Color(0xFF666666);
  final Color _borderColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _fetchCitizenshipStatus();
  }

  @override
  void dispose() {
    _identityDetailsController.dispose();
    _rightToWorkDetailsController.dispose();
    _addressDetailsController.dispose();
    _insuranceDetailsController.dispose();
    _licenseDetailsController.dispose();
    _dvlaController.dispose();
    super.dispose();
  }

  void _updateDocumentStatus() {
    setState(() {
      _documentStatus['identity'] =
          _idFront != null &&
          _idBack != null &&
          _identityDetailsController.text.trim().isNotEmpty;
      if (_isBritishCitizen != null) {
        _documentStatus['citizenship'] =
            _isBritishCitizen!
                ? (_passportFront != null &&
                    _passportBack != null &&
                    _rightToWorkDetailsController.text.trim().isNotEmpty)
                : (_rightToWorkUKFront != null &&
                    _rightToWorkUKBack != null &&
                    _rightToWorkDetailsController.text.trim().isNotEmpty);
      }
      _documentStatus['address'] =
          _addressProofFront != null &&
          _addressProofBack != null &&
          _addressDetailsController.text.trim().isNotEmpty;
      _documentStatus['insurance'] =
          _vehicleInsuranceFront != null &&
          _vehicleInsuranceBack != null &&
          _insuranceDetailsController.text.trim().isNotEmpty;
      _documentStatus['license'] =
          _drivingLicenseFront != null &&
          _drivingLicenseBack != null &&
          _licenseDetailsController.text.trim().isNotEmpty;
      _documentStatus['dvla'] =
          _dvlsFront != null &&
          _dvlsBack != null &&
          _dvlaController.text.trim().isNotEmpty;
    });
  }

  Future<void> _fetchCitizenshipStatus() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) throw Exception('Access token not found');

      final response = await http.get(
        Uri.parse(ApiConfig.driverProfileUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _isBritishCitizen =
              responseData['is_british_citizen'] as bool? ?? false;
        });
      } else {
        throw Exception('Failed to load status: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error loading profile: ${e.toString()}');
      setState(() => _isBritishCitizen = false);
    } finally {
      setState(() => _isLoading = false);
      _updateDocumentStatus();
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('Upload Required'),
            // content: Padding(
            //   padding: const EdgeInsets.only(top: 8.0),
            //   child: Text(message, style: TextStyle(color: _textPrimary)),
            // ),
            actions: [
              CupertinoDialogAction(
                child: Text('Retry', style: TextStyle(color: _primaryColor)),
                onPressed: () {
                  Navigator.pop(context);
                  _fetchCitizenshipStatus();
                },
              ),
              CupertinoDialogAction(
                child: Text('OK', style: TextStyle(color: _primaryColor)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(message, style: TextStyle(color: _textPrimary)),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text('Continue', style: TextStyle(color: _primaryColor)),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    CupertinoPageRoute(
                      builder:
                          (context) =>
                              const DocumentVerificationPendingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
    );
  }

  Future<File?> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      // _showErrorDialog('Error selecting image: ${e.toString()}');
      return null;
    }
  }

  // String _getDocumentTitle(String documentType) {
  //   switch (documentType) {
  //     case 'IDENTITY':
  //       return 'Identity';
  //     case 'RIGHT_TO_WORK':
  //       return 'Right to Work';
  //     case 'ADDRESS':
  //       return 'Address Proof';
  //     case 'INSURANCE':
  //       return 'Vehicle Insurance';
  //     case 'LICENSE':
  //       return 'Driving License';
  //     case 'DVLA':
  //       return 'DVLA Electronic Counterpart';
  //     default:
  //       return 'Document';
  //   }
  // }

  Future<bool> _uploadDocument({
    required String documentType,
    required File frontImage,
    required File backImage,
    required String details,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) throw Exception('Access token not found');

      final uri = Uri.parse(ApiConfig.driverDocumentUrl);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['document_type'] = documentType;

      switch (documentType) {
        case 'IDENTITY':
          request.fields['identity_details'] = details;
          break;
        case 'RIGHT_TO_WORK':
          request.fields['right_to_work_details'] = details;
          break;
        case 'ADDRESS':
          request.fields['address_details'] = details;
          break;
        case 'INSURANCE':
          request.fields['insurance_details'] = details;
          break;
        case 'LICENSE':
          request.fields['license_details'] = details;
          break;
        case 'DVLA':
          request.fields['dvla_details'] = details;
          break;
      }

      request.files.add(
        await http.MultipartFile.fromPath('front_image', frontImage.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('back_image', backImage.path),
      );

      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Upload success: $responseString');
        return true;
      } else {
        debugPrint('Upload failed: $responseString');
        return false;
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      return false;
    }
  }

  Future<void> _submitAllDocuments() async {
    setState(() => _isLoading = true);
    try {
      if (_idFront == null || _idBack == null) {
        throw Exception('Please upload both sides of your Proof of Identity');
      }
      if (_identityDetailsController.text.trim().isEmpty) {
        throw Exception('Please provide details for Proof of Identity');
      }
      if (_isBritishCitizen == null) {
        throw Exception('Citizenship status not loaded. Please try again.');
      }
      if (_isBritishCitizen!) {
        if (_passportFront == null || _passportBack == null) {
          throw Exception('Please upload both sides of your British Passport');
        }
        if (_rightToWorkDetailsController.text.trim().isEmpty) {
          throw Exception('Please provide details for British Passport');
        }
      } else {
        if (_rightToWorkUKFront == null || _rightToWorkUKBack == null) {
          throw Exception(
            'Please upload both sides of your Right to Work document',
          );
        }
        if (_rightToWorkDetailsController.text.trim().isEmpty) {
          throw Exception('Please provide details for Right to Work');
        }
      }
      if (_addressProofFront == null || _addressProofBack == null) {
        throw Exception('Please upload both sides of your Address Proof');
      }
      if (_addressDetailsController.text.trim().isEmpty) {
        throw Exception('Please provide details for Address Proof');
      }
      if (_vehicleInsuranceFront == null || _vehicleInsuranceBack == null) {
        throw Exception('Please upload both sides of your Vehicle Insurance');
      }
      if (_insuranceDetailsController.text.trim().isEmpty) {
        throw Exception('Please provide details for Vehicle Insurance');
      }
      if (_drivingLicenseFront == null || _drivingLicenseBack == null) {
        throw Exception('Please upload both sides of your Driving License');
      }
      if (_licenseDetailsController.text.trim().isEmpty) {
        throw Exception('Please provide details for Driving License');
      }
      if (_dvlsFront == null || _dvlsBack == null) {
        throw Exception(
          'Please upload both sides of your DVLA Electronic Counterpart',
        );
      }
      if (_dvlaController.text.trim().isEmpty) {
        throw Exception(
          'Please provide details for DVLA Electronic Counterpart',
        );
      }

      List<Future<bool>> uploads = [
        _uploadDocument(
          documentType: 'IDENTITY',
          frontImage: _idFront!,
          backImage: _idBack!,
          details: _identityDetailsController.text,
        ),
        _uploadDocument(
          documentType: 'RIGHT_TO_WORK',
          frontImage:
              _isBritishCitizen! ? _passportFront! : _rightToWorkUKFront!,
          backImage: _isBritishCitizen! ? _passportBack! : _rightToWorkUKBack!,
          details: _rightToWorkDetailsController.text,
        ),
        _uploadDocument(
          documentType: 'ADDRESS',
          frontImage: _addressProofFront!,
          backImage: _addressProofBack!,
          details: _addressDetailsController.text,
        ),
        _uploadDocument(
          documentType: 'INSURANCE',
          frontImage: _vehicleInsuranceFront!,
          backImage: _vehicleInsuranceBack!,
          details: _insuranceDetailsController.text,
        ),
        _uploadDocument(
          documentType: 'LICENSE',
          frontImage: _drivingLicenseFront!,
          backImage: _drivingLicenseBack!,
          details: _licenseDetailsController.text,
        ),
        _uploadDocument(
          documentType: 'DVLA',
          frontImage: _dvlsFront!,
          backImage: _dvlsBack!,
          details: _dvlaController.text,
        ),
      ];

      final results = await Future.wait(uploads);
      if (results.contains(false)) {
        throw Exception('Some documents failed to upload. Please try again.');
      }

      _showSuccessDialog('All documents submitted successfully!');
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.doc_text_fill,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Verification',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete your application by uploading all required documents',
                      style: TextStyle(
                        fontSize: 15,
                        color: _textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final completedDocs = _documentStatus.values.where((v) => v).length;
    final totalDocs = _documentStatus.length;
    final progress = completedDocs / totalDocs;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Application Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: progress == 1.0 ? _successColor : _primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedDocs/$totalDocs Complete',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: _borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: progress == 1.0 ? _successColor : _primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progress == 1.0
                ? 'All documents uploaded! Ready to submit.'
                : 'Upload ${totalDocs - completedDocs} more documents to complete your application.',
            style: TextStyle(
              fontSize: 14,
              color: progress == 1.0 ? _successColor : _textSecondary,
              fontWeight: progress == 1.0 ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 15, color: _textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required IconData icon,
    required File? frontFile,
    required File? backFile,
    required Function(File?) onFrontUploaded,
    required Function(File?) onBackUploaded,
    bool isRequired = true,
    TextEditingController? detailsController,
    String documentType = '',
  }) {
    final isComplete =
        frontFile != null &&
        backFile != null &&
        (detailsController == null || detailsController.text.trim().isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? _successColor : _borderColor,
          width: isComplete ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isComplete
                            ? _successColor.withOpacity(0.1)
                            : _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isComplete
                        ? CupertinoIcons.checkmark_alt_circle_fill
                        : icon,
                    color: isComplete ? _successColor : _primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          if (isComplete)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Complete',
                                style: TextStyle(
                                  color: _successColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (!isComplete && isRequired)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Required',
                                style: TextStyle(
                                  color: _warningColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        child: Text(
                          "Learn more about this document",
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () => _navigateToDocumentInfo(title),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Upload Section
            Row(
              children: [
                _buildImageUpload(
                  label: 'Front Side',
                  file: frontFile,
                  onPressed: () async {
                    final file = await _pickImage();
                    if (file != null) {
                      onFrontUploaded(file);
                      _updateDocumentStatus();
                    }
                  },
                ),
                const SizedBox(width: 12),
                _buildImageUpload(
                  label: 'Back Side',
                  file: backFile,
                  onPressed: () async {
                    final file = await _pickImage();
                    if (file != null) {
                      onBackUploaded(file);
                      _updateDocumentStatus();
                    }
                  },
                ),
              ],
            ),
            // Details Section
            if (detailsController != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Additional Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  if (isRequired && detailsController.text.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '(Required)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _warningColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: detailsController,
                placeholder: 'Add any relevant details about this document...',
                maxLines: 2,
                style: TextStyle(color: _textPrimary, fontSize: 15),
                placeholderStyle: TextStyle(color: _textSecondary),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        detailsController.text.trim().isEmpty && isRequired
                            ? _warningColor
                            : _borderColor,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: _cardColor,
                ),
                padding: const EdgeInsets.all(12),
                onChanged: (value) {
                  _updateDocumentStatus();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToDocumentInfo(String title) {
    Widget page;
    switch (title) {
      case 'Proof of Identity':
        page = const IdentityVerificationScreen();
        break;
      case 'British Passport':
        page = const BritishPassport();
        break;
      case 'Right to Work in UK':
        page = const RightToWork();
        break;
      case 'Proof of Address':
        page = const ProofOfAddress();
        break;
      case 'Vehicle Insurance':
        page = const VehicleInsurance();
        break;
      case 'Driving License':
        page = const DriverLicence();
        break;
      case 'DVLA Electronic Counterpart':
        page = const DvlsDocument();
        break;
      default:
        return;
    }
    Navigator.push(context, CupertinoPageRoute(builder: (context) => page));
  }

  Widget _buildImageUpload({
    required String label,
    required File? file,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: file != null ? null : CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: file != null ? _successColor : _borderColor,
              width: file != null ? 2 : 1,
            ),
          ),
          child:
              file != null
                  ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _successColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.checkmark,
                            color: CupertinoColors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.camera_fill,
                        color: _textSecondary,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to upload',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final allComplete = _documentStatus.values.every((status) => status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Final Step',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            allComplete
                ? 'All documents are ready. Submit your application for review.'
                : 'Please complete all document uploads and details before submitting.',
            style: TextStyle(fontSize: 15, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            onPressed: _isLoading || !allComplete ? null : _submitAllDocuments,
            padding: const EdgeInsets.symmetric(vertical: 16),
            borderRadius: BorderRadius.circular(12),
            color: allComplete ? _primaryColor : _borderColor,
            child:
                _isLoading
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Submitting...',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ],
                    )
                    : Text(
                      'Submit Application',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color:
                            allComplete
                                ? CupertinoColors.white
                                : _textSecondary,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _cardColor.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(color: _borderColor.withOpacity(0.3), width: 0.5),
        ),
        middle: Text(
          'Document Upload',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.back, color: _primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            _isLoading && _isBritishCitizen == null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoActivityIndicator(
                        radius: 16,
                        color: _primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your profile...',
                        style: TextStyle(fontSize: 16, color: _textSecondary),
                      ),
                    ],
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildProgressSection(),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        'Identity Verification',
                        'Required documents to verify your identity',
                      ),
                      _buildDocumentCard(
                        title: 'Proof of Identity',
                        icon: CupertinoIcons.person_badge_plus,
                        frontFile: _idFront,
                        backFile: _idBack,
                        onFrontUploaded:
                            (file) => setState(() => _idFront = file),
                        onBackUploaded:
                            (file) => setState(() => _idBack = file),
                        isRequired: true,
                        detailsController: _identityDetailsController,
                        documentType: 'IDENTITY',
                      ),
                      _buildSectionHeader(
                        'Citizenship & Work Authorization',
                        _isBritishCitizen == true
                            ? 'British passport required for citizens'
                            : 'Right to work documentation required',
                      ),
                      if (_isBritishCitizen == true)
                        _buildDocumentCard(
                          title: 'British Passport',
                          icon: CupertinoIcons.doc_text,
                          frontFile: _passportFront,
                          backFile: _passportBack,
                          onFrontUploaded:
                              (file) => setState(() => _passportFront = file),
                          onBackUploaded:
                              (file) => setState(() => _passportBack = file),
                          isRequired: true,
                          detailsController: _rightToWorkDetailsController,
                          documentType: 'RIGHT_TO_WORK',
                        )
                      else
                        _buildDocumentCard(
                          title: 'Right to Work in UK',
                          icon: CupertinoIcons.globe,
                          frontFile: _rightToWorkUKFront,
                          backFile: _rightToWorkUKBack,
                          onFrontUploaded:
                              (file) =>
                                  setState(() => _rightToWorkUKFront = file),
                          onBackUploaded:
                              (file) =>
                                  setState(() => _rightToWorkUKBack = file),
                          isRequired: true,
                          detailsController: _rightToWorkDetailsController,
                          documentType: 'RIGHT_TO_WORK',
                        ),
                      _buildSectionHeader(
                        'Address Verification',
                        'Proof of your current residential address',
                      ),
                      _buildDocumentCard(
                        title: 'Proof of Address',
                        icon: CupertinoIcons.location_solid,
                        frontFile: _addressProofFront,
                        backFile: _addressProofBack,
                        onFrontUploaded:
                            (file) => setState(() => _addressProofFront = file),
                        onBackUploaded:
                            (file) => setState(() => _addressProofBack = file),
                        isRequired: true,
                        detailsController: _addressDetailsController,
                        documentType: 'ADDRESS',
                      ),
                      _buildSectionHeader(
                        'Driving Documentation',
                        'Required documents for vehicle operation',
                      ),
                      _buildDocumentCard(
                        title: 'Vehicle Insurance',
                        icon: CupertinoIcons.car_detailed,
                        frontFile: _vehicleInsuranceFront,
                        backFile: _vehicleInsuranceBack,
                        onFrontUploaded:
                            (file) =>
                                setState(() => _vehicleInsuranceFront = file),
                        onBackUploaded:
                            (file) =>
                                setState(() => _vehicleInsuranceBack = file),
                        isRequired: true,
                        detailsController: _insuranceDetailsController,
                        documentType: 'INSURANCE',
                      ),
                      _buildDocumentCard(
                        title: 'Driving License',
                        icon: CupertinoIcons.creditcard,
                        frontFile: _drivingLicenseFront,
                        backFile: _drivingLicenseBack,
                        onFrontUploaded:
                            (file) =>
                                setState(() => _drivingLicenseFront = file),
                        onBackUploaded:
                            (file) =>
                                setState(() => _drivingLicenseBack = file),
                        isRequired: true,
                        detailsController: _licenseDetailsController,
                        documentType: 'LICENSE',
                      ),
                      _buildDocumentCard(
                        title: 'DVLA Electronic Counterpart',
                        icon: CupertinoIcons.doc_checkmark,
                        frontFile: _dvlsFront,
                        backFile: _dvlsBack,
                        onFrontUploaded:
                            (file) => setState(() => _dvlsFront = file),
                        onBackUploaded:
                            (file) => setState(() => _dvlsBack = file),
                        isRequired: true,
                        detailsController: _dvlaController,
                        documentType: 'DVLA',
                      ),
                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
            if (_isLoading && _isBritishCitizen != null)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: CupertinoActivityIndicator(
                    radius: 16,
                    color: _primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}