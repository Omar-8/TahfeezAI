import '../../domain/dataset_integrity.dart';

/// Thrown by [QuranDatasetImporter] when a candidate dataset fails
/// [DatasetIntegrityValidator] validation. Carries the full [report] so
/// callers (a future dataset-management UI, or a test) can show/assert on
/// every failure, not just the first one — this is what makes integrity
/// failures "fail loudly" per this milestone's Definition of Done, rather
/// than silently importing bad data or reporting only a generic error.
class DatasetIntegrityException implements Exception {
  const DatasetIntegrityException(this.report);

  final DatasetIntegrityReport report;

  @override
  String toString() {
    final lines = report.errors.map((e) => '  - $e').join('\n');
    return 'DatasetIntegrityException: dataset failed validation with '
        '${report.errors.length} error(s):\n$lines';
  }
}
