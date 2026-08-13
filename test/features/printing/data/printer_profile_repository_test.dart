import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/features/printing/data/printer_profile_repository.dart';

void main() {
  late AppDatabase database;
  late PrinterProfileRepository repository;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
    repository = PrinterProfileRepository(database);
  });

  tearDown(() => database.close());

  test('stores a paired Bluetooth barcode printer profile', () async {
    await repository.saveProfile(
      id: 'stockroom-bluetooth',
      name: 'Stockroom label printer',
      address: 'AA:BB:CC:DD:EE:FF',
    );

    final profile = (await repository.list()).single;

    expect(profile.name, 'Stockroom label printer');
    expect(profile.toDevice().id, 'AA:BB:CC:DD:EE:FF#tspl');
  });

  test('rejects an invalid Bluetooth address', () async {
    await expectLater(
      repository.saveProfile(
        id: 'invalid-address',
        name: 'Invalid printer',
        address: 'not-an-address',
      ),
      throwsA(isA<PrinterProfileException>()),
    );
  });

  test('persists and clears the default printer profile', () async {
    await repository.saveProfile(
      id: 'warehouse-zywell',
      name: 'Warehouse ZYWELL',
      address: 'AA:BB:CC:DD:EE:FF',
    );

    await repository.setDefault('warehouse-zywell');

    expect(await repository.defaultProfileId(), 'warehouse-zywell');

    await repository.delete('warehouse-zywell');

    expect(await repository.defaultProfileId(), isNull);
  });
}
