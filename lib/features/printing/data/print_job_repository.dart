import '../../../core/database/app_database.dart';
import '../domain/entities/print_job.dart';

/// Owns local persistence for print-job history.
class PrintJobRepository {
  PrintJobRepository(this._database);

  final AppDatabase _database;

  Future<void> create({
    required String id,
    required String printerName,
    required String labelLayoutId,
    required int recordCount,
    required int copies,
  }) {
    return _database.savePrintJob(
      id: id,
      printerName: printerName,
      labelLayoutId: labelLayoutId,
      recordCount: recordCount,
      copies: copies,
      status: 'pending',
    );
  }

  Future<void> markCompleted(String id) {
    return _database.completePrintJob(id: id, status: 'completed');
  }

  Future<void> markFailed(String id, String errorMessage) {
    return _database.completePrintJob(
      id: id,
      status: 'failed',
      errorMessage: errorMessage,
    );
  }

  Future<List<PrintJob>> listRecent() async {
    final jobs = await _database.printJobs();
    return jobs
        .map(
          (DatabasePrintJob job) => PrintJob(
            id: job.id,
            printerName: job.printerName,
            labelLayoutId: job.labelLayoutId,
            recordCount: job.recordCount,
            copies: job.copies,
            status: job.status,
            createdAt: job.createdAt,
            completedAt: job.completedAt,
            errorMessage: job.errorMessage,
          ),
        )
        .toList();
  }
}
