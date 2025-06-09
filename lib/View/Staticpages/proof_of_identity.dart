import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IdentityVerificationScreen extends StatelessWidget {
  const IdentityVerificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define our color scheme
    const Color primaryBlue = Color(0xFF0A84FF);
    const Color lightBlue = Color(0xFFE1F0FF);
    const Color darkBlue = Color(0xFF0055B8);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: primaryBlue,
        middle: Text(
          'Identity Verification',
          style: TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                
                // Header image
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: lightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.shield_lefthalf_fill,
                      size: 100,
                      color: primaryBlue,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Title
                const Center(
                  child: Text(
                    'Why We Need Proof of Identity',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Main content
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Text(
                    'To ensure the safety, trust, and reliability of the Taskova platform, we require all drivers to provide a valid Proof of Identity, such as a Passport or UK Driving Licence. This step is essential to verify that you are who you say you are and to comply with legal and safety standards. By confirming your identity, we can protect both drivers and customers, prevent fraudulent activity, and build a trusted community of professional delivery drivers. Your document will be securely stored and used only for verification purposes.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
               
                // Privacy note
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Your documents are securely encrypted and stored in compliance with GDPR regulations.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentOption(
    IconData icon,
    String title,
    String subtitle,
    Color primaryColor,
    Color backgroundColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          // Handle document selection
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
