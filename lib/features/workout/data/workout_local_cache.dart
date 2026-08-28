import 'dart:convert';

import 'package:fitmate/features/workout/domain/workout_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class WorkoutLocalCache {
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) {
      return _db!;
    }
    final String dir = (await getApplicationDocumentsDirectory()).path;
    _db = await openDatabase(
      p.join(dir, 'fitmate_outbox.db'),
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          create table set_outbox (
            client_id text primary key,
            session_id text not null,
            payload text not null,
            synced integer not null default 0
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> save(String sessionId, SetLog log) async {
    final Database db = await _open();
    await db.insert(
      'set_outbox',
      <String, Object?>{
        'client_id': log.clientId,
        'session_id': sessionId,
        'payload': jsonEncode(log.toJson(sessionId)),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markSynced(String clientId) async {
    final Database db = await _open();
    await db.update(
      'set_outbox',
      <String, Object?>{'synced': 1},
      where: 'client_id = ?',
      whereArgs: <Object>[clientId],
    );
  }

  Future<List<Map<String, dynamic>>> pending() async {
    final Database db = await _open();
    final List<Map<String, Object?>> rows = await db.query(
      'set_outbox',
      where: 'synced = 0',
    );
    return rows
        .map((Map<String, Object?> row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>)
        .toList();
  }
}
