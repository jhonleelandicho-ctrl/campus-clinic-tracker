import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const StudentDashboard({super.key, required this.userData});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _symptomsController = TextEditingController();
  final _tempController = TextEditingController();
  String _selectedUrgency = 'low';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _symptomsController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  // --- LOGOUT CONFIRMATION MODAL ---
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 28),
              // Red Circular Power Icon Badge
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
              // Split Bottom Buttons
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

  // --- EDIT PROFILE DIALOG ---
  void _openEditProfileDialog(Map<String, dynamic> currentProfile) {
    final nameCtrl = TextEditingController(text: currentProfile['fullName'] ?? '');
    final studentIdCtrl = TextEditingController(text: currentProfile['studentIdNumber'] ?? '');
    final sectionCtrl = TextEditingController(text: currentProfile['section'] ?? '');
    bool isSaving = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.badge, color: Colors.teal.shade800),
              const SizedBox(width: 8),
              const Text('My Student Profile'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dialogError != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                Text(
                  'Email: ${currentProfile['email'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: studentIdCtrl,
                  decoration: const InputDecoration(labelText: 'Student ID Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  decoration: const InputDecoration(labelText: 'Course, Year & Section', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() {
                        isSaving = true;
                        dialogError = null;
                      });

                      final uid = FirebaseAuth.instance.currentUser!.uid;
                      final newStudentId = studentIdCtrl.text.trim().toUpperCase();

                      try {
                        if (newStudentId.isNotEmpty && newStudentId != (currentProfile['studentIdNumber'] ?? '')) {
                          final query = await FirebaseFirestore.instance
                              .collection('users')
                              .where('studentIdNumber', isEqualTo: newStudentId)
                              .limit(1)
                              .get();

                          if (query.docs.isNotEmpty && query.docs.first.id != uid) {
                            throw Exception('Student ID "$newStudentId" is already linked to another student account.');
                          }
                        }

                        await FirebaseFirestore.instance.collection('users').doc(uid).update({
                          'fullName': nameCtrl.text.trim(),
                          'studentIdNumber': newStudentId,
                          'section': sectionCtrl.text.trim().toUpperCase(),
                        });

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.teal),
                        );
                      } catch (e) {
                        setModalState(() {
                          isSaving = false;
                          dialogError = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitTicket(Map<String, dynamic> userProfile) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final queueSnapshot = await FirebaseFirestore.instance
          .collection('queue')
          .where('queueDate', isEqualTo: dateKey)
          .get();

      final queueNum = queueSnapshot.docs.length + 1;

      await FirebaseFirestore.instance.collection('queue').add({
        'studentId': user.uid,
        'studentName': userProfile['fullName'] ?? 'Student',
        'studentIdNumber': userProfile['studentIdNumber'] ?? 'N/A',
        'section': userProfile['section'] ?? 'N/A',
        'studentEmail': user.email,
        'symptoms': _symptomsController.text.trim(),
        'vitals': {
          'temperature': double.tryParse(_tempController.text.trim()) ?? 0.0,
        },
        'urgencyLevel': _selectedUrgency,
        'status': 'pending',
        'queueNumber': queueNum,
        'queueDate': dateKey,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket Submitted! You are Queue #$queueNum'),
          backgroundColor: Colors.teal.shade800,
        ),
      );

      _symptomsController.clear();
      _tempController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, profileSnapshot) {
        final profile = (profileSnapshot.data?.data() as Map<String, dynamic>?) ?? widget.userData;
        final studentName = profile['fullName'] ?? 'Student';
        final studentId = profile['studentIdNumber'] ?? 'N/A';
        final section = profile['section'] ?? 'N/A';

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, $studentName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'ID: $studentId | Section: $section',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.queue), text: 'My Triage & Queue'),
                Tab(icon: Icon(Icons.medication), text: 'OTC Medicines'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.manage_accounts_outlined),
                tooltip: 'My Profile',
                onPressed: () => _openEditProfileDialog(profile),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
                onPressed: () => _confirmLogout(context), // Triggers confirmation modal
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Queue Ticket, Live Clinic Status & Form
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      children: [
                        // Live Clinic Status Banner
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('queue')
                              .where('status', whereIn: ['pending', 'consulting'])
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox.shrink();

                            final activeDocs = snapshot.data!.docs;
                            final consultingList = activeDocs.where((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              return d['status'] == 'consulting';
                            }).toList();

                            final pendingCount = activeDocs.where((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              return d['status'] == 'pending';
                            }).length;

                            final isBusy = consultingList.isNotEmpty;
                            final currentServingNum = isBusy
                                ? (consultingList.first.data() as Map<String, dynamic>)['queueNumber']
                                : null;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 20),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: isBusy ? Colors.deepOrange.shade400 : Colors.teal.shade300,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: isBusy ? Colors.deepOrange.shade50 : Colors.teal.shade50,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isBusy ? Colors.deepOrange.shade100 : Colors.teal.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isBusy ? Icons.medical_services : Icons.how_to_reg,
                                        color: isBusy ? Colors.deepOrange.shade900 : Colors.teal.shade900,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: isBusy ? Colors.deepOrange : Colors.green,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isBusy ? 'NURSE IS CURRENTLY BUSY' : 'CLINIC STATION AVAILABLE',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                  color: isBusy ? Colors.deepOrange.shade900 : Colors.teal.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isBusy
                                                ? 'Now Serving Patient: Ticket #$currentServingNum'
                                                : 'Ready for Next Walk-In Patient',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            pendingCount == 0
                                                ? 'No other students waiting in line'
                                                : '$pendingCount student${pendingCount > 1 ? 's' : ''} currently waiting in queue',
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // My Active Ticket Card
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('queue')
                              .where('studentId', isEqualTo: user.uid)
                              .where('status', whereIn: ['pending', 'consulting'])
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final ticket = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                            final status = ticket['status'] ?? 'pending';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: status == 'consulting' ? Colors.green.shade50 : Colors.amber.shade50,
                                border: Border.all(
                                  color: status == 'consulting' ? Colors.green : Colors.amber.shade700,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: status == 'consulting' ? Colors.green : Colors.amber.shade700,
                                    child: Text(
                                      '#${ticket['queueNumber']}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          status == 'consulting' ? '🩺 In Consultation Now!' : '⏳ Waiting in Queue',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: status == 'consulting' ? Colors.green.shade900 : Colors.amber.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Symptoms: ${ticket['symptoms']}'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Walk-in Form Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Submit Walk-in Ticket',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _symptomsController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'Symptoms / Chief Complaint *',
                                      hintText: 'e.g., Headache, sore throat, dizziness',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _tempController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Temperature (°C, optional)',
                                      hintText: '37.0',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.thermostat),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedUrgency,
                                    decoration: const InputDecoration(
                                      labelText: 'Urgency Level',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'low', child: Text('Low - Mild discomfort')),
                                      DropdownMenuItem(value: 'medium', child: Text('Medium - Moderate pain/fever')),
                                      DropdownMenuItem(value: 'high', child: Text('High - Severe pain/fever')),
                                      DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedUrgency = val);
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _isSubmitting ? null : () => _submitTicket(profile),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade800,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: _isSubmitting
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text('SUBMIT TRIAGE TICKET', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // TAB 2: OTC Medicines Catalog (Read-Only)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('medicines').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No medicines registered yet.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final med = docs[index].data() as Map<String, dynamic>;
                      final stock = med['stockCount'] as int? ?? 0;
                      final isAvailable = stock > 0;

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.medication_liquid_sharp,
                            color: isAvailable ? Colors.teal : Colors.grey,
                            size: 36,
                          ),
                          title: Text(med['genericName'] ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Unit: ${med['unit'] ?? 'item'}'),
                          trailing: Chip(
                            label: Text(
                              isAvailable ? 'IN STOCK' : 'OUT OF STOCK',
                              style: TextStyle(
                                color: isAvailable ? Colors.green.shade900 : Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}