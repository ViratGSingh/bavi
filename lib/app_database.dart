import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:bavi/tables/tabs.dart';
import 'package:uuid/uuid.dart'; // 👈 make sure this matches your actual file name

part 'app_database.g.dart';

@DriftDatabase(tables: [Tabs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tabs.sqlite'));
    return NativeDatabase(file);
  });
}