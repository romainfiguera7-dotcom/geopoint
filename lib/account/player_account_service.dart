import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../server/flutterfire_callable_transport.dart';

enum PlayerAccountKind { guest, google, email }

class PlayerAccountSnapshot {
  const PlayerAccountSnapshot({
    required this.kind,
    required this.uid,
    this.email,
  });

  final PlayerAccountKind kind;
  final String uid;
  final String? email;

  bool get isGuest => kind == PlayerAccountKind.guest;
}

/// Gère les méthodes de connexion sans toucher aux sauvegardes locales.
/// Lorsqu'un invité choisit un compte, les identifiants sont liés à son UID
/// Firebase actuel afin de conserver la continuité de sa progression.
class PlayerAccountService {
  PlayerAccountService._();

  static final PlayerAccountService instance = PlayerAccountService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleInitialized = false;

  Stream<User?> get changes => _auth.userChanges();

  PlayerAccountSnapshot get snapshot {
    final User? user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return PlayerAccountSnapshot(
        kind: PlayerAccountKind.guest,
        uid: user?.uid ?? '',
      );
    }
    final bool usesGoogle = user.providerData.any(
      (UserInfo item) => item.providerId == 'google.com',
    );
    return PlayerAccountSnapshot(
      kind: usesGoogle ? PlayerAccountKind.google : PlayerAccountKind.email,
      uid: user.uid,
      email: user.email,
    );
  }

  Future<bool> isAdministrator({bool forceRefresh = false}) async {
    final User? user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return false;
    }
    final IdTokenResult token = await user.getIdTokenResult(forceRefresh);
    return token.claims?['admin'] == true;
  }

  Future<void> signInWithGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();
    final GoogleSignInAuthentication authentication =
        googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );
    await _linkOrSignIn(credential);
  }

  Future<void> createEmailAccount({
    required String email,
    required String password,
  }) async {
    final AuthCredential credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await _linkOrSignIn(credential);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOutToGuest() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Aucun compte Google initialisé : la déconnexion Firebase suffit.
    }
    await _auth.signInAnonymously();
  }

  /// Supprime les données distantes et l'identifiant Firebase courant, puis
  /// recrée une session invitée vide pour que l'application reste utilisable.
  Future<void> deleteAccountAndData() async {
    await FlutterFireCallableTransport(
      timeout: const Duration(seconds: 60),
    ).call(
      'deletePlayerAccount',
      const <String, dynamic>{'apiVersion': 1},
    );
    try {
      await GoogleSignIn.instance.signOut();
    } on Object {
      // La suppression Firebase a réussi : l'absence de session Google locale
      // ne doit pas empêcher de recréer une session invitée.
    }
    await _auth.signOut();
    await _auth.signInAnonymously();
  }

  Future<void> _linkOrSignIn(AuthCredential credential) async {
    final User? current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithCredential(credential);
        return;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'email-already-in-use') {
          rethrow;
        }
      }
    }
    await _auth.signInWithCredential(credential);
  }
}
