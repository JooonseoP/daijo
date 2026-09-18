import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daijo/features/shopping_list/presentation/app_version_provider.dart';

void main() {
  test('appVersionProvider can be overridden with a fixed version', () async {
    final container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWith((ref) async => '9.9.9'),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(appVersionProvider.future), '9.9.9');
  });
}
