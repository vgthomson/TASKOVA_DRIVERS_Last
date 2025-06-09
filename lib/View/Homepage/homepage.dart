import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskova_drivers/Model/api_config.dart';
import 'package:taskova_drivers/View/Homepage/detailspage.dart';


// Extension for safely accessing map values
extension SafeAccess on Map<String, dynamic> {
  T? get<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    return null;
  }
}

// Models
class DriverProfile {
  final double latitude;
  final double longitude;

  DriverProfile({required this.latitude, required this.longitude});

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      latitude: _parseDouble(json['latitude']) ?? 0.0,
      longitude: _parseDouble(json['longitude']) ?? 0.0,
    );
  }

  factory DriverProfile.defaultProfile() =>
      DriverProfile(latitude: 0.0, longitude: 0.0);
}

class Business {
  final int id;
  final String name;
  final String? image;

  Business({required this.id, required this.name, this.image});
}

class JobPost {
  final int id;
  final String title;
  final String? description;
  final String? startTime;
  final String? endTime;
  final double? hourlyRate;
  final double? perDeliveryRate;
  final List<dynamic> complimentaryBenefits;
  final String createdAt;
  final int businessId;
  final String businessName;
  final String? businessImage;
  final double businessLatitude;
  final double businessLongitude;
  double? distanceMiles;
  final String? jobDate;
  final String? address; // Added address property

  JobPost({
    required this.id,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.hourlyRate,
    this.perDeliveryRate,
    required this.complimentaryBenefits,
    required this.createdAt,
    required this.businessId,
    required this.businessName,
    this.businessImage,
    required this.businessLatitude,
    required this.businessLongitude,
    this.distanceMiles,
    this.jobDate,
    this.address, // Include address in constructor
  });

  Business get business =>
      Business(id: businessId, name: businessName, image: businessImage);

  factory JobPost.fromJson(Map<String, dynamic> json) {
    final businessDetail = json['business_detail'] as Map<String, dynamic>?;
    return JobPost(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unnamed Job',
      description: json['description'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      jobDate: json['job_date'],
      hourlyRate: _parseDouble(json['hourly_rate']),
      perDeliveryRate: _parseDouble(json['per_delivery_rate']),
      complimentaryBenefits: json['complimentary_benefits'] ?? [],
      createdAt: json['created_at'] ?? '',
      businessId: businessDetail?['id'] ?? 0,
      businessName: businessDetail?['name'] ?? 'Unknown Business', // Updated source
      businessImage: businessDetail?['image'] ?? '',
      businessLatitude: _parseDouble(businessDetail?['latitude']) ?? 0.0,
      businessLongitude: _parseDouble(businessDetail?['longitude']) ?? 0.0,
      address: businessDetail?['address'], // Added address
    );
  }

  void calculateDistanceFrom(double driverLat, double driverLng) {
    distanceMiles = calculateDistanceInMiles(
      driverLat,
      driverLng,
      businessLatitude,
      businessLongitude,
    );
  }
}

// Utility Functions
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

double calculateDistanceInMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
) {
  const earthRadiusKm = 6371;
  const kmToMiles = 0.621371;

  final lat1Rad = _degreesToRadians(lat1);
  final lon1Rad = _degreesToRadians(lon1);
  final lat2Rad = _degreesToRadians(lat2);
  final lon2Rad = _degreesToRadians(lon2);

  final dLat = lat2Rad - lat1Rad;
  final dLon = lon2Rad - lon1Rad;
  final a =
      pow(sin(dLat / 2), 2) +
      cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  final distanceKm = earthRadiusKm * c;
  return distanceKm * kmToMiles;
}

double _degreesToRadians(double degrees) => degrees * (pi / 180);

String formatDistance(double? distanceMiles) {
  if (distanceMiles == null) return 'Unknown distance';
  if (distanceMiles < 1) {
    final feet = (distanceMiles * 5280).round();
    return '$feet ft';
  } else if (distanceMiles < 10) {
    return '${distanceMiles.toStringAsFixed(1)} mi';
  }
  return '${distanceMiles.round()} mi';
}

// Home Page Widget
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<JobPost> _jobPosts = [];
  List<JobPost> _filteredJobPosts = [];
  bool _isLoading = true;
  String? _errorMessage;
  DriverProfile? _driverProfile;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _userName;
  double _radiusFilter = 30.0; // Default to 30 miles
  bool _showRadiusFilter = false; // Add this line


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode.unfocus();
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _fetchDriverProfile();
      await _fetchJobPosts();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _jobPosts = [];
      _filteredJobPosts = [];
      _searchQuery = '';
          _radiusFilter = 30.0; // Add this line
    _showRadiusFilter = false; // Add this line

      _searchController.clear();
      _driverProfile = null;
    });
    await _loadData();
  }

 Future<void> _fetchDriverProfile() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final userName = prefs.getString('user_name')?.trim() ?? 'Driver'; // Fallback from SharedPreferences
    print('Retrieved user_name from SharedPreferences: "$userName"'); // Debug

    setState(() {
      _userName = userName; // Set initial username
      if (accessToken == null || accessToken.isEmpty) {
        _errorMessage = 'No access token found. Please log in.';
        _isLoading = false;
      }
    });

    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    final response = await http.get(
      Uri.parse(ApiConfig.driverProfileUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      print('Driver profile API response: $jsonResponse'); // Debug API response
      setState(() {
        _driverProfile = DriverProfile.fromJson(jsonResponse);
        // Use 'name' field from API, fallback to SharedPreferences value
        final apiUserName = jsonResponse['name']?.toString().trim();
        _userName = (apiUserName != null && apiUserName.isNotEmpty) ? apiUserName : _userName;
        print('Updated user_name: "$_userName"'); // Debug final username
      });
    } else if (response.statusCode == 401) {
      setState(() {
        _errorMessage = 'Authentication failed. Please log in again.';
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Failed to load driver profile: ${response.statusCode}';
        _driverProfile = DriverProfile.defaultProfile();
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error fetching driver profile: $e';
      _driverProfile = DriverProfile.defaultProfile();
    });
    print('Error in _fetchDriverProfile: $e'); // Debug error
  }
}

  Future<void> _fetchJobPosts() async {
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

      final response = await http.get(
        Uri.parse(ApiConfig.jobListUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as List<dynamic>;
        final posts = jsonResponse.map((job) => JobPost.fromJson(job)).toList();

        if (_driverProfile != null) {
          for (var post in posts) {
            post.calculateDistanceFrom(
              _driverProfile!.latitude,
              _driverProfile!.longitude,
            );
          }
          posts.sort((a, b) {
            if (a.distanceMiles == null && b.distanceMiles == null) return 0;
            if (a.distanceMiles == null) return 1;
            if (b.distanceMiles == null) return -1;
            return a.distanceMiles!.compareTo(b.distanceMiles!);
          });
        }

        setState(() {
          _jobPosts = posts;
          _filteredJobPosts = posts;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Authentication failed. Please log in again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load job posts: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }
void _applyRadiusFilter() {
  setState(() {
    if (_radiusFilter == 30.0) {
      // Show all jobs if set to max (30 miles)
      _filteredJobPosts = _jobPosts.where((job) {
        final matchesSearch = _searchQuery.isEmpty ||
            job.businessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (job.address?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (job.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        return matchesSearch;
      }).toList();
    } else {
      // Filter by distance and search
      _filteredJobPosts = _jobPosts.where((job) {
        final withinRadius = job.distanceMiles != null && job.distanceMiles! <= _radiusFilter;
        final matchesSearch = _searchQuery.isEmpty ||
            job.businessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (job.address?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (job.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        return withinRadius && matchesSearch;
      }).toList();
    }
  });
}
void _toggleRadiusFilter() {
  setState(() {
    _showRadiusFilter = !_showRadiusFilter;
  });
}
  void _filterJobPosts(String query) {
    setState(() {
      _searchQuery = query;
       _applyRadiusFilter();
      if (query.isEmpty) {
        _filteredJobPosts = _jobPosts;
      } else {
        final queryLower = query.toLowerCase();
        _filteredJobPosts = _jobPosts.where((job) {
          return job.businessName.toLowerCase().contains(queryLower) ||
              job.title.toLowerCase().contains(queryLower) || (job.address?.toLowerCase().contains(queryLower) ?? false) ||
              (job.description?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }
    });
  }

  Widget _buildBusinessImage(JobPost job, {double size = 70}) {
    if (job.businessImage != null && job.businessImage!.isNotEmpty) {
      String imageUrl = job.businessImage!;
      if (!imageUrl.startsWith('http')) {
        imageUrl = '${ApiConfig.getImageUrl}$imageUrl';
        print(imageUrl);
      }else{
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

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Nearby Jobs',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: theme.barBackgroundColor,
        border: null,
      ),
      
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: _refreshData,
              refreshTriggerPullDistance: 100,
              refreshIndicatorExtent: 60,
            ),
            _buildHeaderSection(theme),
            _buildContentSection(theme),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
Widget _buildRadiusFilter(CupertinoThemeData theme) {
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Radius Filter',
              style: theme.textTheme.textStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              '${_radiusFilter.round()} ${_radiusFilter == 30 ? '+ miles' : 'miles'}',
              style: theme.textTheme.textStyle.copyWith(
                color: CupertinoColors.systemBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CupertinoSlider(
          value: _radiusFilter,
          min: 1.0,
          max: 30.0,
          divisions: 29,
          activeColor: CupertinoColors.systemBlue,
          onChanged: (value) {
            setState(() {
              _radiusFilter = value;
            });
            _applyRadiusFilter();
          },
        ),
      ],
    ),
  );
}
Widget _buildHeaderSection(CupertinoThemeData theme) {
  return SliverToBoxAdapter(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_userName != null)
            Text(
  'Hi, $_userName',
  style: GoogleFonts.oswald(
    textStyle: theme.textTheme.navTitleTextStyle.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  ),
),
          if (_userName != null) const SizedBox(height: 8),
          Text(
            'Discover Opportunities',
              style: theme.textTheme.navTitleTextStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Find jobs near you',
              style: theme.textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchBar(theme),
if (_showRadiusFilter) _buildRadiusFilter(theme),
            if (!_isLoading && _errorMessage == null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: CupertinoIcons.briefcase,
                    label: 'Jobs',
                    value: '${_filteredJobPosts.length}',
                    theme: theme,
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: CupertinoColors.separator,
                  ),
                  _buildStatItem(
                    icon: CupertinoIcons.location_circle,
                    label: 'Nearby',
                    value:
                        '${_filteredJobPosts.where((job) => job.distanceMiles != null && job.distanceMiles! < 5).length}',
                    theme: theme,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(CupertinoThemeData theme) {
  return Container(
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: CupertinoTextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            placeholder: 'Search jobs, companies...',
            placeholderStyle: theme.textTheme.textStyle.copyWith(
              color: CupertinoColors.placeholderText,
              fontSize: 14,
            ),
            style: theme.textTheme.textStyle.copyWith(fontSize: 14),
            decoration: const BoxDecoration(),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                CupertinoIcons.search,
                color: CupertinoColors.systemBlue,
                size: 18,
              ),
            ),
            suffix: _searchQuery.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _filterJobPosts('');
                        _searchFocusNode.unfocus();
                      },
                      child: const Icon(
                        CupertinoIcons.clear_circled,
                        color: CupertinoColors.systemGrey,
                        size: 18,
                      ),
                    ),
                  )
                : null,
            onChanged: _filterJobPosts,
          ),
        ),
        // Filter Icon Button
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minSize: 0,
          onPressed: _toggleRadiusFilter,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _showRadiusFilter 
                  ? CupertinoColors.systemBlue.withOpacity(0.1)
                  : CupertinoColors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              CupertinoIcons.slider_horizontal_3,
              color: _showRadiusFilter 
                  ? CupertinoColors.systemBlue 
                  : CupertinoColors.systemGrey,
              size: 18,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildContentSection(CupertinoThemeData theme) {
    if (_isLoading) return _buildLoadingState(theme);
    if (_errorMessage != null) return _buildErrorState(theme);
    if (_filteredJobPosts.isEmpty && _searchQuery.isNotEmpty)
      return _buildNoResultsState(theme);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildJobCard(context, _filteredJobPosts[index], index, theme),
          childCount: _filteredJobPosts.length,
        ),
      ),
    );
  }

  Widget _buildLoadingState(CupertinoThemeData theme) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Container(
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
        ),
        childCount: 3,
      ),
    );
  }

  Widget _buildErrorState(CupertinoThemeData theme) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              style: theme.textTheme.navTitleTextStyle.copyWith(
                color: CupertinoColors.systemRed,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error',
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
              onPressed: _refreshData,
              child: const Text('Try Again', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(CupertinoThemeData theme) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.search,
              color: CupertinoColors.systemGrey,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No Jobs Found for "$_searchQuery"',
              style: theme.textTheme.textStyle.copyWith(
                color: CupertinoColors.systemGrey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search term.',
              style: theme.textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minSize: 36,
              onPressed: () {
                _searchController.clear();
                _filterJobPosts('');
                _searchFocusNode.unfocus();
              },
              child: const Text('Clear Search', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required CupertinoThemeData theme,
  }) {
    return Column(
      children: [
        Icon(icon, color: CupertinoColors.systemBlue, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.textStyle.copyWith(
            color: CupertinoColors.secondaryLabel,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

 Widget _buildJobCard(
  BuildContext context,
  JobPost job,
  int index,
  CupertinoThemeData theme,
) {
  final isUrgent = job.distanceMiles != null && job.distanceMiles! < 2;
  final isHighPay = (job.hourlyRate ?? 0) > 20 || (job.perDeliveryRate ?? 0) > 8;

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
          HapticFeedback.lightImpact();
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
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.separator,
                        width: 0.5,
                      ),
                    ),
                    child: _buildBusinessImage(job),
                  ),
                  if (isUrgent)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.barBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.flame,
                          color: CupertinoColors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          if (isHighPay)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'HIGH PAY',
                                style: theme.textTheme.textStyle.copyWith(
                                  color: CupertinoColors.systemGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
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
                      if (job.address != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          job.address!,
                          style: theme.textTheme.textStyle.copyWith(
                            color: CupertinoColors.secondaryLabel,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: CupertinoIcons.location_solid,
                            text: formatDistance(job.distanceMiles),
                            color: _getDistanceColor(job.distanceMiles),
                            theme: theme,
                          ),
                          const SizedBox(width: 6),
                          _buildInfoChip(
                            icon: CupertinoIcons.clock,
                            text: job.startTime ?? 'N/A',
                            color: CupertinoColors.systemBlue,
                            theme: theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.money_dollar_circle,
                            color: CupertinoColors.systemGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatPayInfo(job),
                              style: theme.textTheme.textStyle.copyWith(
                                color: CupertinoColors.systemGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
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

  String _formatPayInfo(JobPost job) {
    final payParts = <String>[];
    if (job.hourlyRate != null) payParts.add('\$${job.hourlyRate}/hr');
    if (job.perDeliveryRate != null)
      payParts.add('\$${job.perDeliveryRate}/delivery');
    return payParts.isEmpty ? 'Pay TBD' : payParts.join(' + ');
  }
}