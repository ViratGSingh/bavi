import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Tabs extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // optional if you want unique IDs
  TextColumn get title => text().nullable()();
  TextColumn get url => text()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isIncognito => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}