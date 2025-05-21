import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  String? _error;
  bool _loading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;

  final AuthService _authService = AuthService();

  void _toggleForm() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _usernameError = null;
    });
  }

  Future<void> _validateUsername(String username) async {
    if (username.isEmpty) {
      setState(() {
        _usernameError = 'Username cannot be empty';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _usernameError = 'Username must be at least 3 characters';
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _usernameError =
            'Username can only contain letters, numbers, and underscore';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      bool exists = await _authService.checkUsernameExists(username);
      if (exists) {
        setState(() {
          _usernameError = 'Username is already taken';
        });
      }
    } catch (e) {
      setState(() {
        _usernameError = 'Error checking username';
      });
    } finally {
      setState(() {
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _handleEmailAuth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await _authService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        // For registration, validate username first
        if (_usernameController.text.isEmpty) {
          setState(() {
            _error = 'Username is required';
            _loading = false;
          });
          return;
        }

        // Check username one more time before registration
        bool exists = await _authService.checkUsernameExists(
          _usernameController.text,
        );
        if (exists) {
          setState(() {
            _error = 'Username is already taken';
            _loading = false;
          });
          return;
        }

        await _authService.signUpWithEmail(
          _emailController.text,
          _passwordController.text,
          _usernameController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In or Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    errorText: _usernameError,
                    helperText:
                        'This will be used as @username to add you to trips',
                    suffixIcon:
                        _isCheckingUsername
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : null,
                  ),
                  onChanged: (value) => _validateUsername(value),
                ),
              ],
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _handleEmailAuth,
                    child: Text(_isLogin ? 'Login' : 'Sign Up'),
                  ),
              TextButton(
                onPressed: _toggleForm,
                child: Text(
                  _isLogin
                      ? 'Create an account'
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
