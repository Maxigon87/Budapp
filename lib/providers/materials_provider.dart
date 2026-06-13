import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class MaterialItem {
  final String id;
  final String nombre;
  final String unidad;
  final double? ultimoPrecio;

  MaterialItem({
    required this.id,
    required this.nombre,
    required this.unidad,
    this.ultimoPrecio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'unidad': unidad,
      'ultimoPrecio': ultimoPrecio,
    };
  }

  factory MaterialItem.fromMap(Map<dynamic, dynamic> map) {
    return MaterialItem(
      id: (map['id'] ?? '') as String,
      nombre: (map['nombre'] ?? '') as String,
      unidad: (map['unidad'] ?? '') as String,
      ultimoPrecio: map['ultimoPrecio'] != null
          ? (map['ultimoPrecio'] is int ? (map['ultimoPrecio'] as int).toDouble() : (map['ultimoPrecio'] as double))
          : null,
    );
  }

  MaterialItem copyWith({
    String? id,
    String? nombre,
    String? unidad,
    double? ultimoPrecio,
    bool nullPrice = false,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      unidad: unidad ?? this.unidad,
      ultimoPrecio: nullPrice ? null : (ultimoPrecio ?? this.ultimoPrecio),
    );
  }
}

class MaterialsProvider extends ChangeNotifier {
  final Box _box = Hive.box('materials');

  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore => _isFirebaseAvailable ? FirebaseFirestore.instance : null;
  FirebaseAuth? get _auth => _isFirebaseAvailable ? FirebaseAuth.instance : null;

  List<MaterialItem> get materials {
    final List<MaterialItem> list = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        list.add(MaterialItem.fromMap(value));
      }
    }
    // Sort materials alphabetically by name (case-insensitive)
    list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return list;
  }

  List<String> get unidades {
    final unidadSet = <String>{};
    for (final mat in materials) {
      if (mat.unidad.trim().isNotEmpty) {
        unidadSet.add(mat.unidad.trim());
      }
    }
    final list = unidadSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> addMaterial(String nombre, String unidad, double? ultimoPrecio) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = MaterialItem(
      id: id,
      nombre: nombre.trim(),
      unidad: unidad.trim(),
      ultimoPrecio: ultimoPrecio,
    );
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncMaterialToCloud(item);
  }

  Future<void> updateMaterial(String id, String nombre, String unidad, double? ultimoPrecio) async {
    final item = MaterialItem(
      id: id,
      nombre: nombre.trim(),
      unidad: unidad.trim(),
      ultimoPrecio: ultimoPrecio,
    );
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncMaterialToCloud(item);
  }

  Future<void> saveMaterials(List<MaterialItem> itemsToSave) async {
    if (itemsToSave.isEmpty) return;
    for (final item in itemsToSave) {
      await _box.put(item.id, item.toMap());
    }
    notifyListeners();

    // Firebase Sync in parallel
    await Future.wait(itemsToSave.map((item) => _syncMaterialToCloud(item)));
  }

  Future<void> deleteMaterial(String id) async {
    await _box.delete(id);
    notifyListeners();

    // Firebase Sync
    await _deleteMaterialFromCloud(id);
  }

  // Cloud syncing helpers
  Future<void> _syncMaterialToCloud(MaterialItem item) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('materials')
            .doc(item.id)
            .set(item.toMap());
      } catch (e) {
        developer.log("Failed to sync material to Firestore: $e");
      }
    }
  }

  Future<void> _deleteMaterialFromCloud(String id) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('materials')
            .doc(id)
            .delete();
      } catch (e) {
        developer.log("Failed to delete material from Firestore: $e");
      }
    }
  }

  // Pull all materials from Firestore to local Hive
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
          .collection('materials')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        await _box.put(doc.id, data);
      }
      notifyListeners();
    } catch (e) {
      developer.log("Failed to download materials from cloud: $e");
      rethrow;
    }
  }

  // Push all local materials to Firestore
  Future<void> uploadToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    try {
      final allMaterials = materials;
      const int batchSize = 500; // Firestore limit per batch is 500

      for (var i = 0; i < allMaterials.length; i += batchSize) {
        final batch = firestore.batch();
        final end = (i + batchSize < allMaterials.length) ? i + batchSize : allMaterials.length;
        final chunk = allMaterials.sublist(i, end);

        for (var item in chunk) {
          final docRef = firestore
              .collection('users')
              .doc(user.uid)
              .collection('materials')
              .doc(item.id);
          batch.set(docRef, item.toMap());
        }
        await batch.commit();
      }
    } catch (e) {
      developer.log("Failed to upload materials to cloud: $e");
      rethrow;
    }
  }

  void refresh() {
    notifyListeners();
  }
}
