import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _sectionController = TextEditingController();

  bool _isLogin = true;
  String _selectedRole = 'student';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _studentIdController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  // --- "ALREADY REGISTERED" POPUP DIALOG ---
  void _showAlreadyRegisteredDialog(String message, String email) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
            const SizedBox(width: 10),
            const Text(
              'Already Registered',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              setState(() {
                _isLogin = true; // Automatically switch to Sign In
                _emailController.text = email;
                _passwordController.clear();
              });
            },
            child: const Text('GO TO SIGN IN'),
          ),
        ],
      ),
    );
  }

  // --- GENERAL POPUP FOR OTHER ERRORS ---
  void _showNoticeDialog(String title, String message, {bool isError = true}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? Colors.red.shade700 : Colors.teal.shade800,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isError ? Colors.red.shade900 : Colors.teal.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // --- INSTITUTIONAL VALIDATION LOGIC ---
  bool _isValidStudentUsername(String username) {
    if (username == 'student') return true;
    if (!username.startsWith('student')) return false;

    final numberPart = username.substring(7);
    final number = int.tryParse(numberPart);

    return number != null && number >= 1 && number <= 1000 && !numberPart.startsWith('0');
  }

  void _validateInstitutionalEmail(String email, {bool isRegistering = false, String role = 'student'}) {
    if (!email.endsWith('@campus.edu')) {
      throw Exception('Access Denied: Only official @campus.edu institutional emails are permitted.');
    }

    final username = email.split('@').first;

    if (isRegistering) {
      if (role == 'student') {
        if (!_isValidStudentUsername(username)) {
          throw Exception('Invalid Student Username: Student accounts must be "student1@campus.edu" to "student1000@campus.edu".');
        }
      } else if (role == 'nurse') {
        if (!username.startsWith('nurse')) {
          throw Exception('Invalid Staff Account: Nurse accounts must start with "nurse" (e.g., nurse@campus.edu).');
        }
      }
    } else {
      final isNurse = username.startsWith('nurse');
      final isStudent = _isValidStudentUsername(username);

      if (!isNurse && !isStudent) {
        throw Exception('Unauthorized Account: Only assigned student accounts (student1-1000@campus.edu) or clinic staff (nurse@campus.edu) may sign in.');
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final fullName = _nameController.text.trim();
    final studentId = _studentIdController.text.trim().toUpperCase();
    final section = _sectionController.text.trim().toUpperCase();

    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please fill in both email and password.');
      }

      _validateInstitutionalEmail(
        email,
        isRegistering: !_isLogin,
        role: _selectedRole,
      );

      if (_isLogin) {
        // ================= SIGN IN =================
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException {
          final checkUser = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (checkUser.docs.isEmpty) {
            _showNoticeDialog(
              'Account Not Created',
              'No account exists for "$email".\n\nPlease click "Register here" below to set up your student account first.',
            );
          } else {
            _showNoticeDialog(
              'Invalid Credentials',
              'The password entered for "$email" is incorrect.\n\nPlease check your credentials and try again.',
            );
          }
          return;
        }
      } else {
        // ================= REGISTRATION =================
        if (_selectedRole == 'student') {
          if (studentId.isEmpty || section.isEmpty) {
            throw Exception('Please provide your Student ID and Section for verification.');
          }

          // 1. CHECK IF STUDENT ID IS ALREADY REGISTERED (BEFORE TOUCHING AUTH)
          final existingIdQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('studentIdNumber', isEqualTo: studentId)
              .limit(1)
              .get();

          if (existingIdQuery.docs.isNotEmpty) {
            _showAlreadyRegisteredDialog(
              'Student ID "$studentId" is already registered to an existing account.\n\nIf this is your account, please sign in.',
              email,
            );
            return;
          }
        }

        // 2. CHECK IF EMAIL IS ALREADY REGISTERED IN FIRESTORE (BEFORE TOUCHING AUTH)
        final existingEmailQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (existingEmailQuery.docs.isNotEmpty) {
          _showAlreadyRegisteredDialog(
            'The institutional email "$email" is already registered.\n\nPlease sign in with your password.',
            email,
          );
          return;
        }

        // 3. CREATE AUTH ACCOUNT
        UserCredential credential;
        try {
          credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'email-already-in-use') {
            _showAlreadyRegisteredDialog(
              'The institutional email "$email" is already registered in Firebase.\n\nPlease sign in with your password.',
              email,
            );
            return;
          } else {
            rethrow;
          }
        }

        // 4. SAVE PROFILE RECORD
        final uid = credential.user!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'fullName': fullName.isEmpty ? 'Anonymous User' : fullName,
          'email': email,
          'role': _selectedRole,
          'studentIdNumber': _selectedRole == 'student' ? studentId : 'N/A',
          'section': _selectedRole == 'student' ? section : 'N/A',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      _showNoticeDialog('Authentication Error', e.message ?? 'An error occurred.');
    } catch (e) {
      _showNoticeDialog('Notice', e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.local_hospital_rounded, size: 56, color: Colors.teal.shade800),
                    const SizedBox(height: 12),
                    Text(
                      'Campus Clinic Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Authorized Institutional Access Only (@campus.edu)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),

                    if (!_isLogin) ...[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Select Role',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student / Patient')),
                          DropdownMenuItem(value: 'nurse', child: Text('Clinic Nurse / Admin')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_selectedRole == 'student') ...[
                        TextField(
                          controller: _studentIdController,
                          decoration: const InputDecoration(
                            labelText: 'Student ID Number *',
                            hintText: 'e.g., 2024-10023',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _sectionController,
                          decoration: const InputDecoration(
                            labelText: 'Course, Year & Section *',
                            hintText: 'e.g., BSCS 3-A',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.class_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    TextField(
                      controller: _emailController,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        labelText: 'Institutional Email *',
                        hintText: _isLogin
                            ? 'student1@campus.edu or nurse@campus.edu'
                            : (_selectedRole == 'student' ? 'student1@campus.edu' : 'nurse@campus.edu'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email_outlined),
                        helperText: _isLogin
                            ? 'Format: student1-1000@campus.edu'
                            : (_selectedRole == 'student' ? 'Range: student1@campus.edu to student1000@campus.edu' : 'Must start with nurse'),
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enableInteractiveSelection: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_passwordController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.cancel, size: 20, color: Colors.grey),
                                tooltip: 'Clear password',
                                onPressed: () {
                                  _passwordController.clear();
                                  setState(() {});
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.blueGrey,
                              ),
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_isLogin ? 'SIGN IN' : 'REGISTER'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _passwordController.clear();
                        });
                      },
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Register here"
                            : "Already have an account? Sign In",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}