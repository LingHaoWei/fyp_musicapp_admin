import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_admin/models/ModelProvider.dart';
import 'package:fyp_musicapp_admin/pages/home_page.dart';
import 'package:fyp_musicapp_admin/theme/app_color.dart';
import 'amplifyconfiguration.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  Future<void> _configureAmplify() async {
    try {
      final auth = AmplifyAuthCognito();
      final storage = AmplifyStorageS3();
      final api = AmplifyAPI(
        options: APIPluginOptions(modelProvider: ModelProvider.instance),
      );
      await Amplify.addPlugins([auth, storage, api]);
      await Amplify.configure(amplifyconfig);
      safePrint('Successfully configured');

      // Check initial auth state
      await _updateAuthState();

      // Listen for auth events
      Amplify.Hub.listen(HubChannel.Auth, _onAuthEvent);
    } on Exception catch (e) {
      safePrint('Error configuring Amplify: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateAuthState() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      setState(() {
        _isSignedIn = session.isSignedIn;
        _isLoading = false;
      });
    } on Exception catch (e) {
      safePrint('Error configuring Amplify: $e');
    }
  }

  void _onAuthEvent(AuthHubEvent event) {
    switch (event.type) {
      case AuthHubEventType.signedIn:
        safePrint('User is signed in.');
        _updateAuthState();
        break;
      case AuthHubEventType.signedOut:
        safePrint('User is signed out.');
        _updateAuthState();
        break;
      case AuthHubEventType.sessionExpired:
        safePrint('Session expired.');
        _updateAuthState();
        break;
      case AuthHubEventType.userDeleted:
        safePrint('User is deleted.');
        _updateAuthState();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Authenticator(
      authenticatorBuilder: _authenticatorBuilder,
      child: MaterialApp(
        theme: _buildAppTheme(),
        builder: Authenticator.builder(),
        home: _isSignedIn ? const HomePage() : const SizedBox.shrink(),
      ),
    );
  }

  Widget? _authenticatorBuilder(
      BuildContext context, AuthenticatorState state) {
    switch (state.currentStep) {
      case AuthenticatorStep.signIn:
        return CustomScaffold(
          state: state,
          body: SignInForm(),
        );
      default:
        return null; // Use default UI for other steps
    }
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      inputDecorationTheme: const InputDecorationTheme(
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
      ),
      useMaterial3: true,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: AppColor.primaryColor,
        backgroundColor: const Color(0xFFEEEEEE),
      ),
    );
  }
}

class CustomScaffold extends StatelessWidget {
  const CustomScaffold({
    super.key,
    required this.state,
    required this.body,
    this.footer,
  });

  final AuthenticatorState state;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // App logo
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child:
                      Center(child: Image.asset('images/logo.png', width: 100)),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: body,
                ),
              ],
            ),
          ),
        ),
      ),
      persistentFooterButtons: footer != null ? [footer!] : null,
    );
  }
}
