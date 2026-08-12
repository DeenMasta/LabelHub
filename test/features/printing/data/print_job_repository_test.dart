import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/database/app_database.dart';
import 'package:labelhub/features/printing/data/print_job_repository.dart';

void main() {
  late AppDatabase database;
  late PrintJobRepository repository;

  setUp(() async {
    database = await AppDatabase.openForTesting(NativeDatabase.memory());
    repository = PrintJobRepository(database);
  });

  tearDown(() => database.close());

  test('stores completed and failed print jobs locally', () async {
    await repository.create(
      id: 'job-completed',
      printerName: 'Warehouse Zebra',
      labelLayoutId: 'product-label-58x40',
      recordCount: 2,
      copies: 3,
    );
    await repository.markCompleted('job-completed');
    await repository.create(
      id: 'job-failed',
      printerName: 'Warehouse Zebra',
      labelLayoutId: 'product-label-58x40',
      recordCount: 1,
      copies: 1,
    );
    await repository.markFailed('job-failed', 'System service unavailable');

    final jobs = await repository.listRecent();
    final completed = jobs.singleWhere((job) => job.id == 'job-completed');
    final failed = jobs.singleWhere((job) => job.id == 'job-failed');

    expect(completed.isCompleted, isTrue);
    expect(completed.labelCount, 6);
    expect(completed.completedAt, isNotNull);
    expect(failed.isCompleted, isFalse);
    expect(failed.errorMessage, 'System service unavailable');
  });
}
