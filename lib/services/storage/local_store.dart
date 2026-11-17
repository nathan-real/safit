import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Petits fichiers JSON dans le dossier privé de l'app (compte, résultats,
/// réglages). Ils restent après la fermeture de l'app.
class LocalStore {
  LocalStore(Future<Directory> directory) : _directory = directory;

  /// Dossier « safit » dans les documents de l'app.
  factory LocalStore.appDocuments() {
    return LocalStore(() async {
      final base = await getApplicationDocumentsDirectory();
      return Directory('${base.path}${Platform.pathSeparator}safit').create(recursive: true);
    }());
  }

  final Future<Directory> _directory;

  Future<Directory> get directory => _directory;

  Future<File> _file(String name) async =>
      File('${(await _directory).path}${Platform.pathSeparator}$name.json');

  /// Contenu du fichier [name], ou null s'il n'existe pas (ou est illisible).
  Future<Object?> read(String name) async {
    final file = await _file(name);
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
  }

  /// Écrit [json] dans le fichier [name]. On écrit d'abord un fichier
  /// temporaire puis on le renomme : un arrêt brutal ne corrompt pas les données.
  Future<void> write(String name, Object? json) async {
    final file = await _file(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
  }

  Future<void> delete(String name) async {
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }
}
