import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompanyProvider extends ChangeNotifier {
  final Box _box = Hive.box('company_settings');

  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore => _isFirebaseAvailable ? FirebaseFirestore.instance : null;
  FirebaseAuth? get _auth => _isFirebaseAvailable ? FirebaseAuth.instance : null;

  String get name => _box.get('name', defaultValue: '') as String;
  String get address => _box.get('address', defaultValue: '') as String;
  String get phone => _box.get('phone', defaultValue: '') as String;
  String get email => _box.get('email', defaultValue: '') as String;
  String get website => _box.get('website', defaultValue: '') as String;
  String? get logoPath => _box.get('logoPath') as String?;

  bool get isConfigured {
    return name.isNotEmpty && phone.isNotEmpty && email.isNotEmpty;
  }

  void updateCompanyInfo({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String website,
    String? logoPath,
  }) {
    _box.put('name', name);
    _box.put('address', address);
    _box.put('phone', phone);
    _box.put('email', email);
    _box.put('website', website);
    if (logoPath != null) {
      _box.put('logoPath', logoPath);
    }
    notifyListeners();

    // Trigger dynamic cloud sync
    _syncCompanyToCloud();
  }

  void clearLogo() {
    _box.delete('logoPath');
    notifyListeners();
  }

  // Cloud syncing helpers
  Future<void> _syncCompanyToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('company')
            .doc('settings')
            .set({
              'name': name,
              'address': address,
              'phone': phone,
              'email': email,
              'website': website,
            });
      } catch (e) {
        debugPrint("Failed to sync company settings to Firestore: $e");
      }
    }
  }

  // Pull company settings from Firestore to local Hive
  Future<void> syncFromCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    try {
      final doc = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('company')
          .doc('settings')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          await _box.put('name', data['name'] ?? '');
          await _box.put('address', data['address'] ?? '');
          await _box.put('phone', data['phone'] ?? '');
          await _box.put('email', data['email'] ?? '');
          await _box.put('website', data['website'] ?? '');
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Failed to download company settings from cloud: $e");
    }
  }

  // Push company settings to Firestore
  Future<void> uploadToCloud() async {
    await _syncCompanyToCloud();
  }
}
