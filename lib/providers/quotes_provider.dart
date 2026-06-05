import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class QuoteItem {
  final String name;
  final double price;

  QuoteItem({
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }

  factory QuoteItem.fromMap(Map<dynamic, dynamic> map) {
    return QuoteItem(
      name: (map['name'] ?? '') as String,
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0) as double,
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
    );
  }
}

class QuotesProvider extends ChangeNotifier {
  final Box _box = Hive.box('quotes');

  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore => _isFirebaseAvailable ? FirebaseFirestore.instance : null;
  FirebaseAuth? get _auth => _isFirebaseAvailable ? FirebaseAuth.instance : null;

  List<Quote> get quotes {
    final List<Quote> list = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        list.add(Quote.fromMap(value));
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
    await _box.put(quote.id, quote.toMap());
    notifyListeners();

    // Firebase Sync
    await _syncQuoteToCloud(quote);
  }

  Future<void> updateQuoteStatus(String id, String newStatus) async {
    final quoteMap = _box.get(id);
    if (quoteMap is Map) {
      final updatedMap = Map<dynamic, dynamic>.from(quoteMap);
      updatedMap['status'] = newStatus;
      await _box.put(id, updatedMap);
      notifyListeners();

      final updatedQuote = Quote.fromMap(updatedMap);
      await _syncQuoteToCloud(updatedQuote);
    }
  }

  Future<void> deleteQuote(String id) async {
    await _box.delete(id);
    notifyListeners();

    // Firebase Sync
    await _deleteQuoteFromCloud(id);
  }

  // Cloud syncing helpers
  Future<void> _syncQuoteToCloud(Quote quote) async {
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
            .doc(quote.id)
            .set(quote.toMap());
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
        final data = doc.data();
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
      }
    } catch (e) {
      developer.log("Failed to upload quotes to cloud: $e");
      rethrow;
    }
  }
}
