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
        backgroundColor: Color(0xFFF8FCF7) ,
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 20),
          Center(),
          CircleAvatar(
              radius: 80,
              backgroundColor: Colors.grey,
              backgroundImage: AssetImage('assets/images/avatar.png')
          ),
          SizedBox(height: 7),
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

          SizedBox(height: 30),

          SizedBox(
            width: 400,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
          ),
          ),

          SizedBox(height: 20),

          SizedBox(
            width: 400,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 400,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 400,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 400,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Theme
                    .of(context)
                    .primaryColor,
                foregroundColor: Theme
                    .of(context)
                    .colorScheme
                    .onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
              },
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
