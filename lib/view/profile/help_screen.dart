import 'package:flutter/material.dart';
import '';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help Center',
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
