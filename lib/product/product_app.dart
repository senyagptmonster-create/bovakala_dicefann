import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/brand.dart';
import '../app/store.dart';
import '../app/theme.dart';

/// Exercise cards. Swipe through the library and collect the ones you want —
/// the session is assembled by swiping, never by ticking a list.
class ProductApp extends StatefulWidget {
  const ProductApp({super.key});

  @override
  State<ProductApp> createState() => _ProductAppState();
}

class _Exercise {
  final String id;
  final String name;
  final String target;
  final String gear;
  final String sets;
  final String cue;

  const _Exercise({
    required this.id,
    required this.name,
    required this.target,
    required this.gear,
    required this.sets,
    required this.cue,
  });

  static _Exercise? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    String str(Object? v) => v is String ? v : '';
    return _Exercise(
      id: id,
      name: name,
      target: str(raw['target']),
      gear: str(raw['gear']),
      sets: str(raw['sets']),
      cue: str(raw['cue']),
    );
  }
}

class _ProductAppState extends State<ProductApp> {
  static const _kSession = 'ex_session';

  List<_Exercise> _library = const [];
  Set<String> _session = <String>{};
  bool _loading = true;

  final PageController _pages = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var library = <_Exercise>[];
    try {
      final raw = await rootBundle.loadString('assets/json/content.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['exercises'] is List) {
        for (final e in decoded['exercises'] as List) {
          final parsed = _Exercise.tryParse(e);
          if (parsed != null) library.add(parsed);
        }
      }
    } catch (_) {
      library = <_Exercise>[];
    }
    final session = await Store.getStringSet(_kSession);
    if (!mounted) return;
    setState(() {
      _library = library;
      _session = session;
      _loading = false;
    });
  }

  Future<void> _toggle(_Exercise exercise) async {
    final next = Set<String>.of(_session);
    if (!next.remove(exercise.id)) next.add(exercise.id);
    setState(() => _session = next);
    await Store.setStringSet(_kSession, next);
  }

  Future<void> _clearSession() async {
    setState(() => _session = <String>{});
    await Store.setStringSet(_kSession, <String>{});
  }

  void _openSession() {
    final chosen = _library.where((e) => _session.contains(e.id)).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Your session', style: AppTheme.display(22)),
                ),
                if (chosen.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _clearSession();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (chosen.isEmpty)
              Text(
                'Nothing added yet. Swipe the cards and tap add on the ones '
                'you want.',
                style: AppTheme.text(
                  14,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              )
            else
              for (var i = 0; i < chosen.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: AppTheme.radiusOf(0.4),
                          color: cAlt.withValues(alpha: 0.16),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: AppTheme.text(
                            12,
                            color: cAlt,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          chosen[i].name,
                          style: AppTheme.text(
                            15,
                            weight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        chosen[i].sets,
                        style: AppTheme.text(
                          13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: cBg,
        body: Center(child: CircularProgressIndicator(color: cAccent)),
      );
    }
    if (_library.isEmpty) {
      return Scaffold(
        backgroundColor: cBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'Exercise library unavailable.',
              textAlign: TextAlign.center,
              style: AppTheme.text(15, color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(kProductTitle, style: AppTheme.display(25)),
                        Text(
                          '${_page + 1} of ${_library.length}',
                          style: AppTheme.text(
                            13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Тема задаёт кнопкам minimumSize: Size.fromHeight(52), а у
                  // него бесконечная ширина. В Row без Expanded это требование
                  // невыполнимо, поэтому здесь ширину отпускаем.
                  FilledButton.tonalIcon(
                    onPressed: _openSession,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: Text('${_session.length}'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _library.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _card(_library[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                'Swipe for the next exercise',
                style: AppTheme.text(12, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(_Exercise exercise) {
    final added = _session.contains(exercise.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: AppTheme.radius,
          color: AppTheme.surface,
          border: Border.all(
            color: added ? cAccent : AppTheme.border,
            width: added ? 2 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (exercise.target.isNotEmpty) _tag(exercise.target),
                if (exercise.gear.isNotEmpty) _tag(exercise.gear),
              ],
            ),
            const SizedBox(height: 18),
            // Гибкий и с потолком в две строки: длинное название на узком
            // экране иначе выдавливает карточку за пределы страницы.
            Flexible(
              child: Text(
                exercise.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(26, height: 1.15),
              ),
            ),
            const SizedBox(height: 10),
            if (exercise.sets.isNotEmpty)
              Text(
                exercise.sets,
                style: AppTheme.text(
                  17,
                  color: cAlt,
                  weight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  exercise.cue,
                  style: AppTheme.text(
                    15.5,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: added
                  ? OutlinedButton.icon(
                      onPressed: () => _toggle(exercise),
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      label: const Text('Remove from session'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _toggle(exercise),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add to session'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: AppTheme.radiusOf(0.5),
        color: cAlt.withValues(alpha: 0.14),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.text(
          11,
          color: cAlt,
          weight: FontWeight.w700,
          spacing: 1.2,
        ),
      ),
    );
  }
}
