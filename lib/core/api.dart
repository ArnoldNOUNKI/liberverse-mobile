// Client HTTP de l'API Liberverse : même serveur que le site (session par cookie HttpOnly, conservée sur l'appareil).
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';

/// Adresse du serveur. Changer avec : flutter run --dart-define=LIBERVERSE_URL=https://staging.liberverse.fr
const String _kUrl = String.fromEnvironment('LIBERVERSE_URL', defaultValue: 'https://liberverse.fr');
// Version web (aperçu servi par le même serveur) : même origine, cookies gérés par le navigateur
final String kBaseUrl = kIsWeb && _kUrl == 'https://liberverse.fr' ? Uri.base.origin : _kUrl;

class ApiError implements Exception {
  final int status;
  final String message;
  final bool upgrade;
  ApiError(this.status, this.message, {this.upgrade = false});
  @override
  String toString() => message;
}

class Api {
  Api._();
  static final Api I = Api._();

  late final Dio _dio;
  PersistCookieJar? _jar;

  /// Appelé quand le serveur répond 401 (session expirée) : l'app revient à l'accueil.
  void Function()? onUnauthorized;

  Future<void> init() async {
    _dio = Dio(BaseOptions(
      baseUrl: '$kBaseUrl/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json', 'X-Client': 'liberverse-flutter'},
      validateStatus: (_) => true,
    ));
    if (!kIsWeb) {
      final dir = await getApplicationSupportDirectory();
      _jar = PersistCookieJar(storage: FileStorage('${dir.path}/cookies/'));
      _dio.interceptors.add(CookieManager(_jar!));
    }
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, dynamic>? query, bool auth401 = true}) async {
    Response r;
    try {
      r = await _dio.request(path, data: body, queryParameters: query, options: Options(method: method));
    } on DioException catch (e) {
      throw ApiError(0, e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout
          ? 'Connexion impossible. Vérifiez votre accès à Internet.'
          : 'Erreur réseau');
    }
    final data = r.data;
    final code = r.statusCode ?? 0;
    if (code == 401 && auth401) onUnauthorized?.call();
    if (code >= 400) {
      final msg = data is Map && data['error'] != null ? data['error'].toString() : 'Erreur';
      throw ApiError(code, msg, upgrade: data is Map && data['upgrade'] == true);
    }
    return data;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth401 = true}) => _send('GET', path, query: query, auth401: auth401);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body ?? {});
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body ?? {});
  Future<dynamic> delete(String path, [Object? body]) => _send('DELETE', path, body: body);

  /// Envoi d'un fichier (photo, selfie, pièce jointe) — champ « file » comme sur le site.
  Future<dynamic> upload(String path, XFile file, {Map<String, String> fields = const {}}) async {
    final form = FormData.fromMap({
      ...fields,
      'file': MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name.isEmpty ? 'photo.jpg' : file.name),
    });
    return _send('POST', path, body: form);
  }

  /// Fichier JSON public hors /api (dictionnaires de traduction).
  Future<dynamic> getPublic(String path) async {
    final r = await Dio(BaseOptions(baseUrl: kBaseUrl, validateStatus: (_) => true)).get(path);
    return (r.statusCode ?? 500) < 400 ? r.data : null;
  }

  /// Photos protégées (/media/:id) : l'image doit être demandée avec le cookie de session.
  // id de média, ou chemin absolu (avatar illustré : /media/avatar/<uid>/<v>)
  String mediaUrl(String? id) => id == null ? '' : id.startsWith('/') ? '$kBaseUrl$id' : '$kBaseUrl/media/$id';
  Future<Map<String, String>> mediaHeaders() async {
    if (_jar == null) return {};
    final cookies = await _jar!.loadForRequest(Uri.parse(kBaseUrl));
    return {'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; ')};
  }

  Future<void> clearSession() async => _jar?.deleteAll();
}
