// lib/shared/config/environment_config.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static final EnvironmentConfig _instance = EnvironmentConfig._internal();
  factory EnvironmentConfig() => _instance;
  EnvironmentConfig._internal();

  bool _isInitialized = false;
  bool _isDevelopment = false;
  String _databaseId = '';
  String _storageBucket = '';

  /// Verifica se siamo in ambiente di sviluppo
  bool get isDevelopment => _isDevelopment;

  /// ID del database Firestore corrente
  String get databaseId => _databaseId;

  /// Bucket di storage corrente
  String get storageBucket => _storageBucket;

  /// Inizializza la configurazione dell'ambiente
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ EnvironmentConfig già inizializzato');
      return;
    }

    try {
      // In kDebugMode, forza sempre l'uso del database di sviluppo
      if (kDebugMode) {
        _isDevelopment = true;
        _databaseId = 'longeviva-web-app-dev-sviluppo';
        _storageBucket = 'longeviva-web-app-dev-sviluppo';
        debugPrint('🔧 DEBUG MODE: Forzato ambiente di SVILUPPO');
      } else {
        // In release mode, leggi dal file .env (se esiste)
        final useDev = dotenv.env['USE_DEV_DB']?.toLowerCase() == 'true';

        if (useDev) {
          _isDevelopment = true;
          _databaseId = dotenv.env['DEV_DATABASE_ID'] ?? '';
          _storageBucket = dotenv.env['DEV_STORAGE_BUCKET'] ?? '';
          debugPrint('🔧 RELEASE MODE con DEV DB: Ambiente di SVILUPPO');
        } else {
          _isDevelopment = false;
          _databaseId = '(default)';
          _storageBucket = '';
          debugPrint('🚀 RELEASE MODE: Ambiente di PRODUZIONE');
        }
      }

      _isInitialized = true;

      debugPrint('✅ EnvironmentConfig inizializzato:');
      debugPrint('   - Sviluppo: $_isDevelopment');
      debugPrint('   - Database ID: $_databaseId');
      debugPrint('   - Storage Bucket: $_storageBucket');

    } catch (e) {
      debugPrint('❌ Errore inizializzazione EnvironmentConfig: $e');
      // In caso di errore, usa i valori di default (produzione)
      _isDevelopment = false;
      _databaseId = '(default)';
      _storageBucket = '';
      _isInitialized = true;
    }
  }

  /// Configura Firestore con il database corretto
  void configureFirestore() {
    if (!_isInitialized) {
      throw StateError('EnvironmentConfig non inizializzato. Chiama initialize() prima.');
    }

    if (_isDevelopment && _databaseId.isNotEmpty && _databaseId != '(default)') {
      try {
        final settings = Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );

        FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: _databaseId,
        ).settings = settings;

        debugPrint('✅ Firestore configurato per database: $_databaseId');
      } catch (e) {
        debugPrint('❌ Errore configurazione Firestore: $e');
      }
    } else {
      debugPrint('✅ Firestore usa database default (produzione)');
    }
  }

  /// Ottiene l'istanza di Firestore corretta
  FirebaseFirestore getFirestore() {
    if (!_isInitialized) {
      throw StateError('EnvironmentConfig non inizializzato. Chiama initialize() prima.');
    }

    if (_isDevelopment && _databaseId.isNotEmpty && _databaseId != '(default)') {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _databaseId,
      );
    } else {
      return FirebaseFirestore.instance;
    }
  }

  /// Ottiene l'istanza di Storage corretta
  FirebaseStorage getStorage() {
    if (!_isInitialized) {
      throw StateError('EnvironmentConfig non inizializzato. Chiama initialize() prima.');
    }

    if (_isDevelopment && _storageBucket.isNotEmpty) {
      return FirebaseStorage.instanceFor(
        app: Firebase.app(),
        bucket: 'gs://$_storageBucket',
      );
    } else {
      return FirebaseStorage.instance;
    }
  }
}