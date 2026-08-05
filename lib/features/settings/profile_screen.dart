import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import 'settings_controller.dart';

/// Edit the user profile captured during onboarding. Only the name is
/// encouraged; the rest is optional and stays on-device unless cloud sync is
/// enabled.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _nickname;
  late final TextEditingController _age;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsControllerProvider).valueOrNull;
    _name = TextEditingController(text: s?.userName ?? '');
    _nickname = TextEditingController(text: s?.userNickname ?? '');
    _age = TextEditingController(text: s?.userAge?.toString() ?? '');
    _phone = TextEditingController(text: s?.userPhone ?? '');
    _email = TextEditingController(text: s?.userEmail ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _age.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final age = int.tryParse(_age.text.trim());
    await ref.read(settingsControllerProvider.notifier).save(
          (c) => c.copyWith(
            userName: _name.text.trim(),
            userNickname: _nickname.text.trim(),
            userAge: age,
            clearAge: age == null,
            userPhone: _phone.text.trim(),
            userEmail: _email.text.trim(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved. Looking good.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            Text(
              'This lives only on your device. It travels to the cloud solely '
              'if you turn on sync.',
              style: text.bodySmall,
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _nickname,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nickname (optional)',
                helperText: "If set, this is what I'll call you everywhere",
              ),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age (optional)'),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            const SizedBox(height: Insets.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
