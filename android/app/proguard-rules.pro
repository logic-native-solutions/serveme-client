# ProGuard/R8 rules for Paystack SDK and related AndroidX classes used during 3DS flows.
# These are conservative keep rules to avoid NoClassDefFoundError in release builds.

# Keep all Paystack Android SDK classes
-keep class co.paystack.android.** { *; }
-dontwarn co.paystack.android.**

# (Optional) Keep AndroidX Fragment classes used by FlutterFragmentActivity
-keep class androidx.fragment.app.** { *; }
-dontwarn androidx.fragment.app.**
