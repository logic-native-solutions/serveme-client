import 'package:flutter/material.dart';

import 'package:client/custom/social_media_buttons.dart';
import 'package:client/static/load_env.dart';
import 'package:client/service/register_user.dart';

import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// ---------------------------------------------------------------------------
/// RegisterForm
/// A Material 3 registration form that collects personal details, contact,
/// and credentials; validates inputs; and submits to RegisterUserService.
/// On success, navigates to the OTP screen with required arguments.
/// ---------------------------------------------------------------------------
class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

/// ---------------------------------------------------------------------------
/// Constants & Configuration (grouped)
/// ---------------------------------------------------------------------------
const List<String> kGenderOptions = <String>['Male', 'Female'];
const double kFieldSpacing = 12.0;
const EdgeInsets kCountryPrefixPadding = EdgeInsets.symmetric(horizontal: 12.0);

class _RegisterFormState extends State<RegisterForm> {
  // ---------------------------------------------------------------------------
  // Form & Services
  // ---------------------------------------------------------------------------
  final _formKey = GlobalKey<FormState>();
  late final RegisterUserService _registerService = RegisterUserService(Env.httpsServer);

  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------
  final firstNameController = TextEditingController();
  final lastNameController  = TextEditingController();
  final idController        = TextEditingController();
  final emailController     = TextEditingController();
  final passwordController  = TextEditingController();
  final dobController       = TextEditingController();
  final mobileController    = TextEditingController();

  // ---------------------------------------------------------------------------
  // Focus Nodes (one per field to avoid shared focus/cursor issues)
  // ---------------------------------------------------------------------------
  final firstNameFocus = FocusNode();
  final lastNameFocus  = FocusNode();
  final mobileFocus    = FocusNode();
  final genderFocus    = FocusNode();
  final idFocus        = FocusNode();
  final dobFocus       = FocusNode();
  final emailFocus     = FocusNode();
  final passwordFocus  = FocusNode();

  // ---------------------------------------------------------------------------
  // UI State
  // ---------------------------------------------------------------------------
  bool _accepted = false;          // Terms & conditions
  bool _obscurePassword = true;    // Password visibility toggle
  String? selectedGender;          // Gender selection
  DateTime? selectedDate;          // Date of birth selection
  bool _isLoading = false; // prevents double-submits, disables inputs
  double textSize = 16;
  final textFontWeight = FontWeight.w400;

  // Country selection for phone input (emoji flag + dial code)
  Country _country = Country.parse('ZA'); // Sensible default
  String get _dialCode => '+${_country.phoneCode}';

  // ---------------------------------------------------------------------------
  // Server/Field Error Strings (populated from backend on failure)
  // ---------------------------------------------------------------------------
  String? firstNameError;
  String? lastNameError;
  String? mobileError;
  String? idError;
  String? emailError;
  String? passwordError;
  String? dobError;
  String? genderError;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Validators (pure, deterministic)
  // ---------------------------------------------------------------------------
  String? _validateFirstName(String? v) {
    if (v == null || v.trim().isEmpty) return 'First Name is required';
    return null;
  }

  String? _validateLastName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Last Name is required';
    return null;
  }

  String? _validateGender(String? v) {
    if (v == null || v.trim().isEmpty) return 'Gender is required';
    return null;
  }

  String? _validateId(String? v) {
    if (v == null || v.trim().isEmpty) return 'ID Number is required';
    if (v.length != 13) return 'ID Number must be 13 digits';
    if (!RegExp(r'^\d{13}$').hasMatch(v)) return 'ID Number must be numeric';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    final strong = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@#$%^&+=!]).{8,}$');
    if (!strong.hasMatch(v)) {
      return 'Password must be 8+ chars, include upper, lower, number & special char';
    }
    return null;
  }

  /// Phone validator using phone_numbers_parser v9 + selected destination country.
  String? _validateMobileLocal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    try {
      final parsed = _parseWithCountry(v, _country.countryCode);
      final ok = parsed.isValid(type: PhoneNumberType.mobile);
      return ok ? null : 'Enter a valid mobile number';
    } catch (_) {
      return 'Enter a valid mobile number';
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Build +(countryCode)(nsn) (E.164) from a parsed number (v9-friendly).
  String _toE164V9(PhoneNumber p) => '+${p.countryCode}${p.nsn}';

  /// Parse using the selected country (from country_picker) as the destination.
  PhoneNumber _parseWithCountry(String raw, String iso2) {
    final iso = IsoCode.values.firstWhere(
          (c) => c.name.toUpperCase() == iso2.toUpperCase(),
      orElse: () => IsoCode.ZA,
    );
    return PhoneNumber.parse(raw.trim(), destinationCountry: iso);
  }

  /// Opens a date picker and sets both [selectedDate] & [dobController.text].
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dobController.text =
        '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  /// Submits the form to RegisterUserService and maps server errors to fields.
  Future<void> _onRegister() async {
    if (_isLoading) return; // guard: user is already submitting
    if (!_formKey.currentState!.validate()) return;

    // Clear previous errors
    setState(() {
      _isLoading = true;
      firstNameError = lastNameError = mobileError = genderError =
          idError = dobError = emailError = passwordError = null;
    });

    final result = await _registerService.submit(
      firstName:   firstNameController.text,
      lastName:    lastNameController.text,
      phoneNumber: mobileController.text,
      gender:      selectedGender!,
      idNumber:    idController.text,
      dateOfBirth: selectedDate!,
      email:       emailController.text,
      password:    passwordController.text,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pushReplacementNamed(
        context,
        '/otp',
        arguments: <String, Object>{
          'email': emailController.text,
          'phone': mobileController.text,
          'sessionId': result.sessionId!,
        },
      );
      return;
    }

    // Map server-side validation errors back to local UI
    setState(() {
      firstNameError = result.firstName;
      lastNameError  = result.lastName;
      mobileError    = result.phoneNumber;
      genderError    = result.gender;
      idError        = result.idNumber;
      dobError       = result.dateOfBirth;
      emailError     = result.email;
      passwordError  = result.password;

      if (result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets (focused builders keep build() clean)
  // ---------------------------------------------------------------------------

  Widget _firstNameField() => TextFormField(
    controller: firstNameController,
    focusNode: firstNameFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.person, size: 20),
      labelText: 'First Name',
      labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
      hintText: 'John',
      errorText: firstNameError,
    ),
    validator: _validateFirstName,
  );

  Widget _lastNameField() => TextFormField(
    controller: lastNameController,
    focusNode: lastNameFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.person, size: 20),
      labelText: 'Last Name',
      labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
      hintText: 'Doe',
      errorText: lastNameError,
    ),
    validator: _validateLastName,
  );

  Widget _mobileField() => TextFormField(
    controller: mobileController,
    focusNode: mobileFocus,
    keyboardType: TextInputType.phone,
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
    decoration: InputDecoration(
      labelText: 'Mobile Number',
      labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
      hintText: '071 234 5678',
      errorText: mobileError,
      // Country picker prefix: emoji flag + +code + chevron
      prefixIcon: InkWell(
        onTap: () {
          showCountryPicker(
            context: context,
            showPhoneCode: true,
            onSelect: (c) => setState(() => _country = c),
          );
        },
        child: Padding(
          padding: kCountryPrefixPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_country.flagEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(_dialCode, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    ),
    validator: (_) => _validateMobileLocal(mobileController.text),
    onChanged: (v) {
      // Optional: prettify national format as the user types
      try {
        final parsed = _parseWithCountry(v, _country.countryCode);
        final formatted = parsed.formatNsn();
        if (formatted.isNotEmpty && formatted != v) {
          mobileController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      } catch (_) {/* ignore while typing */}
    },
    onFieldSubmitted: (_) {
      // Normalize to E.164 for backend
      try {
        final parsed = _parseWithCountry(mobileController.text, _country.countryCode);
        if (parsed.isValid(type: PhoneNumberType.mobile)) {
          mobileController.text = _toE164V9(parsed); // e.g., +27123456789
        }
      } catch (_) {/* ignore */}
    },
  );

  Widget _genderField() => LayoutBuilder(
    builder: (context, constraints) {
      final double fieldWidth = constraints.maxWidth; // Use full width; remove 360 cap
      final options = kGenderOptions;

      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: fieldWidth),
        child: FormField<String>(
          validator: (_) => _validateGender(selectedGender),
          builder: (formState) {
            return Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                final q = textEditingValue.text.trim().toLowerCase();
                if (q.isEmpty) return options;
                return options.where((o) => o.toLowerCase().contains(q));
              },
              onSelected: (v) {
                setState(() => selectedGender = v);
                formState.didChange(v);
              },
              displayStringForOption: (o) => o,
              fieldViewBuilder:
                  (context, textController, focusNode, onFieldSubmitted) {
                if ((selectedGender ?? '').isNotEmpty &&
                    textController.text != selectedGender) {
                  textController.text = selectedGender!;
                }
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                    hintText: 'Select gender',
                    // prefixIcon: const Icon(Icons.wc), // Removed as requested
                    errorText: formState.errorText ?? genderError,
                    prefixIcon: const Icon(Icons.wc, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(null),
                      tooltip: 'Show all',
                      onPressed: () {
                        if (textController.text.isEmpty) {
                          textController.text = ' ';
                          textController.selection =
                          const TextSelection.collapsed(offset: 1);
                          Future.microtask(textController.clear);
                        } else {
                          final v = textController.text;
                          textController.text = v;
                          textController.selection =
                              TextSelection.collapsed(offset: v.length);
                        }
                      },
                    ),
                  ),
                  onChanged: (v) {
                    setState(() => selectedGender =
                    v.trim().isEmpty ? null : v);
                    formState.didChange(selectedGender);
                  },
                  textInputAction: TextInputAction.next,
                  onTap: () {
                    if (textController.text.isEmpty) {
                      textController.text = ' ';
                      textController.selection =
                      const TextSelection.collapsed(offset: 1);
                      Future.microtask(textController.clear);
                    }
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                // Limit popup to at most two rows; smaller if only 1 result.
                final int visibleRows =
                options.length < 2 ? options.length : 2;
                const double rowHeight = 48.0;
                final double popupMaxHeight =
                    (visibleRows.clamp(0, 2)) * rowHeight;

                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: fieldWidth,
                        maxHeight: popupMaxHeight,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemExtent: rowHeight,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                            dense: true,
                            visualDensity:
                            const VisualDensity(vertical: -2),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  );

  Widget _idField() => TextFormField(
    controller: idController,
    focusNode: idFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: 'Identification Number (ID)',
      labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
      hintText: '9001014800086',
      prefixIcon: const Icon(Icons.badge, size: 20),
      errorText: idError,
    ),
    validator: _validateId,
  );

  Widget _dobField() => TextFormField(
    controller: dobController,
    focusNode: dobFocus,
    readOnly: true,
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
    decoration: InputDecoration(
      labelText: 'Date of Birth',
      labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
      hintText: 'DD/MM/YYYY',
      errorText: dobError,
      // prefixIcon: const Icon(Icons.cake_outlined), // Removed as requested
      suffixIcon: IconButton(
        icon: const Icon(Icons.calendar_month, size: 20),
        onPressed: _pickDate,
      ),
    ),
    onTap: _pickDate,
    validator: (_) =>
    (selectedDate == null) ? 'Please select your date of birth' : null,
  );

  Widget _emailField() => TextFormField(
    controller: emailController,
    focusNode: emailFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
    keyboardType: TextInputType.emailAddress,
    decoration: InputDecoration(
      labelText: 'Email',
      labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
      hintText: 'john.doe@example.com',
      prefixIcon: const Icon(Icons.email, size: 20),
      errorText: emailError,
    ),
    validator: _validateEmail,
  );

  Widget _passwordField() => TextFormField(
    controller: passwordController,
    focusNode: passwordFocus,
    textInputAction: TextInputAction.done,
    style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
    obscureText: _obscurePassword,
    decoration: InputDecoration(
      labelText: 'Password',
      labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
      hintText: 'Minimum 8 chars, upper, lower, number, symbol',
      errorText: passwordError,
      // prefixIcon: const Icon(Icons.lock), // Removed as requested
      suffixIcon: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    ),
    validator: _validatePassword,
  );

  Widget _termsRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Checkbox(
        value: _accepted,
        onChanged: (b) => setState(() => _accepted = b ?? false),
      ),
      const SizedBox(width: 1),
      Expanded(
        child: GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/terms'),
          child: const Text(
            'By registering, you agree to our Terms and Conditions.',
            maxLines: 3,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    ],
  );


  Widget _continueButton() => FilledButton(
    onPressed: (_isLoading || !_accepted) ? null : _onRegister,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    child: _isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Continue'),
  );

  Widget _loginPrompt() => Align(
    alignment: Alignment.center,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Already have an account? '),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          child: const Text('Log in'),
        ),
      ],
    ),
  );

  Widget _orContinueWith() => Row(
    children: const [
      Expanded(child: Divider(endIndent: 8)),
      Text('or continue with'),
      Expanded(child: Divider(indent: 8)),
    ],
  );

  Widget _socialButtons() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 16,
    runSpacing: 8,
    children: [
      SocialBox(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google login tapped')),
          );
        },
        child: Image.asset('assets/images/google.png', height: 26, width: 26),
      ),
      SocialBox(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Apple login tapped')),
          );
        },
        child: const Icon(Icons.apple, size: 26),
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _firstNameField(),
          const SizedBox(height: kFieldSpacing),
          _lastNameField(),
          const SizedBox(height: kFieldSpacing),
          _mobileField(),
          const SizedBox(height: kFieldSpacing),
          _genderField(),
          const SizedBox(height: kFieldSpacing),
          _idField(),
          const SizedBox(height: kFieldSpacing),
          _dobField(),
          const SizedBox(height: kFieldSpacing),
          _emailField(),
          const SizedBox(height: kFieldSpacing),
          _passwordField(),
          const SizedBox(height: 10),
          _termsRow(),
          const SizedBox(height: 10),
          _continueButton(),
          const SizedBox(height: 5),
          _loginPrompt(),
          const SizedBox(height: kFieldSpacing),
          _orContinueWith(),
          const SizedBox(height: kFieldSpacing),
          _socialButtons(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}