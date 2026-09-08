import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/geopoint_admin_control.dart';
import '../../challenges/challenge_definition.dart';
import '../../challenges/challenge_pack_validator.dart';
import '../../challenges/challenge_studio_draft.dart';
import '../../challenges/challenge_studio_exporter.dart';
import '../../challenges/challenge_studio_preview.dart';
import '../../challenges/challenge_studio_storage.dart';
import '../../challenges/challenge_server_connection.dart';
import '../../game/game_controller.dart';
import '../design/geopoint_design.dart';
import 'challenge_studio_editor_screen.dart';
import 'challenge_ui_helpers.dart';
import 'geopoint_admin_control_screen.dart';

class ChallengeStudioScreen extends StatefulWidget {
  const ChallengeStudioScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<ChallengeStudioScreen> createState() => _ChallengeStudioScreenState();
}

class _ChallengeStudioScreenState extends State<ChallengeStudioScreen> {
  List<ChallengeStudioDraft> _drafts = const <ChallengeStudioDraft>[];
  bool _loading = true;
  bool _saving = false;
  bool _publishing = false;
  DateTime _simulatedAt = DateTime.now();
  late int _simulatedPlayerLevel;
  bool _simulatedChildProfile = false;

  Set<String> get _countryIds => widget.controller.countries
      .map((country) => country.id)
      .toSet();

  @override
  void initState() {
    super.initState();
    _simulatedPlayerLevel =
        widget.controller.playerProfile.currentLevel.clamp(1, 100).toInt();
    _load();
  }

  Future<void> _load() async {
    final List<ChallengeStudioDraft> drafts =
        await ChallengeStudioStorage.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _drafts = drafts;
      _loading = false;
    });
  }

  Future<void> _saveDrafts(List<ChallengeStudioDraft> drafts) async {
    setState(() => _saving = true);
    final bool saved = await ChallengeStudioStorage.save(drafts);
    if (!mounted) {
      return;
    }
    setState(() {
      if (saved) {
        _drafts = List<ChallengeStudioDraft>.unmodifiable(drafts);
      }
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Brouillons Studio enregistrés sur cet appareil.'
              : 'Impossible d’enregistrer les brouillons.',
        ),
      ),
    );
  }

  Future<void> _openAdminControl() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const GeoPointAdminControlScreen(),
      ),
    );
  }

  Future<ChallengePeriod?> _choosePeriod() {
    return showDialog<ChallengePeriod>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: const Text('Créer quel défi ?'),
          children: ChallengePeriod.values.map((ChallengePeriod period) {
            final IconData icon = period == ChallengePeriod.daily
                ? Icons.today_rounded
                : period == ChallengePeriod.weekly
                    ? Icons.date_range_rounded
                    : period == ChallengePeriod.monthly
                        ? Icons.calendar_month_rounded
                        : Icons.all_inclusive_rounded;
            return SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(period),
              child: ListTile(
                leading: Icon(icon),
                title: Text('Défi ${period.label.toLowerCase()}'),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Future<void> _createDraft() async {
    final ChallengePeriod? period = await _choosePeriod();
    if (period == null || !mounted) {
      return;
    }
    ChallengeStudioDraft fresh = ChallengeStudioDraft.fresh(period: period);
    int suffix = 2;
    final Set<String> ids = _drafts
        .map((ChallengeStudioDraft draft) => draft.id)
        .toSet();
    final String baseId = fresh.id;
    while (ids.contains(fresh.id)) {
      fresh = fresh.copyWith(id: '${baseId}_$suffix');
      suffix++;
    }
    await _openEditor(fresh);
  }

  Future<void> _openEditor(
    ChallengeStudioDraft draft, {
    int? replaceIndex,
  }) async {
    final ChallengeStudioDraft? edited =
        await Navigator.of(context).push<ChallengeStudioDraft>(
      MaterialPageRoute<ChallengeStudioDraft>(
        builder: (BuildContext context) => ChallengeStudioEditorScreen(
          draft: draft,
          countries: widget.controller.countries,
        ),
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    final bool duplicateId = _drafts.asMap().entries.any(
      (MapEntry<int, ChallengeStudioDraft> entry) =>
          entry.key != replaceIndex && entry.value.id == edited.id,
    );
    if (duplicateId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet identifiant existe déjà.')),
      );
      return;
    }
    final List<ChallengeStudioDraft> updated = <ChallengeStudioDraft>[
      ..._drafts,
    ];
    if (replaceIndex == null) {
      updated.add(edited);
    } else {
      updated[replaceIndex] = edited;
    }
    await _saveDrafts(updated);
  }

  Future<void> _duplicate(int index) async {
    final ChallengeStudioDraft source = _drafts[index];
    int suffix = 2;
    String id = '${source.id}_copie';
    final Set<String> ids = _drafts
        .map((ChallengeStudioDraft draft) => draft.id)
        .toSet();
    while (ids.contains(id)) {
      id = '${source.id}_copie_$suffix';
      suffix++;
    }
    await _openEditor(source.duplicate(id));
  }

  Future<void> _delete(int index) async {
    final ChallengeStudioDraft draft = _drafts[index];
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Supprimer ce brouillon ?'),
        content: Text('« ${draft.title} » sera retiré de PointGeo Studio.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final List<ChallengeStudioDraft> updated = <ChallengeStudioDraft>[
      ..._drafts,
    ]..removeAt(index);
    await _saveDrafts(updated);
  }

  Future<void> _toggleDisabled(int index) async {
    final List<ChallengeStudioDraft> updated = <ChallengeStudioDraft>[
      ..._drafts,
    ];
    final ChallengeStudioDraft draft = updated[index];
    updated[index] = draft.copyWith(disabled: !draft.disabled);
    await _saveDrafts(updated);
  }

  Future<void> _pickSimulationDate() async {
    final DateTime local = _simulatedAt.toLocal();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'DATE À SIMULER',
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
      helpText: 'HEURE À SIMULER',
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _simulatedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  ChallengeStudioExport? _buildExport({bool notifyError = true}) {
    try {
      return ChallengeStudioExporter.build(
        drafts: _drafts,
        countryIds: _countryIds,
      );
    } on FormatException catch (error) {
      if (notifyError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return null;
    }
  }

  Future<void> _validate() async {
    final ChallengeStudioExport? export = _buildExport();
    if (export == null || !mounted) {
      return;
    }
    await _showValidationResult(export, allowCopy: false);
  }

  Future<void> _export() async {
    final ChallengeStudioExport? export = _buildExport();
    if (export == null || !mounted) {
      return;
    }
    if (!export.isValid) {
      await _showValidationResult(export, allowCopy: false);
      return;
    }
    await Clipboard.setData(ClipboardData(text: export.json));
    if (!mounted) {
      return;
    }
    await _showValidationResult(export, allowCopy: true);
  }

  Future<void> _publish() async {
    final ChallengeStudioExport? export = _buildExport();
    if (export == null || !mounted) return;
    if (!export.isValid) {
      await _showValidationResult(export, allowCopy: false);
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.cloud_upload_rounded, color: GeoColors.gold),
        title: const Text('Publier ce pack ?'),
        content: Text(
          '${export.pack.challenges.length} configuration(s) seront envoyées '
          'à Firebase. Le pack deviendra la version active de PointGeo dès '
          'la fin de la publication.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.publish_rounded),
            label: const Text('PUBLIER'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final gateway = ChallengeServerConnection.adminGateway;
    if (gateway == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion Firebase indisponible.')),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      final GeoPointAdminPublishedPack published =
          await gateway.publishChallengePack(export.json);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          icon: const Icon(Icons.cloud_done_rounded, color: GeoColors.mint),
          title: const Text('Pack publié'),
          content: Text(
            '${published.packId} • révision ${published.revision}\n'
            '${published.challengeCount} défis disponibles côté serveur.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('TERMINÉ'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().contains('permission-denied')
                ? 'Publication refusée : ce compte n’est pas administrateur.'
                : 'Publication impossible : $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _showValidationResult(
    ChallengeStudioExport export, {
    required bool allowCopy,
  }) {
    final int errors = export.issues
        .where((ChallengeValidationIssue issue) => issue.isError)
        .length;
    final int warnings = export.issues.length - errors;
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(errors == 0 ? 'Pack valide' : '$errors erreur(s)'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  errors == 0
                      ? allowCopy
                          ? 'Le JSON complet a été copié. Il contient aussi les variantes enfant sécurisées.'
                          : 'Aucune erreur bloquante. $warnings avertissement(s).'
                      : 'Corrige les points ci-dessous avant l’export.',
                ),
                if (export.issues.isNotEmpty) const SizedBox(height: 12),
                ...export.issues.map((ChallengeValidationIssue issue) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          issue.isError
                              ? Icons.error_rounded
                              : Icons.warning_amber_rounded,
                          color: issue.isError ? GeoColors.coral : GeoColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(issue.message)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('FERMER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChallengeStudioExport? simulationExport =
        _buildExport(notifyError: false);
    final ChallengeStudioPreview? preview = simulationExport == null
        ? null
        : ChallengeStudioPreview.evaluate(
            pack: simulationExport.pack,
            simulatedAt: _simulatedAt,
            playerLevel: _simulatedPlayerLevel,
            isChildProfile: _simulatedChildProfile,
          );
    return Scaffold(
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _createDraft,
              icon: const Icon(Icons.add_rounded),
              label: const Text('NOUVEAU DÉFI'),
            ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'POINTGEO STUDIO',
                      subtitle: 'Créer, vérifier et publier',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 22),
                    _StudioIntroCard(draftCount: _drafts.length),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openAdminControl,
                        icon: const Icon(Icons.admin_panel_settings_rounded),
                        label: const Text('CONTRÔLE INTERNE'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _drafts.isEmpty ? null : _validate,
                            icon: const Icon(Icons.fact_check_rounded),
                            label: const Text('VALIDER'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _drafts.isEmpty ? null : _export,
                            icon: const Icon(Icons.copy_all_rounded),
                            label: const Text('EXPORTER JSON'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _drafts.isEmpty || _publishing
                            ? null
                            : _publish,
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: Text(
                          _publishing
                              ? 'PUBLICATION EN COURS…'
                              : 'PUBLIER DANS POINTGEO',
                        ),
                      ),
                    ),
                    if (!_loading && _drafts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      _SimulationCard(
                        preview: preview!,
                        onPickDate: _pickSimulationDate,
                        onLevelChanged: (int level) {
                          setState(() => _simulatedPlayerLevel = level);
                        },
                        onChildProfileChanged: (bool value) {
                          setState(() => _simulatedChildProfile = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 26),
                    const GeoSectionHeading(
                      eyebrow: 'Brouillons locaux',
                      title: 'Tes défis',
                      description:
                          'Crée des défis programmés ou permanents.',
                    ),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 70),
                        child: Center(
                          child: CircularProgressIndicator(color: GeoColors.gold),
                        ),
                      )
                    else if (_drafts.isEmpty)
                      const _EmptyStudioCard()
                    else
                      ..._drafts.asMap().entries.map(
                        (MapEntry<int, ChallengeStudioDraft> entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _DraftCard(
                            draft: entry.value,
                            onEdit: () => _openEditor(
                              entry.value,
                              replaceIndex: entry.key,
                            ),
                            onDuplicate: () => _duplicate(entry.key),
                            onToggleDisabled: () =>
                                _toggleDisabled(entry.key),
                            onDelete: () => _delete(entry.key),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_saving || _publishing)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: GeoColors.gold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SimulationCard extends StatelessWidget {
  const _SimulationCard({
    required this.preview,
    required this.onPickDate,
    required this.onLevelChanged,
    required this.onChildProfileChanged,
  });

  final ChallengeStudioPreview preview;
  final VoidCallback onPickDate;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<bool> onChildProfileChanged;

  String _formatDate(DateTime utc) {
    final DateTime date = utc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102542).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GeoColors.mint.withValues(alpha: 0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.visibility_rounded, color: GeoColors.mint),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'SIMULATION JOUEUR',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${preview.visibleChallenges.length} visible(s)',
                style: const TextStyle(
                  color: GeoColors.mint,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Vérifie ce qu’un joueur verra avant de publier le pack.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            leading: const Icon(Icons.edit_calendar_rounded),
            title: const Text('Date et heure simulées'),
            subtitle: Text(_formatDate(preview.simulatedAtUtc)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onPickDate,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(Icons.military_tech_rounded, color: GeoColors.gold),
              const SizedBox(width: 8),
              Text(
                'Niveau ${preview.playerLevel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: preview.playerLevel.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            label: '${preview.playerLevel}',
            onChanged: (double value) => onLevelChanged(value.round()),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simuler un profil enfant'),
            subtitle: const Text(
              'Affiche automatiquement les variantes Junior sans publicité.',
            ),
            value: preview.isChildProfile,
            onChanged: onChildProfileChanged,
          ),
          const Divider(height: 28),
          ...ChallengePeriod.values.map((ChallengePeriod period) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _SimulatedChallengeTile(
                period: period,
                challenges: preview.challengesFor(period),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SimulatedChallengeTile extends StatelessWidget {
  const _SimulatedChallengeTile({
    required this.period,
    required this.challenges,
  });

  final ChallengePeriod period;
  final List<ChallengeDefinition> challenges;

  @override
  Widget build(BuildContext context) {
    final ChallengeDefinition? challenge =
        challenges.isEmpty ? null : challenges.first;
    final bool conflict =
        period != ChallengePeriod.permanent && challenges.length > 1;
    final Color color = period == ChallengePeriod.daily
        ? GeoColors.coral
        : period == ChallengePeriod.weekly
            ? GeoColors.gold
            : GeoColors.purple;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: challenge == null ? 0.04 : 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: challenge == null ? 0.18 : 0.92),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              conflict
                  ? Icons.warning_amber_rounded
                  : challenge == null
                      ? Icons.visibility_off_rounded
                      : Icons.flag_rounded,
              color: conflict
                  ? GeoColors.coral
                  : challenge == null
                      ? Colors.white54
                      : GeoColors.navy,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  conflict
                      ? '${challenges.length} défis ${period.label.toLowerCase()}s actifs'
                      : challenge?.title ??
                          'Aucun défi ${period.label.toLowerCase()}',
                  style: TextStyle(
                    color: conflict
                        ? GeoColors.coral
                        : challenge == null
                            ? Colors.white54
                            : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  conflict
                      ? 'Conflit à corriger avant publication'
                      : challenge == null
                          ? 'Hors période, désactivé ou inaccessible'
                          : '${challenge.questionCount ?? 0} questions • '
                              '${challengeDifficultyLabel(challenge.difficultyId)} • '
                              '${challenge.reward.xp} XP',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          Icon(
            conflict
                ? Icons.error_rounded
                : challenge == null
                ? Icons.remove_circle_outline_rounded
                : Icons.check_circle_rounded,
            color: conflict
                ? GeoColors.coral
                : challenge == null
                    ? Colors.white38
                    : GeoColors.mint,
          ),
        ],
      ),
    );
  }
}

class _StudioIntroCard extends StatelessWidget {
  const _StudioIntroCard({required this.draftCount});

  final int draftCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF7957D5), Color(0xFF3C82E8)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.dashboard_customize_rounded,
              color: Colors.white, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$draftCount brouillon${draftCount > 1 ? 's' : ''}',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Espace privé de développement. Rien n’est publié automatiquement.',
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onEdit,
    required this.onDuplicate,
    required this.onToggleDisabled,
    required this.onDelete,
  });

  final ChallengeStudioDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleDisabled;
  final VoidCallback onDelete;

  String _date(DateTime date) {
    final DateTime local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = draft.period == ChallengePeriod.daily
        ? GeoColors.coral
        : draft.period == ChallengePeriod.weekly
            ? GeoColors.gold
            : GeoColors.purple;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFF152A4B).withValues(
              alpha: draft.disabled ? 0.68 : 0.96,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.65)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      draft.period.label.toUpperCase(),
                      style: const TextStyle(
                        color: GeoColors.navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (draft.disabled) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: GeoColors.coral.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'DÉSACTIVÉ',
                        style: TextStyle(
                          color: GeoColors.coral,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (String action) {
                      if (action == 'duplicate') {
                        onDuplicate();
                      }
                      if (action == 'delete') {
                        onDelete();
                      }
                      if (action == 'toggle') {
                        onToggleDisabled();
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy_rounded),
                          title: Text('Dupliquer'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'toggle',
                        child: ListTile(
                          leading: Icon(
                            draft.disabled
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          title: Text(
                            draft.disabled ? 'Réactiver' : 'Désactiver',
                          ),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Supprimer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                draft.title,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                draft.description,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _Tag(icon: Icons.schedule_rounded, text: '${_date(draft.validFromUtc)} → ${_date(draft.validUntilUtc)}'),
                  _Tag(icon: Icons.quiz_rounded, text: '${draft.questionCount} questions'),
                  _Tag(icon: Icons.check_circle_rounded, text: '${draft.minimumCorrectAnswers} bonnes'),
                  _Tag(icon: Icons.star_rounded, text: '${draft.rewardXp} XP'),
                  if (draft.minimumPlayerLevel > 1)
                    _Tag(
                      icon: Icons.military_tech_rounded,
                      text: 'Niveau ${draft.minimumPlayerLevel}',
                    ),
                  if (draft.ranked)
                    const _Tag(icon: Icons.leaderboard_rounded, text: 'Classé'),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('MODIFIER ET PRÉVISUALISER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: GeoColors.gold, size: 15),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

class _EmptyStudioCard extends StatelessWidget {
  const _EmptyStudioCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.add_chart_rounded, color: GeoColors.gold, size: 46),
          SizedBox(height: 12),
          Text(
            'Aucun brouillon pour le moment.\nAppuie sur « Nouveau défi » pour commencer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }
}
