import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/companion.dart';
import '../../providers/companion_providers.dart';

// ─────────────────────────────────────────────────────────────
//  CompanionSettingsScreen
//  Controls global companion defaults.
//  Per-book overrides live in each BookSession.
// ─────────────────────────────────────────────────────────────
class CompanionSettingsScreen extends ConsumerStatefulWidget {
  const CompanionSettingsScreen({super.key});

  @override
  ConsumerState<CompanionSettingsScreen> createState() =>
      _CompanionSettingsScreenState();
}

class _CompanionSettingsScreenState
    extends ConsumerState<CompanionSettingsScreen> {
  late CompanionConfig _draft;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = ref.read(companionSettingsServiceProvider).config;
    _noteController.text = _draft.customPersonaNote ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companion = _draft.type;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        title: const Text('Companion settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.amber),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Persona selection ────────────────────────────
          const _SectionHeader('Your companion'),
          const SizedBox(height: 12),
          ...CompanionType.values.map(
            (type) => _CompanionOption(
              type: type,
              selected: companion == type,
              onTap: () => setState(
                () => _draft = CompanionConfig.defaultFor(type).copyWith(
                  voiceEnabled: _draft.voiceEnabled,
                  citeSources: _draft.citeSources,
                  showConfidence: _draft.showConfidence,
                  customPersonaNote: _draft.customPersonaNote,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Response style ───────────────────────────────
          const _SectionHeader('Response style'),
          const SizedBox(height: 12),

          _SegmentedRow<Verbosity>(
            label: 'Detail level',
            values: Verbosity.values,
            selected: _draft.verbosity,
            labelFor: (v) => v.label,
            accentColor: companion.primaryColor,
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(verbosity: v);
            }),
          ),
          const SizedBox(height: 16),

          _SegmentedRow<ResponseMode>(
            label: 'Interaction mode',
            values: ResponseMode.values,
            selected: _draft.responseMode,
            labelFor: (v) => v.label,
            accentColor: companion.primaryColor,
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(responseMode: v);
            }),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _draft.responseMode.description,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),

          const SizedBox(height: 28),

          // ── Features ─────────────────────────────────────
          const _SectionHeader('Features'),
          const SizedBox(height: 8),

          _SwitchTile(
            label: 'Voice reading',
            subtitle: 'Companion reads responses aloud',
            value: _draft.voiceEnabled,
            accentColor: companion.primaryColor,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(voiceEnabled: v)),
          ),
          _SwitchTile(
            label: 'Proactive nudges',
            subtitle: 'Companion shares insights without being asked',
            value: _draft.proactiveNudges,
            accentColor: companion.primaryColor,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(proactiveNudges: v)),
          ),

          const SizedBox(height: 28),

          // ── Advanced ──────────────────────────────────────
          const _SectionHeader('Advanced'),
          const SizedBox(height: 8),

          _SwitchTile(
            label: 'Cite sources',
            subtitle: 'Flags when a response goes beyond the book',
            value: _draft.citeSources,
            accentColor: companion.primaryColor,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(citeSources: v)),
          ),
          _SwitchTile(
            label: 'Show uncertainty',
            subtitle: 'Companion signals when it\'s not fully sure',
            value: _draft.showConfidence,
            accentColor: companion.primaryColor,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(showConfidence: v)),
          ),

          const SizedBox(height: 20),

          const Text(
            'Custom instruction',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a personal note to your companion\'s behaviour across all books. '
            'E.g. "Always use British English" or "I\'m a medical professional — no need to simplify."',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLines: 3,
            style: const TextStyle(color: AppColors.cream),
            onChanged: (v) =>
                _draft = _draft.copyWith(customPersonaNote: v.trim()),
            decoration: const InputDecoration(hintText: 'Optional'),
          ),

          const SizedBox(height: 32),

          Center(
            child: TextButton(
              onPressed: _resetDefaults,
              child: Text(
                'Reset to defaults for ${companion.displayName}',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _save() {
    _draft = _draft.copyWith(
      customPersonaNote: _noteController.text.trim(),
    );
    ref.read(companionSettingsServiceProvider).applyConfig(_draft);
    Navigator.of(context).pop();
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.midnight2,
        title: const Text(
          'Reset settings?',
          style: TextStyle(color: AppColors.cream),
        ),
        content: Text(
          'This will reset ${_draft.type.displayName}\'s settings to defaults. '
          'Your per-book companion choices won\'t be affected.',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _draft = CompanionConfig.defaultFor(_draft.type);
        _noteController.text = '';
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _CompanionOption extends StatelessWidget {
  const _CompanionOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final CompanionType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? type.primaryColor.withValues(alpha: 0.15)
              : AppColors.midnight3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? type.primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: type.primaryColor,
              radius: 20,
              child: Text(
                type.displayName[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    type.tagline,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: type.primaryColor),
          ],
        ),
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.accentColor,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelFor;
  final Color accentColor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.cream,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: values
              .map(
                (v) => Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: v == selected
                            ? accentColor
                            : AppColors.midnight3,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        labelFor(v),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: v == selected
                              ? Colors.white
                              : AppColors.muted,
                          fontWeight: v == selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
