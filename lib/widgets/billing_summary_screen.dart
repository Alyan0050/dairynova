import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/app_theme.dart';

class BillingSummaryScreen extends StatelessWidget {
  const BillingSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Calculate the start of the current month
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
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          double monthlyTotal = 0;
          List<QueryDocumentSnapshot> orders = snapshot.data?.docs ?? [];
          
          for (var doc in orders) {
            monthlyTotal += (doc['totalAmount'] ?? 0).toDouble();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalCard(monthlyTotal),
                const SizedBox(height: 30),
                const Text("Monthly Breakdown", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (orders.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("No delivered orders this month."),
                  )),
                ...orders.map((doc) => ListTile(
                  title: Text("Order #${doc.id.substring(0, 5).toUpperCase()}"),
                  subtitle: Text("${(doc['orderDate'] as Timestamp).toDate().toString().substring(0, 10)}"),
                  trailing: Text("Rs. ${doc['totalAmount']}", 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, 
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: orders.isEmpty ? null : () => _generateInvoice(context, orders, monthlyTotal),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text("Generate PDF Invoice", style: TextStyle(color: Colors.white)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("Amount Due This Month", 
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 10),
          Text("Rs. ${total.toStringAsFixed(0)}", 
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // FR-13: PDF Generation Logic Fixed
  Future<void> _generateInvoice(BuildContext context, List<QueryDocumentSnapshot> orders, double total) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("DAIRY NOVA - MONTHLY INVOICE", 
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text("Billing Month: ${DateTime.now().month}/${DateTime.now().year}"),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Order ID', 'Date', 'Amount'],
                  ...orders.map((doc) => [
                    doc.id.substring(0, 5).toUpperCase(),
                    (doc['orderDate'] as Timestamp).toDate().toString().substring(0, 10),
                    "Rs. ${doc['totalAmount']}"
                  ])
                ],
              ),
              pw.SizedBox(height: 20),
              // FIXED: Using pw.Align instead of pw.Alignment for the widget
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Total Due: Rs. ${total.toStringAsFixed(0)}", 
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}