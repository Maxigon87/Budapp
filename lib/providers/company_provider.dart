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

  String? _resolvedLogoPath;
  String? get logoPath => _resolvedLogoPath;

  CompanyProvider() {
    _initLogoPath();
  }

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
    // Migration check: if there is an old 'logoPath' but no 'hasLogo'
    final oldLogoPath = _box.get('logoPath') as String?;
    final hasLogoKey = _box.containsKey('hasLogo');
    
    if (oldLogoPath != null && !hasLogoKey) {
      try {
        final file = File(oldLogoPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          final compressedBytes = await _resizeLogo(bytes);
          final base64Logo = base64Encode(compressedBytes);
          await _box.put('logoBase64', base64Logo);
          await _box.put('hasLogo', true);
        }
      } catch (e) {
        debugPrint("Failed to migrate old logo: $e");
      }
      await _box.delete('logoPath');
    }

    final hasLogo = _box.get('hasLogo', defaultValue: false) as bool;
    if (hasLogo) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        _resolvedLogoPath = '${directory.path}/company_logo.png';
        
        if (!File(_resolvedLogoPath!).existsSync()) {
          final base64Logo = _box.get('logoBase64') as String?;
          if (base64Logo != null && base64Logo.isNotEmpty) {
            final bytes = base64Decode(base64Logo);
            await File(_resolvedLogoPath!).writeAsBytes(bytes);
          } else {
            _resolvedLogoPath = null;
            await _box.put('hasLogo', false);
          }
        }
      } catch (e) {
        debugPrint("Error initializing logo path: $e");
        _resolvedLogoPath = null;
      }
      notifyListeners();
    }
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
    await _box.put('name', name);
    await _box.put('address', address);
    await _box.put('phone', phone);
    await _box.put('email', email);
    await _box.put('website', website);

    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final permanentPath = '${directory.path}/company_logo.png';
        
        if (logoPath != permanentPath) {
          final sourceFile = File(logoPath);
          if (sourceFile.existsSync()) {
            final bytes = await sourceFile.readAsBytes();
            final compressedBytes = await _resizeLogo(bytes);
            await File(permanentPath).writeAsBytes(compressedBytes);
            final base64Logo = base64Encode(compressedBytes);
            await _box.put('logoBase64', base64Logo);
            await _box.put('hasLogo', true);
            _resolvedLogoPath = permanentPath;
          }
        }
      } catch (e) {
        debugPrint("Error saving logo file: $e");
      }
    } else {
      await _box.put('hasLogo', false);
      await _box.delete('logoBase64');
      _resolvedLogoPath = null;
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/company_logo.png');
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error deleting logo file: $e");
      }
    }

    notifyListeners();

    // Trigger dynamic cloud sync in background (do not await)
    _syncCompanyToCloud();
  }

  void clearLogo() async {
    await _box.put('hasLogo', false);
    await _box.delete('logoBase64');
    _resolvedLogoPath = null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/company_logo.png');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error deleting logo file: $e");
    }
    notifyListeners();
    
    // Trigger dynamic cloud sync in background (do not await)
    _syncCompanyToCloud();
  }

  // Cloud syncing helpers
  Future<void> _syncCompanyToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        final logoBase64 = _box.get('logoBase64') as String?;
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
          
          final logoBase64 = data['logoBase64'] as String?;
          if (logoBase64 != null && logoBase64.isNotEmpty) {
            await _box.put('logoBase64', logoBase64);
            await _box.put('hasLogo', true);
            
            final directory = await getApplicationDocumentsDirectory();
            _resolvedLogoPath = '${directory.path}/company_logo.png';
            try {
              final bytes = base64Decode(logoBase64);
              await File(_resolvedLogoPath!).writeAsBytes(bytes);
            } catch (e) {
              debugPrint("Error writing downloaded logo file: $e");
            }
          } else {
            await _box.put('hasLogo', false);
            await _box.delete('logoBase64');
            _resolvedLogoPath = null;
            try {
              final directory = await getApplicationDocumentsDirectory();
              final file = File('${directory.path}/company_logo.png');
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
        final logoBase64 = _box.get('logoBase64') as String?;
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
      } catch (e) {
        debugPrint("Failed to sync company settings to Firestore: $e");
        rethrow;
      }
    }
  }
}
