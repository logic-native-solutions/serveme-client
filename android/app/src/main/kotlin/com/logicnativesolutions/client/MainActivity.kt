package com.logicnativesolutions.client

import io.flutter.embedding.android.FlutterFragmentActivity

// MainActivity for the Android app.
// Some payment SDKs (including Paystack 3DS flows) require FragmentActivity.
// Extending FlutterFragmentActivity ensures 3-D Secure card auth screens can work.
class MainActivity : FlutterFragmentActivity()
