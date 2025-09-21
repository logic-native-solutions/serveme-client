import 'package:flutter/material.dart';


class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: _WalletScreen());
  }
}

class _WalletScreen extends StatefulWidget {
  const _WalletScreen();

  @override
  State<_WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<_WalletScreen> {
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
              'Wallet',
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
