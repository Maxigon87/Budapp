import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../providers/quotes_provider.dart';

class MercadoPagoService {
  static const String _baseUrl = 'https://api.mercadopago.com/checkout/preferences';

  /// Creates a Checkout Preference on Mercado Pago and returns the `init_point` URL.
  static Future<String?> createPaymentPreference({
    required String accessToken,
    required Quote quote,
  }) async {
    if (accessToken.trim().isEmpty) return null;

    try {
      // Calculate discount multiplier to apply directly to each item's unit price
      final double discountMultiplier = 1.0 - (quote.discountPercentage / 100.0);

      // Build items array from quote items
      final List<Map<String, dynamic>> itemsPayload = quote.items.map((item) {
        return {
          'title': item.name,
          'quantity': item.quantity,
          'unit_price': item.price * discountMultiplier,
          'currency_id': 'ARS',
        };
      }).toList();

      final Map<String, dynamic> payer = {
        'name': quote.clientName,
      };

      if (quote.clientPhone.trim().isNotEmpty) {
        payer['phone'] = {
          'number': quote.clientPhone.trim(),
        };
      }

      final body = {
        'items': itemsPayload,
        'external_reference': quote.number.isNotEmpty ? quote.number : quote.id,
        'payer': payer,
        'back_urls': {
          'success': 'https://www.mercadopago.com.ar',
          'failure': 'https://www.mercadopago.com.ar',
          'pending': 'https://www.mercadopago.com.ar',
        },
        'auto_return': 'approved',
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer ${accessToken.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? initPoint = data['init_point'] as String?;
        final String? sandboxInitPoint = data['sandbox_init_point'] as String?;
        
        // Return init_point or fallback to sandbox_init_point
        return initPoint ?? sandboxInitPoint;
      } else {
        debugPrint('Mercado Pago Preference Error [${response.statusCode}]: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception while creating Mercado Pago Preference: $e');
      return null;
    }
  }
}
