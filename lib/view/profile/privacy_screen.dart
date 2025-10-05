import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false,
        backgroundColor: Color(0xFFF8FCF7) ,
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
      ),
    );
  }
}
