import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

import '../utils/services_excel_importer.dart';

class ServiceItem {
  static const String defaultCategory = 'Sin categoría';

  final String id;
  final String name;
  final double price;
  final String category;

  ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    this.category = defaultCategory,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
    };
  }

  factory ServiceItem.fromMap(Map<dynamic, dynamic> map) {
    return ServiceItem(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0) as double,
      category: _normalizeCategory(map['category']),
    );
  }

  static String _normalizeCategory(dynamic rawCategory) {
    final category = rawCategory is String ? rawCategory.trim() : '';
    return category.isEmpty ? defaultCategory : category;
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
    // Sort services by category, then alphabetically by name
    list.sort((a, b) {
      final categoryComparison = a.category.toLowerCase().compareTo(b.category.toLowerCase());
      if (categoryComparison != 0) return categoryComparison;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  List<String> get categories {
    final categorySet = <String>{ServiceItem.defaultCategory};
    for (final service in services) {
      categorySet.add(service.category);
    }
    final list = categorySet.toList()
      ..sort((a, b) {
        if (a == ServiceItem.defaultCategory) return -1;
        if (b == ServiceItem.defaultCategory) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return list;
  }

  Future<void> addService(String name, double price, String category) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = ServiceItem(id: id, name: name, price: price, category: _normalizeCategory(category));
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncServiceToCloud(item);
  }

  Future<int> importServices(List<ServiceExcelRow> rows) async {
    final importedItems = <ServiceItem>[];
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    // Create a map to lookup services by category and name for duplicate check
    final serviceMap = <String, ServiceItem>{};
    for (final s in services) {
      final key = '${s.category.trim().toLowerCase()}_${s.name.trim().toLowerCase()}';
      serviceMap[key] = s;
    }

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final normalizedCategory = _normalizeCategory(row.category);
      final normalizedName = row.name.trim();
      final key = '${normalizedCategory.toLowerCase()}_${normalizedName.toLowerCase()}';

      final existing = serviceMap[key];
      if (existing != null) {
        // Overwrite the price of the existing service
        final updatedItem = ServiceItem(
          id: existing.id,
          name: existing.name, // Keep the existing case of the service name
          price: row.price,
          category: existing.category,
        );
        serviceMap[key] = updatedItem;
        importedItems.add(updatedItem);
        await _box.put(existing.id, updatedItem.toMap());
      } else {
        // Add new service
        final id = '${timestamp}_$index';
        final newItem = ServiceItem(
          id: id,
          name: row.name,
          price: row.price,
          category: normalizedCategory,
        );
        serviceMap[key] = newItem;
        importedItems.add(newItem);
        await _box.put(id, newItem.toMap());
      }
    }

    if (importedItems.isEmpty) return 0;

    notifyListeners();

    // Firebase Sync in parallel
    await Future.wait(importedItems.map((item) => _syncServiceToCloud(item)));

    return importedItems.length;
  }

  Future<void> updateService(String id, String name, double price, String category) async {
    final item = ServiceItem(id: id, name: name, price: price, category: _normalizeCategory(category));
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncServiceToCloud(item);
  }

  String _normalizeCategory(String category) {
    final trimmed = category.trim();
    return trimmed.isEmpty ? ServiceItem.defaultCategory : trimmed;
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
      rethrow;
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
      final allServices = services;
      const int batchSize = 500; // Firestore limit per batch is 500

      for (var i = 0; i < allServices.length; i += batchSize) {
        final batch = firestore.batch();
        final end = (i + batchSize < allServices.length) ? i + batchSize : allServices.length;
        final chunk = allServices.sublist(i, end);

        for (var item in chunk) {
          final docRef = firestore
              .collection('users')
              .doc(user.uid)
              .collection('services')
              .doc(item.id);
          batch.set(docRef, item.toMap());
        }
        await batch.commit();
      }
    } catch (e) {
      developer.log("Failed to upload services to cloud: $e");
      rethrow;
    }
  }

  void refresh() {
    notifyListeners();
  }
}
