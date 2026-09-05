import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_dialog.dart';

class AdminProfileCard extends StatefulWidget {
  const AdminProfileCard({super.key});

  @override
  State<AdminProfileCard> createState() => _AdminProfileCardState();
}

class _AdminProfileCardState extends State<AdminProfileCard> {
  Map<String, dynamic>? adminData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection("admins")
        .doc(user.uid)
        .get();

    if (mounted) {
      setState(() {
        adminData = doc.data();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final name = adminData?["name"] ?? "Unknown";
    final role = adminData?["role"] ?? "Administrator";
    final email = adminData?["email"] ?? "";
    final phone = adminData?["phone"] ?? "";

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 700) {
              return _mobileLayout(
                name,
                role,
                email,
                phone,
              );
            }

            return _desktopLayout(
              name,
              role,
              email,
              phone,
            );
          },
        ),
      ),
    );
  }

  Widget _desktopLayout(
      String name,
      String role,
      String email,
      String phone,
      ) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 45,
          backgroundColor: Colors.blue,
          child: Icon(
            Icons.person,
            size: 50,
            color: Colors.white,
          ),
        ),

        const SizedBox(width: 25),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                role,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Text(email),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Text(phone),
                ],
              ),
            ],
          ),
        ),

        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const EditProfileDialog(),
            ).then((_) {
              _loadAdmin();
            });
          },          icon: const Icon(Icons.edit),
          label: const Text("Edit Profile"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout(
      String name,
      String role,
      String email,
      String phone,
      ) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 45,
          backgroundColor: Colors.blue,
          child: Icon(
            Icons.person,
            size: 50,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 15),

        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          role,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined),
            const SizedBox(width: 8),
            Text(email),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_outlined),
            const SizedBox(width: 8),
            Text(phone),
          ],
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.edit),
          label: const Text("Edit Profile"),
        ),
      ],
    );
  }
}