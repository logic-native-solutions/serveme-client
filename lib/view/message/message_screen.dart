import 'package:flutter/material.dart';


class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: _MessageScreen());
  }
}

class _MessageScreen extends StatefulWidget {
  const _MessageScreen();

  @override
  State<_MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<_MessageScreen> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        16,
      ),
      child: const Column(
        children: [
            Text(
                'Message',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
        ],
      ),
    );
  }
}
