import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'repository/grades_repository.dart';
import 'providers/education_mode_provider.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/stats_page.dart';
import 'pages/diary_page.dart';
import 'pages/settings_page.dart';
import 'pages/onboarding_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GradesRepository()),
        ChangeNotifierProvider(create: (_) => EducationModeProvider()),
      ],
      child: MaterialApp(
        title: 'Grades',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('it', 'IT'),
        ],
        home: const RootAppScreen(),
      ),
    );
  }
}

class RootAppScreen extends StatelessWidget {
  const RootAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);

    if (modeProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!modeProvider.isOnboardingCompleted) {
      return const OnboardingPage();
    }

    return const MainNavigation();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    HomePage(),
    StatisticsPage(),
    DiaryPage(),
    SettingsPage()
  ];

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: isUni
            ? const [
                NavigationDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school),
                    label: 'Libretto'),
                NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: 'Media & CFU'),
                NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: 'Appelli & Orario'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Impostazioni'),
              ]
            : const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Statistiche'),
                NavigationDestination(
                    icon: Icon(Icons.book_outlined),
                    selectedIcon: Icon(Icons.book),
                    label: 'Diario'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Impostazioni'),
              ],
      ),
    );
  }
}
