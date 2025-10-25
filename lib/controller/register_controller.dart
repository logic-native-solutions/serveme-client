import 'dart:async';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'package:client/static/load_env.dart';
import 'package:client/service/register_user.dart';
import 'package:client/model/register_model.dart';
import 'package:client/custom/social_media_buttons.dart';

class RegisterController extends ChangeNotifier {
  // ------------------------------- Constants --------------------------------
  static const List<String> genderOptions = <String>['Male', 'Female'];
  static const Map<String, String> rolePayloadMap = {
    'Client': 'CLIENT',
    'Provider': 'PROVIDER',
  };
  static const double kFieldSpacing = 12.0;
  final EdgeInsets kCountryPrefixPadding =
  const EdgeInsets.symmetric(horizontal: 12.0);

  // -------------------------------- Form ------------------------------------
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final idController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final dobController = TextEditingController();
  final mobileController = TextEditingController();

  // Role state
  String? selectedRole;
  // Gender state
  String? selectedGender;

  // Focus Nodes (kept for precise focus & keyboard behaviour)
  final firstNameFocus = FocusNode();
  final lastNameFocus = FocusNode();
  final mobileFocus = FocusNode();
  final genderFocus = FocusNode();
  final idFocus = FocusNode();
  final dobFocus = FocusNode();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  final roleFocus = FocusNode();

  // -------------------------------- State -----------------------------------
  bool acceptedTerms = false;
  bool obscurePassword = true;
  DateTime? selectedDate;
  bool isLoading = false;
  double textSize = 16;
  final FontWeight textFontWeight = FontWeight.w400;

  Country country = Country.parse('ZA'); // sensible default
  String get dialCode => '+${country.phoneCode}';

  // Errors
  final errors = RegisterErrors();

  // Service
  late final RegisterUserService _registerService =
  RegisterUserService(Env.httpsServer);

  // -------------------------------- Lifecycle -------------------------------
  void init(BuildContext context) {
    loadEnv(); // ensure .env is loaded before using Env
  }

  @override
  void dispose() {
    // Controllers
    firstNameController.dispose();
    lastNameController.dispose();
    idController.dispose();
    emailController.dispose();
    passwordController.dispose();
    dobController.dispose();
    mobileController.dispose();

    // Focus nodes
    firstNameFocus.dispose();
    lastNameFocus.dispose();
    mobileFocus.dispose();
    genderFocus.dispose();
    idFocus.dispose();
    dobFocus.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();

    super.dispose();
  }

  // -------------------------------- Validators ------------------------------
  String? validateFirstName(String? v) {
    if (v == null || v.trim().isEmpty) {
      errors.firstName = 'First Name is required';
      return errors.firstName;
    }
    return null;
  }

  String? validateLastName(String? v) {
    if (v == null || v.trim().isEmpty) {
      errors.lastName = 'Last Name is required';
      return errors.lastName;
    }
    return null;
  }

  String? validateGender(String? v) {
    if (v == null || v.trim().isEmpty) {
      errors.gender = 'Gender is required';
      return errors.gender;
    }
    return null;
  }

  String? validateRole(String? v) {
    if (v == null || v.trim().isEmpty) {
      errors.role = 'Role is required';
      return errors.role;
    }
    return null;
  }

  String? validateId(String? v) {
    if (v == null || v.trim().isEmpty) {
      errors.idNumber = 'ID Number is required';
      return errors.idNumber;
    }
    if (v.length != 13) {
      errors.idNumber = 'ID Number must be 13 digits';
      return errors.idNumber;
    }
    if (!RegExp(r'^\d{13}$').hasMatch(v)) {
      errors.idNumber = 'ID Number must be numeric';
      return errors.idNumber;
    }
    return null;
  }

  String? validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) {
      errors.email = 'Please enter your email';
      return errors.email;
    }
    if (!RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$').hasMatch(v)) {
      errors.email = 'Enter a valid email address';
      return errors.email;
    }
    return null;
  }

  String? validatePassword(String? v) {
    if (v == null || v.isEmpty) {
      errors.password = 'Please enter your password';
      return errors.password;
    }
    final strong =
    RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@#$%^&+=!]).{8,}$');
    if (!strong.hasMatch(v)) {
      errors.password = 'Password must be 8+ chars, include upper, lower, number & special char';
      return errors.password;
    }
    return null;
  }

  String? validateMobileLocal(String? v) {
    if (v == null || v.trim().isEmpty) {
      errors.phoneNumber = 'Mobile number is required';
      return errors.phoneNumber;
    }
    try {
      final parsed = _parseWithCountry(v, country.countryCode);
      final ok = parsed.isValid(type: PhoneNumberType.mobile);
      return ok ? null : errors.phoneNumber = 'Enter a valid mobile number';
    } catch (_) {
      return errors.phoneNumber = 'Enter a valid mobile number';
    }
  }

  // -------------------------------- Helpers ---------------------------------
  String _toE164(PhoneNumber p) => '+${p.countryCode}${p.nsn}';

  PhoneNumber _parseWithCountry(String raw, String iso2) {
    final iso = IsoCode.values.firstWhere(
          (c) => c.name.toUpperCase() == iso2.toUpperCase(),
      orElse: () => IsoCode.ZA,
    );
    return PhoneNumber.parse(raw.trim(), destinationCountry: iso);
  }

  void onMobileChanged(String v) {
    try {
      final parsed = _parseWithCountry(v, country.countryCode);
      final formatted = parsed.formatNsn();
      if (formatted.isNotEmpty && formatted != v) {
        mobileController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    } catch (_) {/* ignore while typing */}
  }

  void normalizeMobileToE164() {
    try {
      final parsed =
      _parseWithCountry(mobileController.text, country.countryCode);
      if (parsed.isValid(type: PhoneNumberType.mobile)) {
        mobileController.text = _toE164(parsed); // e.g., +27123456789
      }
    } catch (_) {/* ignore */}
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final ctx = formKey.currentContext;
    if (ctx == null) return;

    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      selectedDate = picked;
      dobController.text =
      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      notifyListeners();
    }
  }

  // -------------------------------- Actions ---------------------------------
  Future<void> onRegister(BuildContext context) async {
    if (isLoading) return;

    // Run validators first
    final valid = formKey.currentState?.validate() ?? false;

    // Extra safety: ensure non-null for fields not bound to a TextFormField
    String? banner;
    if (selectedGender == null) {
      errors.gender = 'Gender is required';
      banner ??= 'Please complete required fields.';
    }
    if (selectedRole == null) {
      errors.role = 'Role is required';
      banner ??= 'Please complete required fields.';
    }
    if (selectedDate == null) {
      errors.dateOfBirth = 'Please select your date of birth';
      banner ??= 'Please complete required fields.';
    }

    if (!valid || banner != null) {
      notifyListeners();
      return;
    }

    isLoading = true;
    errors.clear();
    notifyListeners();

    final rolePayload =
        rolePayloadMap[selectedRole] ?? selectedRole!.toUpperCase();

    final result = await _registerService.submit(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
      phoneNumber: mobileController.text,
      gender: selectedGender!,
      role: rolePayload,
      idNumber: idController.text,
      dateOfBirth: selectedDate!,
      email: emailController.text,
      password: passwordController.text,
    );

    if (result.success) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/otp',
          arguments: <String, Object>{
            'email': emailController.text,
            'phone': mobileController.text,
            'sessionId': result.sessionId!,
          },
        );
      }
      isLoading = false;
      notifyListeners();
      return;
    }

    // Map server-side errors back to UI
    errors.firstName = result.firstName;
    errors.lastName = result.lastName;
    errors.phoneNumber = result.phoneNumber;
    errors.gender = result.gender;
    errors.role = result.role;
    errors.idNumber = result.idNumber;
    errors.dateOfBirth = result.dateOfBirth;
    errors.email = result.email;
    errors.password = result.password;
    errors.role = result.role;
    errors.message = result.message;

    if (context.mounted && errors.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.message!)),
      );
    }

    isLoading = false;
    notifyListeners();
  }

  // -------------------------------- UI helpers ------------------------------
  List<Widget> socialButtons(BuildContext context) => [
    SocialBox(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google login tapped')),
        );
      },
      child: Image.asset('assets/images/google.png', height: 26, width: 26),
    ),
    const SizedBox(width: 16),
    SocialBox(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple login tapped')),
        );
      },
      child: const Icon(Icons.apple, size: 26),
    ),
  ];

  // ------------------------------- View toggles ------------------------------
  void toggleObscure() {
    obscurePassword = !obscurePassword;
  }
}