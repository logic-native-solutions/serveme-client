import 'package:client/view/profile/profile_screen.dart';
import 'package:flutter/material.dart';


class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black),
          textAlign: TextAlign.left,
        ),
        centerTitle: false,
        backgroundColor: Color(0xFFF8FCF7),
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
      ),
      // Use a scroll view and horizontal padding to ensure the form never touches screen edges
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Center(
          // Constrain the max content width for better readability on large screens
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- Avatar ----------
                const Center(),
                // Use an explicit child with BoxFit.contain so the avatar image is not zoomed/cropped
                CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/avatar.png',
                      // Contain prevents zoom-in/cropping that CircleAvatar.backgroundImage (cover) would cause
                      fit: BoxFit.contain,
                      width: 160,
                      height: 160,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                // ---------- Name (read-only display pulled from existing UserField widget) ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    UserField(
                      fieldKey: 'firstName',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    UserField(
                      fieldKey: 'lastName',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ---------- Form Fields ----------
                // Full-width inside the constrained container; never exceeds maxWidth and keeps side padding
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                // ---------- Save Button ----------
                // Make button take full width of the form area while respecting padding and maxWidth
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
