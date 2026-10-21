import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../profile/models/user_profile.dart';

class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  UserRole _role = UserRole.protected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(
              context.tr('role_title'),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(context.tr('role_subtitle')),
            const SizedBox(height: 20),
            for (final role in UserRole.values)
              _RoleCard(
                role: role,
                selected: role == _role,
                onTap: () => setState(() => _role = role),
              ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: context.tr('continue'),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.signUp, arguments: _role),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final icon = switch (role) {
      UserRole.protected => Icons.shield_outlined,
      UserRole.guardian => Icons.visibility_outlined,
      UserRole.both => Icons.people_outline,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 30, color: selected ? scheme.onPrimaryContainer : scheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('role_${role.name}'),
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(context.tr('role_${role.name}_desc'), style: text.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? scheme.primary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
