import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/core/printing/label_printer.dart';
import 'package:labelhub/features/printing/data/printer_profile_repository.dart';

void main() {
  late AppDatabase database;
  late PrinterProfileRepository repository;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
    repository = PrinterProfileRepository(database);
  });

  tearDown(() => database.close());

  test(
    'stores a named network printer profile for direct ZPL printing',
    () async {
      await repository.saveNetwork(
        id: 'warehouse-zebra',
        name: 'Warehouse Zebra',
        host: '192.168.1.25',
        port: 9100,
        protocol: PrinterProtocol.zpl,
      );

      final profiles = await repository.list();

      expect(profiles, hasLength(1));
      expect(profiles.single.name, 'Warehouse Zebra');
      expect(profiles.single.protocol, PrinterProtocol.zpl);
      expect(profiles.single.toDevice().id, 'network:192.168.1.25:9100');
    },
  );

  test('rejects an invalid TCP port', () async {
    await expectLater(
      repository.saveNetwork(
        id: 'invalid-port',
        name: 'Invalid printer',
        host: 'printer.local',
        port: 70000,
        protocol: PrinterProtocol.tspl,
      ),
      throwsA(isA<PrinterProfileException>()),
    );
  });
}
