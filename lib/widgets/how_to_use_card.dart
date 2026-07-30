import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A reusable card that opens the YouTube tutorial when tapped.
///
/// Use it on any home page so users can learn how to use the app.
class HowToUseCard extends StatelessWidget {
  static const String tutorialUrl =
      'https://youtu.be/WOHOzqiQNRE?si=tLmb7_ATTKiGeFBt';

  final EdgeInsetsGeometry margin;

  const HowToUseCard({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  Future<void> _openTutorial(BuildContext context) async {
    final uri = Uri.parse(tutorialUrl);
    final messenger = ScaffoldMessenger.of(context);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the tutorial. Please visit: $tutorialUrl',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTutorial(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'How to use the app',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Watch a short YouTube tutorial',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
