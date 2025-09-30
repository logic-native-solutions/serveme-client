import 'package:flutter/material.dart';
import 'package:client/controller/register_controller.dart';
import 'package:country_picker/country_picker.dart';


/// ---------------------------------------------------------------------------
/// RegisterScreen
///
/// Presents the registration form inside a scrollable, keyboard-safe layout.
/// Responsibilities:
///  • Scaffold that shifts content when the keyboard appears
///  • Tap-to-dismiss keyboard gesture
///  • Centers content and constrains max width on large screens
/// ---------------------------------------------------------------------------
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      resizeToAvoidBottomInset: true, // body slides up with keyboard
      body: SafeArea(child: _RegisterBody()),
    );
  }
}

/// ---------------------------------------------------------------------------
/// _RegisterBody
///
/// Internal body for [RegisterScreen]. Handles padding, scrolling, and layout.
/// ---------------------------------------------------------------------------
class _RegisterBody extends StatelessWidget {
  const _RegisterBody();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard on tap
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              15,                // breathing room at top
              16,
              bottomInset + 16,  // space for keyboard
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading
                    Text(
                      'Register',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Subtitle
                    const Text(
                      'Please fill in the fields below to create account.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Registration form
                    const _RegisterForm(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// RegisterForm (View-only). All logic is in RegisterController.
class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  late final RegisterController controller;

  @override
  void initState() {
    super.initState();
    controller = RegisterController()..init(context);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // ------------------------------ UI Pieces ---------------------------------
  Widget _firstNameField() => TextFormField(
    controller: controller.firstNameController,
    focusNode: controller.firstNameFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(
        fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.person, size: 20),
      labelText: 'First Name',
      labelStyle: TextStyle(
          fontSize: controller.textSize,
          fontWeight: controller.textFontWeight),
      hintText: 'John',
      errorText: controller.errors.firstName,
    ),
    validator: controller.validateFirstName,
  );

  Widget _lastNameField() => TextFormField(
    controller: controller.lastNameController,
    focusNode: controller.lastNameFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(
        fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.person, size: 20),
      labelText: 'Last Name',
      labelStyle: TextStyle(
          fontSize: controller.textSize,
          fontWeight: controller.textFontWeight),
      hintText: 'Doe',
      errorText: controller.errors.lastName,
    ),
    validator: controller.validateLastName,
  );

  Widget _mobileField() => TextFormField(
    controller: controller.mobileController,
    focusNode: controller.mobileFocus,
    keyboardType: TextInputType.phone,
    textInputAction: TextInputAction.next,
    style: TextStyle(
        fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    decoration: InputDecoration(
      labelText: 'Mobile Number',
      labelStyle: TextStyle(
          fontSize: controller.textSize,
          fontWeight: controller.textFontWeight),
      hintText: '071 234 5678',
      errorText: controller.errors.phoneNumber,
      // Country picker prefix: emoji flag + +code + chevron
      prefixIcon: InkWell(
        onTap: () {
          showCountryPicker(
            context: context,
            showPhoneCode: true,
            onSelect: (c) => setState(() => controller.country = c),
          );
        },
        child: Padding(
          padding: controller.kCountryPrefixPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(controller.country.flagEmoji,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(controller.dialCode,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    ),
    validator: controller.validateMobileLocal,
    onChanged: (v) => setState(() => controller.onMobileChanged(v)),
    onFieldSubmitted: (_) {
      controller.normalizeMobileToE164();
      setState(() {});
    },
  );

  Widget _genderField() => LayoutBuilder(
    builder: (context, constraints) {
      final double fieldWidth = constraints.maxWidth;
      final options = RegisterController.genderOptions;

      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: fieldWidth),
        child: FormField<String>(
          validator: (_) => controller.validateGender(controller.selectedGender),
          builder: (formState) {
            return Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                final q = textEditingValue.text.trim().toLowerCase();
                if (q.isEmpty) return options;
                return options.where((o) => o.toLowerCase().contains(q));
              },
              onSelected: (v) {
                setState(() => controller.selectedGender = v);
                formState.didChange(v);
              },
              displayStringForOption: (o) => o,
              fieldViewBuilder:
                  (context, textController, focusNode, onFieldSubmitted) {
                if ((controller.selectedGender ?? '').isNotEmpty &&
                    textController.text != controller.selectedGender) {
                  textController.text = controller.selectedGender!;
                }
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  style: TextStyle(
                      fontSize: controller.textSize,
                      fontWeight: controller.textFontWeight),
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(
                        fontSize: controller.textSize,
                        fontWeight: controller.textFontWeight),
                    hintText: 'Select gender',
                    errorText:
                    formState.errorText ?? controller.errors.gender,
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
                    setState(() => controller.selectedGender =
                    v.trim().isEmpty ? null : v);
                    formState.didChange(controller.selectedGender);
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

  Widget _roleField() => LayoutBuilder(
    builder: (context, constraints) {
      final double fieldWidth = constraints.maxWidth;
      const options = ['Client', 'Provider'];

      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: fieldWidth),
        child: FormField<String>(
          validator: (_) => controller.validateRole(controller.selectedRole),
          builder: (formState) {
            return Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                final q = textEditingValue.text.trim().toLowerCase();
                if (q.isEmpty) return options;
                return options.where((o) => o.toLowerCase().contains(q));
              },
              onSelected: (v) {
                setState(() => controller.selectedRole = v);
                formState.didChange(v);
              },
              displayStringForOption: (o) => o,
              fieldViewBuilder: (context, textController, focusNode, _) {
                final role = controller.selectedRole;
                if ((role ?? '').isNotEmpty && textController.text != role) {
                  textController.text = role!;
                }
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  style: TextStyle(
                    fontSize: controller.textSize,
                    fontWeight: controller.textFontWeight,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(
                      fontSize: controller.textSize,
                      fontWeight: controller.textFontWeight,
                    ),
                    hintText: 'Select role',
                    errorText: formState.errorText ?? controller.errors.role,
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
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
                    final val = v.trim().isEmpty ? null : v;
                    setState(() => controller.selectedRole = val);
                    formState.didChange(controller.selectedRole);
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
              optionsViewBuilder: (context, onSelected, opts) {
                final int visibleRows = opts.length < 2 ? opts.length : 2;
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
                        itemCount: opts.length,
                        itemBuilder: (context, index) {
                          final option = opts.elementAt(index);
                          return ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -2),
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
    controller: controller.idController,
    focusNode: controller.idFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(
        fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: 'Identification Number (ID)',
      labelStyle: TextStyle(
          fontSize: controller.textSize,
          fontWeight: controller.textFontWeight),
      hintText: '9001014800086',
      prefixIcon: const Icon(Icons.badge, size: 20),
      errorText: controller.errors.idNumber,
    ),
    validator: controller.validateId,
  );

  Widget _dobField() => TextFormField(
    controller: controller.dobController,
    focusNode: controller.dobFocus,
    readOnly: true,
    textInputAction: TextInputAction.next,
    style: TextStyle(
        fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    decoration: InputDecoration(
      labelText: 'Date of Birth',
      labelStyle: TextStyle(
          fontSize: controller.textSize,
          fontWeight: controller.textFontWeight),
      hintText: 'DD/MM/YYYY',
      errorText: controller.errors.dateOfBirth,
      suffixIcon: IconButton(
        icon: const Icon(Icons.calendar_month, size: 20),
        onPressed: () async {
          await controller.pickDate();
          if (mounted) setState(() {});
        },
      ),
    ),
    onTap: () async {
      await controller.pickDate();
      if (mounted) setState(() {});
    },
    validator: (_) => controller.selectedDate == null
        ? 'Please select your date of birth'
        : null,
  );

  Widget _emailField() => TextFormField(
    controller: controller.emailController,
    focusNode: controller.emailFocus,
    textInputAction: TextInputAction.next,
    style: TextStyle(
        fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    keyboardType: TextInputType.emailAddress,
    decoration: InputDecoration(
      labelText: 'Email',
      labelStyle: TextStyle(
          fontSize: controller.textSize,
          fontWeight: controller.textFontWeight),
      hintText: 'john.doe@example.com',
      prefixIcon: const Icon(Icons.email, size: 20),
      errorText: controller.errors.email,
    ),
    validator: controller.validateEmail,
  );

  Widget _passwordField() => TextFormField(
    controller: controller.passwordController,
    focusNode: controller.passwordFocus,
    textInputAction: TextInputAction.done,
    style: TextStyle(
        fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    obscureText: controller.obscurePassword,
    decoration: InputDecoration(
      labelText: 'Password',
      labelStyle: TextStyle(
          fontSize: controller.textSize,
          fontWeight: controller.textFontWeight),
      hintText: 'Minimum 8 chars, upper, lower, number, symbol',
      errorText: controller.errors.password,
      suffixIcon: IconButton(
        icon: Icon(controller.obscurePassword
            ? Icons.visibility_off
            : Icons.visibility, size: 20),
        onPressed: () => setState(controller.toggleObscure),
      ),
    ),
    validator: controller.validatePassword,
  );

  Widget _termsRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Checkbox(
        value: controller.acceptedTerms,
        onChanged: (b) => setState(() => controller.acceptedTerms = b ?? false),
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
    onPressed: (controller.isLoading || !controller.acceptedTerms)
        ? null
        : () => controller.onRegister(context),
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    child: controller.isLoading
        ? const SizedBox(
        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
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
    children: controller.socialButtons(context),
  );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Simple setState-based rebuilds; you can swap to Provider/Riverpod later.
    return Form(
      key: controller.formKey,
      child: Column(
        children: [
          _firstNameField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _lastNameField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _mobileField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _genderField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _roleField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _idField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _dobField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _emailField(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _passwordField(),
          const SizedBox(height: 10),
          _termsRow(),
          const SizedBox(height: 10),
          _continueButton(),
          const SizedBox(height: 5),
          _loginPrompt(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _orContinueWith(),
          const SizedBox(height: RegisterController.kFieldSpacing),
          _socialButtons(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}