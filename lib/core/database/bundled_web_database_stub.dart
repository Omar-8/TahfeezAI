import 'package:drift/drift.dart';

/// Native: the ready-made databases are files put in place at the start
/// (`BundledDatabaseInstaller`), opened like any other.
QueryExecutor? openBundledWebDatabase(String name) => null;

/// Native: nothing to tidy.
Future<void> deleteStaleBundledWebDatabases() async {}
