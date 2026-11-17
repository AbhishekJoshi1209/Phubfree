import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/phubbing_repository.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/nudge_service.dart';
import 'services/permission_service.dart';
import 'services/phub_inference_service.dart';
import 'state/settings_controller.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/nudge_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted preferences before the first frame so there is no
  // flash of the wrong theme.
  final themeController = ThemeController();
  await themeController.load();

  final settingsController = SettingsController();
  await settingsController.load();

  // Load the on-device phubbing detection model.
  final inferenceService = PhubInferenceService();
  await inferenceService.load();

  final nudgeService = NudgeService();

  final repo = PhubbingRepository();
  repo.attachInferenceService(inferenceService);
  repo.start();

  runApp(
    PhubbFreeApp(
      themeController: themeController,
      settingsController: settingsController,
      repo: repo,
      inferenceService: inferenceService,
      nudgeService: nudgeService,
    ),
  );
}

class PhubbFreeApp extends StatelessWidget {
  final ThemeController themeController;
  final SettingsController settingsController;
  final PhubbingRepository repo;
  final PhubInferenceService inferenceService;
  final NudgeService nudgeService;

  const PhubbFreeApp({
    super.key,
    required this.themeController,
    required this.settingsController,
    required this.repo,
    required this.inferenceService,
    required this.nudgeService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: settingsController),
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider(create: (_) => PermissionService()),
        Provider<PhubInferenceService>.value(value: inferenceService),
        ChangeNotifierProvider.value(value: nudgeService),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Phubb-Free',
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: AppThemeData.light(),
            darkTheme: AppThemeData.dark(),
            // Short cross-fade when switching themes (~200ms).
            themeAnimationDuration: const Duration(milliseconds: 200),
            home: const AppEntry(),
          );
        },
      ),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  StreamSubscription<dynamic>? _nudgeSub;

  @override
  void initState() {
    super.initState();
    // Listen to the event stream and evaluate nudges for each event.
    final repo = context.read<PhubbingRepository>();
    _nudgeSub = repo.eventStream.listen((event) {
      if (!mounted) return;
      final nudge = context.read<NudgeService>();
      final settings = context.read<SettingsController>();
      nudge.evaluate(
        event: event,
        probability: repo.lastProbability,
        settings: settings,
      );
    });
  }

  @override
  void dispose() {
    _nudgeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    if (!settings.onboardingComplete) {
      return OnboardingScreen(
        onComplete: () {
          // Rebuild via notifyListeners from completeOnboarding
        },
      );
    }

    return NudgeOverlay(child: const AppShell());
  }
}
