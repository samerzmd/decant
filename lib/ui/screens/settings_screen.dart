import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_service.dart';
import '../../models/app_settings.dart';
import '../../logic/streak_reminder.dart';
import '../../models/liquid_palette.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../reminder_prompt.dart';
import '../widgets/cloud_save_section.dart';
import 'sound_browser_screen.dart';
import '../../l10n/l10n.dart';

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
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: DecantColors.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.settings,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: DecantColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                    children: [
                      if (ref.watch(cloudSyncProvider).available) ...[
                        _SectionLabel(context.l10n.cloudSave),
                        const CloudSaveSection(),
                        const SizedBox(height: 18),
                      ],
                      _SectionLabel(context.l10n.audio),
                      _SwitchTile(
                        label: context.l10n.muteAll,
                        icon: Icons.volume_off_rounded,
                        value: audio.muted,
                        onChanged: (_) => ctrl.toggleMute(),
                      ),
                      _SliderTile(
                        label: context.l10n.soundEffects,
                        icon: Icons.water_drop_rounded,
                        value: audio.sfxVolume,
                        enabled: !audio.muted,
                        onChanged: ctrl.setSfxVolume,
                      ),
                      _SliderTile(
                        label: context.l10n.ambience,
                        icon: Icons.spa_rounded,
                        value: audio.ambientVolume,
                        enabled: !audio.muted && audio.ambientEnabled,
                        onChanged: ctrl.setAmbientVolume,
                      ),
                      _SliderTile(
                        label: context.l10n.music,
                        icon: Icons.music_note_rounded,
                        value: audio.musicVolume,
                        enabled: !audio.muted,
                        onChanged: ctrl.setMusicVolume,
                      ),
                      _SwitchTile(
                        label: context.l10n.ambientLoop,
                        icon: Icons.waves_rounded,
                        value: audio.ambientEnabled,
                        onChanged: (_) => ctrl.toggleAmbient(),
                      ),
                      if (audio.ambientEnabled)
                        _NavTile(
                          title: context.l10n.ambienceSound,
                          value: audio.ambientTrack.label,
                          detail: context.l10n.soundCount(
                            audio.ambientTrack.categoryInfo.label,
                            kAmbientCatalog.length,
                          ),
                          icon: audio.ambientTrack.icon,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SoundBrowserScreen(
                                kind: SoundKind.ambient,
                              ),
                            ),
                          ),
                        ),
                      _SwitchTile(
                        label: context.l10n.backgroundMusic,
                        subtitle: context.l10n.backgroundMusicSubtitle,
                        icon: Icons.library_music_rounded,
                        value: audio.musicEnabled,
                        onChanged: (_) => ctrl.toggleMusic(),
                      ),
                      if (audio.musicEnabled)
                        _NavTile(
                          title: context.l10n.musicTrack,
                          value: audio.musicTrack.label,
                          detail: context.l10n.trackCount(
                            audio.musicTrack.categoryInfo.label,
                            kMusicCatalog.length,
                          ),
                          icon: audio.musicTrack.icon,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SoundBrowserScreen(
                                kind: SoundKind.music,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      _SectionLabel(context.l10n.feel),
                      _SwitchTile(
                        label: context.l10n.haptics,
                        icon: Icons.vibration_rounded,
                        value: settings.hapticsEnabled,
                        onChanged: (_) => ctrl.toggleHaptics(),
                      ),
                      _SwitchTile(
                        label: context.l10n.keepAwake,
                        subtitle: "Don't let the screen sleep while playing",
                        icon: Icons.light_mode_rounded,
                        value: settings.keepScreenOn,
                        onChanged: (_) => ctrl.toggleKeepScreenOn(),
                      ),
                      _ChoiceTile<PourSpeed>(
                        title: context.l10n.pourSpeed,
                        icon: Icons.speed_rounded,
                        options: PourSpeed.values,
                        labelOf: context.l10n.pourSpeedLabel,
                        value: settings.pourSpeed,
                        onChanged: ctrl.setPourSpeed,
                      ),
                      _SwitchTile(
                        label: context.l10n.zenMode,
                        subtitle: context.l10n.zenModeSubtitle,
                        icon: Icons.spa_rounded,
                        value: settings.zenMode,
                        onChanged: (_) => ctrl.toggleZenMode(),
                      ),
                      if (ref.read(reminderServiceProvider).supported)
                        _SwitchTile(
                          label: context.l10n.streakReminders,
                          subtitle: context.l10n.streakRemindersSubtitle,
                          icon: Icons.notifications_active_rounded,
                          value: settings.streakReminders,
                          onChanged: (on) => _setReminders(context, ref, on),
                        ),
                      if (settings.streakReminders &&
                          ref.read(reminderServiceProvider).supported)
                        _ChoiceTile<int>(
                          title: context.l10n.reminderTime,
                          icon: Icons.schedule_rounded,
                          options: kReminderHours,
                          labelOf: (h) => MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(TimeOfDay(hour: h, minute: 0)),
                          value: settings.reminderHour,
                          onChanged: ctrl.setReminderHour,
                        ),
                      const SizedBox(height: 18),
                      _SectionLabel(context.l10n.accessibility),
                      _ChoiceTile<UiTheme>(
                        title: context.l10n.theme,
                        icon: Icons.dark_mode_rounded,
                        options: UiTheme.values,
                        labelOf: context.l10n.uiThemeLabel,
                        value: settings.uiTheme,
                        onChanged: ctrl.setUiTheme,
                      ),
                      _ChoiceTile<LiquidPalette>(
                        title: context.l10n.liquidColors,
                        icon: Icons.palette_rounded,
                        options: LiquidPalette.values,
                        labelOf: context.l10n.liquidPaletteLabel,
                        value: settings.liquidPalette,
                        onChanged: ctrl.setLiquidPalette,
                      ),
                      _SwitchTile(
                        label: context.l10n.colorblindSymbols,
                        subtitle: context.l10n.colorblindSubtitle,
                        icon: Icons.remove_red_eye_rounded,
                        value: settings.colorblindMode,
                        onChanged: (_) => ctrl.toggleColorblind(),
                      ),
                      _SwitchTile(
                        label: context.l10n.reduceMotion,
                        subtitle: context.l10n.reduceMotionSubtitle,
                        icon: Icons.motion_photos_off_rounded,
                        value: settings.reduceMotion,
                        onChanged: (_) => ctrl.toggleReduceMotion(),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel(context.l10n.language),
                      _ChoiceTile<AppLanguage>(
                        title: context.l10n.language,
                        icon: Icons.translate_rounded,
                        options: AppLanguage.values,
                        labelOf: context.l10n.appLanguageLabel,
                        value: settings.language,
                        onChanged: ctrl.setLanguage,
                      ),
                      // Shown only where the consent law applies (EEA, UK).
                      if (ref
                          .read(adServiceProvider)
                          .privacyOptionsRequired) ...[
                        const SizedBox(height: 18),
                        _SectionLabel(context.l10n.privacy),
                        _NavTile(
                          title: context.l10n.privacy,
                          value: context.l10n.adPrivacyChoices,
                          detail: context.l10n.adPrivacySubtitle,
                          icon: Icons.privacy_tip_rounded,
                          onTap: () =>
                              ref.read(adServiceProvider).showPrivacyOptions(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Streak reminders switch: on goes through the permission prompt.
Future<void> _setReminders(BuildContext context, WidgetRef ref, bool on) async {
  if (on) {
    await turnOnReminders(context, ref);
  } else {
    ref.read(settingsProvider.notifier).setStreakReminders(false);
  }
}

/// Chips picking one of [options]: pour speed, theme, colors, language.
/// Up to four share a row; more wrap onto extra lines.
class _ChoiceTile<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<T> options;
  final String Function(T) labelOf;
  final T value;
  final ValueChanged<T> onChanged;

  const _ChoiceTile({
    required this.title,
    required this.icon,
    required this.options,
    required this.labelOf,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: DecantColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DecantColors.accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: DecantColors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (options.length > 4)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final o in options) _chip(o, padX: 14)],
            )
          else
            Row(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _chip(options[i])),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(T option, {double padX = 6}) {
    final selected = option == value;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () => onChanged(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: padX),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? DecantColors.accent
                : DecantColors.ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              labelOf(option),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color:
                    selected ? DecantColors.onAccent : DecantColors.onSurface,
              ),
            ),
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
          color: DecantColors.accent.withValues(alpha: 0.9),
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
        color: DecantColors.ink.withValues(alpha: 0.06),
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
                Text(
                  label,
                  style: TextStyle(
                    color: DecantColors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: DecantColors.subtle.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: DecantColors.accent,
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
          color: DecantColors.ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: DecantColors.accent, size: 22),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(
                  color: DecantColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: enabled ? onChanged : null,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${(value * 100).round()}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: DecantColors.subtle.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row showing the current choice; tapping opens a full picker screen.
class _NavTile extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  const _NavTile({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title: $value',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: DecantColors.ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DecantColors.accent.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: DecantColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: DecantColors.subtle.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: DecantColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detail,
                      style: TextStyle(
                        color: DecantColors.subtle.withValues(alpha: 0.7),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: DecantColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}
