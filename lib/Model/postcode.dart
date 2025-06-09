// 1. First, create a new PostcodeSearchWidget file in your project
// lib/Widgets/postcode_search_widget.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';

class PostcodeSearchWidget extends StatefulWidget {
  final Function(double latitude, double longitude, String address) onAddressSelected;
  final String placeholderText;
  final TextEditingController? postcodeController;

  const PostcodeSearchWidget({
    Key? key,
    required this.onAddressSelected,
    this.placeholderText = 'Postcode',
    this.postcodeController,
  }) : super(key: key);

  @override
  _PostcodeSearchWidgetState createState() => _PostcodeSearchWidgetState();
}

class _PostcodeSearchWidgetState extends State<PostcodeSearchWidget> {
  late TextEditingController _postcodeController;
  bool _isSearching = false;
  List<Map<String, dynamic>> _addressSuggestions = [];
  Timer? _debounceTimer;
  late AppLanguage appLanguage;

  // Define blue and white color scheme
  final Color primaryBlue = Color(0xFF1A5DC1);
  final Color lightBlue = Color(0xFFE6F0FF);
  final Color accentBlue = Color(0xFF0E4DA4);
  final Color whiteColor = CupertinoColors.white;

  @override
  void initState() {
    super.initState();
    _postcodeController = widget.postcodeController ?? TextEditingController();
    _postcodeController.addListener(_onPostcodeChanged);
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
  }

  @override
  void dispose() {
    _postcodeController.removeListener(_onPostcodeChanged);
    if (widget.postcodeController == null) {
      _postcodeController.dispose();
    }
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onPostcodeChanged() {
    // Debounce the input to avoid too many API calls
    if (_postcodeController.text.length >= 3) {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _fetchAddressSuggestions(_postcodeController.text);
      });
    } else {
      setState(() {
        _addressSuggestions = [];
      });
    }
  }

  Future<void> _fetchAddressSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _addressSuggestions = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      List<Map<String, dynamic>> suggestions = [];

      for (var location in locations) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        for (var placemark in placemarks) {
          String address = _formatAddress(placemark);
          if (address.isNotEmpty) {
            suggestions.add({
              'address': address,
              'latitude': location.latitude,
              'longitude': location.longitude,
            });
          }
        }
      }

      setState(() {
        _addressSuggestions = suggestions;
      });
    } catch (e) {
      // _showErrorDialog('Error fetching suggestions: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [
      placemark.street ?? '',
      placemark.locality ?? '',
      placemark.administrativeArea ?? '',
      placemark.postalCode ?? '',
      placemark.country ?? '',
    ];
    return addressParts.where((part) => part.isNotEmpty).join(', ');
  }

  void _selectAddress(Map<String, dynamic> suggestion) {
    setState(() {
      _addressSuggestions = []; // Clear suggestions
    });

    widget.onAddressSelected(
      suggestion['latitude'],
      suggestion['longitude'],
      suggestion['address'],
    );
  }

  Future<void> _searchByPostcode(String postcode) async {
    if (postcode.isEmpty) return;

    setState(() {
      _isSearching = true;
      _addressSuggestions = []; // Clear any existing suggestions
    });

    try {
      List<Location> locations = await locationFromAddress(postcode);
      List<Map<String, dynamic>> allAddresses = [];

      for (var location in locations) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        for (var placemark in placemarks) {
          String address = _formatAddress(placemark);
          if (address.isNotEmpty) {
            allAddresses.add({
              'address': address,
              'latitude': location.latitude,
              'longitude': location.longitude,
            });
          }
        }
      }

      // If we found multiple addresses, show them all as suggestions
      if (allAddresses.length > 1) {
        setState(() {
          _addressSuggestions = allAddresses;
        });
      } 
      // If we only found one address, select it automatically
      else if (allAddresses.length == 1) {
        widget.onAddressSelected(
          allAddresses[0]['latitude'],
          allAddresses[0]['longitude'],
          allAddresses[0]['address'],
        );
      }
    } catch (e) {
      _showErrorDialog('Error searching postcode: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(appLanguage.get('error')),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(appLanguage.get('ok')),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: whiteColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: primaryBlue.withOpacity(0.5),
                  ),
                ),
                child: CupertinoTextField(
                  controller: _postcodeController,
                  placeholder: widget.placeholderText,
                  placeholderStyle: TextStyle(
                    color: Colors.grey,
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(
                      left: 10,
                    ),
                    child: Icon(
                      CupertinoIcons.search,
                      color: primaryBlue,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  style: TextStyle(color: primaryBlue),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      8,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 8,
              ),
              color: primaryBlue,
              borderRadius: BorderRadius.circular(8),
              child: Text(
                appLanguage.get('search'),
                style: TextStyle(color: whiteColor),
              ),
              onPressed: () => _searchByPostcode(
                _postcodeController.text,
              ),
            ),
          ],
        ),

        // Autocomplete Suggestions
        if (_addressSuggestions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: whiteColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: primaryBlue.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxHeight: 200,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _addressSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _addressSuggestions[index];
               return GestureDetector(
  onTap: () => _selectAddress(suggestion),
  child: Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: index == _addressSuggestions.length - 1
              ? Colors.transparent
              : Colors.grey.withOpacity(0.2),
        ),
      ),
    ),
    child: Text(
      suggestion['address'],
      style: TextStyle(color: accentBlue),
    ),
  ),
);
              },
            ),
          ),

        // Loading Indicator
        if (_isSearching)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: CupertinoActivityIndicator(
                color: primaryBlue,
              ),
            ),
          ),
      ],
    );
  }
}
