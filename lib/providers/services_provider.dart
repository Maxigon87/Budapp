import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class ServiceItem {
  final String id;
  final String name;
  final double price;

  ServiceItem({
    required this.id,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  factory ServiceItem.fromMap(Map<dynamic, dynamic> map) {
    return ServiceItem(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0) as double,
    );
  }
}

class ServicesProvider extends ChangeNotifier {
  final Box _box = Hive.box('services');

  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore => _isFirebaseAvailable ? FirebaseFirestore.instance : null;
  FirebaseAuth? get _auth => _isFirebaseAvailable ? FirebaseAuth.instance : null;

  List<ServiceItem> get services {
    final List<ServiceItem> list = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        list.add(ServiceItem.fromMap(value));
      }
    }
    // Sort services alphabetically by name
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> addService(String name, double price) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = ServiceItem(id: id, name: name, price: price);
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncServiceToCloud(item);
  }

  Future<void> updateService(String id, String name, double price) async {
    final item = ServiceItem(id: id, name: name, price: price);
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncServiceToCloud(item);
  }

  Future<void> deleteService(String id) async {
    await _box.delete(id);
    notifyListeners();

    // Firebase Sync
    await _deleteServiceFromCloud(id);
  }

  // Cloud syncing helpers
  Future<void> _syncServiceToCloud(ServiceItem item) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('services')
            .doc(item.id)
            .set(item.toMap());
      } catch (e) {
        developer.log("Failed to sync service to Firestore: $e");
      }
    }
  }

  Future<void> _deleteServiceFromCloud(String id) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('services')
            .doc(id)
            .delete();
      } catch (e) {
        developer.log("Failed to delete service from Firestore: $e");
      }
    }
  }

  // Pull all services from Firestore to local Hive
  Future<void> syncFromCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('services')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        await _box.put(doc.id, data);
      }
      notifyListeners();
    } catch (e) {
      developer.log("Failed to download services from cloud: $e");
    }
  }

  // Push all local services to Firestore
  Future<void> uploadToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    try {
      final batch = firestore.batch();
      for (var item in services) {
        final docRef = firestore
            .collection('users')
            .doc(user.uid)
            .collection('services')
            .doc(item.id);
        batch.set(docRef, item.toMap());
      }
      await batch.commit();
    } catch (e) {
      developer.log("Failed to upload services to cloud: $e");
    }
  }
}
