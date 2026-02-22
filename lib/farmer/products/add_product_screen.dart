import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; // Added for File support on mobile
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../models/product_model.dart'; // Import your model

class AddProductScreen extends StatefulWidget {
  final String farmId;
  final Product? existingProduct; // Added for Editing/Restocking

  const AddProductScreen({super.key, required this.farmId, this.existingProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  
  String _selectedCategory = 'Milk';
  final List<String> _categories = ['Milk', 'Yogurt', 'Cheese', 'Butter', 'Desi Ghee'];
  
  String _selectedUnit = 'Ltr';
  final List<String> _units = ['Ltr', 'Kg', 'Pack', 'Gram'];

  XFile? _productImage;
  String? _existingImageUrl;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final String _apiKey = "7dedc06d9f9ba46be0f57c22bada50b6"; 

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if editing
    _nameController = TextEditingController(text: widget.existingProduct?.name ?? "");
    _priceController = TextEditingController(text: widget.existingProduct?.price.toString() ?? "");
    _stockController = TextEditingController(text: widget.existingProduct?.stock.toString() ?? "");
    
    if (widget.existingProduct != null) {
      _selectedCategory = widget.existingProduct!.category;
      _selectedUnit = widget.existingProduct!.unit;
      _existingImageUrl = widget.existingProduct!.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

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
    // If not editing, an image is mandatory. If editing, we can keep the old one.
    if (!_formKey.currentState!.validate() || (_productImage == null && _existingImageUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide all details and a product photo"))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;
      
      // Only upload if a new image was picked
      if (_productImage != null) {
        imageUrl = await _uploadImage(_productImage!);
      }

      if (imageUrl != null) {
        final Map<String, dynamic> productData = {
          'farmId': widget.farmId,
          'name': _nameController.text.trim(),
          'category': _selectedCategory,
          'unit': _selectedUnit,
          'price': double.parse(_priceController.text.trim()),
          'stock': int.parse(_stockController.text.trim()), // Sync with Inventory Alert
          'imageUrl': imageUrl,
          'isAvailable': int.parse(_stockController.text.trim()) > 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (widget.existingProduct != null) {
          // UPDATE Existing
          await FirebaseFirestore.instance
              .collection('products')
              .doc(widget.existingProduct!.id)
              .update(productData);
        } else {
          // ADD New
          productData['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('products').add(productData);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.existingProduct != null ? "Product Updated!" : "Product Listed!"), 
              backgroundColor: Colors.green
            )
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePreview() {
    if (_productImage != null) {
      return kIsWeb 
        ? Image.network(_productImage!.path, fit: BoxFit.cover) 
        : Image.file(File(_productImage!.path), fit: BoxFit.cover);
    }
    
    if (_existingImageUrl != null) {
      return Image.network(_existingImageUrl!, fit: BoxFit.cover);
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 40, color: AppColors.primary),
        Text("Upload Image")
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existingProduct != null ? "Edit Product" : "Add New Product"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
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
                    child: _buildImagePreview(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Product Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: InputDecoration(
                        labelText: "Unit",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                      decoration: InputDecoration(
                        labelText: "Price", 
                        prefixText: "Rs. ",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Stock Quantity",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitProduct,
                      child: Text(
                        widget.existingProduct != null ? "UPDATE PRODUCT" : "LIST PRODUCT",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}