import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:fitmate/core/local/outbox_op.dart';
import 'package:fitmate/core/local/snapshot_keys.dart';

class LocalStore {
  Database? _db;
  Future<void>? _opening;

  Future<void> ensureReady() {
    return _opening ??= _open();
  }

  Future<void> _open() async {
    final String dir = (await getApplicationDocumentsDirectory()).path;
    _db = await openDatabase(
      p.join(dir, 'fitmate_outbox.db'),
      version: 2,
      onCreate: (Database db, int version) async {
        await _createV2(db);
      },
      onUpgrade: (Database db, int from, int to) async {
        if (from < 2) {
          await _createV2(db);
          await _migrateSetOutbox(db);
        }
      },
    );
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      create table if not exists snapshots (
        key text primary key,
        value text not null,
        updated_at integer not null
      )
    ''');
    await db.execute('''
      create table if not exists outbox (
        id text primary key,
        type text not null,
        entity text not null,
        payload text not null,
        created_at integer not null,
        attempts integer not null default 0,
        last_error text
      )
    ''');
    await db.execute('''
      create table if not exists set_logs (
        client_id text primary key,
        session_id text not null,
        workout_exercise_id text not null,
        payload text not null,
        completed integer not null default 0,
        completed_at integer
      )
    ''');
    await db.execute('''
      create table if not exists sessions (
        id text primary key,
        payload text not null,
        status text not null,
        started_at integer not null
      )
    ''');
  }

  Future<void> _migrateSetOutbox(Database db) async {
    try {
      final List<Map<String, Object?>> rows = await db.query('set_outbox', where: 'synced = 0');
      for (final Map<String, Object?> row in rows) {
        final String clientId = row['client_id'] as String;
        final String sessionId = row['session_id'] as String;
        final String payload = row['payload'] as String;
        await db.insert(
          'outbox',
          <String, Object?>{
            'id': clientId,
            'type': OutboxType.upsertSetLog,
            'entity': SnapshotKeys.setLogs,
            'payload': jsonEncode(<String, dynamic>{
              'session_id': sessionId,
              'row': jsonDecode(payload),
            }),
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'attempts': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await db.insert(
          'set_logs',
          <String, Object?>{
            'client_id': clientId,
            'session_id': sessionId,
            'workout_exercise_id': (jsonDecode(payload) as Map)['workout_exercise_id'] as String? ?? '',
            'payload': payload,
            'completed': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {
      // v1 table may not exist on a fresh install that jumped to v2.
    }
  }

  Future<Database> get _database async {
    await ensureReady();
    return _db!;
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'snapshots',
      where: 'key = ?',
      whereArgs: <Object>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
  }

  Future<List<dynamic>?> getList(String key) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'snapshots',
      where: 'key = ?',
      whereArgs: <Object>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return jsonDecode(rows.first['value'] as String) as List<dynamic>;
  }

  Future<void> setJson(String key, Map<String, dynamic>? value) async {
    if (value == null) {
      await deleteSnapshot(key);
      return;
    }
    final Database db = await _database;
    await db.insert(
      'snapshots',
      <String, Object?>{
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setList(String key, List<dynamic> value) async {
    final Database db = await _database;
    await db.insert(
      'snapshots',
      <String, Object?>{
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSnapshot(String key) async {
    final Database db = await _database;
    await db.delete('snapshots', where: 'key = ?', whereArgs: <Object>[key]);
  }

  Future<String> enqueue({
    required String type,
    required String entity,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    final Database db = await _database;
    final String opId = id ?? const Uuid().v4();
    await db.insert(
      'outbox',
      <String, Object?>{
        'id': opId,
        'type': type,
        'entity': entity,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'attempts': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return opId;
  }

  Future<List<OutboxOp>> pending() async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query('outbox', orderBy: 'created_at asc');
    return rows.map(_opFromRow).toList();
  }

  Future<int> pendingCount() async {
    final Database db = await _database;
    final int? count = Sqflite.firstIntValue(await db.rawQuery('select count(*) from outbox'));
    return count ?? 0;
  }

  Future<DateTime?> oldestPendingAt() async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'outbox',
      columns: <String>['created_at'],
      orderBy: 'created_at asc',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(rows.first['created_at'] as int);
  }

  Future<bool> isDirty(String entity) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'outbox',
      columns: <String>['id'],
      where: 'entity = ?',
      whereArgs: <Object>[entity],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> remove(String id) async {
    final Database db = await _database;
    await db.delete('outbox', where: 'id = ?', whereArgs: <Object>[id]);
  }

  Future<void> markError(String id, String error) async {
    final Database db = await _database;
    await db.rawUpdate(
      'update outbox set attempts = attempts + 1, last_error = ? where id = ?',
      <Object>[error, id],
    );
  }

  Future<void> saveSetLog(String sessionId, Map<String, dynamic> row) async {
    final Database db = await _database;
    await db.insert(
      'set_logs',
      <String, Object?>{
        'client_id': row['client_id'] as String,
        'session_id': sessionId,
        'workout_exercise_id': row['workout_exercise_id'] as String? ?? '',
        'payload': jsonEncode(row),
        'completed': (row['completed'] as bool? ?? false) ? 1 : 0,
        'completed_at': row['completed_at'] == null
            ? null
            : DateTime.tryParse(row['completed_at'] as String)?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> setLogsForExercise(String workoutExerciseId) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'set_logs',
      where: 'workout_exercise_id = ? and completed = 1',
      whereArgs: <Object>[workoutExerciseId],
      orderBy: 'completed_at desc',
      limit: 12,
    );
    return rows
        .map((Map<String, Object?> row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>?> sessionById(String id) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<void> saveSession(Map<String, dynamic> row) async {
    final Database db = await _database;
    final DateTime started = DateTime.tryParse(row['started_at'] as String? ?? '') ?? DateTime.now();
    await db.insert(
      'sessions',
      <String, Object?>{
        'id': row['id'] as String,
        'payload': jsonEncode(row),
        'status': row['status'] as String? ?? 'in_progress',
        'started_at': started.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> completedSessions({int limit = 30}) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'sessions',
      where: 'status = ?',
      whereArgs: <Object>['completed'],
      orderBy: 'started_at desc',
      limit: limit,
    );
    return rows
        .map((Map<String, Object?> row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> replaceSetLogs(List<Map<String, dynamic>> rows) async {
    final Database db = await _database;
    final Batch batch = db.batch();
    batch.delete('set_logs');
    for (final Map<String, dynamic> row in rows) {
      batch.insert(
        'set_logs',
        <String, Object?>{
          'client_id': row['client_id'] as String? ?? row['id'] as String,
          'session_id': row['session_id'] as String? ?? '',
          'workout_exercise_id': row['workout_exercise_id'] as String? ?? '',
          'payload': jsonEncode(row),
          'completed': (row['completed'] as bool? ?? false) ? 1 : 0,
          'completed_at': row['completed_at'] == null
              ? null
              : DateTime.tryParse(row['completed_at'] as String)?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceSessions(List<Map<String, dynamic>> rows) async {
    final Database db = await _database;
    final Batch batch = db.batch();
    batch.delete('sessions');
    for (final Map<String, dynamic> row in rows) {
      final DateTime started = DateTime.tryParse(row['started_at'] as String? ?? '') ?? DateTime.now();
      batch.insert(
        'sessions',
        <String, Object?>{
          'id': row['id'] as String,
          'payload': jsonEncode(row),
          'status': row['status'] as String? ?? 'completed',
          'started_at': started.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clear() async {
    final Database db = await _database;
    await db.delete('snapshots');
    await db.delete('outbox');
    await db.delete('set_logs');
    await db.delete('sessions');
  }

  OutboxOp _opFromRow(Map<String, Object?> row) {
    return OutboxOp(
      id: row['id'] as String,
      type: row['type'] as String,
      entity: row['entity'] as String,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      attempts: row['attempts'] as int? ?? 0,
      lastError: row['last_error'] as String?,
    );
  }
}
