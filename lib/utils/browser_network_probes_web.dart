import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> probeFetch(String url) async {
  final response = await web.window
      .fetch(url.toJS, web.RequestInit(mode: 'no-cors', cache: 'no-store'))
      .toDart;
  return 'type=${response.type} status=${response.status}';
}

const _dbName = 'parkour-spot-diagnostics';
const _storeName = 'probe';

Future<String> probeIndexedDb() {
  final completer = Completer<String>();
  final request = web.window.indexedDB.open(_dbName, 1);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains(_storeName)) {
      db.createObjectStore(_storeName);
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!completer.isCompleted) completer.completeError('open blocked');
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError('open failed: ${request.error?.message}');
    }
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    try {
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      tx
          .objectStore(_storeName)
          .put(DateTime.now().toUtc().toIso8601String().toJS, 'lastProbe'.toJS);
      tx.oncomplete = ((web.Event _) {
        db.close();
        if (!completer.isCompleted) completer.complete('write ok');
      }).toJS;
      tx.onerror = ((web.Event _) {
        db.close();
        if (!completer.isCompleted) {
          completer.completeError('write failed: ${tx.error?.message}');
        }
      }).toJS;
      tx.onabort = ((web.Event _) {
        db.close();
        if (!completer.isCompleted) {
          completer.completeError('write aborted: ${tx.error?.message}');
        }
      }).toJS;
    } catch (e) {
      db.close();
      if (!completer.isCompleted) completer.completeError('transaction: $e');
    }
  }).toJS;
  return completer.future;
}
