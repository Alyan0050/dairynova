import 'dart:convert';
import 'dart:typed_data';
// The 'show' keyword restricts the import to just kIsWeb
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final String farmId;
  const AddProductScreen({super.key, required this.farmId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  
  String _selectedCategory = 'Milk';
  final List<String> _categories = ['Milk', 'Yogurt', 'Cheese', 'Butter', 'Desi Ghee'];
  
  String _selectedUnit = 'Ltr';
  final List<String> _units = ['Ltr', 'Kg', 'Pack', 'Gram'];

  XFile? _productImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final String _apiKey = "7dedc06d9f9ba46be0f57c22bada50b6"; 

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey'),
      );
      Uint8List data = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('image', data, filename: imageFile.name));
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData)['data']['url'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _productImage = picked);
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate() || _productImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide all details and a product photo"))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = await _uploadImage(_productImage!);

      if (imageUrl != null) {
        await FirebaseFirestore.instance.collection('products').add({
          'farmId': widget.farmId,
          'name': _nameController.text.trim(),
          'category': _selectedCategory,
          'unit': _selectedUnit,
          'price': double.parse(_priceController.text.trim()),
          'stock': int.parse(_stockController.text.trim()),
          'imageUrl': imageUrl,
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product listed successfully!"), backgroundColor: Colors.green)
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UPDATED PREVIEW LOGIC TO REMOVE THE YELLOW LINE ---
  Widget _buildImagePreview() {
    if (_productImage == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 40, color: AppColors.primary),
          Text("Upload Image")
        ],
      );
    }

    // Using kIsWeb here tells the compiler the import is used
    if (kIsWeb) {
      return Image.network(_productImage!.path, fit: BoxFit.cover);
    } else {
      return Image.network(_productImage!.path, fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Product")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Product Photo", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImagePreview(), // Calling our new method
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Product Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: "Category"),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: "Unit"),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Price", prefixText: "Rs. "),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Stock Quantity"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitProduct,
                      child: const Text("LIST PRODUCT"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}