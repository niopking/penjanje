import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? currentUser;

  Future<AuthResult> login(String username, String password) async {
    try {
      if (username.trim().isEmpty || password.trim().isEmpty) {
        return AuthResult(
          success: false,
          message: 'Molimo unesite korisničko ime i lozinku.',
        );
      }

      final QuerySnapshot result = await _firestore
          .collection('korisnici')
          .where('username', isEqualTo: username.trim())
          .where('password', isEqualTo: password.trim())
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Pogrešno korisničko ime ili lozinka.',
        );
      }

      final doc = result.docs.first;
      currentUser = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};

      return AuthResult(success: true, message: 'Uspješna prijava!');
    } on FirebaseException catch (e) {
      return AuthResult(success: false, message: 'Greška: ${e.message}');
    } catch (e) {
      return AuthResult(
          success: false, message: 'Neočekivana greška. Pokušajte ponovo.');
    }
  }

  void logout() => currentUser = null;
}

class AuthResult {
  final bool success;
  final String message;

  AuthResult({required this.success, required this.message});
}