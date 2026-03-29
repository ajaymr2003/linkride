import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:firebase_auth/firebase_auth.dart'; // Added
import '../../../services/cloudinary_service.dart'; // Added

class StepLicenseDetails extends StatefulWidget {
  const StepLicenseDetails({super.key}); // Removed parameters as we handle logic internally

  @override
  State<StepLicenseDetails> createState() => _StepLicenseDetailsState();
}

class _StepLicenseDetailsState extends State<StepLicenseDetails> {
  final TextEditingController _dlController = TextEditingController();
  
  // Storage for raw and final files
  File? _frontFinal, _backFinal;
  File? _tempRawFile; 
  
  // Logic States
  bool _isCropping = false;
  bool _isFrontTarget = true; 
  bool _isSaving = false; // Internal loading state
  
  final _cropController = CropController(aspectRatio: 3 / 2); 
  final Color primaryGreen = const Color(0xFF11A860);
  final RegExp dlRegex = RegExp(r'^[A-Z]{2}[0-9]{2}[0-9]{4}[0-9]{7}$');
  final String uid = FirebaseAuth.instance.currentUser!.uid; // Get UID

  // 1. Pick Image
  Future<void> _pickImage(bool isFront) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked != null) {
      setState(() {
        _tempRawFile = File(picked.path);
        _isFrontTarget = isFront;
        _isCropping = true;
      });
    }
  }

  // 2. Process Crop
  Future<void> _processCrop() async {
    ui.Image bitmap = await _cropController.croppedBitmap();
    final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final fileName = _isFrontTarget ? 'license_front' : 'license_back';
    final file = await File('${tempDir.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.png').create();
    await file.writeAsBytes(bytes);

    setState(() {
      if (_isFrontTarget) {
        _frontFinal = file;
      } else {
        _backFinal = file;
      }
      _isCropping = false;
      _tempRawFile = null;
    });
  }

  // --- NEW: UPLOAD TO CLOUDINARY AND SAVE ALL TO FIRESTORE ---
  Future<void> _saveAndFinish(String dlClean) async {
    setState(() => _isSaving = true);

    try {
      // 1. Upload both images in parallel
      final results = await Future.wait([
        CloudinaryService.uploadImage(_frontFinal!),
        CloudinaryService.uploadImage(_backFinal!),
      ]);

      String? frontUrl = results[0];
      String? backUrl = results[1];

      if (frontUrl != null && backUrl != null) {
        // 2. Update Firestore document
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'license_number': dlClean,
          'license_front': frontUrl,
          'license_back': backUrl,
        });

        // 3. Return to Hub
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception("One or more images failed to upload");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dlClean = _dlController.text.replaceAll(" ", "").toUpperCase();
    bool isValid = dlRegex.hasMatch(dlClean) && _frontFinal != null && _backFinal != null;

    return WillPopScope(
      onWillPop: () async {
        if (_isCropping) {
          setState(() => _isCropping = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _isCropping ? null : AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
        body: _isSaving 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF11A860)))
          : (_isCropping ? _buildCropperView() : _buildMainForm(dlClean, isValid)),
      ),
    );
  }

  Widget _buildCropperView() {
    return Column(
      children: [
        const SizedBox(height: 50),
        Text("Crop ${_isFrontTarget ? 'Front' : 'Back'} Side", 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            child: CropImage(
              controller: _cropController,
              image: Image.file(_tempRawFile!),
              gridColor: primaryGreen,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _isCropping = false), child: const Text("CANCEL"))),
              const SizedBox(width: 15),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                onPressed: _processCrop, 
                child: const Text("DONE", style: TextStyle(color: Colors.white)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainForm(String dlClean, bool isValid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("License Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          TextField(
            controller: _dlController,
            onChanged: (v) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(15),
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            decoration: InputDecoration(
              hintText: "15-Digit DL Number",
              counterText: "${dlClean.length}/15",
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 30),
          const Text("Upload Photos", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 15),

          _imgBox("Front Side", _frontFinal, () => _pickImage(true)),
          const SizedBox(height: 15),
          _imgBox("Back Side", _backFinal, () => _pickImage(false)),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: isValid ? () => _saveAndFinish(dlClean) : null,
              child: const Text("SAVE LICENSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgBox(String label, File? file, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 170, width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: file == null ? Colors.grey.shade300 : primaryGreen, width: 2), 
        borderRadius: BorderRadius.circular(12), 
        color: Colors.grey[50]
      ),
      child: file == null 
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400),
                Text(label, style: TextStyle(color: Colors.grey.shade500)),
              ])) 
          : Stack(
              children: [
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(file, fit: BoxFit.cover))),
                Positioned(right: 8, top: 8, child: CircleAvatar(backgroundColor: primaryGreen, radius: 15, child: const Icon(Icons.edit, size: 15, color: Colors.white))),
              ],
            ),
    ),
  );
}