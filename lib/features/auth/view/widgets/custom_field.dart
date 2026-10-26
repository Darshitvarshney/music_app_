import 'package:flutter/material.dart';

class CustomField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final bool isEmail;

  /// 6-digit numeric code (e.g. the sign-up invite code)
  final bool isCode;
  const CustomField({
    super.key,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.isEmail = false,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {  
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : (isCode ? TextInputType.number : TextInputType.text),
      maxLength: isCode ? 6 : null,
      // obscuringCharacter: '*',
      decoration: InputDecoration(
        hintText: hintText,
        counterText: isCode ? '' : null,
      ),
      validator: (value) {
        if (value!.trim().isEmpty) {
          return 'Please enter $hintText';
        }
        if (isEmail &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
          return 'Please enter a valid email address';
        }
        if (isCode && !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
          return '$hintText must be 6 digits';
        }
        return null;
      },
    );
  }
}