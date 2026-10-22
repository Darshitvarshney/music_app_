// import 'package:flutter/gestures.dart';
import 'package:client/features/auth/model/auth_response_model.dart';
import 'package:client/features/auth/repositories/auth_local_repository.dart';
import 'package:client/features/auth/repositories/sign_up_in.dart';
import 'package:client/features/auth/view/pages/signup_page.dart';
import 'package:client/features/home/view/pages/home_page.dart';
import 'package:flutter/material.dart';

import 'package:client/features/auth/view/widgets/custom_field.dart';
import 'package:client/features/auth/view/widgets/signup_login_button.dart';
import 'package:client/core/theme/app_pallete.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  // final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    // nameController.dispose();
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
                  'Sign In',
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                // CustomField(
                //   hintText: 'Name',
                //   controller: nameController,
                // ),

                // const SizedBox(height: 16),
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
                  buttonText: 'Sign In',
                  isLoading: _isLoading,
                  onTap: () async {
                    if (_isLoading || !formKey.currentState!.validate()) return;

                    setState(() => _isLoading = true);
                    final repository = SignUpInRepository();
                    try {
                      final response = await repository.signIn(
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
                                fallback:
                                    'Unable to sign in. Check your email and password.',
                              ),
                            ),
                          ),
                        );
                      } else {
                        final authData =
                            AuthResponseModel.fromJson(response.body);
                        await AuthLocalRepository().saveAuthData(authData);

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              authData.message ?? 'Login successful!',
                            ),
                          ),
                        );

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomePage(user: authData.user),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to sign in. Check your connection and try again.',
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
                    // Navigate to the sign-up page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignupPage()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account ?  ",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                      children: [
                        TextSpan(
                          text: 'Sign Up',
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
