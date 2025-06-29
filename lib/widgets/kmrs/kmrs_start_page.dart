import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../../services/kmrs_service.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';
import '../../models/kmrs_models.dart';
import '../../theme/racing_theme.dart';
import '../common/glassmorphism_section_card.dart';
import '../common/glassmorphism_input_field.dart';
import 'glassmorphism_pilot_card.dart';

/// Start Page KMRS - Configuration de la session de course (14 inputs authentiques)
/// Reproduit exactement la première feuille Excel KMRS selon Strategie.txt
class KmrsStartPage extends StatefulWidget {
  final KmrsService kmrsService;
  final Function(RaceConfiguration) onConfigurationChanged;

  const KmrsStartPage({
    super.key,
    required this.kmrsService,
    required this.onConfigurationChanged,
  });

  @override
  State<KmrsStartPage> createState() => _KmrsStartPageState();
}

class _KmrsStartPageState extends State<KmrsStartPage> {
  final _formKey = GlobalKey<FormState>();
  late RaceConfiguration _config;
  final List<PilotData> _pilots = [];

  // Controllers pour les 7 inputs KMRS simplifiés
  final _minStintTimeController = TextEditingController();           // Minimum Stint Time (Minutes)
  final _maxStintTimeController = TextEditingController();           // Maximum Stint Time (Minutes)
  final _requiredPitstopsController = TextEditingController();       // Required Pitstops
  final _pitLaneClosedStartController = TextEditingController();     // Pit Lane Closed Start (Minutes)
  final _pitLaneClosedEndController = TextEditingController();       // Pit Lane Closed End (Minutes)
  final _tempsRoulageMinController = TextEditingController();        // Temps Roulage Min/Pilote
  final _tempsRoulageMaxController = TextEditingController();        // Temps Roulage Max/Pilote
  
  // 2 inputs complémentaires
  final _sessionNameController = TextEditingController();            // Nom de session
  final _trackNameController = TextEditingController();              // Nom du circuit

  // Race Duration comme dropdown (1-30 heures)
  double _raceDurationHours = 4.0;
  final List<double> _raceDurationOptions = List.generate(30, (index) => (index + 1).toDouble());

  @override
  void initState() {
    super.initState();
    _initializeFromSession();
  }

  @override
  void dispose() {
    // Controllers KMRS simplifiés
    _minStintTimeController.dispose();
    _maxStintTimeController.dispose();
    _requiredPitstopsController.dispose();
    _pitLaneClosedStartController.dispose();
    _pitLaneClosedEndController.dispose();
    _tempsRoulageMinController.dispose();
    _tempsRoulageMaxController.dispose();
    
    // Controllers complémentaires
    _sessionNameController.dispose();
    _trackNameController.dispose();
    super.dispose();
  }

  void _initializeFromSession() async {
    final session = widget.kmrsService.currentSession;
    if (session != null) {
      _config = session.configuration;
      // BUG FIX: Ne pas copier les pilotes ici, utiliser directement ceux du service
      _pilots.clear(); // Vider la liste locale pour éviter les doublons
      
      // Initialiser avec la configuration KMRS simplifiée
      _sessionNameController.text = session.sessionName;
      
      // Auto-populer le nom du circuit depuis la configuration
      await _loadCircuitNameFromConfig();
      
      _raceDurationHours = _config.raceDurationHours;
      _minStintTimeController.text = _config.minStintTimeMinutes.toString();
      _maxStintTimeController.text = _config.maxStintTimeMinutes.toString();
      _requiredPitstopsController.text = _config.requiredPitstops.toString();
      _pitLaneClosedStartController.text = _config.pitLaneClosedStartMinutes.toString();
      _pitLaneClosedEndController.text = _config.pitLaneClosedEndMinutes.toString();
      _tempsRoulageMinController.text = _config.tempsRoulageMinPilote.toString();
      _tempsRoulageMaxController.text = _config.tempsRoulageMaxPilote.toString();
    } else {
      _config = RaceConfiguration.defaultConfig();
      await _initializeDefaultValues();
    }
  }

  Future<void> _initializeDefaultValues() async {
    // Valeurs par défaut KMRS simplifiées
    _sessionNameController.text = 'Session KMRS ${DateTime.now().day}/${DateTime.now().month}';
    
    // Auto-populer le nom du circuit depuis la configuration
    await _loadCircuitNameFromConfig();
    
    _raceDurationHours = 4.0;                     // 4 heures (exemple du fichier)
    _minStintTimeController.text = '15';          // 15 minutes minimum
    _maxStintTimeController.text = '50';          // 50 minutes maximum
    _requiredPitstopsController.text = '7';       // 7 arrêts obligatoires
    _pitLaneClosedStartController.text = '15';    // 15 min fermé début
    _pitLaneClosedEndController.text = '15';      // 15 min fermé fin
    _tempsRoulageMinController.text = '120';      // 120 min minimum par pilote
    _tempsRoulageMaxController.text = '240';      // 240 min maximum par pilote
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RacingTheme.racingBlack,
              Colors.grey[900]!,
              RacingTheme.racingBlack,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: _buildResponsiveLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 768;
    
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildSessionInfoSection(),
                _buildRaceParametersSection(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildTeamManagementSection(),
                _buildActionsSection(),
              ],
            ),
          ),
        ],
      );
    } else if (isTablet) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSessionInfoSection()),
              const SizedBox(width: 16),
              Expanded(child: _buildRaceParametersSection()),
            ],
          ),
          _buildTeamManagementSection(),
          _buildActionsSection(),
        ],
      );
    } else {
      return Column(
        children: [
          _buildSessionInfoSection(),
          _buildRaceParametersSection(),
          _buildTeamManagementSection(),
          _buildActionsSection(),
        ],
      );
    }
  }


  Widget _buildSessionInfoSection() {
    return GlassmorphismSectionCardCompact(
      title: 'Informations de Session',
      subtitle: 'Configuration générale de la course',
      icon: Icons.info_outline,
      accentColor: RacingTheme.racingGreen,
      children: [
        GlassmorphismInputField(
          label: 'Nom de la session',
          controller: _sessionNameController,
          icon: Icons.title,
          hint: 'Session KMRS du jour',
          accentColor: RacingTheme.racingGreen,
        ),
        const SizedBox(height: 20),
        GlassmorphismInputField(
          label: 'Circuit de karting',
          controller: _trackNameController,
          icon: Icons.location_on,
          hint: 'Nom du circuit',
          accentColor: RacingTheme.racingGreen,
          readOnly: true,
        ),
        const SizedBox(height: 20),
        GlassmorphismDropdownField<double>(
          label: 'Durée de la course',
          icon: Icons.timer,
          value: _raceDurationHours,
          hint: 'Sélectionnez la durée',
          accentColor: RacingTheme.racingGreen,
          items: _raceDurationOptions.map((hours) {
            return DropdownMenuItem<double>(
              value: hours,
              child: Text(
                '${hours.toInt()} heure${hours > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _raceDurationHours = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildRaceParametersSection() {
    return GlassmorphismSectionCardCompact(
      title: 'Paramètres de Course KMRS',
      subtitle: 'Configuration technique des relais et arrêts',
      icon: Icons.engineering,
      accentColor: Colors.orange,
      children: [
        // Temps de relais
        Row(
          children: [
            Expanded(
              child: GlassmorphismInputField(
                label: 'Relais minimum',
                controller: _minStintTimeController,
                icon: Icons.timer_outlined,
                hint: '15 min',
                inputType: TextInputType.number,
                accentColor: Colors.orange,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassmorphismInputField(
                label: 'Relais maximum',
                controller: _maxStintTimeController,
                icon: Icons.timer,
                hint: '50 min',
                inputType: TextInputType.number,
                accentColor: Colors.orange,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Arrêts obligatoires
        GlassmorphismInputField(
          label: 'Arrêts obligatoires',
          controller: _requiredPitstopsController,
          icon: Icons.local_gas_station,
          hint: 'Nombre d\'arrêts requis',
          inputType: TextInputType.number,
          accentColor: Colors.orange,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 20),
        
        // Fermeture pit lane
        Row(
          children: [
            Expanded(
              child: GlassmorphismInputField(
                label: 'Fermeture début',
                controller: _pitLaneClosedStartController,
                icon: Icons.block,
                hint: '15 min',
                inputType: TextInputType.number,
                accentColor: Colors.orange,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassmorphismInputField(
                label: 'Fermeture fin',
                controller: _pitLaneClosedEndController,
                icon: Icons.block,
                hint: '15 min',
                inputType: TextInputType.number,
                accentColor: Colors.orange,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Temps pilote
        Row(
          children: [
            Expanded(
              child: GlassmorphismInputField(
                label: 'Temps min/pilote',
                controller: _tempsRoulageMinController,
                icon: Icons.person_outline,
                hint: '120 min',
                inputType: TextInputType.number,
                accentColor: Colors.orange,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassmorphismInputField(
                label: 'Temps max/pilote',
                controller: _tempsRoulageMaxController,
                icon: Icons.person,
                hint: '240 min',
                inputType: TextInputType.number,
                accentColor: Colors.orange,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamManagementSection() {
    // ✅ Double réactivité : StreamBuilder + ListenableBuilder pour affichage instantané
    return StreamBuilder<RaceSession?>(
      stream: widget.kmrsService.getKmrsSessionStream(),
      builder: (context, snapshot) {
        return ListenableBuilder(
          listenable: widget.kmrsService,
          builder: (context, _) {
            // Utiliser les données du cache service (optimistic) ou stream (confirmation)
            final session = widget.kmrsService.currentSession ?? snapshot.data;
            final servicePilots = session?.pilots ?? [];
            
            if (kDebugMode) {
              print('🔧 TeamManagement: Rebuilding with ${servicePilots.length} pilots');
            }
            
            return GlassmorphismSectionCardCompact(
              title: 'Équipe de Pilotes',
              subtitle: '${servicePilots.length} pilote${servicePilots.length > 1 ? 's' : ''} configuré${servicePilots.length > 1 ? 's' : ''}',
              icon: Icons.people,
              accentColor: Colors.teal,
              children: [
                ...servicePilots.asMap().entries.map((entry) {
                  final index = entry.key;
                  final pilot = entry.value;
                  return GlassmorphismPilotCard(
                    pilot: pilot,
                    index: index,
                    onEdit: () => _editPilot(index),
                    onDelete: () => _removePilot(index),
                    accentColor: Colors.teal,
                  );
                }).toList(),
                const SizedBox(height: 16),
                GlassmorphismAddPilotButton(
                  onPressed: _addPilot,
                  accentColor: Colors.teal,
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildActionsSection() {
    return GlassmorphismSectionCardCompact(
      title: 'Actions de Configuration',
      subtitle: 'Sauvegarder ou réinitialiser les paramètres',
      icon: Icons.settings,
      accentColor: RacingTheme.racingGreen,
      children: [
        _buildGlassmorphismButton(
          label: 'Sauvegarder Configuration',
          icon: Icons.save,
          color: RacingTheme.racingGreen,
          onPressed: _saveConfiguration,
        ),
        const SizedBox(height: 16),
        _buildGlassmorphismButton(
          label: 'Réinitialiser',
          icon: Icons.refresh,
          color: Colors.orange,
          onPressed: _resetToDefaults,
        ),
      ],
    );
  }

  Widget _buildGlassmorphismButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




  void _addPilot() {
    _showPilotDialog();
  }

  void _editPilot(int index) {
    final servicePilots = widget.kmrsService.currentSession?.pilots ?? [];
    if (index < servicePilots.length) {
      _showPilotDialog(pilot: servicePilots[index], index: index);
    }
  }

  void _removePilot(int index) {
    final servicePilots = widget.kmrsService.currentSession?.pilots ?? [];
    if (index < servicePilots.length) {
      final pilotToRemove = servicePilots[index];
      widget.kmrsService.removePilot(pilotToRemove.id);
    }
  }

  void _showPilotDialog({PilotData? pilot, int? index}) {
    final nameController = TextEditingController(text: pilot?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.teal.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              pilot == null ? Icons.person_add : Icons.edit,
                              color: Colors.teal,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pilot == null ? 'Ajouter un pilote' : 'Modifier le pilote',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Configuration de l\'équipe',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Input
                      GlassmorphismInputField(
                        label: 'Nom complet du pilote',
                        controller: nameController,
                        icon: Icons.person,
                        hint: 'Prénom Nom',
                        accentColor: Colors.teal,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom du pilote est requis';
                          }
                          if (value.trim().length < 2) {
                            return 'Le nom doit contenir au moins 2 caractères';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogButton(
                              label: 'Annuler',
                              icon: Icons.close,
                              color: Colors.grey,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogButton(
                              label: 'Sauvegarder',
                              icon: Icons.check,
                              color: Colors.teal,
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  final updatedPilot = PilotData(
                                    id: pilot?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                    name: nameController.text.trim(),
                                    nickname: nameController.text.trim().split(' ').first,
                                    bestLapTime: pilot?.bestLapTime ?? Duration.zero,
                                    averageLapTime: pilot?.averageLapTime ?? const Duration(seconds: 90),
                                    lapTimes: pilot?.lapTimes ?? [],
                                    totalLaps: pilot?.totalLaps ?? 0,
                                    totalDriveTime: pilot?.totalDriveTime ?? Duration.zero,
                                    skillLevel: pilot?.skillLevel ?? 0.5,
                                    statistics: pilot?.statistics ?? {},
                                  );

                                  widget.kmrsService.updatePilot(updatedPilot);
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveConfiguration() {
    if (_formKey.currentState!.validate()) {
      // Créer la configuration KMRS simplifiée avec les 7 inputs
      final newConfig = RaceConfiguration(
        // Les 7 inputs KMRS simplifiés
        raceDurationHours: _raceDurationHours,
        minStintTimeMinutes: int.tryParse(_minStintTimeController.text) ?? 15,
        maxStintTimeMinutes: int.tryParse(_maxStintTimeController.text) ?? 50,
        requiredPitstops: int.tryParse(_requiredPitstopsController.text) ?? 7,
        pitLaneClosedStartMinutes: int.tryParse(_pitLaneClosedStartController.text) ?? 15,
        pitLaneClosedEndMinutes: int.tryParse(_pitLaneClosedEndController.text) ?? 15,
        pitstopFixDuration: const Duration(minutes: 2), // Valeur fixe par défaut
        tempsRoulageMinPilote: int.tryParse(_tempsRoulageMinController.text) ?? 120,
        tempsRoulageMaxPilote: int.tryParse(_tempsRoulageMaxController.text) ?? 240,
        
        // Inputs complémentaires avec valeurs par défaut
        raceType: 'Endurance',
        trackName: _trackNameController.text.isEmpty ? 'Circuit par défaut' : _trackNameController.text,
        numberOfPilots: widget.kmrsService.currentSession?.pilots.length ?? 0, // Nombre basé sur les pilotes du service
        averageLapTime: const Duration(seconds: 90), // Valeur par défaut
        customSettings: {},
      );

      widget.onConfigurationChanged(newConfig);

      // BUG FIX: Ne pas sauvegarder les pilotes ici pour éviter la duplication
      // Les pilotes sont déjà gérés par l'interface de pilotes séparément

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration KMRS simplifiée sauvegardée avec succès'),
          backgroundColor: RacingTheme.racingGreen,
        ),
      );
    }
  }

  Future<void> _loadCircuitNameFromConfig() async {
    try {
      final sessionDoc = await SessionService.getSession();
      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data();
        final selectedCircuitId = sessionData?['selectedCircuitId'] as String?;
        
        if (selectedCircuitId != null && selectedCircuitId.isNotEmpty) {
          final circuitName = await CircuitService.getCircuitName(selectedCircuitId);
          if (circuitName != null && mounted) {
            setState(() {
              _trackNameController.text = circuitName;
            });
          }
        } else if (mounted) {
          // Aucun circuit sélectionné dans la configuration
          setState(() {
            _trackNameController.text = 'Aucun circuit sélectionné';
          });
        }
      } else if (mounted) {
        // Configuration par défaut
        setState(() {
          _trackNameController.text = 'Circuit par défaut';
        });
      }
    } catch (e) {
      // En cas d'erreur, utiliser une valeur par défaut
      if (mounted) {
        setState(() {
          _trackNameController.text = 'Circuit par défaut';
        });
      }
    }
  }

  void _resetToDefaults() {
    setState(() {
      _config = RaceConfiguration.defaultConfig();
      _initializeDefaultValues();
    });
    
    // Réinitialiser complètement la session pour éviter les doublons
    widget.kmrsService.resetSession();
  }
}