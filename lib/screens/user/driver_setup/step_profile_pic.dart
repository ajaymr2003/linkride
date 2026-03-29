import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:firebase_auth/firebase_auth.dart'; // Added
import '../../../services/cloudinary_service.dart'; // Added

class StepProfilePic extends StatefulWidget {
  const StepProfilePic({super.key}); // Removed onNext callback as we pop back to Hub

  @override
  State<StepProfilePic> createState() => _StepProfilePicState();
}

class _StepProfilePicState extends State<StepProfilePic> {
  // Camera & Logic
  CameraController? _cameraController;
  final ImagePicker _picker = ImagePicker();
  bool _isCameraReady = false;
  bool _hasPermission = false;
  bool _isUploading = false; // Added: For loading state during DB update

  // Files
  File? _rawFile;
  File? _finalFile;
  bool _isCropping = false;

  final _cropController = CropController(aspectRatio: 1.0);
  final Color primaryGreen = const Color(0xFF11A860);
  final String uid = FirebaseAuth.instance.currentUser!.uid; // Added

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _hasPermission = true);
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front, 
      orElse: () => cameras.first
    );
    
    _cameraController = CameraController(front, ResolutionPreset.medium, enableAudio: false);

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraReady) return;
    try {
      final xFile = await _cameraController!.takePicture();
      setState(() {
        _rawFile = File(xFile.path);
        _isCropping = true;
      });
    } catch (e) {
      debugPrint("Capture failed: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      setState(() {
        _rawFile = File(xFile.path);
        _isCropping = true;
        _finalFile = null;
      });
    }
  }

  Future<void> _processCrop() async {
    ui.Image bitmap = await _cropController.croppedBitmap();
    final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    
    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.png').create();
    await file.writeAsBytes(bytes);

    setState(() {
      _finalFile = file;
      _isCropping = false;
    });
  }

  // --- NEW: UPLOAD TO CLOUDINARY AND SAVE TO FIRESTORE ---
  Future<void> _uploadAndSave() async {
    if (_finalFile == null) return;
    
    setState(() => _isUploading = true);
    try {
      // 1. Upload to Cloudinary
      String? url = await CloudinaryService.uploadImage(_finalFile!);

      if (url != null) {
        // 2. Update Firestore immediately
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profile_pic': url,
        });

        // 3. Go back to Hub
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving photo: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isUploading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF11A860))) 
          : Column(
        children: [
          const Text("Profile Photo", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text("Identity Verification", style: TextStyle(color: Colors.grey)),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), 
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20), 
                child: _buildViewStack()
              ),
            ),
          ),
          
          _buildBottomUI(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildViewStack() {
    if (_isCropping && _rawFile != null) {
      return CropImage(
        controller: _cropController, 
        image: Image.file(_rawFile!), 
        gridColor: primaryGreen
      );
    }

    if (_finalFile != null) {
      return Center(
        child: CircleAvatar(
          radius: 110, 
          backgroundImage: FileImage(_finalFile!)
        )
      );
    }

    if (_isCameraReady && _hasPermission) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                border: Border.all(color: Colors.white54, width: 2)
              ),
            ),
          ),
        ],
      );
    }

    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildBottomUI() {
    if (_isCropping) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => setState(() => _isCropping = false), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.red))
          ),
          const SizedBox(width: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: _processCrop, 
            child: const Text("DONE", style: TextStyle(color: Colors.white))
          ),
        ],
      );
    }

    if (_finalFile != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: _uploadAndSave, // Changed: Now uploads and saves to DB
                child: const Text("CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(onPressed: () => setState(() => _finalFile = null), child: const Text("Retake Photo")),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library, size: 35, color: Colors.grey),
          ),
          GestureDetector(
            onTap: _capturePhoto,
            child: Container(
              height: 70, width: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey, width: 4),
              ),
              child: Center(
                child: Container(
                  height: 55, width: 55,
                  decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}