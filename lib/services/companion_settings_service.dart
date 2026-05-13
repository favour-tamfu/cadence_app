import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../models/companion.dart';

// ─────────────────────────────────────────────────────────────
//  CompanionSettingsService
//  Manages the global default companion config used when a
//  new book is opened without a specific session.
// ─────────────────────────────────────────────────────────────
class CompanionSettingsService extends ChangeNotifier {
  CompanionSettingsService({required SessionRepository repository})
      : _repo = repository {
    _config = _repo.loadGlobalConfig();
  }

  final SessionRepository _repo;
  late CompanionConfig _config;

  CompanionConfig get config => _config;

  Future<void> setCompanionType(CompanionType type) async {
    _config = CompanionConfig.defaultFor(type).copyWith(
      voiceEnabled: _config.voiceEnabled,
      citeSources: _config.citeSources,
      showConfidence: _config.showConfidence,
      customPersonaNote: _config.customPersonaNote,
    );
    await _save();
  }

  Future<void> setVerbosity(Verbosity verbosity) async {
    _config = _config.copyWith(verbosity: verbosity);
    await _save();
  }

  Future<void> setResponseMode(ResponseMode mode) async {
    _config = _config.copyWith(responseMode: mode);
    await _save();
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    _config = _config.copyWith(voiceEnabled: enabled);
    await _save();
  }

  Future<void> setProactiveNudges(bool enabled) async {
    _config = _config.copyWith(proactiveNudges: enabled);
    await _save();
  }

  Future<void> setSocraticMode(bool enabled) async {
    _config = _config.copyWith(socraticMode: enabled);
    await _save();
  }

  Future<void> setCustomPersonaNote(String? note) async {
    _config = _config.copyWith(customPersonaNote: note);
    await _save();
  }

  Future<void> setCiteSources(bool value) async {
    _config = _config.copyWith(citeSources: value);
    await _save();
  }

  Future<void> setShowConfidence(bool value) async {
    _config = _config.copyWith(showConfidence: value);
    await _save();
  }

  Future<void> applyConfig(CompanionConfig config) async {
    _config = config;
    await _save();
  }

  Future<void> resetToDefaults() async {
    _config = CompanionConfig.defaultFor(_config.type);
    await _save();
  }

  Future<void> _save() async {
    await _repo.saveGlobalConfig(_config);
    notifyListeners();
  }
}
