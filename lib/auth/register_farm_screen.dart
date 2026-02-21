import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/farm_model.dart';
import './farm_status_screen.dart';

class RegisterFarmScreen extends StatefulWidget {
  final Farm? existingFarm; // Add this to handle updates
  const RegisterFarmScreen({super.key, this.existingFarm});

  @override
  State<RegisterFarmScreen> createState() => _RegisterFarmScreenState();
}

class _RegisterFarmScreenState extends State<RegisterFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ownerController;
  late TextEditingController _locationController;

  XFile? _newCnicFile;
  // Initialize with nulls to track which of the 5 photos are being replaced
  List<XFile?> _newFarmFiles = List.filled(5, null); 
  
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final String _apiKey = "7dedc06d9f9ba46be0f57c22bada50b6"; 

  @override
  void initState() {
    super.initState();
    // Pre-fill existing data if we are in "Edit Mode"
    _nameController = TextEditingController(text: widget.existingFarm?.name ?? "");
    _ownerController = TextEditingController(text: widget.existingFarm?.owner ?? "");
    _locationController = TextEditingController(text: widget.existingFarm?.location ?? "");
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey'));
      Uint8List data = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('image', data, filename: imageFile.name));
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData)['data']['url']; 
    } catch (e) { return null; }
  }

  Future<void> _pickImage(int index, bool isCnic) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        if (isCnic) _newCnicFile = picked;
        else _newFarmFiles[index] = picked;
      });
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if we have a CNIC (either a new one picked or an old one existing)
    bool hasCnic = _newCnicFile != null || (widget.existingFarm?.cnicUrl.isNotEmpty ?? false);
    if (!hasCnic) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CNIC photo is required")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Process CNIC: Use new upload if picked, otherwise keep existing URL
      String finalCnicUrl = widget.existingFarm?.cnicUrl ?? "";
      if (_newCnicFile != null) {
        finalCnicUrl = await _uploadImage(_newCnicFile!) ?? finalCnicUrl;
      }

      // 2. Process 5 Photos: Re-upload only the ones that were changed
      List<String> finalFarmUrls = widget.existingFarm != null 
          ? List.from(widget.existingFarm!.farmPhotos) 
          : List.filled(5, "");

      for (int i = 0; i < 5; i++) {
        if (_newFarmFiles[i] != null) {
          String? url = await _uploadImage(_newFarmFiles[i]!);
          if (url != null) finalFarmUrls[i] = url;
        }
      }

      // 3. Prepare the update
      Map<String, dynamic> data = {
        'ownerId': FirebaseAuth.instance.currentUser!.uid,
        'ownerName': _ownerController.text.trim(),
        'farmName': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'cnicUrl': finalCnicUrl,
        'farmPhotos': finalFarmUrls,
        'status': 'pending', // Re-submitting always resets status to pending
        'adminFeedback': "", // Clear old feedback
        'flaggedImages': [], // Clear old flags
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existingFarm != null) {
        await FirebaseFirestore.instance.collection('farms').doc(widget.existingFarm!.id).update(data);
      } else {
        await FirebaseFirestore.instance.collection('farms').add(data);
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => FarmStatusScreen(farmName: _nameController.text)),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Smart preview that handles New Files, Old URLs, and Flagged status
  Widget _imageBox(int index, bool isCnic) {
    bool isFlagged = !isCnic && (widget.existingFarm?.flaggedImages.contains(index) ?? false);
    String? existingUrl = isCnic ? widget.existingFarm?.cnicUrl : widget.existingFarm?.farmPhotos[index];
    XFile? newFile = isCnic ? _newCnicFile : _newFarmFiles[index];

    return InkWell(
      onTap: () => _pickImage(index, isCnic),
      child: Container(
        decoration: BoxDecoration(
          // Red border if the admin flagged this specific image
          border: Border.all(color: isFlagged ? Colors.red : Colors.grey.shade400, width: isFlagged ? 2.5 : 1),
          borderRadius: BorderRadius.circular(12),
          color: isFlagged ? Colors.red.withOpacity(0.05) : Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: newFile != null 
            ? Image.network(newFile.path, fit: BoxFit.cover) 
            : (existingUrl != null && existingUrl.isNotEmpty)
              ? Image.network(existingUrl, fit: BoxFit.cover)
              : const Center(child: Icon(Icons.add_a_photo, color: Colors.grey)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingFarm != null ? "Update Registration" : "Farm Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _ownerController, decoration: const InputDecoration(labelText: "Owner Name"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 12),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Farm Name"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 12),
              TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: "Location"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 24),
              
              const Text("CNIC Document", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(height: 150, width: double.infinity, child: _imageBox(0, true)),
              
              const SizedBox(height: 24),
              const Text("Farm Photos (Red Borders Need Correction)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: 5,
                itemBuilder: (ctx, i) => _imageBox(i, false),
              ),
              const SizedBox(height: 40),
              _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _submitData, child: Text(widget.existingFarm != null ? "RE-SUBMIT" : "SUBMIT FOR REVIEW")),
            ],
          ),
        ),
      ),
    );
  }
}