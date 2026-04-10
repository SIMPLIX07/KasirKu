import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalImageStore {
  LocalImageStore._();

  static final LocalImageStore instance = LocalImageStore._();

  static const String _databaseName = 'kasirku_images.db';
  static const String _tableName = 'image_cache';

  Database? _database;

  Future<Database> _openDatabase() async {
    final cached = _database;
    if (cached != null) {
      return cached;
    }

    final directory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(directory.path, _databaseName);

    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_tableName ('
          'cacheKey TEXT PRIMARY KEY, '
          'ownerId TEXT NOT NULL, '
          'recordType TEXT NOT NULL, '
          'localPath TEXT NOT NULL, '
          'createdAt INTEGER NOT NULL'
          ')',
        );
      },
    );

    _database = database;
    return database;
  }

  Future<String?> saveImageCopy({
    required File sourceFile,
    required String ownerId,
    required String recordType,
    required String recordId,
    required String filePrefix,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final safeOwnerId = _sanitizeSegment(ownerId);
      final safeRecordType = _sanitizeSegment(recordType);
      final safeRecordId = _sanitizeSegment(recordId);
      final targetDirectory = Directory(
        p.join(
          directory.path,
          'kasirku_images',
          safeOwnerId,
          safeRecordType,
          safeRecordId,
        ),
      );
      await targetDirectory.create(recursive: true);

      final extension = p.extension(sourceFile.path).trim();
      final safeExtension = extension.isNotEmpty ? extension : '.jpg';
      final fileName =
          '${_sanitizeSegment(filePrefix)}_${DateTime.now().millisecondsSinceEpoch}$safeExtension';
      final targetFile = await sourceFile.copy(
        p.join(targetDirectory.path, fileName),
      );

      final cacheKey = '$safeOwnerId:$safeRecordType:$safeRecordId';
      final database = await _openDatabase();
      final existing = await database.query(
        _tableName,
        columns: const ['localPath'],
        where: 'cacheKey = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final previousPath = existing.first['localPath'] as String?;
        if (previousPath != null &&
            previousPath.isNotEmpty &&
            previousPath != targetFile.path) {
          final previousFile = File(previousPath);
          if (await previousFile.exists()) {
            await previousFile.delete();
          }
        }
      }

      await database.insert(_tableName, <String, dynamic>{
        'cacheKey': cacheKey,
        'ownerId': safeOwnerId,
        'recordType': safeRecordType,
        'localPath': targetFile.path,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return targetFile.path;
    } catch (e) {
      debugPrint('[LOCAL_IMAGE_STORE_ERROR] $e');
      return null;
    }
  }

  String _sanitizeSegment(String raw) {
    final trimmed = raw.trim();
    final normalized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.isEmpty ? 'item' : collapsed;
  }
}

bool isRemoteImageSource(String source) {
  final uri = Uri.tryParse(source.trim());
  if (uri == null) {
    return false;
  }
  return uri.scheme == 'http' || uri.scheme == 'https';
}

Widget buildStoredImage(
  String source, {
  required Widget Function() fallback,
  BoxFit fit = BoxFit.cover,
}) {
  final normalizedSource = source.trim();
  if (normalizedSource.isEmpty) {
    return fallback();
  }

  if (isRemoteImageSource(normalizedSource)) {
    return Image.network(
      normalizedSource,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }

  final file = File(normalizedSource);
  if (file.existsSync()) {
    return Image.file(file, fit: fit, errorBuilder: (_, __, ___) => fallback());
  }

  return fallback();
}
