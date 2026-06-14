import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'dart:async';

class QuoteItem {
  final String name;
  final double price;
  final int quantity;
  final bool isMaterial;
  final String? unidad;

  QuoteItem({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.isMaterial = false,
    this.unidad,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'isMaterial': isMaterial,
      'unidad': unidad,
    };
  }

  factory QuoteItem.fromMap(Map<dynamic, dynamic> map) {
    return QuoteItem(
      name: (map['name'] ?? '') as String,
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0) as double,
      quantity: (map['quantity'] ?? 1) as int,
      isMaterial: (map['isMaterial'] ?? false) as bool,
      unidad: map['unidad'] as String?,
    );
  }
}

class Quote {
  final String id;
  final String number;
  final DateTime date;
  final String clientName;
  final String clientPhone;
  final String clientAddress;
  final List<QuoteItem> items;
  final double total;
  final String status; // 'Pendiente', 'Aceptado', 'Rechazado'
  final String observations;
  final String userId;
  final String syncStatus; // 'pending', 'synced', 'deleted'

  Quote({
    required this.id,
    required this.number,
    required this.date,
    required this.clientName,
    required this.clientPhone,
    required this.clientAddress,
    required this.items,
    required this.total,
    required this.status,
    required this.observations,
    this.userId = 'guest',
    this.syncStatus = 'synced',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'date': date.toIso8601String(),
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientAddress': clientAddress,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'status': status,
      'observations': observations,
      'userId': userId,
      'syncStatus': syncStatus,
    };
  }

  factory Quote.fromMap(Map<dynamic, dynamic> map) {
    final rawItems = map['items'] as List? ?? [];
    final itemsList = rawItems
        .map((i) => QuoteItem.fromMap(i as Map<dynamic, dynamic>))
        .toList();

    return Quote(
      id: (map['id'] ?? '') as String,
      number: (map['number'] ?? '') as String,
      date: DateTime.parse((map['date'] ?? DateTime.now().toIso8601String()) as String),
      clientName: (map['clientName'] ?? '') as String,
      clientPhone: (map['clientPhone'] ?? '') as String,
      clientAddress: (map['clientAddress'] ?? '') as String,
      items: itemsList,
      total: (map['total'] is int) ? (map['total'] as int).toDouble() : (map['total'] ?? 0.0) as double,
      status: (map['status'] ?? 'Pendiente') as String,
      observations: (map['observations'] ?? '') as String,
      userId: (map['userId'] ?? 'guest') as String,
      syncStatus: (map['syncStatus'] ?? 'synced') as String,
    );
  }
}

class QuotesProvider extends ChangeNotifier {
  final Box _box = Hive.box('quotes');
  Timer? _syncTimer;

  QuotesProvider() {
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

  List<Quote> get quotes {
    final List<Quote> list = [];
    final currentUid = _currentUserId;
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = Quote.fromMap(value);
        if (item.userId == currentUid && item.syncStatus != 'deleted') {
          list.add(item);
        }
      }
    }
    // Sort quotes by date descending (newest first)
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  String getNextQuoteNumber() {
    final list = quotes;
    if (list.isEmpty) return '0001';

    // Extract numeric values from quotes
    int maxNum = 0;
    for (var q in list) {
      final parsed = int.tryParse(q.number);
      if (parsed != null && parsed > maxNum) {
        maxNum = parsed;
      }
    }
    final nextNum = maxNum + 1;
    return nextNum.toString().padLeft(4, '0');
  }

  Future<void> saveQuote(Quote quote) async {
    final currentUid = _currentUserId;
    final quoteWithUser = Quote(
      id: quote.id,
      number: quote.number,
      date: quote.date,
      clientName: quote.clientName,
      clientPhone: quote.clientPhone,
      clientAddress: quote.clientAddress,
      items: quote.items,
      total: quote.total,
      status: quote.status,
      observations: quote.observations,
      userId: currentUid,
      syncStatus: currentUid == 'guest' ? 'synced' : 'pending',
    );

    await _box.put(quoteWithUser.id, quoteWithUser.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncQuoteToCloud(quoteWithUser);
  }

  Future<void> updateQuoteStatus(String id, String newStatus) async {
    final currentUid = _currentUserId;
    final quoteMap = _box.get(id);
    if (quoteMap is Map) {
      final updatedMap = Map<dynamic, dynamic>.from(quoteMap);
      updatedMap['status'] = newStatus;
      updatedMap['syncStatus'] = currentUid == 'guest' ? 'synced' : 'pending';
      
      await _box.put(id, updatedMap);
      notifyListeners();

      final updatedQuote = Quote.fromMap(updatedMap);
      await _syncQuoteToCloud(updatedQuote);
    }
  }

  Future<void> deleteQuote(String id) async {
    final currentUid = _currentUserId;
    if (currentUid == 'guest') {
      await _box.delete(id);
      notifyListeners();
      return;
    }

    final itemMap = _box.get(id);
    if (itemMap is Map) {
      final item = Quote.fromMap(itemMap);
      final deletedQuote = Quote(
        id: item.id,
        number: item.number,
        date: item.date,
        clientName: item.clientName,
        clientPhone: item.clientPhone,
        clientAddress: item.clientAddress,
        items: item.items,
        total: item.total,
        status: item.status,
        observations: item.observations,
        userId: item.userId,
        syncStatus: 'deleted',
      );
      await _box.put(id, deletedQuote.toMap());
      notifyListeners();

      // Firebase Sync
      await _deleteQuoteFromCloud(id);
    }
  }

  // Cloud syncing helpers
  Future<void> _syncQuoteToCloud(Quote quote) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null && quote.userId == user.uid) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('quotes')
            .doc(quote.id)
            .set(quote.toMap());

        // Update local status to synced if it was pending
        if (quote.syncStatus == 'pending') {
          final syncedQuote = Quote(
            id: quote.id,
            number: quote.number,
            date: quote.date,
            clientName: quote.clientName,
            clientPhone: quote.clientPhone,
            clientAddress: quote.clientAddress,
            items: quote.items,
            total: quote.total,
            status: quote.status,
            observations: quote.observations,
            userId: quote.userId,
            syncStatus: 'synced',
          );
          await _box.put(quote.id, syncedQuote.toMap());
        }
      } catch (e) {
        developer.log("Failed to sync quote to Firestore: $e");
      }
    }
  }

  Future<void> _deleteQuoteFromCloud(String id) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('quotes')
            .doc(id)
            .delete();

        // Remove completely from Hive once deleted on server
        await _box.delete(id);
      } catch (e) {
        developer.log("Failed to delete quote from Firestore: $e");
      }
    }
  }

  // Pull all quotes from Firestore to local Hive
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
          .collection('quotes')
          .get();

      for (var doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['userId'] = user.uid;
        data['syncStatus'] = 'synced';
        await _box.put(doc.id, data);
      }
      notifyListeners();
    } catch (e) {
      developer.log("Failed to download quotes from cloud: $e");
      rethrow;
    }
  }

  // Push all local quotes to Firestore
  Future<void> uploadToCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return;

    final user = auth.currentUser;
    if (user == null) return;

    try {
      final allQuotes = quotes;
      const int batchSize = 500; // Firestore limit per batch is 500

      for (var i = 0; i < allQuotes.length; i += batchSize) {
        final batch = firestore.batch();
        final end = (i + batchSize < allQuotes.length) ? i + batchSize : allQuotes.length;
        final chunk = allQuotes.sublist(i, end);

        for (var quote in chunk) {
          final docRef = firestore
              .collection('users')
              .doc(user.uid)
              .collection('quotes')
              .doc(quote.id);
          batch.set(docRef, quote.toMap());
        }
        await batch.commit();

        for (var quote in chunk) {
          final syncedQuote = Quote(
            id: quote.id,
            number: quote.number,
            date: quote.date,
            clientName: quote.clientName,
            clientPhone: quote.clientPhone,
            clientAddress: quote.clientAddress,
            items: quote.items,
            total: quote.total,
            status: quote.status,
            observations: quote.observations,
            userId: quote.userId,
            syncStatus: 'synced',
          );
          await _box.put(quote.id, syncedQuote.toMap());
        }
      }
    } catch (e) {
      developer.log("Failed to upload quotes to cloud: $e");
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
    final List<Quote> pending = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = Quote.fromMap(value);
        if (item.userId == user.uid && item.syncStatus == 'pending') {
          pending.add(item);
        }
      }
    }
    for (var item in pending) {
      await _syncQuoteToCloud(item);
    }

    // 2. Sync pending deletions
    final List<String> deletedIds = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = Quote.fromMap(value);
        if (item.userId == user.uid && item.syncStatus == 'deleted') {
          deletedIds.add(item.id);
        }
      }
    }
    for (var id in deletedIds) {
      await _deleteQuoteFromCloud(id);
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
        final item = Quote.fromMap(value);
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
    final List<Quote> itemsToTransfer = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        final item = Quote.fromMap(value);
        if (item.userId == 'guest') {
          guestKeys.add(key.toString());
          itemsToTransfer.add(item);
        }
      }
    }
    for (var item in itemsToTransfer) {
      final transferredItem = Quote(
        id: item.id,
        number: item.number,
        date: item.date,
        clientName: item.clientName,
        clientPhone: item.clientPhone,
        clientAddress: item.clientAddress,
        items: item.items,
        total: item.total,
        status: item.status,
        observations: item.observations,
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
        final item = Quote.fromMap(value);
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
