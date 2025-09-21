import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// ---------------------------------------------------------------------------
/// Loader
/// Centralized app-wide loading indicator.
///
/// This uses [SpinKitCubeGrid] from `flutter_spin kit` to display a subtle
/// cube-grid animation in the brand color.
///
/// Usage
/// -----
/// ```dart
/// return const Center(child: AppLoader());
/// ```
///
/// Or wrap in a [SizedBox] for fixed sizing.
/// ---------------------------------------------------------------------------

/// A preconfigured [SpinKitCubeGrid] used as the default loading indicator.
final Widget appLoader = SpinKitCubeGrid(
  itemBuilder: (BuildContext context, int index) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.green,
      ),
    );
  },
);