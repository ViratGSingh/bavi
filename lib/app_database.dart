import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:bavi/tables/tabs.dart';
import 'package:bavi/tables/threads.dart';
import 'package:uuid/uuid.dart'; // 👈 make sure this matches your actual file name

part 'app_database.g.dart';

@DriftDatabase(tables: [Tabs, Threads])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() => _instance;

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  // ✅ Get all saved tabs
  Future<List<Tab>> getAllTabs() => select(tabs).get();

  // ✅ Insert a new tab
  Future<int> insertTab(TabsCompanion tab) => into(tabs).insert(tab);

  // ✅ Delete a tab by ID
  Future<void> deleteTab(String id) async {
    await (delete(tabs)..where((t) => t.id.equals(id))).go();
  }

  // ✅ Update tab data (title, url, imagePath, updatedAt, etc.)
  Future<void> updateTab(String id, TabsCompanion updated) async {
    await (update(tabs)..where((t) => t.id.equals(id))).write(updated);
  }

  // --- Threads (Offline History) ---

  // ✅ Get all threads ordered by updatedAt descending
  Future<List<Thread>> getAllThreads() => (select(threads)
        ..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
        ]))
      .get();

  // ✅ Insert a new thread
  Future<int> insertThread(ThreadsCompanion thread) =>
      into(threads).insert(thread);

  // ✅ Update an existing thread
  Future<void> updateThread(String id, ThreadsCompanion thread) async {
    await (update(threads)..where((t) => t.id.equals(id))).write(thread);
  }

  // ✅ Get a thread by ID
  Future<Thread?> getThreadById(String id) =>
      (select(threads)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ✅ Delete a thread by ID
  Future<void> deleteThread(String id) async {
    await (delete(threads)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tabs.sqlite'));
    return NativeDatabase(file);
  });
}
