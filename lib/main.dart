import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/permissions/permission_providers.dart';
import 'core/permissions/permission_service_impl.dart';
import 'features/shopping_list/presentation/shopping_list_providers.dart';

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'daijo.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();

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
