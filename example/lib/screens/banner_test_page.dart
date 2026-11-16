import 'package:flutter/material.dart';
import 'package:preload_google_ads/preload_google_ads.dart';

/// A standalone page with a banner, opened with a named route so the banner
/// pool can be tested: open it, close it quickly, open it again. The second
/// open should show the banner at once, reused from the shared pool instead
/// of loading a new one.
class BannerTestPage extends StatelessWidget {
  /// Route name used with `Navigator.pushNamed`.
  static const String routeName = '/banner-test';

  const BannerTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banner Test Page')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to test banner reuse',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '1. Wait for the banner below to appear, then go back.\n'
              '2. Open this page again: the banner should show instantly.\n'
              '3. Open and close this page quickly, then open it again: the '
              'banner that arrived late should show instantly too.\n\n'
              'Watch the ad counter: "Load" should not go up on reopen.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: PreloadGoogleAds.instance.showBannerAd(),
      ),
    );
  }
}
