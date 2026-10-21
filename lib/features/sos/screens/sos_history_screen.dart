import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../data/sos_event_repository.dart';
import '../models/sos_event.dart';
import '../../../core/routing/app_routes.dart';

class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  List<SosEventSummary> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await SosEventRepository.instance.history();
      if (mounted) setState(() => _events = list);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}  ${_two(d.hour)}:${_two(d.minute)}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('sos_history'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _events.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [Text(context.tr('sos_history_empty'), textAlign: TextAlign.center)],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (context, i) {
                      final e = _events[i];
                      final color = switch (e.status) {
                        'active' => AppTheme.sosRed,
                        'duress' => scheme.error,
                        _ => AppTheme.safeGreen,
                      };
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.incidentReport, arguments: e.id),
                          leading: CircleAvatar(child: Text('${e.level}')),
                          title: Text(context.tr('level_${e.level}_name')),
                          subtitle: Text(_date(e.startedAt)),
                          trailing: Wrap(
                            spacing: 6,
                            direction: Axis.vertical,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              StatusChip(label: context.tr('event_status_${e.status}'), color: color),
                              if (e.isTest) StatusChip(label: 'TEST', color: scheme.outline),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
