import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_provider.dart';
import '../features/printing/data/printer_profile_repository.dart';
import '../features/printing/domain/entities/printer_profile.dart';

/// Supplies the configured default printer to the application shell.
final activePrinterProfileProvider = FutureProvider<PrinterProfile?>(
  (Ref ref) async {
    final database = await ref.watch(appDatabaseProvider.future);
    final repository = PrinterProfileRepository(database);
    final results = await Future.wait<Object?>(<Future<Object?>>[
      repository.list(),
      repository.defaultProfileId(),
    ]);
    final profiles = results[0]! as List<PrinterProfile>;
    final defaultProfileId = results[1] as String?;
    if (defaultProfileId == null) {
      return null;
    }
    return profiles
        .where((PrinterProfile profile) => profile.id == defaultProfileId)
        .firstOrNull;
  },
);
