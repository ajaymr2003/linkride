import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // Required for picking images
import '../../../../services/cloudinary_service.dart'; // Required for uploading

class EditPersonalDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditPersonalDetailsPage({super.key, required this.userData});

  @override
  State<EditPersonalDetailsPage> createState() => _EditPersonalDetailsPageState();
}

class _EditPersonalDetailsPageState extends State<EditPersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  String? _dob;
  
  // Image editing variables
  File? _newProfileImage; 
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.userData['name']);
    _lastNameController = TextEditingController(text: widget.userData['last_name'] ?? "");
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? "");
    _dob = widget.userData['dob'];
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Optimize size
      );
      if (picked != null) {
        setState(() {
          _newProfileImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dob = DateFormat('dd-MM-yyyy').format(picked));
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      String? profilePicUrl = widget.userData['profile_pic'];

      // 1. If a new image was selected, upload it to Cloudinary first
      if (_newProfileImage != null) {
        String? uploadedUrl = await CloudinaryService.uploadImage(_newProfileImage!);
        if (uploadedUrl != null) {
          profilePicUrl = uploadedUrl;
        } else {
          throw Exception("Image upload failed");
        }
      }

      // 2. Update Firestore with text data and (potentially new) image URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dob,
        'profile_pic': profilePicUrl,
      });

      if (mounted) {
        Navigator.pop(context); // Go back to About You tab
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Update failed. Please check connection.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current Cloudinary URL from existing data
    final String? currentUrl = widget.userData['profile_pic'];
    const Color primaryGreen = Color(0xFF11A860);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Personal Details"), 
        elevation: 0, 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PROFILE PHOTO SECTION ---
              Center(
                child: Stack(
                  children: [
                    // The Avatar
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: _newProfileImage != null
                              ? FileImage(_newProfileImage!) as ImageProvider
                              : (currentUrl != null && currentUrl.isNotEmpty
                                  ? NetworkImage(currentUrl)
                                  : const AssetImage('assets/placeholder_user.png') // Fallback if no net image
                                      as ImageProvider), 
                        ),
                      ),
                      // Fallback icon if no image exists at all
                      child: (_newProfileImage == null && (currentUrl == null || currentUrl.isEmpty))
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    // The Camera Icon Button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: primaryGreen,
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "Tap icon to change photo", 
                  style: TextStyle(color: Colors.grey, fontSize: 12)
                )
              ),
              const SizedBox(height: 30),

              // --- TEXT FIELDS ---
              _buildField("First Name", _firstNameController),
              const SizedBox(height: 20),
              _buildField("Last Name", _lastNameController),
              const SizedBox(height: 20),
              
              const Text("Date of Birth", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_dob ?? "Select Date"),
                trailing: const Icon(Icons.calendar_month),
                onTap: _selectDate,
              ),
              const Divider(),
              const SizedBox(height: 20),
              
              _buildField("Mobile Number", _phoneController, isPhone: true),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: controller, 
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          validator: (value) => value!.isEmpty ? "Required" : null,
        ),
      ],
    );
  }
}