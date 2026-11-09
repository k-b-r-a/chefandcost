import 'dart:typed_data';
import 'sqlite_validator_stub.dart'
    if (dart.library.io) 'sqlite_validator_io.dart';

Future<bool> validateSqliteIntegrity(Uint8List bytes) =>
    validateSqliteIntegrityPlatform(bytes);
