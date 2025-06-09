import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Homepage/detailspage.dart';
import 'package:taskova_drivers/View/Homepage/homepage.dart';



class AppliedJobsPage extends StatefulWidget {
  const AppliedJobsPage({Key? key}) : super(key: key);

  @override
  State<AppliedJobsPage> createState() => _AppliedJobsPageState();
}

class _AppliedJobsPageState extends State<AppliedJobsPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _jobRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _fetchAppliedJobs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppliedJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _jobRequests = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null || accessToken.isEmpty) {
        setState(() {
          _errorMessage = 'No access token found. Please log in.';
          _isLoading = false;
        });
        return;
      }

      // Fetch job requests
      final response = await http.get(
        Uri.parse(ApiConfig.jobRequestUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobRequests = jsonDecode(response.body);
        final List<Map<String, dynamic>> enrichedJobRequests = [];

        // Fetch job details for each request
        for (var request in jobRequests) {
          try {
            final jobResponse = await http.get(
              Uri.parse('${ApiConfig.jobListUrl}${request['job']}/'),
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              },
            );

            if (jobResponse.statusCode == 200) {
              final jobData = jsonDecode(jobResponse.body);
              final jobPost = JobPost.fromJson(jobData);

              // Optionally fetch driver profile to calculate distance
              final driverProfile = await _fetchDriverProfile(accessToken);
              if (driverProfile != null) {
                jobPost.calculateDistanceFrom(
                  driverProfile.latitude,
                  driverProfile.longitude,
                );
              }

              enrichedJobRequests.add({
                'request': request,
                'job': jobPost,
              });
            } else {
              print('Failed to fetch job details for job ID ${request['job']}: ${jobResponse.statusCode}');
              // Optionally add a placeholder job to show the request even if job details fail
              // enrichedJobRequests.add({
              //   'request': request,
              //   'job': JobPost(
              //     id: request['job'],
              //     title: 'Job Details Unavailable',
              //     businessName: 'Unknown',
              //     complimentaryBenefits: [],
              //     createdAt: '',
              //     businessId: 0,
              //     businessLatitude: 0.0,
              //     businessLongitude: 0.0,
              //     jobDate: request['created_at']?.substring(0, 10) ?? 'TBD',
              //   ),
              // });
            }
          } catch (e) {
            print('Error fetching job details for job ID ${request['job']}: $e');
            enrichedJobRequests.add({
              'request': request,
              'job': JobPost(
                id: request['job'],
                title: 'Job Details Unavailable',
                businessName: 'Unknown',
                complimentaryBenefits: [],
                createdAt: '',
                businessId: 0,
                businessLatitude: 0.0,
                businessLongitude: 0.0,
                jobDate: request['created_at']?.substring(0, 10) ?? 'TBD',
              ),
            });
          }
        }

        if (mounted) {
          setState(() {
            _jobRequests = enrichedJobRequests;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Authentication failed. Please log in again.';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load applied jobs: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading applied jobs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<DriverProfile?> _fetchDriverProfile(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.driverProfileUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return DriverProfile.fromJson(jsonResponse);
      }
    } catch (e) {
      print('Error fetching driver profile: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverNavigationBar(theme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _isLoading
                  ? _buildLoadingState(theme)
                  : _errorMessage != null
                      ? _buildErrorState(theme)
                      : _jobRequests.isEmpty
                          ? _buildEmptyState(theme)
                          : _buildJobList(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverNavigationBar(CupertinoThemeData theme) {
    return CupertinoSliverNavigationBar(
      largeTitle: Text(
        'Applied Jobs',
        style: theme.textTheme.navLargeTitleTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: theme.barBackgroundColor,
      border: null,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(
          CupertinoIcons.back,
          color: CupertinoColors.activeBlue,
          size: 28,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(
          CupertinoIcons.refresh,
          color: CupertinoColors.activeBlue,
          size: 28,
        ),
        onPressed: _fetchAppliedJobs,
      ),
    );
  }

  Widget _buildLoadingState(CupertinoThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.barBackgroundColor,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(11.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  color: CupertinoColors.systemGrey5,
                ),
                const SizedBox(height: 6),
                Container(
                  width: 100,
                  height: 12,
                  color: CupertinoColors.systemGrey5,
                ),
                const SizedBox(height: 10),
                Container(
                  width: 80,
                  height: 10,
                  color: CupertinoColors.systemGrey5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CupertinoThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.barBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            'Something Went Wrong',
            style: theme.textTheme.textStyle.copyWith(
              color: CupertinoColors.systemRed,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage!,
            style: theme.textTheme.textStyle.copyWith(
              color: CupertinoColors.systemRed,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minSize: 36,
            onPressed: _fetchAppliedJobs,
            child: const Text('Try Again', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CupertinoThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.barBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.briefcase,
            color: CupertinoColors.systemGrey,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'No Applied Jobs',
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You haven’t applied for any jobs yet. Browse available jobs to get started!',
            style: theme.textTheme.textStyle.copyWith(
              color: CupertinoColors.systemGrey,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJobList(CupertinoThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: _jobRequests.asMap().entries.map((entry) {
          final index = entry.key;
          final jobRequest = entry.value['request'];
          final JobPost job = entry.value['job'];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => JobDetailPage(jobPost: job),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.barBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBusinessImage(job),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    job.title,
                                    style: theme.textTheme.textStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: jobRequest['is_accepted']
                                        ? CupertinoColors.systemGreen
                                            .withOpacity(0.1)
                                        : CupertinoColors.systemYellow
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: jobRequest['is_accepted']
                                          ? CupertinoColors.systemGreen
                                          : CupertinoColors.systemYellow,
                                    ),
                                  ),
                                  child: Text(
                                    jobRequest['is_accepted']
                                        ? 'Accepted'
                                        : 'Pending',
                                    style: theme.textTheme.textStyle.copyWith(
                                      color: jobRequest['is_accepted']
                                          ? CupertinoColors.systemGreen
                                          : CupertinoColors.systemYellow,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              job.businessName,
                              style: theme.textTheme.textStyle.copyWith(
                                color: CupertinoColors.systemBlue,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildInfoChip(
                                  icon: CupertinoIcons.calendar,
                                  text: job.jobDate ?? 'TBD',
                                  color: CupertinoColors.systemBlue,
                                  theme: theme,
                                ),
                                if (job.distanceMiles != null) ...[
                                  const SizedBox(width: 6),
                                  _buildInfoChip(
                                    icon: CupertinoIcons.location_solid,
                                    text: formatDistance(job.distanceMiles),
                                    color: _getDistanceColor(job.distanceMiles),
                                    theme: theme,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          CupertinoIcons.chevron_right,
                          color: CupertinoColors.tertiaryLabel,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBusinessImage(JobPost job, {double size = 70}) {
    if (job.businessImage != null && job.businessImage!.isNotEmpty) {
      String imageUrl = job.businessImage!;
      if (!imageUrl.startsWith('http')) {
        imageUrl = '${ApiConfig.getImageUrl}$imageUrl';
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(11.5),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            return loadingProgress == null
                ? child
                : _buildImagePlaceholder(size);
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder(size);
          },
        ),
      );
    }
    return _buildImagePlaceholder(size);
  }

  Widget _buildImagePlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey4,
        borderRadius: BorderRadius.circular(11.5),
      ),
      child: Icon(
        CupertinoIcons.building_2_fill,
        color: CupertinoColors.systemGrey,
        size: size * 0.5,
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
    required CupertinoThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.textStyle.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDistanceColor(double? distance) {
    if (distance == null) return CupertinoColors.systemOrange;
    if (distance < 2) return CupertinoColors.systemGreen;
    if (distance < 5) return CupertinoColors.systemBlue;
    return CupertinoColors.systemOrange;
  }
}