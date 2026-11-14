import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Email/password registration screen.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'Deutschland');
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    _street.dispose();
    _postalCode.dispose();
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Vorname und Nachname eingeben')),
      );
      return;
    }
    if (_password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort muss mindestens 8 Zeichen haben')),
      );
      return;
    }
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwörter stimmen nicht überein')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text.trim(),
            password: _password.text,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phone: _phone.text.trim(),
            addressStreet: _street.text.trim(),
            addressPostalCode: _postalCode.text.trim(),
            addressCity: _city.text.trim(),
            addressCountry: _country.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrierung erfolgreich. Bitte E-Mail bestätigen.'),
          ),
        );
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registrierung fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: AppScrollView(
        children: [
          SizedBox(height: AppSpacing.sectionMargin),
          SectionHeaderCard(
            title: 'Konto erstellen',
            subtitle: 'Registriere dich für Virtumi Home',
            icon: Symbols.person_add,
            filled: true,
          ),
          SizedBox(height: AppSpacing.sectionMargin),
          AppCard(
            child: Column(
              children: [
                SettingsInputRow(
                  icon: Symbols.person,
                  label: 'Vorname *',
                  controller: _firstName,
                  iconColor: context.palette.accentBlue,
                  keyboardType: TextInputType.name,
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.badge,
                  label: 'Nachname *',
                  controller: _lastName,
                  iconColor: context.palette.accentIndigo,
                  keyboardType: TextInputType.name,
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.mail,
                  label: 'E-Mail',
                  controller: _email,
                  iconColor: context.palette.accentBlue,
                  keyboardType: TextInputType.emailAddress,
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.lock,
                  label: 'Passwort',
                  controller: _password,
                  iconColor: context.palette.accentOrange,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.lock_reset,
                  label: 'Passwort bestätigen',
                  controller: _confirm,
                  iconColor: context.palette.accentGreen,
                  obscure: _obscure,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          const AppSectionLabel('Weitere Angaben (optional)'),
          AppCard(
            child: Column(
              children: [
                SettingsInputRow(
                  icon: Symbols.phone,
                  label: 'Telefon',
                  controller: _phone,
                  iconColor: context.palette.accentTeal,
                  keyboardType: TextInputType.phone,
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.home,
                  label: 'Straße',
                  controller: _street,
                  iconColor: context.palette.accentOrange,
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.markunread_mailbox,
                  label: 'PLZ',
                  controller: _postalCode,
                  iconColor: context.palette.accentAmber,
                  keyboardType: TextInputType.number,
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.location_city,
                  label: 'Stadt',
                  controller: _city,
                  iconColor: context.palette.accentSky,
                ),
                const Divider(height: 1),
                SettingsInputRow(
                  icon: Symbols.public,
                  label: 'Land',
                  controller: _country,
                  iconColor: context.palette.accentPurple,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrieren'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Bereits registriert? Anmelden'),
          ),
        ],
      ),
    );
  }
}
