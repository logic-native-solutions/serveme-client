import 'package:flutter/material.dart';

void showToastMessage(String msg, BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}