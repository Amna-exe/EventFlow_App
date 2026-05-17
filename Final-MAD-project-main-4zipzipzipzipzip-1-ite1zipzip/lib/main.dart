import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/landing_screen.dart';
import 'services/seed_service.dart';
import 'services/firebase_seed_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SeedService().seed();

  unawaited(FirebaseSeedService().seedIfNeeded());

  runApp(const EventApp());
}

void unawaited(Future<void> future) {}

class EventApp extends StatelessWidget {
  const EventApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventFlow',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),

      home: const LandingScreen(),
    );
  }
}
