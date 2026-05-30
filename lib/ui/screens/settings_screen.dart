import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_service.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';

/// Audio mixer (SFX / ambience / music), mute, ambient toggle, haptics and the
/// colorblind-friendly rendering option. All changes persist immediately.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final audio = settings.audio;

    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: DecantColors.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: DecantColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                  children: [
                    const _SectionLabel('Audio'),
                    _SwitchTile(
                      label: 'Mute all',
                      icon: Icons.volume_off_rounded,
                      value: audio.muted,
                      onChanged: (_) => ctrl.toggleMute(),
                    ),
                    _SliderTile(
                      label: 'Sound effects',
                      icon: Icons.water_drop_rounded,
                      value: audio.sfxVolume,
                      enabled: !audio.muted,
                      onChanged: ctrl.setSfxVolume,
                    ),
                    _SliderTile(
                      label: 'Ambience',
                      icon: Icons.spa_rounded,
                      value: audio.ambientVolume,
                      enabled: !audio.muted && audio.ambientEnabled,
                      onChanged: ctrl.setAmbientVolume,
                    ),
                    _SliderTile(
                      label: 'Music',
                      icon: Icons.music_note_rounded,
                      value: audio.musicVolume,
                      enabled: !audio.muted,
                      onChanged: ctrl.setMusicVolume,
                    ),
                    _SwitchTile(
                      label: 'Ambient background loop',
                      icon: Icons.waves_rounded,
                      value: audio.ambientEnabled,
                      onChanged: (_) => ctrl.toggleAmbient(),
                    ),
                    if (audio.ambientEnabled)
                      _AmbientPicker(
                        selected: audio.ambientTrack,
                        enabled: !audio.muted,
                        onSelect: ctrl.setAmbientTrack,
                      ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Feel'),
                    _SwitchTile(
                      label: 'Haptic feedback',
                      icon: Icons.vibration_rounded,
                      value: settings.hapticsEnabled,
                      onChanged: (_) => ctrl.toggleHaptics(),
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Accessibility'),
                    _SwitchTile(
                      label: 'Colorblind symbols',
                      subtitle: 'Show a distinct shape on each liquid color',
                      icon: Icons.remove_red_eye_rounded,
                      value: settings.colorblindMode,
                      onChanged: (_) => ctrl.toggleColorblind(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4, left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: DecantColors.accent.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: DecantColors.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: DecantColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: DecantColors.subtle.withOpacity(0.8),
                          fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: DecantColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: DecantColors.accent, size: 22),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(
                      color: DecantColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: enabled ? onChanged : null,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text('${(value * 100).round()}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: DecantColors.subtle.withOpacity(0.9),
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable chips for the ambient bed (Twilight Pad / Rain / Ocean / …).
class _AmbientPicker extends StatelessWidget {
  final AmbientTrack selected;
  final bool enabled;
  final ValueChanged<AmbientTrack> onSelect;

  const _AmbientPicker({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  static const Map<AmbientTrack, IconData> _icons = {
    AmbientTrack.pad: Icons.nightlight_round,
    AmbientTrack.rain: Icons.grain_rounded,
    AmbientTrack.ocean: Icons.water_rounded,
    AmbientTrack.stream: Icons.water_drop_rounded,
    AmbientTrack.fireplace: Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ambience sound',
                style: TextStyle(
                    color: DecantColors.subtle.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final track in AmbientTrack.values)
                  _AmbientChip(
                    label: track.label,
                    icon: _icons[track] ?? Icons.music_note_rounded,
                    active: track == selected,
                    onTap: enabled ? () => onSelect(track) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _AmbientChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? DecantColors.accent.withOpacity(0.22)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? DecantColors.accent
                : Colors.white.withOpacity(0.12),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active ? DecantColors.accent : DecantColors.subtle),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? DecantColors.onSurface : DecantColors.subtle,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
