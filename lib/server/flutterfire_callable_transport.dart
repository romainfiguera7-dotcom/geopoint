// Les paramètres publics `functions` et `callableInvoker` sont conservés pour
// les tests et les intégrations, tandis que les champs restent privés.
// ignore_for_file: prefer_initializing_formals

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_callable_gateway.dart';

typedef FlutterFireCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> data,
);
typedef FlutterFireAuthenticationRefresh = Future<void> Function();
typedef FlutterFireAuthenticationErrorTest = bool Function(Object error);

/// Transport réel entre les contrats GeoPoint et les fonctions callable.
class FlutterFireCallableTransport implements GeoPointCallableTransport {
  FlutterFireCallableTransport({
    FirebaseFunctions? functions,
    this.timeout = const Duration(seconds: 20),
    FlutterFireCallableInvoker? callableInvoker,
    FlutterFireAuthenticationRefresh? refreshAuthentication,
    FlutterFireAuthenticationErrorTest? authenticationErrorTest,
  }) : _functions = functions,
       _callableInvoker = callableInvoker,
       _refreshAuthentication =
           refreshAuthentication ?? _refreshFirebaseTokens,
       _authenticationErrorTest =
           authenticationErrorTest ?? _isUnauthenticatedError;

  final FirebaseFunctions? _functions;
  final Duration timeout;
  final FlutterFireCallableInvoker? _callableInvoker;
  final FlutterFireAuthenticationRefresh _refreshAuthentication;
  final FlutterFireAuthenticationErrorTest _authenticationErrorTest;

  @override
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    Object? response;
    try {
      if (functionName.startsWith('admin') ||
          functionName == 'getAdminControlDashboard') {
        await _refreshAuthentication();
      }
      response = await _invoke(functionName, data);
    } catch (error) {
      if (!_authenticationErrorTest(error)) {
        rethrow;
      }
      debugPrint(
        'GeoPoint Firebase : jeton expiré, renouvellement avant une nouvelle '
        'tentative de $functionName.',
      );
      await _refreshAuthentication();
      response = await _invoke(functionName, data);
    }
    return normalizeResponse(response);
  }

  Future<Object?> _invoke(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final FlutterFireCallableInvoker? callableInvoker = _callableInvoker;
    if (callableInvoker != null) {
      return callableInvoker(functionName, data);
    }
    final FirebaseFunctions functions = _functions ??
        FirebaseFunctions.instanceFor(region: 'europe-west1');
    final HttpsCallable callable = functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final HttpsCallableResult<dynamic> result =
        await callable.call<dynamic>(data);
    return result.data;
  }

  static bool _isUnauthenticatedError(Object error) {
    return error is FirebaseFunctionsException &&
        error.code == 'unauthenticated';
  }

  static Future<void> _refreshFirebaseTokens() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'La session Firebase du joueur a été perdue.',
      );
    }
    await user.getIdToken(true);
    await FirebaseAppCheck.instance.getToken(true);
  }

  static Map<String, dynamic> normalizeResponse(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'La fonction Firebase a renvoyé une réponse invalide.',
      );
    }
    return value.map<String, dynamic>(
      (dynamic key, dynamic item) =>
          MapEntry<String, dynamic>(key.toString(), item),
    );
  }
}
