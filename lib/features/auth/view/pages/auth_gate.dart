import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../model/user_model.dart';
import '../../repositories/auth_local_repository.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../../home/view/pages/home_page.dart';
import 'signup_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _localRepo = AuthLocalRepository();
  final _authViewModel = AuthViewModel();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final refreshToken = await _localRepo.getRefreshToken();
      final cachedUser = await _localRepo.getUser();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _user = cachedUser;
            _isLoading = false;
          });
        }

        // Silently validate and refresh session in background
        _authViewModel.checkAuthAndRefreshToken().then((valid) {
          if (!valid && mounted) {
            // Session expired or invalidated on backend
            setState(() {
              _isAuthenticated = false;
              _user = null;
            });
          }
        });
        return;
      }
    } catch (_) {
      // In case of read errors, fall back to unauthenticated screen
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Pallete.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Pallete.gradient2,
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      return HomePage(user: _user);
    }

    return const SignupPage();
  }
}
