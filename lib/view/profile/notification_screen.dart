import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Notifications',
            style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Color(0xFFF8FCF7),
        centerTitle: false,
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
      ),

    );
  }
}
