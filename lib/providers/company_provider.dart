import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class CompanyProvider extends ChangeNotifier {
  final Box _box = Hive.box('company_settings');
  Timer? _syncTimer;

  CompanyProvider() {
    _initLogoPath();
    _startSyncTimer();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncPendingToCloud();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore => _isFirebaseAvailable ? FirebaseFirestore.instance : null;
  FirebaseAuth? get _auth => _isFirebaseAvailable ? FirebaseAuth.instance : null;

  String get _currentUserId {
    final auth = _auth;
    if (auth != null && auth.currentUser != null) {
      return auth.currentUser!.uid;
    }
    return 'guest';
  }

  String get name => _box.get('${_currentUserId}_name', defaultValue: '') as String;
  String get address => _box.get('${_currentUserId}_address', defaultValue: '') as String;
  String get phone => _box.get('${_currentUserId}_phone', defaultValue: '') as String;
  String get email => _box.get('${_currentUserId}_email', defaultValue: '') as String;
  String get website => _box.get('${_currentUserId}_website', defaultValue: '') as String;

  String? _resolvedLogoPath;
  String? get logoPath => _resolvedLogoPath;

  Future<Uint8List> _resizeLogo(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 150,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint("Error resizing logo image: $e");
    }
    return bytes;
  }

  Future<void> _initLogoPath() async {
    final uid = _currentUserId;
    
    // Migration check: check if there are legacy global key values (e.g., name, address)
    // and if we are in guest or user mode, migrate them to prefix key if prefix key doesn't exist
    if (!_box.containsKey('${uid}_name') && _box.containsKey('name')) {
      await _box.put('${uid}_name', _box.get('name'));
      await _box.put('${uid}_address', _box.get('address'));
      await _box.put('${uid}_phone', _box.get('phone'));
      await _box.put('${uid}_email', _box.get('email'));
      await _box.put('${uid}_website', _box.get('website'));
      await _box.put('${uid}_hasLogo', _box.get('hasLogo', defaultValue: false));
      await _box.put('${uid}_logoBase64', _box.get('logoBase64'));
      
      // Delete legacy global keys to keep database clean
      await _box.delete('name');
      await _box.delete('address');
      await _box.delete('phone');
      await _box.delete('email');
      await _box.delete('website');
      await _box.delete('hasLogo');
      await _box.delete('logoBase64');
    }

    final hasLogo = _box.get('${uid}_hasLogo', defaultValue: false) as bool;
    if (hasLogo) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        _resolvedLogoPath = '${directory.path}/${uid}_company_logo.png';
        
        if (!File(_resolvedLogoPath!).existsSync()) {
          final base64Logo = _box.get('${uid}_logoBase64') as String?;
          if (base64Logo != null && base64Logo.isNotEmpty) {
            final bytes = base64Decode(base64Logo);
            await File(_resolvedLogoPath!).writeAsBytes(bytes);
          } else {
            _resolvedLogoPath = null;
            await _box.put('${uid}_hasLogo', false);
          }
        }
      } catch (e) {
        debugPrint("Error initializing logo path: $e");
        _resolvedLogoPath = null;
      }
    } else {
      _resolvedLogoPath = null;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await _initLogoPath();
  }

  bool get isConfigured {
    return name.isNotEmpty && phone.isNotEmpty && email.isNotEmpty;
  }

  Future<void> updateCompanyInfo({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String website,
    String? logoPath,
  }) async {
    final uid = _currentUserId;

    await _box.put('${uid}_name', name);
    await _box.put('${uid}_address', address);
    await _box.put('${uid}_phone', phone);
    await _box.put('${uid}_email', email);
    await _box.put('${uid}_website', website);
    await _box.put('${uid}_syncStatus', uid == 'guest' ? 'synced' : 'pending');

    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final permanentPath = '${directory.path}/${uid}_company_logo.png';
        
        if (logoPath != permanentPath) {
          final sourceFile = File(logoPath);
          if (sourceFile.existsSync()) {
            final bytes = await sourceFile.readAsBytes();
            final compressedBytes = await _resizeLogo(bytes);
            await File(permanentPath).writeAsBytes(compressedBytes);
            final base64Logo = base64Encode(compressedBytes);
            await _box.put('${uid}_logoBase64', base64Logo);
            await _box.put('${uid}_hasLogo', true);
            _resolvedLogoPath = permanentPath;
          }
        }
      } catch (e) {
        debugPrint("Error saving logo file: $e");
      }
    } else {
      await _box.put('${uid}_hasLogo', false);
      await _box.delete('${uid}_logoBase64');
      _resolvedLogoPath = null;
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/${uid}_company_logo.png');
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error deleting logo file: $e");
      }
    }

    notifyListeners();

    // Trigger cloud sync
    await _syncCompanyToCloud();
  }

  void clearLogo() async {
    final uid = _currentUserId;
    await _box.put('${uid}_hasLogo', false);
    await _box.delete('${uid}_logoBase64');
    await _box.put('${uid}_syncStatus', uid == 'guest' ? 'synced' : 'pending');
    _resolvedLogoPath = null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${uid}_company_logo.png');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error deleting logo file: $e");
    }
    notifyListeners();
    
    // Trigger cloud sync
    await _syncCompanyToCloud();
  }

  // Cloud syncing helpers
  Future<void> _syncCompanyToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        final logoBase64 = _box.get('${user.uid}_logoBase64') as String?;
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
              'logoBase64': logoBase64,
            });
        
        await _box.put('${user.uid}_syncStatus', 'synced');
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
          final uid = user.uid;
          await _box.put('${uid}_name', data['name'] ?? '');
          await _box.put('${uid}_address', data['address'] ?? '');
          await _box.put('${uid}_phone', data['phone'] ?? '');
          await _box.put('${uid}_email', data['email'] ?? '');
          await _box.put('${uid}_website', data['website'] ?? '');
          await _box.put('${uid}_syncStatus', 'synced');
          
          final logoBase64 = data['logoBase64'] as String?;
          if (logoBase64 != null && logoBase64.isNotEmpty) {
            await _box.put('${uid}_logoBase64', logoBase64);
            await _box.put('${uid}_hasLogo', true);
            
            final directory = await getApplicationDocumentsDirectory();
            _resolvedLogoPath = '${directory.path}/${uid}_company_logo.png';
            try {
              final bytes = base64Decode(logoBase64);
              await File(_resolvedLogoPath!).writeAsBytes(bytes);
            } catch (e) {
              debugPrint("Error writing downloaded logo file: $e");
            }
          } else {
            await _box.put('${uid}_hasLogo', false);
            await _box.delete('${uid}_logoBase64');
            _resolvedLogoPath = null;
            try {
              final directory = await getApplicationDocumentsDirectory();
              final file = File('${directory.path}/${uid}_company_logo.png');
              if (file.existsSync()) {
                await file.delete();
              }
            } catch (e) {
              debugPrint("Error deleting logo file: $e");
            }
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Failed to download company settings from cloud: $e");
      rethrow;
    }
  }

  // Push company settings to Firestore
  Future<void> uploadToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        final logoBase64 = _box.get('${user.uid}_logoBase64') as String?;
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
              'logoBase64': logoBase64,
            });
        
        await _box.put('${user.uid}_syncStatus', 'synced');
      } catch (e) {
        debugPrint("Failed to sync company settings to Firestore: $e");
        rethrow;
      }
    }
  }

  Future<void> syncPendingToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;
    final user = auth.currentUser;
    if (user == null) return;

    final syncStatus = _box.get('${user.uid}_syncStatus', defaultValue: 'synced') as String;
    if (syncStatus == 'pending') {
      await _syncCompanyToCloud();
    }
  }

  Future<void> syncWithCloud() async {
    await syncPendingToCloud();
    await syncFromCloud();
  }

  Future<void> clearUserData(String uid) async {
    final prefix = '${uid}_';
    final keysToDelete = [];
    for (var key in _box.keys) {
      if (key is String && key.startsWith(prefix)) {
        keysToDelete.add(key);
      }
    }
    for (var key in keysToDelete) {
      await _box.delete(key);
    }
    
    _resolvedLogoPath = null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${uid}_company_logo.png');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error deleting logo file on clear: $e");
    }

    notifyListeners();
  }

  Future<void> transferGuestDataToUser(String newUid) async {
    final guestPrefix = 'guest_';
    final List<String> keysToCopy = [];
    for (var key in _box.keys) {
      if (key is String && key.startsWith(guestPrefix)) {
        keysToCopy.add(key);
      }
    }
    for (var key in keysToCopy) {
      final cleanKey = key.substring(guestPrefix.length);
      await _box.put('${newUid}_$cleanKey', _box.get(key));
      await _box.delete(key);
    }
    await _box.put('${newUid}_syncStatus', 'pending');
    try {
      final directory = await getApplicationDocumentsDirectory();
      final guestLogo = File('${directory.path}/guest_company_logo.png');
      if (guestLogo.existsSync()) {
        await guestLogo.rename('${directory.path}/${newUid}_company_logo.png');
      }
    } catch (e) {
      debugPrint("Error renaming logo during transfer: $e");
    }
    await _initLogoPath();
    notifyListeners();
  }

  bool hasPendingSync(String uid) {
    final syncStatus = _box.get('${uid}_syncStatus', defaultValue: 'synced') as String;
    return syncStatus == 'pending';
  }
}
