import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/store.dart';

Store storeFromRow(StoreRow row) => Store(
      id: row.id,
      name: row.name,
      latitude: row.latitude,
      longitude: row.longitude,
      radius: row.radius,
    );

StoresCompanion storeToCompanion(Store s) => StoresCompanion(
      id: Value(s.id),
      name: Value(s.name),
      latitude: Value(s.latitude),
      longitude: Value(s.longitude),
      radius: Value(s.radius),
    );
