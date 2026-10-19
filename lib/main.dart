import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/permissions/permission_providers.dart';
import 'core/permissions/permission_service_impl.dart';
import 'features/shopping_list/presentation/shopping_list_providers.dart';
import 'features/stores/application/store_seeder.dart';
import 'features/stores/data/datasources/store_local_datasource.dart';
import 'features/stores/data/datasources/store_seed_loader.dart';
import 'features/stores/data/repositories/store_repository_impl.dart';

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'daijo.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();

  // 매장 시드 1회 적재(버전 플래그 기반). 실패해도 앱은 계속 동작.
  await StoreSeeder(
    loader: StoreSeedLoader(rootBundle),
    repository: StoreRepositoryImpl(StoreLocalDataSource(db)),
    db: db,
  ).ensureSeeded();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        permissionServiceProvider.overrideWithValue(
          const PermissionHandlerService(),
        ),
      ],
      child: const DaijoApp(),
    ),
  );
}
