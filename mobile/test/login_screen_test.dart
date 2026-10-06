import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/l10n/app_strings.dart';
import 'package:saude_konekta/core/theme/app_theme.dart';
import 'package:saude_konekta/features/auth/auth_repository.dart';
import 'package:saude_konekta/features/auth/login_screen.dart';
import 'package:saude_konekta/features/auth/user_profile.dart';

UserProfile? _profile;

UserProfile _sampleProfile() {
  return const UserProfile(
    id: 1,
    username: 'maria',
    role: 'DOCTOR',
    facility: null,
    firstName: 'Maria',
    lastName: 'Silva',
  );
}

class _FakeAuth implements AuthService {
  _FakeAuth({this.loginError, this.profile});

  final Object? loginError;
  final UserProfile? profile;
  int loginCalls = 0;

  @override
  Future<UserProfile> login(String username, String password) async {
    loginCalls++;
    final error = loginError;
    if (error != null) {
      throw error;
    }
    return profile ?? _profile!;
  }

  @override
  Future<bool> hasSession() async => false;

  @override
  Future<void> logout() async {}

  @override
  UserProfile? get currentProfile => profile;
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: child);
}

void main() {
  setUpAll(() {
    _profile = _sampleProfile();
  });

  testWidgets('shows Tetum login labels', (tester) async {
    await tester.pumpWidget(
      _wrap(LoginScreen(authService: _FakeAuth(), onLoggedIn: () {})),
    );

    expect(find.text(AppStrings.appName), findsWidgets);
    expect(find.text(AppStrings.username), findsOneWidget);
    expect(find.text(AppStrings.password), findsOneWidget);
    expect(find.text(AppStrings.login), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('empty fields show required validation inline', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      _wrap(LoginScreen(authService: auth, onLoggedIn: () {})),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text(AppStrings.requiredFields), findsOneWidget);
    expect(auth.loginCalls, 0);
  });

  testWidgets('invalid credentials error is shown inline', (tester) async {
    final auth = _FakeAuth(
      loginError: const AuthFailedException(AppStrings.invalidCredentials),
    );
    await tester.pumpWidget(
      _wrap(LoginScreen(authService: auth, onLoggedIn: () {})),
    );

    await tester.enterText(find.byType(TextField).at(0), 'maria');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.invalidCredentials), findsOneWidget);
    expect(auth.loginCalls, 1);
  });

  testWidgets('connection error is shown inline', (tester) async {
    final auth = _FakeAuth(
      loginError: const NetworkException(AppStrings.connectionError),
    );
    await tester.pumpWidget(
      _wrap(LoginScreen(authService: auth, onLoggedIn: () {})),
    );

    await tester.enterText(find.byType(TextField).at(0), 'maria');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.connectionError), findsOneWidget);
  });

  testWidgets('successful login calls onLoggedIn', (tester) async {
    var loggedIn = false;
    final auth = _FakeAuth(profile: _profile);
    await tester.pumpWidget(
      _wrap(
        LoginScreen(
          authService: auth,
          onLoggedIn: () => loggedIn = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'maria');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
    await tester.pumpAndSettle();

    expect(loggedIn, isTrue);
    expect(auth.loginCalls, 1);
  });
}