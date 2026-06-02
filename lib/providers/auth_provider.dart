import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseAuth? get _auth => _isFirebaseAvailable ? FirebaseAuth.instance : null;

  User? _user;
  bool _isLoading = false;

  AuthProvider() {
    _initListener();
  }

  void _initListener() {
    final auth = _auth;
    if (auth != null) {
      auth.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    }
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<String?> signIn(String email, String password) async {
    final auth = _auth;
    if (auth == null) return "El servicio de nube no está configurado.";

    _isLoading = true;
    notifyListeners();
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _getFriendlyErrorMessage(e.code);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password) async {
    final auth = _auth;
    if (auth == null) return "El servicio de nube no está configurado.";

    _isLoading = true;
    notifyListeners();
    try {
      await auth.createUserWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _getFriendlyErrorMessage(e.code);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth != null) {
      await auth.signOut();
    }
    _user = null;
    notifyListeners();
  }

  String _getFriendlyErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Este usuario ha sido deshabilitado.';
      case 'user-not-found':
        return 'No se encontró ningún usuario con este correo electrónico.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Este correo electrónico ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'operation-not-allowed':
        return 'La operación no está permitida.';
      default:
        return 'Ocurrió un error de autenticación: $code';
    }
  }
}
