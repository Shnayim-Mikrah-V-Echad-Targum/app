import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/city_providers.dart';
import '../../../app/providers.dart';
import '../../../core/calendar/city.dart';
import '../../../data/city_directory.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';

/// Chooses the city for Shabbat times from a list, searched by name in
/// English or Hebrew. The device's location is never asked for: its time
/// zone only suggests where to start.
class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({super.key});

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  final _query = TextEditingController();
  Timer? _announcement;

  @override
  void dispose() {
    _announcement?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _choose(City? city) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(city: city));
    context.pop();
  }

  /// Tells a screen reader how many cities match, once typing pauses.
  void _changed(CityDirectory? directory) {
    setState(() {});
    _announcement?.cancel();
    if (directory == null || _query.text.trim().isEmpty) return;
    _announcement = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final count = directory.search(_query.text).length;
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.cityResultsCount(count),
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final directory = ref.watch(cityDirectoryProvider);
    final loaded = directory.value;
    return Scaffold(
      appBar: AppBar(title: Text(l.cityPickerTitle)),
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.citySearchLabel,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l.citySearchClear,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _query.clear();
                              _changed(loaded);
                            },
                          ),
                  ),
                  onChanged: (_) => _changed(loaded),
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (directory) {
              AsyncData(:final value) => _Cities(directory: value, query: _query.text.trim(), onChoose: _choose),
              AsyncError() => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.errorGeneric, textAlign: TextAlign.center),
                ),
              // Loaded in a moment (and usually already, by Reading &
              // customs), so nothing stands in for it.
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

/// The cities matching [query], or with none, the city chosen and those in
/// the device's time zone.
class _Cities extends ConsumerWidget {
  const _Cities({required this.directory, required this.query, required this.onChoose});

  final CityDirectory directory;
  final String query;
  final ValueChanged<City?> onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final he = context.isHebrewUi;
    final chosen = ref.watch(settingsProvider.select((s) => s.city));
    final note = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 24, 4, 0),
      child: Text(l.cityListNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
    Widget row(City city) {
      final selected = city.id == chosen?.id;
      return PaperRow(
        title: city.name(hebrew: he),
        subtitle: directory.placeOf(city, hebrew: he),
        trailing: selected ? Icon(Icons.check, color: theme.colorScheme.primary, semanticLabel: l.citySelected) : null,
        mergeTrailing: true,
        chevron: false,
        onTap: () => onChoose(city),
      );
    }

    if (query.isNotEmpty) {
      final found = directory.search(query);
      return PageBody(
        children: [
          const Gap(16),
          if (found.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 0),
              // The query keeps its own direction inside the sentence.
              child: Text(l.cityNoResults('\u2068$query\u2069'), style: theme.textTheme.bodyLarge),
            )
          else
            PaperGroup(children: [for (final c in found) row(c)]),
          note,
        ],
      );
    }
    final zone = ref.watch(deviceTimeZoneProvider).value;
    // The chosen city is already at the top.
    final nearby = [
      if (zone != null)
        for (final c in directory.inTimeZone(zone, limit: 9))
          if (c.id != chosen?.id) c,
    ].take(8);
    return PageBody(
      children: [
        if (chosen != null) ...[
          GroupHeader(l.cityYours),
          PaperGroup(
            children: [
              row(chosen),
              PaperRow(title: l.cityNone, subtitle: l.cityNoneDesc, chevron: false, onTap: () => onChoose(null)),
            ],
          ),
        ],
        if (nearby.isNotEmpty) ...[
          GroupHeader(l.cityNearYou),
          PaperGroup(children: [for (final c in nearby) row(c)]),
        ],
        note,
      ],
    );
  }
}
