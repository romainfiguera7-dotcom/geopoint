import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../challenges/challenge_definition.dart';
import '../../challenges/challenge_studio_draft.dart';
import '../../geo_engine/geo_country.dart';
import '../design/geopoint_design.dart';

class ChallengeStudioEditorScreen extends StatefulWidget {
  const ChallengeStudioEditorScreen({
    required this.draft,
    required this.countries,
    super.key,
  });

  final ChallengeStudioDraft draft;
  final List<GeoCountry> countries;

  @override
  State<ChallengeStudioEditorScreen> createState() =>
      _ChallengeStudioEditorScreenState();
}

class _ChallengeStudioEditorScreenState
    extends State<ChallengeStudioEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _questionCountController;
  late final TextEditingController _minimumCorrectController;
  late final TextEditingController _minimumScoreController;
  late final TextEditingController _xpController;
  late final TextEditingController _coinsController;
  late final TextEditingController _diamondsController;
  late final TextEditingController _progressionController;
  late ChallengePeriod _period;
  late String _modeId;
  late String _difficultyId;
  late String? _continentId;
  late Set<String> _countryIds;
  late DateTime _validFromUtc;
  late DateTime _validUntilUtc;

  static const Map<String, String> _modeLabels = <String, String>{
    'find_country': 'Trouver le pays',
    'find_capital': 'Trouver la capitale',
    'find_flag': 'Trouver le drapeau',
    'ultimate': 'Silhouettes',
    'mixed': 'Questions mixtes',
  };
  static const Map<String, String> _difficultyLabels = <String, String>{
    'discovery': 'Découverte',
    'easy': 'Facile',
    'intermediate': 'Intermédiaire',
    'hard': 'Difficile',
    'expert': 'Expert',
  };
  static const Map<String, String> _continentLabels = <String, String>{
    'world': 'Monde entier',
    'africa': 'Afrique',
    'americas': 'Amériques',
    'asia': 'Asie',
    'europe': 'Europe',
    'oceania': 'Océanie',
    'polar': 'Régions polaires',
  };

  @override
  void initState() {
    super.initState();
    final ChallengeStudioDraft draft = widget.draft;
    _idController = TextEditingController(text: draft.id);
    _titleController = TextEditingController(text: draft.title);
    _descriptionController = TextEditingController(text: draft.description);
    _questionCountController =
        TextEditingController(text: '${draft.questionCount}');
    _minimumCorrectController =
        TextEditingController(text: '${draft.minimumCorrectAnswers}');
    _minimumScoreController =
        TextEditingController(text: '${draft.minimumScore}');
    _xpController = TextEditingController(text: '${draft.rewardXp}');
    _coinsController = TextEditingController(text: '${draft.rewardCoins}');
    _diamondsController =
        TextEditingController(text: '${draft.rewardDiamonds}');
    _progressionController =
        TextEditingController(text: '${draft.progressionPoints}');
    _period = draft.period;
    _modeId = draft.modeId;
    _difficultyId = draft.difficultyId;
    _continentId = draft.continentId;
    _countryIds = draft.countryIds.toSet();
    _validFromUtc = draft.validFromUtc;
    _validUntilUtc = draft.validUntilUtc;
    for (final TextEditingController controller in <TextEditingController>[
      _titleController,
      _questionCountController,
      _minimumCorrectController,
      _xpController,
      _coinsController,
      _diamondsController,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _questionCountController.dispose();
    _minimumCorrectController.dispose();
    _minimumScoreController.dispose();
    _xpController.dispose();
    _coinsController.dispose();
    _diamondsController.dispose();
    _progressionController.dispose();
    super.dispose();
  }

  int _readInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  String? _requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;
  }

  String? _positiveInt(String? value) {
    final int? parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0 ? 'Entier supérieur à 0' : null;
  }

  String? _nonNegativeInt(String? value) {
    final int? parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 0 ? 'Entier positif ou nul' : null;
  }

  Future<void> _pickDate({required bool start}) async {
    final DateTime initial =
        (start ? _validFromUtc : _validUntilUtc).toLocal();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035, 12, 31),
      helpText: start ? 'DATE DE DÉBUT' : 'DATE DE FIN',
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: start ? 'HEURE DE DÉBUT' : 'HEURE DE FIN',
    );
    if (time == null || !mounted) {
      return;
    }
    final DateTime local = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _validFromUtc = local.toUtc();
      } else {
        _validUntilUtc = local.toUtc();
      }
    });
  }

  Future<void> _selectCountries() async {
    final Set<String> selection = <String>{..._countryIds};
    String query = '';
    final List<GeoCountry> sorted = <GeoCountry>[...widget.countries]
      ..sort((GeoCountry a, GeoCountry b) => a.name.compareTo(b.name));
    final Set<String>? result = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final List<GeoCountry> visible = sorted.where((GeoCountry country) {
              final String normalized = query.trim().toLowerCase();
              return normalized.isEmpty ||
                  country.name.toLowerCase().contains(normalized) ||
                  country.id.toLowerCase().contains(normalized);
            }).toList(growable: false);
            return AlertDialog(
              title: const Text('Choisir des pays'),
              content: SizedBox(
                width: 520,
                height: 520,
                child: Column(
                  children: <Widget>[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Rechercher',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (String value) {
                        setDialogState(() => query = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (BuildContext context, int index) {
                          final GeoCountry country = visible[index];
                          return CheckboxListTile(
                            value: selection.contains(country.id),
                            title: Text(country.displayNameWithFlag),
                            subtitle: Text(country.id),
                            onChanged: (bool? selected) {
                              setDialogState(() {
                                selected == true
                                    ? selection.add(country.id)
                                    : selection.remove(country.id);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('ANNULER'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selection),
                  child: Text('VALIDER (${selection.length})'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _countryIds = result);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_validFromUtc.isBefore(_validUntilUtc)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit suivre le début.')),
      );
      return;
    }
    final int questions = _readInt(_questionCountController);
    final int minimumCorrect = _readInt(_minimumCorrectController);
    if (minimumCorrect > questions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le minimum de réponses dépasse le nombre de questions.'),
        ),
      );
      return;
    }
    if (_continentId == null && _countryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis au moins un pays.')),
      );
      return;
    }
    Navigator.of(context).pop(
      ChallengeStudioDraft(
        id: _idController.text.trim().toLowerCase().replaceAll(' ', '_'),
        period: _period,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        validFromUtc: _validFromUtc,
        validUntilUtc: _validUntilUtc,
        modeId: _modeId,
        difficultyId: _difficultyId,
        continentId: _continentId,
        countryIds: _countryIds.toList()..sort(),
        questionCount: questions,
        minimumCorrectAnswers: minimumCorrect,
        minimumScore: _readInt(_minimumScoreController),
        rewardXp: _readInt(_xpController),
        rewardCoins: _readInt(_coinsController),
        rewardDiamonds: _readInt(_diamondsController),
        progressionPoints: _readInt(_progressionController),
        ranked: true,
        geoBrainPersonalizationAllowed: false,
        minimumPlayerLevel: 1,
        disabled: widget.draft.disabled,
      ),
    );
  }

  String _formatDate(DateTime utc) {
    final DateTime date = utc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle sectionStyle = GoogleFonts.fredoka(
      color: GeoColors.gold,
      fontSize: 19,
      fontWeight: FontWeight.w700,
    );
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                children: <Widget>[
                  GeoGameTopBar(
                    title: 'STUDIO',
                    subtitle: 'Configurer un défi',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 22),
                  _EditorPreview(
                    period: _period,
                    title: _titleController.text.trim(),
                    questionCount: _readInt(_questionCountController),
                    minimumCorrect: _readInt(_minimumCorrectController),
                    xp: _readInt(_xpController),
                    coins: _readInt(_coinsController),
                    diamonds: _readInt(_diamondsController),
                  ),
                  const SizedBox(height: 16),
                  _StudioPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Identité', style: sectionStyle),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _idController,
                          validator: (String? value) {
                            final String? required = _requiredText(value);
                            if (required != null) {
                              return required;
                            }
                            return RegExp(r'^[a-zA-Z0-9_-]+$')
                                    .hasMatch(value!.trim())
                                ? null
                                : 'Utilise lettres, chiffres, _ ou -';
                          },
                          decoration: _decoration('Identifiant technique'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          validator: _requiredText,
                          decoration: _decoration('Titre affiché'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          validator: _requiredText,
                          maxLines: 3,
                          decoration: _decoration('Description'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StudioPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Calendrier', style: sectionStyle),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<ChallengePeriod>(
                          initialValue: _period,
                          decoration: _decoration('Rythme'),
                          items: ChallengePeriod.values.map((ChallengePeriod value) {
                            return DropdownMenuItem<ChallengePeriod>(
                              value: value,
                              child: Text(value.label),
                            );
                          }).toList(growable: false),
                          onChanged: (ChallengePeriod? value) {
                            if (value != null) {
                              setState(() => _period = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _DateButton(
                          label: 'Début',
                          value: _formatDate(_validFromUtc),
                          onPressed: () => _pickDate(start: true),
                        ),
                        const SizedBox(height: 10),
                        _DateButton(
                          label: 'Fin',
                          value: _formatDate(_validUntilUtc),
                          onPressed: () => _pickDate(start: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StudioPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Partie', style: sectionStyle),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _modeId,
                          decoration: _decoration('Type de questions'),
                          items: _modeLabels.entries.map((MapEntry<String, String> entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(growable: false),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() => _modeId = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _difficultyId,
                          decoration: _decoration('Difficulté'),
                          items: _difficultyLabels.entries.map((MapEntry<String, String> entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(growable: false),
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() => _difficultyId = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String?>(_continentId),
                          initialValue: _continentId,
                          decoration: _decoration('Zone géographique'),
                          items: <DropdownMenuItem<String>>[
                            ..._continentLabels.entries.map(
                              (MapEntry<String, String> entry) =>
                                  DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            ),
                          ],
                          onChanged: (String? value) {
                            setState(() {
                              _continentId = value;
                              _countryIds.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _selectCountries();
                            if (_countryIds.isNotEmpty && mounted) {
                              setState(() => _continentId = null);
                            }
                          },
                          icon: const Icon(Icons.public_rounded),
                          label: Text(
                            _countryIds.isEmpty
                                ? 'CHOISIR DES PAYS PRÉCIS'
                                : '${_countryIds.length} PAYS SÉLECTIONNÉS',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                controller: _questionCountController,
                                validator: _positiveInt,
                                keyboardType: TextInputType.number,
                                decoration: _decoration('Questions'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _minimumCorrectController,
                                validator: _nonNegativeInt,
                                keyboardType: TextInputType.number,
                                decoration: _decoration('Bonnes réponses'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _minimumScoreController,
                          validator: _nonNegativeInt,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Score minimum (0 = aucun)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StudioPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Récompenses', style: sectionStyle),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(child: _numberField(_xpController, 'XP')),
                            const SizedBox(width: 8),
                            Expanded(child: _numberField(_coinsController, 'Pièces')),
                            const SizedBox(width: 8),
                            Expanded(child: _numberField(_diamondsController, 'Diamants')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _numberField(_progressionController, 'Progression défi'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StudioPanel(
                    child: Column(
                      children: <Widget>[
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.leaderboard_rounded,
                            color: GeoColors.purple,
                          ),
                          title: Text('Classement automatique'),
                          subtitle: Text(
                            'Accessible dès le niveau 1 avec les mêmes règles '
                            'pour tous les joueurs adultes.',
                          ),
                        ),
                        const Divider(),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.replay_rounded, color: GeoColors.gold),
                          title: Text('Relances automatiques'),
                          subtitle: Text(
                            'Adulte : 1 essai gratuit, puis publicité illimitée. '
                            'Enfant : reprises gratuites, sans publicité.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('ENREGISTRER LE BROUILLON'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      validator: _nonNegativeInt,
      keyboardType: TextInputType.number,
      decoration: _decoration(label),
    );
  }
}

class _StudioPanel extends StatelessWidget {
  const _StudioPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF152A4B).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _EditorPreview extends StatelessWidget {
  const _EditorPreview({
    required this.period,
    required this.title,
    required this.questionCount,
    required this.minimumCorrect,
    required this.xp,
    required this.coins,
    required this.diamonds,
  });

  final ChallengePeriod period;
  final String title;
  final int questionCount;
  final int minimumCorrect;
  final int xp;
  final int coins;
  final int diamonds;

  @override
  Widget build(BuildContext context) {
    final Color accent = period == ChallengePeriod.daily
        ? GeoColors.coral
        : period == ChallengePeriod.weekly
            ? GeoColors.gold
            : GeoColors.purple;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.92),
            const Color(0xFF284F82),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'APERÇU — ${period.label.toUpperCase()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title.isEmpty ? 'Titre du défi' : title,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _PreviewChip(text: '$questionCount questions'),
              _PreviewChip(text: '$minimumCorrect à réussir'),
              const _PreviewChip(text: 'Accessible à tous'),
              _PreviewChip(text: '$xp XP'),
              if (coins > 0) _PreviewChip(text: '$coins pièces'),
              if (diamonds > 0) _PreviewChip(text: '$diamonds diamant(s)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit_calendar_rounded),
      onTap: onPressed,
    );
  }
}
