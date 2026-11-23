import 'utils/csv_export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum DateFilter { today, week, month, allTime, custom }

class NurseDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const NurseDashboard({super.key, required this.userData});

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- LOGOUT CONFIRMATION MODAL ---
  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade200, width: 2),
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 38,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout Account',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Are you sure you want to logout? Once you logout you need to login again. Are you Ok?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(dialogCtx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: Colors.teal.shade50,
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        FirebaseAuth.instance.signOut();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: Colors.red.shade700,
                        alignment: Alignment.center,
                        child: const Text(
                          'Yes, Logout !',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getUrgencyPriority(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
      default:
        return 1;
    }
  }

  void _openMedicineDialog([DocumentSnapshot? existingDoc]) {
    final isEditing = existingDoc != null;
    final data = isEditing ? existingDoc.data() as Map<String, dynamic> : null;

    final nameCtrl = TextEditingController(text: data?['genericName'] ?? '');
    final stockCtrl = TextEditingController(text: data?['stockCount']?.toString() ?? '50');
    final thresholdCtrl = TextEditingController(text: data?['lowStockThreshold']?.toString() ?? '15');
    String selectedUnit = data?['unit'] ?? 'tablet';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Medicine' : 'Add New Medicine'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Medicine Name & Dosage *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
                    DropdownMenuItem(value: 'capsule', child: Text('Capsule')),
                    DropdownMenuItem(value: 'sachet', child: Text('Sachet')),
                    DropdownMenuItem(value: 'bottle', child: Text('Bottle')),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedUnit = val;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock Count *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Low-Stock Warning Threshold', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                final threshold = int.tryParse(thresholdCtrl.text.trim()) ?? 10;

                if (name.isEmpty) return;

                final payload = {
                  'genericName': name,
                  'unit': selectedUnit,
                  'stockCount': stock,
                  'lowStockThreshold': threshold,
                  'isAvailable': stock > 0,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEditing) {
                  await existingDoc.reference.update(payload);
                } else {
                  await FirebaseFirestore.instance.collection('medicines').add(payload);
                }

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
              },
              child: Text(isEditing ? 'Save Changes' : 'Add to Inventory'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteMedicine(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['genericName'] ?? 'this medicine';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Medicine?'),
        content: Text('Are you sure you want to delete "$name" from the inventory? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            onPressed: () async {
              await doc.reference.delete();
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "$name" from inventory.'), backgroundColor: Colors.blueGrey.shade800),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openConsultationDialog(DocumentSnapshot ticketDoc) {
    final ticket = ticketDoc.data() as Map<String, dynamic>;
    final ticketId = ticketDoc.id;

    final chiefComplaintCtrl = TextEditingController(text: ticket['symptoms'] ?? '');
    final diagnosisCtrl = TextEditingController();
    final actionTakenCtrl = TextEditingController();

    String? selectedMedicineId;
    int quantity = 1;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Consultation: ${ticket['studentName']} (#${ticket['queueNumber']})'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: chiefComplaintCtrl,
                        decoration: const InputDecoration(labelText: 'Chief Complaint', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: diagnosisCtrl,
                        decoration: const InputDecoration(labelText: 'Diagnosis *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: actionTakenCtrl,
                        decoration: const InputDecoration(labelText: 'Action / Advice Given', border: OutlineInputBorder()),
                      ),
                      const Divider(height: 32),
                      const Text('Dispense Medicine (Atomic Decrement)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('medicines').where('stockCount', isGreaterThan: 0).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final meds = snapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            value: selectedMedicineId,
                            hint: const Text('Select Medicine (Optional)'),
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: meds.map((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text('${d['genericName']} (${d['stockCount']} ${d['unit']}s left)'),
                              );
                            }).toList(),
                            onChanged: (val) => setModalState(() => selectedMedicineId = val),
                          );
                        },
                      ),
                      if (selectedMedicineId != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Quantity to Dispense: '),
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: quantity > 1 ? () => setModalState(() => quantity--) : null,
                            ),
                            Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => setModalState(() => quantity++),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (diagnosisCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a diagnosis.')),
                            );
                            return;
                          }

                          setModalState(() => isProcessing = true);
                          final nurseUser = FirebaseAuth.instance.currentUser!;

                          try {
                            if (selectedMedicineId != null) {
                              final medRef = FirebaseFirestore.instance.collection('medicines').doc(selectedMedicineId);
                              final logRef = FirebaseFirestore.instance.collection('dispense_logs').doc();

                              await FirebaseFirestore.instance.runTransaction((transaction) async {
                                final medSnap = await transaction.get(medRef);
                                final stock = medSnap.data()?['stockCount'] as int? ?? 0;
                                final medName = medSnap.data()?['genericName'] ?? '';

                                if (stock < quantity) {
                                  throw Exception('Not enough stock remaining!');
                                }

                                final newStock = stock - quantity;
                                transaction.update(medRef, {
                                  'stockCount': newStock,
                                  'isAvailable': newStock > 0,
                                });

                                transaction.set(logRef, {
                                  'logId': logRef.id,
                                  'ticketId': ticketId,
                                  'patientId': ticket['studentId'],
                                  'patientName': ticket['studentName'],
                                  'nurseId': nurseUser.uid,
                                  'medicineId': selectedMedicineId,
                                  'medicineName': medName,
                                  'quantity': quantity,
                                  'timestamp': FieldValue.serverTimestamp(),
                                });
                              });
                            }

                            await FirebaseFirestore.instance.collection('queue').doc(ticketId).update({
                              'status': 'completed',
                              'consultationDetails': {
                                'nurseId': nurseUser.uid,
                                'nurseName': widget.userData['fullName'] ?? 'Staff Nurse',
                                'chiefComplaint': chiefComplaintCtrl.text.trim(),
                                'diagnosis': diagnosisCtrl.text.trim(),
                                'actionTaken': actionTakenCtrl.text.trim(),
                                'completedAt': FieldValue.serverTimestamp(),
                              },
                            });

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                          } catch (e) {
                            setModalState(() => isProcessing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text('Complete & Dispense'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nurse Station - ${widget.userData['fullName']}'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Live Queue'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory Manager'),
            Tab(icon: Icon(Icons.history), text: 'Dispense Logs'),
            Tab(icon: Icon(Icons.assessment_outlined), text: 'Reports & Export'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ======================== TAB 1: LIVE QUEUE ========================
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('queue')
                .where('status', whereIn: ['pending', 'consulting'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No walk-in patients currently in queue.', style: TextStyle(fontSize: 16)),
                );
              }

              docs.sort((a, b) {
                final uA = _getUrgencyPriority((a.data() as Map<String, dynamic>)['urgencyLevel'] ?? 'low');
                final uB = _getUrgencyPriority((b.data() as Map<String, dynamic>)['urgencyLevel'] ?? 'low');
                if (uA != uB) return uB.compareTo(uA);

                final int numA = (a.data() as Map<String, dynamic>)['queueNumber'] ?? 0;
                final int numB = (b.data() as Map<String, dynamic>)['queueNumber'] ?? 0;
                return numA.compareTo(numB);
              });

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final ticket = doc.data() as Map<String, dynamic>;
                  final urgency = (ticket['urgencyLevel'] ?? 'low').toString().toLowerCase();
                  final status = ticket['status'] ?? 'pending';
                  final studentName = ticket['studentName'] ?? 'Student';
                  final studentId = ticket['studentIdNumber'] ?? 'N/A';
                  final section = ticket['section'] ?? 'N/A';
                  final symptoms = ticket['symptoms'] ?? 'No symptoms listed';
                  final tempVal = double.tryParse("${ticket['vitals']?['temperature'] ?? ''}");
                  final bool isHighFever = tempVal != null && tempVal >= 38.0;

                  Color cardBgColor;
                  Color alertColor;
                  IconData urgencyIcon;
                  String urgencyText;

                  switch (urgency) {
                    case 'emergency':
                      cardBgColor = Colors.red.shade50;
                      alertColor = Colors.red.shade800;
                      urgencyIcon = Icons.emergency;
                      urgencyText = '🚨 EMERGENCY PRIORITY';
                      break;
                    case 'high':
                      cardBgColor = Colors.orange.shade50;
                      alertColor = Colors.deepOrange.shade800;
                      urgencyIcon = Icons.warning_rounded;
                      urgencyText = '⚠️ HIGH URGENCY';
                      break;
                    case 'medium':
                      cardBgColor = Colors.amber.shade50;
                      alertColor = Colors.amber.shade900;
                      urgencyIcon = Icons.error_outline;
                      urgencyText = 'MODERATE URGENCY';
                      break;
                    case 'low':
                    default:
                      cardBgColor = Colors.white;
                      alertColor = Colors.teal.shade700;
                      urgencyIcon = Icons.check_circle_outline;
                      urgencyText = 'LOW / STABLE';
                  }

                  return Card(
                    elevation: urgency == 'emergency' || urgency == 'high' ? 3 : 1,
                    color: cardBgColor,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: alertColor,
                        width: urgency == 'emergency' ? 2.5 : (urgency == 'high' ? 2.0 : 1.2),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: alertColor.withOpacity(0.15),
                            child: Text(
                              '#${ticket['queueNumber']}',
                              style: TextStyle(color: alertColor, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: alertColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(urgencyIcon, color: Colors.white, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            urgencyText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isHighFever)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade700,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                                            const SizedBox(width: 3),
                                            Text(
                                              'HIGH FEVER ($tempVal °C)',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  studentName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: $studentId | Section: $section',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Symptoms: $symptoms',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Recorded Temp: ${tempVal != null ? "$tempVal °C" : "Not recorded"}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (status == 'pending')
                            ElevatedButton.icon(
                              onPressed: () => doc.reference.update({'status': 'consulting'}),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: alertColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.notifications_active, size: 18),
                              label: const Text('Call In', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          if (status == 'consulting')
                            ElevatedButton.icon(
                              onPressed: () => _openConsultationDialog(doc),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.medical_services, size: 18),
                              label: const Text('Consult & Dispense', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // ======================== TAB 2: INVENTORY MANAGER ========================
          Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
              onPressed: () => _openMedicineDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Medicine'),
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('medicines').orderBy('genericName').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final meds = snapshot.data?.docs ?? [];
                if (meds.isEmpty) {
                  return const Center(child: Text('No medicines found in inventory.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: meds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = meds[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final stock = data['stockCount'] as int? ?? 0;
                    final threshold = data['lowStockThreshold'] as int? ?? 15;
                    final isLowStock = stock <= threshold;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock ? Colors.red.shade100 : Colors.teal.shade100,
                          child: Icon(Icons.medication, color: isLowStock ? Colors.red.shade900 : Colors.teal.shade900),
                        ),
                        title: Text(data['genericName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Unit: ${data['unit']} | Low Stock Alert at: $threshold ${data['unit']}s'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLowStock)
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                                child: Text('LOW STOCK ($stock left)', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            else
                              Text('$stock ${data['unit']}s in stock', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                              tooltip: 'Edit Medicine',
                              onPressed: () => _openMedicineDialog(doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete Medicine',
                              onPressed: () => _confirmDeleteMedicine(doc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ======================== TAB 3: DISPENSE LOGS ========================
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('dispense_logs').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final logs = snapshot.data?.docs ?? [];
              if (logs.isEmpty) {
                return const Center(child: Text('No medicines dispensed yet.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = logs[index].data() as Map<String, dynamic>;
                  final qty = log['quantity'] ?? 1;
                  final medName = log['medicineName'] ?? 'Medicine';
                  final patient = log['patientName'] ?? 'Student';

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                      title: Text('$qty x $medName dispensed to $patient'),
                      subtitle: Text('Ticket ID: ${log['ticketId']}'),
                    ),
                  );
                },
              );
            },
          ),

          // ======================== TAB 4: ADVANCED REPORTS & HISTORY ========================
          const ReportsAndHistoryTab(),
        ],
      ),
    );
  }
}

/// Independent, focus-stable Reports and History Tab
class ReportsAndHistoryTab extends StatefulWidget {
  const ReportsAndHistoryTab({super.key});

  @override
  State<ReportsAndHistoryTab> createState() => _ReportsAndHistoryTabState();
}

class _ReportsAndHistoryTabState extends State<ReportsAndHistoryTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<QuerySnapshot> _completedStream;

  DateFilter _selectedFilter = DateFilter.allTime;
  DateTimeRange? _customDateRange;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _completedStream = FirebaseFirestore.instance
        .collection('queue')
        .where('status', isEqualTo: 'completed')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  DateTime? _getTicketDate(Map<String, dynamic> data) {
    if (data['consultationDetails'] != null && data['consultationDetails']['completedAt'] != null) {
      final val = data['consultationDetails']['completedAt'];
      if (val is Timestamp) return val.toDate();
    }
    if (data['createdAt'] != null) {
      final val = data['createdAt'];
      if (val is Timestamp) return val.toDate();
    }
    if (data['queueDate'] != null) {
      try {
        return DateTime.parse(data['queueDate']);
      } catch (_) {}
    }
    return null;
  }

  bool _matchesFilter(Map<String, dynamic> data, String query) {
    if (query.isNotEmpty) {
      final name = (data['studentName'] ?? '').toString().toLowerCase();
      final idNum = (data['studentIdNumber'] ?? '').toString().toLowerCase();
      final consult = data['consultationDetails'] as Map<String, dynamic>?;
      final diagnosis = (consult?['diagnosis'] ?? '').toString().toLowerCase();

      if (!name.contains(query) && !idNum.contains(query) && !diagnosis.contains(query)) {
        return false;
      }
    }

    final ticketDate = _getTicketDate(data);
    if (ticketDate == null) return true;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedFilter) {
      case DateFilter.today:
        return ticketDate.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            ticketDate.isBefore(todayEnd.add(const Duration(seconds: 1)));
      case DateFilter.week:
        final weekStart = todayStart.subtract(const Duration(days: 7));
        return ticketDate.isAfter(weekStart) && ticketDate.isBefore(todayEnd.add(const Duration(seconds: 1)));
      case DateFilter.month:
        final monthStart = todayStart.subtract(const Duration(days: 30));
        return ticketDate.isAfter(monthStart) && ticketDate.isBefore(todayEnd.add(const Duration(seconds: 1)));
      case DateFilter.custom:
        if (_customDateRange == null) return true;
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        return ticketDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            ticketDate.isBefore(end.add(const Duration(seconds: 1)));
      case DateFilter.allTime:
      default:
        return true;
    }
  }

 void _downloadCsv(String csvContent, String fileName) {
  downloadCsvWeb(csvContent, fileName);
}

  Future<void> _exportFilteredCsv(List<DocumentSnapshot> filteredTickets) async {
    final dispenseLogsSnap = await FirebaseFirestore.instance.collection('dispense_logs').get();

    final Map<String, List<String>> ticketMeds = {};
    for (final doc in dispenseLogsSnap.docs) {
      final log = doc.data();
      final tid = log['ticketId'] ?? '';
      final medSummary = "${log['medicineName']} (x${log['quantity']})";
      ticketMeds.putIfAbsent(tid, () => []).add(medSummary);
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln('Date,Ticket ID,Student Name,Student ID,Section,Symptoms,Diagnosis,Action Taken,Medicines Dispensed');

    for (final doc in filteredTickets) {
      final d = doc.data() as Map<String, dynamic>;
      final c = d['consultationDetails'] as Map<String, dynamic>?;
      final tid = doc.id;
      final medsGiven = ticketMeds[tid]?.join('; ') ?? 'None';
      final date = d['queueDate'] ?? 'N/A';
      final studentId = d['studentIdNumber'] ?? 'N/A';
      final section = d['section'] ?? 'N/A';

      csv.writeln(
        '"$date","${doc.id}","${d['studentName']}","$studentId","$section","${d['symptoms']}","${c?['diagnosis'] ?? 'N/A'}","${c?['actionTaken'] ?? 'N/A'}","$medsGiven"',
      );
    }

    final filterLabel = _selectedFilter.name.toUpperCase();
    _downloadCsv(csv.toString(), 'campus_clinic_report_${filterLabel}_${DateTime.now().millisecondsSinceEpoch}.csv');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${filteredTickets.length} records to CSV!'), backgroundColor: Colors.teal),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade800,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = DateFilter.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<QuerySnapshot>(
      stream: _completedStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCompleted = snapshot.data?.docs ?? [];

        allCompleted.sort((a, b) {
          final dateA = _getTicketDate(a.data() as Map<String, dynamic>) ?? DateTime(2000);
          final dateB = _getTicketDate(b.data() as Map<String, dynamic>) ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        return AnimatedBuilder(
          animation: _searchController,
          builder: (context, _) {
            final query = _searchController.text.trim().toLowerCase();

            final filtered = allCompleted.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _matchesFilter(data, query);
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.filter_alt_outlined, color: Colors.teal.shade800),
                                  const SizedBox(width: 8),
                                  const Text('Consultation History & Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const ValueKey('consultation_search_field_locked'),
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                enableInteractiveSelection: true,
                                decoration: InputDecoration(
                                  hintText: 'Search by student name, student ID, or diagnosis...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _searchFocusNode.requestFocus();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Today'),
                                    selected: _selectedFilter == DateFilter.today,
                                    selectedColor: Colors.teal.shade100,
                                    onSelected: (val) => setState(() => _selectedFilter = DateFilter.today),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Past 7 Days (Week)'),
                                    selected: _selectedFilter == DateFilter.week,
                                    selectedColor: Colors.teal.shade100,
                                    onSelected: (val) => setState(() => _selectedFilter = DateFilter.week),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Past 30 Days (Month)'),
                                    selected: _selectedFilter == DateFilter.month,
                                    selectedColor: Colors.teal.shade100,
                                    onSelected: (val) => setState(() => _selectedFilter = DateFilter.month),
                                  ),
                                  ChoiceChip(
                                    label: const Text('All Time'),
                                    selected: _selectedFilter == DateFilter.allTime,
                                    selectedColor: Colors.teal.shade100,
                                    onSelected: (val) => setState(() => _selectedFilter = DateFilter.allTime),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.calendar_month, size: 18),
                                    label: Text(
                                      _selectedFilter == DateFilter.custom && _customDateRange != null
                                          ? '${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}'
                                          : 'Custom Date Range',
                                    ),
                                    backgroundColor: _selectedFilter == DateFilter.custom ? Colors.teal.shade100 : null,
                                    onPressed: _pickCustomDateRange,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        color: Colors.teal.shade50,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Showing ${filtered.length} Consultation${filtered.length == 1 ? '' : 's'}',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Active Filter: ${_selectedFilter == DateFilter.custom ? "Custom Range" : _selectedFilter.name.toUpperCase()}',
                                      style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                ),
                                icon: const Icon(Icons.download),
                                label: const Text('EXPORT FILTERED CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: filtered.isEmpty ? null : () => _exportFilteredCsv(filtered),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Completed Consultations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${filtered.length} records', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No patient consultations found for the selected timeframe.',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = filtered[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final consult = data['consultationDetails'] as Map<String, dynamic>?;
                            final studentName = data['studentName'] ?? 'Student';
                            final studentId = data['studentIdNumber'] ?? 'N/A';
                            final section = data['section'] ?? 'N/A';
                            final diagnosis = consult?['diagnosis'] ?? 'No Diagnosis';
                            final actionTaken = consult?['actionTaken'] ?? 'No Action Taken';
                            final dateStr = data['queueDate'] ?? 'N/A';

                            return Card(
                              child: ExpansionTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  child: Icon(Icons.check, color: Colors.white),
                                ),
                                title: Text('$studentName — $diagnosis', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('ID: $studentId | Section: $section | Date: $dateStr'),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16.0),
                                    color: Colors.grey.shade50,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Symptoms Reported: ${data['symptoms']}'),
                                        const SizedBox(height: 4),
                                        Text('Vitals (Temp): ${data['vitals']?['temperature']} °C'),
                                        const SizedBox(height: 4),
                                        Text('Clinical Action / Advice: $actionTaken'),
                                        const SizedBox(height: 4),
                                        Text('Attending Nurse: ${consult?['nurseName'] ?? 'Nurse'}'),
                                        const SizedBox(height: 4),
                                        Text('Ticket ID: ${doc.id}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}