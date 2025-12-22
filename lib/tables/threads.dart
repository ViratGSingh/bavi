import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Threads extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get sessionData => text()(); // Serialized ThreadSessionData JSON
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
