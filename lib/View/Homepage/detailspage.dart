import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Chat/chat.dart';
import 'package:taskova_drivers/View/Homepage/admin_approval.dart';
import 'package:taskova_drivers/View/Homepage/homepage.dart';
import 'package:taskova_drivers/View/driver_document.dart';


class JobDetailPage extends StatefulWidget {
  final JobPost jobPost;

  const JobDetailPage({Key? key, required this.jobPost}) : super(key: key);

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with SingleTickerProviderStateMixin {
  String? _jobRequestId;
  bool _isAccepted = false;
  bool _isLoading = false;
  bool _hasApplied = false; // New flag to track application status
  String? _chatRoomId;
  String? _driverId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _reviewController = TextEditingController();
  double _rating = 0.0;
  bool _hasSubmittedReview = false; // New flag to track review submission
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _checkIfAlreadyApplied();
        _checkIfReviewExists(); // Add this to check for existing review

  }

  @override
  void dispose() {
    _animationController.dispose();
    _reviewController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyApplied() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse(ApiConfig.jobRequestUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobRequests = jsonDecode(response.body);
        final appliedJob = jobRequests.firstWhere(
          (request) => request['job'] == widget.jobPost.id,
          orElse: () => null,
        );

        if (appliedJob != null) {
          setState(() {
            _jobRequestId = appliedJob['id'].toString();
            _hasApplied = true; // Set applied status
          });
          _checkIfJobIsAccepted();
        }
      }
    } catch (e) {
      print('Error checking applied jobs: $e');
    }
  }
Future<void> _checkIfReviewExists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reviewKey = 'review_submitted_${widget.jobPost.id}';
      final hasSubmitted = prefs.getBool(reviewKey) ?? false;

      if (mounted) {
        setState(() {
          _hasSubmittedReview = hasSubmitted;
        });
      }
    } catch (e) {
      print('Error checking review status: $e');
    }
  }

  Future<void> _checkIfJobIsAccepted() async {
    if (_jobRequestId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.jobRequestsAcceptedUrl}$_jobRequestId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isAccepted = data['is_accepted'] ?? false;
            _chatRoomId = data['chat_room_id']?.toString();
            _driverId = data['driver_id']?.toString();
          });
        }
      }
    } catch (e) {
      print('Error checking job acceptance: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

Future<void> _submitReview() async {
  try {
    // Retrieve access token
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken == null || accessToken.isEmpty) {
      _showErrorMessage(context, 'Authentication error: Access token is missing.');
      return;
    }

    // Validate required fields
    if (widget.jobPost.id == null || widget.jobPost.businessId == null) {
      _showErrorMessage(context, 'Error: Job ID or Business ID is missing.');
      return;
    }
    if (_rating <= 0) {
      _showErrorMessage(context, 'Please provide a rating.');
      return;
    }
    if (_reviewController.text.trim().isEmpty) {
      _showErrorMessage(context, 'Please enter your feedback.');
      return;
    }

    // Prepare request body
    final requestBody = {
      'rater_type': 'user',
      'ratee_type': 'business',
      'job': widget.jobPost.id,
      'ratee': widget.jobPost.businessId,
      'rating': _rating.toInt(), // Convert rating to integer
      'comment': _reviewController.text.trim(),
    };

    print('Submitting review with body: $requestBody'); // Log request body for debugging

    // Make HTTP POST request
    final response = await http.post(
      Uri.parse(ApiConfig.ratingsUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    print('Response status: ${response.statusCode}'); // Log status code
    print('Response body: ${response.body}'); // Log response body

    if (response.statusCode == 201) {
       final reviewKey = 'review_submitted_${widget.jobPost.id}';
        await prefs.setBool(reviewKey, true);
      _showSuccessMessage(context, 'Review submitted successfully!');
      if (mounted) {
        setState(() {
          _reviewController.clear();
          _rating = 0.0;
          _hasSubmittedReview = true; // Set flag to true after successful submission
        });
      }
    } else {
      // Parse error message from response if available
      String errorMessage = 'Failed to submit review. Please try again.';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['detail'] ?? errorData['message'] ?? errorMessage;
      } catch (_) {
        // If response body is not JSON, use default message
      }
      // _showErrorMessage(context, errorMessage);
    }
  } catch (e, stackTrace) {
    print('Error submitting review: $e\n$stackTrace'); // Log error and stack trace
    _showErrorMessage(context, 'Error submitting review: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGrey6,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverNavigationBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildBusinessImage(),
                _buildJobHeader(),
                _buildJobContent(),
                SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverNavigationBar() {
    return CupertinoSliverNavigationBar(
      largeTitle: Text(
        widget.jobPost.title,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.black,
        ),
      ),
      middle: Text(
        widget.jobPost.businessName,
        style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
      ),
      backgroundColor: CupertinoColors.white,
      border: null,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Icon(
          CupertinoIcons.back,
          color: CupertinoColors.activeBlue,
          size: 28,
        ),
        onPressed: () => Navigator.pop(context),
      ),
   
    );
  }

  Widget _buildBusinessImage() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CupertinoColors.systemGrey5, CupertinoColors.white],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.jobPost.businessImage != null &&
                  widget.jobPost.businessImage!.isNotEmpty
              ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: Image.network(
                    widget.jobPost.businessImage!.startsWith('http')
                        ? widget.jobPost.businessImage!
                        : '${ApiConfig.getImageUrl}${widget.jobPost.businessImage}',
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => _buildPlaceholderImage(),
                  ),
                )
              : _buildPlaceholderImage(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOverlayChip(
                      CupertinoIcons.calendar,
                      widget.jobPost.jobDate ?? 'TBD',
                      CupertinoColors.systemGreen,
                    ),
                    if (widget.jobPost.distanceMiles != null)
                      _buildOverlayChip(
                        CupertinoIcons.location_solid,
                        formatDistance(widget.jobPost.distanceMiles),
                        CupertinoColors.systemBlue,
                      ),
                  ],
                ),
                SizedBox(height: 8),
                _buildOverlayChip(
                  CupertinoIcons.clock,
                  '${widget.jobPost.startTime ?? 'N/A'} - ${widget.jobPost.endTime ?? 'N/A'}',
                  CupertinoColors.systemOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: CupertinoColors.systemGrey4,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.building_2_fill,
              size: 80,
              color: CupertinoColors.systemGrey2,
            ),
            SizedBox(height: 8),
            Text(
              'No Image Available',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeader() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.jobPost.distanceMiles != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CupertinoColors.systemBlue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        size: 16,
                        color: CupertinoColors.systemBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        formatDistance(widget.jobPost.distanceMiles),
                        style: TextStyle(
                          color: CupertinoColors.systemBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                CupertinoIcons.calendar,
                'Date',
                widget.jobPost.jobDate ?? 'TBD',
                CupertinoColors.systemGreen,
              ),
              SizedBox(width: 12),
              _buildInfoChip(
                CupertinoIcons.clock,
                'Time',
                '${widget.jobPost.startTime ?? 'N/A'} - ${widget.jobPost.endTime ?? 'N/A'}',
                CupertinoColors.systemOrange,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              if (widget.jobPost.hourlyRate != null)
                _buildInfoChip(
                  CupertinoIcons.money_dollar_circle,
                  'Hourly',
                  '\$${widget.jobPost.hourlyRate?.toStringAsFixed(2)}',
                  CupertinoColors.systemPurple,
                ),
              if (widget.jobPost.hourlyRate != null &&
                  widget.jobPost.perDeliveryRate != null)
                SizedBox(width: 12),
              if (widget.jobPost.perDeliveryRate != null)
                _buildInfoChip(
                  CupertinoIcons.car_detailed,
                  'Per Delivery',
                  '\$${widget.jobPost.perDeliveryRate?.toStringAsFixed(2)}',
                  CupertinoColors.systemTeal,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSection(
            'Job Description',
            widget.jobPost.description ?? 'No description available',
            CupertinoIcons.doc_text,
          ),
          SizedBox(height: 16),
          _buildLocationSection(),
          SizedBox(height: 16),
          _buildBenefitsSection(),
          SizedBox(height: 16),
if (_isAccepted && !_hasSubmittedReview) ...[
          SizedBox(height: 16),
          _buildReviewSection(),
        ],     SizedBox(height: 16),
              _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: CupertinoColors.systemBlue,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CupertinoIcons.location_solid,
                      color: CupertinoColors.systemGreen,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.systemGrey5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location,
                          color: CupertinoColors.systemGrey,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.jobPost.address}',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.jobPost.distanceMiles != null) ...[
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.arrow_right_arrow_left,
                            color: CupertinoColors.systemGrey,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Distance: ${formatDistance(widget.jobPost.distanceMiles)}',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = widget.jobPost.complimentaryBenefits;
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CupertinoIcons.gift,
                      color: CupertinoColors.systemPurple,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Benefits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              benefits.isEmpty
                  ? Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CupertinoColors.systemGrey5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.info_circle,
                            color: CupertinoColors.systemGrey2,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No additional benefits listed',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: benefits
                          .map(
                            (benefit) => Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    CupertinoColors.systemGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: CupertinoColors.systemGreen,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.checkmark_circle,
                                    color: CupertinoColors.systemGreen,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      benefit.toString(),
                                      style: TextStyle(
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
  return SlideTransition(
    position: _slideAnimation,
    child: FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    CupertinoIcons.star_fill,
                    color: CupertinoColors.systemYellow,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Leave a Review',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Rate your experience',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemGrey,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _rating
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      color: CupertinoColors.systemYellow,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 20),
            Text(
              'Your Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemGrey,
              ),
            ),
            SizedBox(height: 12),
            CupertinoTextField(
              controller: _reviewController,
              placeholder: 'Share your experience...',
              placeholderStyle: TextStyle(
                color: CupertinoColors.systemGrey2,
                fontSize: 16,
              ),
              minLines: 3,
              maxLines: 5,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              style: TextStyle(
                color: CupertinoColors.black,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: _rating > 0 && _reviewController.text.isNotEmpty
                    ? _submitReview
                    : null,
                color: CupertinoColors.activeBlue,
                child: Text(
                  'Submit Review',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.all(16),
      color: CupertinoColors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAccepted && _chatRoomId != null) ...[
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => ChatPage(
                          driverId: _driverId!,
                          chatRoomId: _chatRoomId!,
                          businessName: widget.jobPost.businessName,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Chat with ${widget.jobPost.businessName}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? Center(
                      child: CupertinoActivityIndicator(
                        color: CupertinoColors.activeBlue,
                      ),
                    )
                  : _hasApplied || _isAccepted
    ? CupertinoButton(
        onPressed: () {}, // Do nothing, but keep it enabled for color
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: CupertinoColors.systemGreen,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle,
              size: 24,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 8),
            Text(
              'Applied',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      )
    : CupertinoButton(
        onPressed: () => _handleJobApplication(context),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: CupertinoColors.activeBlue,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.paperplane,
              size: 24,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 8),
            Text(
              'Apply for this Job',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      )


            ),
          ],
        ),
      ),
    );
  }

  void _handleJobApplication(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          'Apply for ${widget.jobPost.title}?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to apply for this job at ${widget.jobPost.businessName}.',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemBlue),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle,
                    color: CupertinoColors.systemBlue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The business will be notified of your application.',
                      style: TextStyle(
                        color: CupertinoColors.systemBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _submitJobApplication(context);
            },
            child: Text(
              'Apply Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.activeBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String formatDistance(double? distanceMiles) {
    if (distanceMiles == null) return 'N/A';
    if (distanceMiles < 1) {
      return '${(distanceMiles * 5280).round()} ft';
    } else {
      return '${distanceMiles.toStringAsFixed(1)} miles';
    }
  }

  Future<void> _submitJobApplication(BuildContext context) async {
    BuildContext? loadingContext;

    try {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) {
          loadingContext = ctx;
          return Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: CupertinoActivityIndicator(
                radius: 16,
                color: Colors.blue.shade700,
              ),
            ),
          );
        },
      );

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      // Check profile approval status
      final profileResponse = await http.get(
        Uri.parse(ApiConfig.profileStatusUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        if (profileData['is_approved'] != true) {
          if (loadingContext != null && Navigator.canPop(loadingContext!)) {
            Navigator.pop(loadingContext!);
          }
          if (profileData['is_document_complete'] == true) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => DocumentVerificationPendingScreen(),
              ),
            );
          } else {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => DocumentRegistrationPage(),
              ),
            );
          }
          return;
        }
      } else {
        throw Exception('Failed to check profile status');
      }

      // Continue with existing job application logic
      final requestBody = {'job': widget.jobPost.id};

      final response = await http.post(
        Uri.parse(ApiConfig.jobRequestUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (loadingContext != null && Navigator.canPop(loadingContext!)) {
        Navigator.pop(loadingContext!);
      }

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final jobRequestId = responseData['id'].toString();
        setState(() {
          _jobRequestId = jobRequestId;
          _hasApplied = true; // Update applied status
        });
        await _checkIfJobIsAccepted();
        _showApplicationSuccessMessage(context);
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorMessage(
          context,
          errorData['detail'] ??
              'Failed to submit application. Please try again.',
        );
      }
    } catch (e) {
      if (loadingContext != null && Navigator.canPop(loadingContext!)) {
        Navigator.pop(loadingContext!);
      }
      _showErrorMessage(
        context,
        'You have already applied for this job or there was an error. Please try again.',
      );
    }
  }

  void _showApplicationSuccessMessage(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 100),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade900.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                ),
              ),
              child: Icon(
                CupertinoIcons.check_mark_circled,
                color: Colors.white,
                size: 48,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Application Submitted!',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your application for ${widget.jobPost.title} has been sent to ${widget.jobPost.businessName}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}