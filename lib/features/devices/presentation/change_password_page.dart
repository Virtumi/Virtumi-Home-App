import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/device_settings_header.dart';

/// Change device password (Supabase queue or direct UDP protocol 2).
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    if (_current.text.isEmpty || _next.text.isEmpty) {
      error = 'Bitte alle Felder ausfüllen';
    } else if (_next.text.length < 8) {
      error = 'Das neue Passwort muss mind. 8 Zeichen haben';
    } else if (_next.text.length > 16) {
      error = 'Das neue Passwort darf maximal 16 Zeichen haben';
    } else if (_next.text != _confirm.text) {
      error = 'Die Passwörter stimmen nicht überein';
    }

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(deviceRequestRepositoryProvider).requestPasswordChange(
            deviceId: widget.deviceId,
            currentCode: _current.text,
            newCode: _next.text,
          );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gerätepasswort wurde geändert'),
          ),
        );
        _current.clear();
        _next.clear();
        _confirm.clear();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppScaffold(
      header: const AppHeader(),
      body: AppScrollView(
        children: [
          DeviceSettingsHeader(
            deviceId: widget.deviceId,
            title: 'Passwort ändern',
            icon: Symbols.lock,
          ),
          const AppSectionLabel('Sicherheit'),
          GroupedListCard(
            children: [
              SettingsInputRow(
                icon: Symbols.lock_open,
                label: 'Aktuelles Passwort',
                controller: _current,
                iconColor: p.accentOrange,
                obscure: _obscureCurrent,
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              SettingsInputRow(
                icon: Symbols.password,
                label: 'Neues Passwort',
                controller: _next,
                iconColor: p.accentBlue,
                obscure: _obscureNext,
                onToggleObscure: () =>
                    setState(() => _obscureNext = !_obscureNext),
              ),
              SettingsInputRow(
                icon: Symbols.check_circle,
                label: 'Bestätigen',
                controller: _confirm,
                iconColor: p.accentGreen,
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ],
          ),
          SaveCancelCard(
            saveLabel: _saving ? 'Speichern …' : 'Speichern',
            cancelLabel: 'Abbrechen',
            onCancel: _saving
                ? () {}
                : () => Navigator.of(context).maybePop(),
            onSave: _saving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}
