import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'dart:async';

class MaterialItem {
  static const String defaultCategory = 'Sin categoría';

  final String id;
  final String nombre;
  final String categoria;
  final double? ultimoPrecio;
  final String userId;
  final String syncStatus; // 'pending', 'synced', 'deleted'

  MaterialItem({
    required this.id,
    required this.nombre,
    required this.categoria,
    this.ultimoPrecio,
    this.userId = 'guest',
    this.syncStatus = 'synced',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'ultimoPrecio': ultimoPrecio,
      'userId': userId,
      'syncStatus': syncStatus,
    };
  }

  factory MaterialItem.fromMap(Map<dynamic, dynamic> map) {
    final rawCategory = (map['categoria'] ?? map['unidad'] ?? '') as String;
    return MaterialItem(
      id: (map['id'] ?? '') as String,
      nombre: (map['nombre'] ?? '') as String,
      categoria: rawCategory.trim().isEmpty ? defaultCategory : rawCategory.trim(),
      ultimoPrecio: map['ultimoPrecio'] != null
          ? (map['ultimoPrecio'] is int ? (map['ultimoPrecio'] as int).toDouble() : (map['ultimoPrecio'] as double))
          : null,
      userId: (map['userId'] ?? 'guest') as String,
      syncStatus: (map['syncStatus'] ?? 'synced') as String,
    );
  }

  MaterialItem copyWith({
    String? id,
    String? nombre,
    String? categoria,
    double? ultimoPrecio,
    bool nullPrice = false,
    String? userId,
    String? syncStatus,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      ultimoPrecio: nullPrice ? null : (ultimoPrecio ?? this.ultimoPrecio),
      userId: userId ?? this.userId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class MaterialsProvider extends ChangeNotifier {
  final Box _box = Hive.box('materials');
  Timer? _syncTimer;

  MaterialsProvider() {
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

  List<MaterialItem> get materials {
    final List<MaterialItem> list = [];
    final currentUid = _currentUserId;
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = MaterialItem.fromMap(value);
        if (item.userId == currentUid && item.syncStatus != 'deleted') {
          list.add(item);
        }
      }
    }
    // Sort materials alphabetically by name (case-insensitive)
    list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return list;
  }

  List<String> get categorias {
    final categoriaSet = <String>{MaterialItem.defaultCategory};
    for (final mat in materials) {
      categoriaSet.add(mat.categoria);
    }
    final list = categoriaSet.toList()
      ..sort((a, b) {
        if (a == MaterialItem.defaultCategory) return -1;
        if (b == MaterialItem.defaultCategory) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return list;
  }

  Future<void> addMaterial(String nombre, String categoria, double? ultimoPrecio) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final currentUid = _currentUserId;
    final item = MaterialItem(
      id: id,
      nombre: nombre.trim(),
      categoria: categoria.trim().isEmpty ? MaterialItem.defaultCategory : categoria.trim(),
      ultimoPrecio: ultimoPrecio,
      userId: currentUid,
      syncStatus: currentUid == 'guest' ? 'synced' : 'pending',
    );
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncMaterialToCloud(item);
  }

  Future<void> updateMaterial(String id, String nombre, String categoria, double? ultimoPrecio) async {
    final currentUid = _currentUserId;
    final item = MaterialItem(
      id: id,
      nombre: nombre.trim(),
      categoria: categoria.trim().isEmpty ? MaterialItem.defaultCategory : categoria.trim(),
      ultimoPrecio: ultimoPrecio,
      userId: currentUid,
      syncStatus: currentUid == 'guest' ? 'synced' : 'pending',
    );
    await _box.put(id, item.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncMaterialToCloud(item);
  }

  Future<void> saveMaterials(List<MaterialItem> itemsToSave) async {
    if (itemsToSave.isEmpty) return;
    final currentUid = _currentUserId;
    final List<MaterialItem> processedItems = [];

    for (final item in itemsToSave) {
      final processedItem = MaterialItem(
        id: item.id,
        nombre: item.nombre,
        categoria: item.categoria,
        ultimoPrecio: item.ultimoPrecio,
        userId: currentUid,
        syncStatus: currentUid == 'guest' ? 'synced' : 'pending',
      );
      await _box.put(processedItem.id, processedItem.toMap());
      processedItems.add(processedItem);
    }
    notifyListeners();

    // Firebase Sync in parallel
    if (currentUid != 'guest') {
      await Future.wait(processedItems.map((item) => _syncMaterialToCloud(item)));
    }
  }

  Future<void> deleteMaterial(String id) async {
    final currentUid = _currentUserId;
    if (currentUid == 'guest') {
      await _box.delete(id);
      notifyListeners();
      return;
    }

    final itemMap = _box.get(id);
    if (itemMap is Map) {
      final item = MaterialItem.fromMap(itemMap);
      final deletedItem = MaterialItem(
        id: item.id,
        nombre: item.nombre,
        categoria: item.categoria,
        ultimoPrecio: item.ultimoPrecio,
        userId: item.userId,
        syncStatus: 'deleted',
      );
      await _box.put(id, deletedItem.toMap());
      notifyListeners();

      // Firebase Sync
      await _deleteMaterialFromCloud(id);
    }
  }

  // Cloud syncing helpers
  Future<void> _syncMaterialToCloud(MaterialItem item) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null && item.userId == user.uid) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('materials')
            .doc(item.id)
            .set(item.toMap());

        // Update local status to synced if it was pending
        if (item.syncStatus == 'pending') {
          final syncedItem = MaterialItem(
            id: item.id,
            nombre: item.nombre,
            categoria: item.categoria,
            ultimoPrecio: item.ultimoPrecio,
            userId: item.userId,
            syncStatus: 'synced',
          );
          await _box.put(item.id, syncedItem.toMap());
        }
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

        // Remove completely from Hive once deleted on server
        await _box.delete(id);
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
        final data = Map<String, dynamic>.from(doc.data());
        data['userId'] = user.uid;
        data['syncStatus'] = 'synced';
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

        for (var item in chunk) {
          final syncedItem = MaterialItem(
            id: item.id,
            nombre: item.nombre,
            categoria: item.categoria,
            ultimoPrecio: item.ultimoPrecio,
            userId: item.userId,
            syncStatus: 'synced',
          );
          await _box.put(item.id, syncedItem.toMap());
        }
      }
    } catch (e) {
      developer.log("Failed to upload materials to cloud: $e");
      rethrow;
    }
  }

  Future<void> syncPendingToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;
    final user = auth.currentUser;
    if (user == null) return;

    // 1. Sync pending additions/updates
    final List<MaterialItem> pending = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = MaterialItem.fromMap(value);
        if (item.userId == user.uid && item.syncStatus == 'pending') {
          pending.add(item);
        }
      }
    }
    for (var item in pending) {
      await _syncMaterialToCloud(item);
    }

    // 2. Sync pending deletions
    final List<String> deletedIds = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = MaterialItem.fromMap(value);
        if (item.userId == user.uid && item.syncStatus == 'deleted') {
          deletedIds.add(item.id);
        }
      }
    }
    for (var id in deletedIds) {
      await _deleteMaterialFromCloud(id);
    }
  }

  Future<void> syncWithCloud() async {
    await syncPendingToCloud();
    await syncFromCloud();
  }

  Future<void> clearUserData(String uid) async {
    final keysToDelete = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = MaterialItem.fromMap(value);
        if (item.userId == uid) {
          keysToDelete.add(key);
        }
      }
    }
    for (var key in keysToDelete) {
      await _box.delete(key);
    }
    notifyListeners();
  }

  Future<void> transferGuestDataToUser(String newUid) async {
    final List<String> guestKeys = [];
    final List<MaterialItem> itemsToTransfer = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = MaterialItem.fromMap(value);
        if (item.userId == 'guest') {
          guestKeys.add(key.toString());
          itemsToTransfer.add(item);
        }
      }
    }
    for (var item in itemsToTransfer) {
      final transferredItem = MaterialItem(
        id: item.id,
        nombre: item.nombre,
        categoria: item.categoria,
        ultimoPrecio: item.ultimoPrecio,
        userId: newUid,
        syncStatus: 'pending',
      );
      await _box.put(transferredItem.id, transferredItem.toMap());
    }
    for (var key in guestKeys) {
      await _box.delete(key);
    }
    notifyListeners();
  }

  bool hasPendingSync(String uid) {
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = MaterialItem.fromMap(value);
        if (item.userId == uid && (item.syncStatus == 'pending' || item.syncStatus == 'deleted')) {
          return true;
        }
      }
    }
    return false;
  }

  void refresh() {
    notifyListeners();
  }
}
