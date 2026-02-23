import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Essential to prevent web crashes
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart'; 
import '../utils/app_theme.dart';

class BillingSummaryScreen extends StatelessWidget {
  const BillingSummaryScreen({super.key});

  // Helper to fetch user name from Firestore
  Future<String> _getCustomerName(String uid) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['name'] ?? "Customer" : "Customer";
  }

  // Helper to fetch farm name if it's not in the order document
  Future<String> _getFarmName(String farmId) async {
    if (farmId.isEmpty) return "Unknown Farm";
    DocumentSnapshot farmDoc = await FirebaseFirestore.instance.collection('farms').doc(farmId).get();
    return farmDoc.exists ? (farmDoc.data() as Map<String, dynamic>)['farmName'] ?? "Farm" : "Farm";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Billing & Analytics", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user?.uid)
            .where('status', isEqualTo: 'Delivered')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          List<QueryDocumentSnapshot> allDocs = snapshot.data?.docs ?? [];
          List<QueryDocumentSnapshot> currentMonthOrders = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            Timestamp? dateStamp = data['orderDate'] ?? data['nextDeliveryDate'];
            if (dateStamp == null) return false;
            DateTime date = dateStamp.toDate();
            return date.isAfter(firstDayOfMonth) || date.isAtSameMomentAs(firstDayOfMonth);
          }).toList();

          double monthlyTotal = 0;
          for (var doc in currentMonthOrders) {
            monthlyTotal += (doc['totalAmount'] ?? 0).toDouble();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalCard(monthlyTotal),
                const SizedBox(height: 30),
                const Text("Monthly Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (currentMonthOrders.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("No delivered orders this month."),
                  )),
                ...currentMonthOrders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  Timestamp dateStamp = data['orderDate'] ?? data['nextDeliveryDate'] ?? Timestamp.now();
                  List items = data['items'] ?? [];
                  String shortOrderId = doc.id.substring(0, 6).toUpperCase();
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text("${data['farmName'] ?? 'Farm'} - #$shortOrderId"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(dateStamp.toDate())),
                          Text("Items: ${items.map((i) => "${i['name']} (x${i['quantity']})").join(', ')}",
                               style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      trailing: Text("Rs. ${data['totalAmount']}", 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  );
                }),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, 
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: currentMonthOrders.isEmpty ? null : () async {
                      String customerName = await _getCustomerName(user!.uid);
                      await _generateInvoice(context, customerName, currentMonthOrders, monthlyTotal);
                    },
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text("Generate & Download Invoice", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(double total) {
    return Container(
      padding: const EdgeInsets.all(25),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("Amount Due This Month", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 10),
          Text("Rs. ${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _generateInvoice(BuildContext context, String customerName, List<QueryDocumentSnapshot> orders, double total) async {
    final pdf = pw.Document();

    List<List<String>> tableData = [<String>['Date', 'Order ID', 'Farm', 'Items & Qty', 'Amount']];
    
    for (var doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      Timestamp ts = data['orderDate'] ?? data['nextDeliveryDate'] ?? Timestamp.now();
      List items = data['items'] ?? [];
      String itemString = items.map((i) => "${i['name']} (x${i['quantity']})").join('\n');
      
      // Attempt to fetch farm name dynamically if missing
      String farmName = data['farmName'] ?? await _getFarmName(data['farmId'] ?? "");
      String shortOrderId = doc.id.substring(0, 6).toUpperCase();

      tableData.add([
        DateFormat('dd/MM/yy').format(ts.toDate()),
        "#$shortOrderId",
        farmName,
        itemString,
        "Rs. ${data['totalAmount']}"
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("DAIRY NOVA", style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  pw.Text("MONTHLY INVOICE", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.green900),
              pw.SizedBox(height: 20),
              pw.Text("Customer Name: $customerName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text("Billing Period: ${DateFormat('MMMM yyyy').format(DateTime.now())}"),
              pw.SizedBox(height: 20),
              
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
                data: tableData,
              ),
              pw.SizedBox(height: 30),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Divider(color: PdfColors.black),
                    pw.Text("Total Payable: Rs. ${total.toStringAsFixed(0)}", 
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // On Web, this opens the browser's print preview for 'Save as PDF'
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());

    // Local Download Logic for Mobile only
    if (!kIsWeb) {
      try {
        final bytes = await pdf.save();
        Directory? directory;
        
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) directory = await getExternalStorageDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        final String fileName = "Invoice_${DateFormat('MMM_yyyy').format(DateTime.now())}.pdf";
        final file = File("${directory!.path}/$fileName");
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Invoice downloaded to: ${file.path}"), backgroundColor: AppColors.primary),
        );
      } catch (e) {
        debugPrint("Local save failed: $e");
      }
    }
  }
}