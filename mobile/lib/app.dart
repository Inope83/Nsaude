import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/api/token_store.dart';
import 'core/l10n/app_strings.dart';
import 'core/sync/app_database.dart';
import 'core/sync/connectivity_service.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/emergencies/emergency_repository.dart';
import 'features/facilities/facility_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/geography/geography_repository.dart';
import 'features/patients/patient_repository.dart';
import 'features/referrals/referral_repository.dart';
import 'features/shell/app_shell.dart';

class SaudeKonektaApp extends StatefulWidget {
  const SaudeKonektaApp({
    super.key,
    this.tokenStore,
    this.authService,
    this.patientService,
    this.geographyService,
    this.emergencyService,
    this.referralService,
    this.facilityService,
    this.syncEngine,
    this.connectivityService,
    this.database,
  });

  final TokenStore? tokenStore;
  final AuthService? authService;
  final PatientService? patientService;
  final GeographyService? geographyService;
  final EmergencyService? emergencyService;
  final ReferralService? referralService;
  final FacilityService? facilityService;
  final SyncEngine? syncEngine;
  final ConnectivityService? connectivityService;
  final AppDatabase? database;

  @override
  State<SaudeKonektaApp> createState() => _SaudeKonektaAppState();
}

class _SaudeKonektaAppState extends State<SaudeKonektaApp> {
  late final AuthService _authService;
  late final PatientService _patientService;
  late final GeographyService _geographyService;
  late final EmergencyService _emergencyService;
  late final ReferralService _referralService;
  late final FacilityService _facilityService;
  SyncEngine? _syncEngine;
  ConnectivityService? _connectivity;
  bool _checkingSession = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    final tokenStore = widget.tokenStore ?? SecureTokenStore();
    final client = ApiClient(tokenStore: tokenStore);
    _authService = widget.authService ??
        AuthRepository(client: client, tokenStore: tokenStore);
    final syncEngine = widget.syncEngine ?? _createSyncEngine(client);
    _syncEngine = syncEngine;
    _connectivity ??= widget.connectivityService;
    _patientService = widget.patientService ??
        PatientRepository(client, syncEngine: syncEngine);
    _geographyService =
        widget.geographyService ?? GeographyRepository(client);
    _emergencyService = widget.emergencyService ??
        EmergencyRepository(client, syncEngine: syncEngine);
    _referralService = widget.referralService ??
        ReferralRepository(client, syncEngine: syncEngine);
    _facilityService = widget.facilityService ?? FacilityRepository(client);
    _restoreSession();
  }

  SyncEngine? _createSyncEngine(ApiClient client) {
    final needsSync = widget.patientService == null ||
        widget.emergencyService == null ||
        widget.referralService == null;
    if (!needsSync) {
      return null;
    }
    final connectivity =
        widget.connectivityService ?? ConnectivityPlusService();
    _connectivity = connectivity;
    return SyncEngine(
      store: widget.database ?? AppDatabase.file(),
      client: client,
      connectivity: connectivity,
    );
  }

  Future<void> _restoreSession() async {
    var signedIn = false;
    try {
      signedIn = await _authService.hasSession();
    } catch (_) {
      signedIn = false;
    }
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _checkingSession = false;
    });
  }

  void _onLoggedIn() {
    setState(() => _signedIn = true);
  }

  void _onLoggedOut() {
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _checkingSession
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _signedIn
              ? AppShell(
                  authService: _authService,
                  patientService: _patientService,
                  geographyService: _geographyService,
                  emergencyService: _emergencyService,
                  referralService: _referralService,
                  facilityService: _facilityService,
                  syncEngine: _syncEngine,
                  connectivity: _connectivity,
                  onLoggedOut: _onLoggedOut,
                )
              : LoginScreen(
                  authService: _authService,
                  onLoggedIn: _onLoggedIn,
                ),
    );
  }
}
