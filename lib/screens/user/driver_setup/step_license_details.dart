import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';

class StepLicenseDetails extends StatefulWidget {
  final bool isSubmitting;
  final Function(String, File, File) onFinalSubmit;
  const StepLicenseDetails({super.key, required this.isSubmitting, required this.onFinalSubmit});

  @override
  State<StepLicenseDetails> createState() => _StepLicenseDetailsState();
}

class _StepLicenseDetailsState extends State<StepLicenseDetails> {
  final TextEditingController _dlController = TextEditingController();
  
  // Storage for raw and final files
  File? _frontFinal, _backFinal;
  File? _tempRawFile; 
  
  // Cropping Logic
  bool _isCropping = false;
  bool _isFrontTarget = true; // Tracks if we are cropping front or back
  final _cropController = CropController(aspectRatio: 3 / 2); // ID Card Shape

  final Color primaryGreen = const Color(0xFF11A860);
  final RegExp dlRegex = RegExp(r'^[A-Z]{2}[0-9]{2}[0-9]{4}[0-9]{7}$');

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

  // 2. Process Crop (Same logic as Profile)
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
        body: _isCropping ? _buildCropperView() : _buildMainForm(dlClean, isValid),
      ),
    );
  }

  // --- VIEW 1: THE CROPPER ---
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

  // --- VIEW 2: THE FORM ---
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
              onPressed: (isValid && !widget.isSubmitting) 
                  ? () => widget.onFinalSubmit(dlClean, _frontFinal!, _backFinal!) 
                  : null,
              child: widget.isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("SUBMIT APPLICATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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