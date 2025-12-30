import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkRide Firebase Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FirebaseTestScreen(),
    );
  }
}

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final _database = FirebaseDatabase.instance.ref();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _titleController = TextEditingController();
  final _firestoreTitleController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _firestoreItems = [];
  bool _isLoading = false;
  bool _isFirestoreLoading = false;
  bool _isAuthLoading = false;
  String _firestoreStatus = 'Unknown';
  String _authStatus = 'Not signed in';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFirestoreData();
    _testFirestoreConnection();
  }

  Future<void> _testFirestoreConnection() async {
    try {
      setState(() => _firestoreStatus = 'Testing...');
      await _firestore
          .collection('_test')
          .doc('connection')
          .get(const GetOptions(source: Source.server));
      setState(() => _firestoreStatus = 'Connected ✓');
    } catch (e) {
      setState(
        () => _firestoreStatus = 'Failed: ${e.toString().split('\n').first}',
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('test_items').get();
      final items = <Map<String, dynamic>>[];
      if (snapshot.exists) {
        for (var child in snapshot.children) {
          items.add({
            'key': child.key,
            ...Map<String, dynamic>.from(child.value as Map),
          });
        }
      }
      setState(() => _items = items);
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFirestoreData() async {
    setState(() => _isFirestoreLoading = true);
    try {
      final snapshot = await _firestore.collection('test_items').get();
      final items = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        items.add({'id': doc.id, ...doc.data()});
      }
      setState(() => _firestoreItems = items);
    } catch (e) {
      _showError('Failed to load Firestore data: $e');
    } finally {
      setState(() => _isFirestoreLoading = false);
    }
  }

  Future<void> _addItem() async {
    if (_titleController.text.isEmpty) {
      _showError('Please enter a title');
      return;
    }
    try {
      final newKey = _database.child('test_items').push().key;
      await _database.child('test_items/$newKey').set({
        'title': _titleController.text,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _titleController.clear();
      _loadData();
      _showSuccess('Item added successfully');
    } catch (e) {
      _showError('Failed to add item: $e');
    }
  }

  Future<void> _addFirestoreItem() async {
    if (_firestoreTitleController.text.isEmpty) {
      _showError('Please enter a title');
      return;
    }
    setState(() => _isFirestoreLoading = true);
    try {
      await _firestore.collection('test_items').add({
        'title': _firestoreTitleController.text,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _firestoreTitleController.clear();
      await _loadFirestoreData();
      _showSuccess('Firestore item added successfully');
    } catch (e) {
      _showError('Failed to add Firestore item: ${e.toString()}');
    } finally {
      setState(() => _isFirestoreLoading = false);
    }
  }

  Future<void> _deleteItem(String key) async {
    try {
      await _database.child('test_items/$key').remove();
      _loadData();
      _showSuccess('Item deleted');
    } catch (e) {
      _showError('Failed to delete item: $e');
    }
  }

  Future<void> _deleteFirestoreItem(String id) async {
    try {
      await _firestore.collection('test_items').doc(id).delete();
      _loadFirestoreData();
      _showSuccess('Firestore item deleted');
    } catch (e) {
      _showError('Failed to delete Firestore item: $e');
    }
  }

  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter email and password');
      return;
    }
    setState(() => _isAuthLoading = true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() => _authStatus = 'Signed up: ${_auth.currentUser?.email}');
      _showSuccess('Sign up successful');
      _clearAuthFields();
    } catch (e) {
      _showError('Sign up failed: ${e.toString()}');
    } finally {
      setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter email and password');
      return;
    }
    setState(() => _isAuthLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() => _authStatus = 'Signed in: ${_auth.currentUser?.email}');
      _showSuccess('Sign in successful');
      _clearAuthFields();
    } catch (e) {
      _showError('Sign in failed: ${e.toString()}');
    } finally {
      setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      setState(() => _authStatus = 'Not signed in');
      _showSuccess('Signed out');
    } catch (e) {
      _showError('Sign out failed: $e');
    }
  }

  void _clearAuthFields() {
    _emailController.clear();
    _passwordController.clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _firestoreTitleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Database Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Auth Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Authentication',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _authStatus.contains('Signed in')
                              ? Colors.green
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _authStatus,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isAuthLoading ? null : _signUp,
                          child: _isAuthLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign Up'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isAuthLoading ? null : _signIn,
                          child: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(thickness: 2),
            // Realtime Database Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Realtime Database',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'Enter item title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addItem,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                      ? const Center(
                          child: Text('No items. Add one to get started!'),
                        )
                      : SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return ListTile(
                                title: Text(item['title'] ?? 'Untitled'),
                                subtitle: Text(
                                  item['createdAt'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteItem(item['key']),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
            const Divider(thickness: 2),
            // Firestore Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Firestore',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _firestoreStatus.contains('Connected')
                              ? Colors.green
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _firestoreStatus,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firestoreTitleController,
                          decoration: InputDecoration(
                            hintText: 'Enter Firestore item title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isFirestoreLoading
                            ? null
                            : _addFirestoreItem,
                        child: _isFirestoreLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isFirestoreLoading && _firestoreItems.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _firestoreItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No Firestore items. Add one to get started!',
                          ),
                        )
                      : SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: _firestoreItems.length,
                            itemBuilder: (context, index) {
                              final item = _firestoreItems[index];
                              return ListTile(
                                title: Text(item['title'] ?? 'Untitled'),
                                subtitle: Text(
                                  item['createdAt'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteFirestoreItem(item['id']),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
