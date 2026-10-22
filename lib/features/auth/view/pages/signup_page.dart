// import 'package:flutter/gestures.dart';
import 'package:client/features/auth/model/auth_response_model.dart';
import 'package:client/features/auth/repositories/auth_local_repository.dart';
import 'package:client/features/auth/repositories/sign_up_in.dart';
import 'package:client/features/auth/view/pages/login_page.dart';
import 'package:flutter/material.dart';

import 'package:client/features/auth/view/widgets/custom_field.dart';
import 'package:client/features/auth/view/widgets/signup_login_button.dart';
import 'package:client/core/theme/app_pallete.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(15.0),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                CustomField(hintText: 'Name', controller: nameController),

                const SizedBox(height: 16),

                CustomField(
                  hintText: 'Email',
                  controller: emailController,
                  isEmail: true,
                ),

                const SizedBox(height: 16),

                CustomField(
                  hintText: 'Password',
                  controller: passwordController,
                  obscureText: true,
                ),

                const SizedBox(height: 16),

                SignupLoginButton(
                  buttonText: 'Sign Up',
                  isLoading: _isLoading,
                  onTap: () async {
                    if (_isLoading || !formKey.currentState!.validate()) return;

                    setState(() => _isLoading = true);
                    final repository = SignUpInRepository();
                    try {
                      final response = await repository.signUp(
                        name: nameController.text,
                        email: emailController.text,
                        password: passwordController.text,
                      );

                      if (!context.mounted) return;

                      if (response.statusCode < 200 ||
                          response.statusCode >= 300) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              repository.errorMessage(
                                response,
                                fallback: 'Unable to sign up. Please try again.',
                              ),
                            ),
                          ),
                        );
                      } else {
                        try {
                          final authData =
                              AuthResponseModel.fromJson(response.body);
                          await AuthLocalRepository().saveAuthData(authData);
                        } catch (_) {}

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Account created successfully! Please sign in.',
                            ),
                          ),
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SigninPage(),
                          ),
                        );
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to sign up. Check your connection and try again.',
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                ),

                const SizedBox(height: 7),

                GestureDetector(
                  onTap: () {
                    // Navigate to the sign-in page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SigninPage()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Already have an account ?  ',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            color: Pallete.gradient1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
