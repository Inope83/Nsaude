import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/sync/connectivity_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_repository.dart';
import '../auth/user_profile.dart';
import '../emergencies/emergency_list_screen.dart';
import '../emergencies/emergency_repository.dart';
import '../facilities/facility_repository.dart';
import '../geography/geography_repository.dart';
import '../overview/overview_screen.dart';
import '../patients/patient_list_screen.dart';
import '../patients/patient_repository.dart';
import '../referrals/referral_list_screen.dart';
import '../referrals/referral_repository.dart';
import '../sync/sync_status_screen.dart';

const List<String> _tabLabels = [
  AppStrings.tabOverview,
  AppStrings.tabEmergencies,
  AppStrings.tabReferrals,
  AppStrings.tabPatients,
];

const List<IconData> _tabIcons = [
  Icons.home_outlined,
  Icons.emergency_outlined,
  Icons.swap_horiz_outlined,
  Icons.groups_outlined,
];

const int _patientsTabIndex = 3;
const int _emergenciesTabIndex = 1;
const int _referralsTabIndex = 2;

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.authService,
    required this.onLoggedOut,
    this.patientService,
    this.geographyService,
    this.emergencyService,
    this.referralService,
    this.facilityService,
    this.syncEngine,
    this.connectivity,
    this.initialIndex = 0,
  });

  final AuthService authService;
  final VoidCallback onLoggedOut;
  final PatientService? patientService;
  final GeographyService? geographyService;
  final EmergencyService? emergencyService;
  final ReferralService? referralService;
  final FacilityService? facilityService;
  final SyncEngine? syncEngine;
  final ConnectivityService? connectivity;
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    widget.onLoggedOut();
  }

  void _openSyncStatus() {
    final syncEngine = widget.syncEngine;
    final connectivity = widget.connectivity;
    if (syncEngine == null || connectivity == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SyncStatusScreen(
          syncEngine: syncEngine,
          connectivity: connectivity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          if (widget.syncEngine != null && widget.connectivity != null)
            IconButton(
              onPressed: _openSyncStatus,
              tooltip: AppStrings.syncTooltip,
              icon: const Icon(Icons.cloud_sync_outlined),
            ),
          IconButton(
            onPressed: _logout,
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: _TabBody(
        index: _index,
        profile: widget.authService.currentProfile,
        patientService: widget.patientService,
        geographyService: widget.geographyService,
        emergencyService: widget.emergencyService,
        referralService: widget.referralService,
        facilityService: widget.facilityService,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (var i = 0; i < _tabLabels.length; i++)
            NavigationDestination(
              icon: Icon(_tabIcons[i]),
              label: _tabLabels[i],
            ),
        ],
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.index,
    required this.profile,
    this.patientService,
    this.geographyService,
    this.emergencyService,
    this.referralService,
    this.facilityService,
  });

  final int index;
  final UserProfile? profile;
  final PatientService? patientService;
  final GeographyService? geographyService;
  final EmergencyService? emergencyService;
  final ReferralService? referralService;
  final FacilityService? facilityService;

  @override
  Widget build(BuildContext context) {
    final service = patientService;
    if (index == 0 &&
        service != null &&
        emergencyService != null &&
        referralService != null) {
      return OverviewScreen(
        patientService: service,
        emergencyService: emergencyService!,
        referralService: referralService!,
        roleLabel:
            profile == null ? null : AppStrings.roleDisplayName(profile!.role),
      );
    }
    if (index == _patientsTabIndex && service != null) {
      return PatientListScreen(
        patientService: service,
        geographyService: geographyService,
      );
    }
    final emergencies = emergencyService;
    if (index == _emergenciesTabIndex && emergencies != null) {
      return EmergencyListScreen(
        emergencyService: emergencies,
        patientService: patientService,
      );
    }
    final referrals = referralService;
    if (index == _referralsTabIndex && referrals != null) {
      return ReferralListScreen(
        referralService: referrals,
        patientService: patientService,
        facilityService: facilityService,
      );
    }
    final theme = Theme.of(context);
    final role = profile?.role;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _tabLabels[index],
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            if (index == 0 && role != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                '${AppStrings.roleLabel}: ${AppStrings.roleDisplayName(role)}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            Text(
              AppStrings.placeholderTitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
