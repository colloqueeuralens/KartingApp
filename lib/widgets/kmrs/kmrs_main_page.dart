import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import '../../services/kmrs_service.dart';
import '../../models/kmrs_models.dart';
import '../../theme/racing_theme.dart';
import '../common/glassmorphism_section_card.dart';
import '../common/glassmorphism_input_field.dart';

/// Main Page KMRS - Interface authentique avec 5 inputs + 3 tableaux
/// Reproduit exactement la Main Page Excel selon Strategie.txt
class KmrsMainPage extends StatefulWidget {
  final KmrsService kmrsService;
  final Function(String, Duration, Duration, Duration?, Duration?, String) onStintAdded;

  const KmrsMainPage({
    super.key,
    required this.kmrsService,
    required this.onStintAdded,
  });

  @override
  State<KmrsMainPage> createState() => _KmrsMainPageState();
}

class _KmrsMainPageState extends State<KmrsMainPage> {
  // Controllers pour les 5 vrais inputs KMRS selon Strategie.txt
  final _lastStintDurationMinutesController = TextEditingController();  // Last stint duration (mm:ss) - Minutes
  final _lastStintDurationSecondsController = TextEditingController();  // Last stint duration (mm:ss) - Seconds
  final _pitstopMinutesController = TextEditingController();            // Pitstop (mm:ss) - Minutes
  final _pitstopSecondsController = TextEditingController();            // Pitstop (mm:ss) - Seconds
  final _pitInMinutesController = TextEditingController();              // Pit In (mm:ss) - Minutes
  final _pitInSecondsController = TextEditingController();              // Pit In (mm:ss) - Seconds
  final _pitOutMinutesController = TextEditingController();             // Pit Out (mm:ss) - Minutes
  final _pitOutSecondsController = TextEditingController();             // Pit Out (mm:ss) - Seconds
  
  String? _selectedPilotId;

  // State management pour le chrono de course
  Timer? _raceTimer;
  bool _isRaceRunning = false;
  DateTime? _raceStartTime;
  Duration _currentRaceDuration = Duration.zero;

  @override
  void dispose() {
    // Controllers KMRS authentiques
    _lastStintDurationMinutesController.dispose();
    _lastStintDurationSecondsController.dispose();
    _pitstopMinutesController.dispose();
    _pitstopSecondsController.dispose();
    _pitInMinutesController.dispose();
    _pitInSecondsController.dispose();
    _pitOutMinutesController.dispose();
    _pitOutSecondsController.dispose();
    
    // Nettoyage du timer
    _raceTimer?.cancel();
    super.dispose();
  }

  // Méthodes pour gérer le chrono de course
  void _startRaceTimer() {
    if (!_isRaceRunning) {
      setState(() {
        _isRaceRunning = true;
        _raceStartTime = DateTime.now();
      });
      
      _raceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateRaceTime();
      });
    }
  }

  void _stopRaceTimer() {
    setState(() {
      _isRaceRunning = false;
    });
    _raceTimer?.cancel();
  }

  void _updateRaceTime() {
    if (_raceStartTime != null) {
      setState(() {
        _currentRaceDuration = DateTime.now().difference(_raceStartTime!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: StreamBuilder<RaceSession?>(
        stream: widget.kmrsService.getKmrsSessionStream(),
        builder: (context, snapshot) {
          // Gestion d'erreur
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.all(24),
            child: _buildResponsiveLayout(context),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    
    if (isDesktop) {
      // Layout desktop : Row avec colonnes 35%/65%
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne gauche: Inputs KMRS (35%)
          Expanded(
            flex: 2,
            child: _buildKmrsInputsSection(),
          ),
          const SizedBox(width: 24),
          
          // Colonne droite: Tableaux de données (65%)
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTrackingDrivingTimeTable(),
                  const SizedBox(height: 20),
                  _buildStrategieCalculationTable(),
                  const SizedBox(height: 20),
                  _buildSuiviDeCourseTable(),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Layout mobile/tablet : Tout en colonne
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildKmrsInputsSection(),
            SizedBox(height: isMobile ? 16 : 20),
            _buildTrackingDrivingTimeTable(),
            SizedBox(height: isMobile ? 16 : 20),
            _buildStrategieCalculationTable(),
            SizedBox(height: isMobile ? 16 : 20),
            _buildSuiviDeCourseTable(),
          ],
        ),
      );
    }
  }


  Widget _buildKmrsInputsSection() {
    final session = widget.kmrsService.currentSession;
    final pilots = session?.pilots ?? [];
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    
    // Largeur adaptative du dropdown pilote
    double pilotDropdownWidth;
    if (isMobile) {
      pilotDropdownWidth = screenWidth * 0.9; // 90% sur mobile
    } else if (isTablet) {
      pilotDropdownWidth = screenWidth * 0.7; // 70% sur tablet
    } else {
      pilotDropdownWidth = screenWidth * 0.3; // 30% sur desktop
    }
    
    return GlassmorphismSectionCardCompact(
      title: 'Chronométrage KMRS',
      subtitle: 'Saisie des temps de relais et arrêts',
      icon: Icons.timer,
      accentColor: Colors.blue,
      children: [
        // Sélection du pilote (responsive)
        Center(
          child: SizedBox(
            width: pilotDropdownWidth,
            child: _buildPilotSelectionGlass(pilots),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        
        // Durée du relais + Pit Stop (responsive)
        if (isMobile) ...[
          // Mobile : En colonne pour plus de lisibilité
          _buildTimeInputSection(
            'Durée du relais',
            Icons.timer,
            _lastStintDurationMinutesController,
            _lastStintDurationSecondsController,
            '',
          ),
          const SizedBox(height: 12),
          _buildTimeInputSection(
            'Pit Stop',
            Icons.build_circle,
            _pitstopMinutesController,
            _pitstopSecondsController,
            '',
          ),
        ] else ...[
          // Tablet/Desktop : En ligne
          Row(
            children: [
              Expanded(
                child: _buildTimeInputSection(
                  'Durée du relais',
                  Icons.timer,
                  _lastStintDurationMinutesController,
                  _lastStintDurationSecondsController,
                  '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeInputSection(
                  'Pit Stop',
                  Icons.build_circle,
                  _pitstopMinutesController,
                  _pitstopSecondsController,
                  '',
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: isMobile ? 12 : 8),
        
        // Pit In + Pit Out (responsive)
        if (isMobile) ...[
          // Mobile : En colonne
          _buildTimeInputSection(
            'Pit In',
            Icons.login,
            _pitInMinutesController,
            _pitInSecondsController,
            '',
          ),
          const SizedBox(height: 12),
          _buildTimeInputSection(
            'Pit Out',
            Icons.logout,
            _pitOutMinutesController,
            _pitOutSecondsController,
            '',
          ),
        ] else ...[
          // Tablet/Desktop : En ligne
          Row(
            children: [
              Expanded(
                child: _buildTimeInputSection(
                  'Pit In',
                  Icons.login,
                  _pitInMinutesController,
                  _pitInSecondsController,
                  '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeInputSection(
                  'Pit Out',
                  Icons.logout,
                  _pitOutMinutesController,
                  _pitOutSecondsController,
                  '',
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: isMobile ? 16 : 12),
        
        // Bouton de sauvegarde
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildPilotSelectionGlass(List<PilotData> pilots) {
    return GlassmorphismDropdownField<String>(
      label: 'Pilote du relais',
      icon: Icons.person,
      value: _selectedPilotId ?? (pilots.isNotEmpty ? pilots.first.id : ''),
      hint: 'Sélectionnez le pilote',
      accentColor: Colors.blue,
      items: pilots.map((pilot) {
        return DropdownMenuItem<String>(
          value: pilot.id,
          child: Text(
            pilot.name,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedPilotId = value;
        });
      },
    );
  }

  Widget _buildTimeInputSection(
    String title,
    IconData icon,
    TextEditingController minutesController,
    TextEditingController secondsController,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GlassmorphismInputField(
                label: 'Minutes',
                controller: minutesController,
                icon: Icons.schedule,
                hint: '00',
                inputType: TextInputType.number,
                accentColor: Colors.blue,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                ':',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GlassmorphismInputField(
                label: 'Secondes',
                controller: secondsController,
                icon: Icons.schedule,
                hint: '00',
                inputType: TextInputType.number,
                accentColor: Colors.blue,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saveRelayData,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isMobile ? 18 : 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withValues(alpha: 0.8),
                Colors.blue.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.save,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Enregistrer le Relais',
                style: TextStyle(
                  color: Colors.white,
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

  Widget _buildTrackingDrivingTimeTable() {
    final session = widget.kmrsService.currentSession;
    final pilots = session?.pilots ?? [];
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Headers et flexValues pour ce tableau
    final headers = ['Pilotes', 'Drive Time', 'Relais', 'Min Rest.', 'Max Rest.'];
    final mobileHeaders = ['Pilotes', 'Drive Time', 'Relais', 'Min Rest.', 'Max Rest.']; // Headers abrégés pour mobile
    final flexValues = [25, 20, 12, 21, 22]; // Ajustés pour mobile
    
    Widget tableContent = Column(
      children: [
        // Headers avec le système responsive
        _buildResponsiveTableHeader(headers, flexValues, Colors.teal, mobileHeaders: mobileHeaders),
        SizedBox(height: isMobile ? 2 : 6),
        
        // Data rows
        ...pilots.map((pilot) {
          final pilotStints = session?.stints.where((s) => s.pilotId == pilot.id).toList() ?? [];
          final totalDriveTime = pilotStints.map((s) => s.actualDuration).fold(Duration.zero, (a, b) => a + b);
          final nbRelais = pilotStints.length;
          
          // Calcul KMRS: Temps Min/Max restant - Précision milliseconde
          final config = session?.configuration;
          final tempsMinRestantMs = ((config?.tempsRoulageMinPilote ?? 120) * 60 * 1000) - totalDriveTime.inMilliseconds;
          final tempsMaxRestantMs = ((config?.tempsRoulageMaxPilote ?? 240) * 60 * 1000) - totalDriveTime.inMilliseconds;
          final tempsMinRestantDuration = Duration(milliseconds: tempsMinRestantMs.clamp(0, double.infinity).toInt());
          final tempsMaxRestantDuration = Duration(milliseconds: tempsMaxRestantMs.clamp(0, double.infinity).toInt());
          
          final rowData = [
            pilot.name,
            _formatDurationResponsive(totalDriveTime),
            nbRelais.toString(),
            _formatDurationResponsive(tempsMinRestantDuration),
            _formatDurationResponsive(tempsMaxRestantDuration),
          ];
          
          return _buildResponsiveTableRow(rowData, flexValues);
        }).toList(),
        
        if (pilots.isEmpty)
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            child: Text(
              'Aucun pilote configuré',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: isMobile ? 8 : 14,
              ),
            ),
          ),
      ],
    );
    
    return GlassmorphismSectionCardCompact(
      title: 'Temps de Conduite',
      subtitle: 'Suivi des temps par pilote et relais effectués',
      icon: Icons.schedule,
      accentColor: Colors.teal,
      children: [
        // Plus de scroll horizontal : tout s'affiche en pleine largeur
        tableContent,
      ],
    );
  }

  Widget _buildStrategieCalculationTable() {
    final session = widget.kmrsService.currentSession;
    final config = session?.configuration;
    
    if (config == null) {
      return GlassmorphismSectionCardCompact(
        title: 'Calculs Stratégiques',
        subtitle: 'Configuration KMRS requise',
        icon: Icons.calculate,
        accentColor: Colors.orange,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Veuillez configurer les paramètres KMRS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    // FORMULE EXCEL KMRS AUTHENTIQUE - Calcul dynamique temps réel
    final stintsCompleted = session?.stints ?? [];
    final nombreTotalRelais = config.requiredPitstops + 1;
    
    // Calcul du temps restant de course (en minutes, avec décimales)
    final tempsTotalCourseMinutes = config.raceDurationHours * 60;
    final tempsEcouleMinutes = stintsCompleted.fold<double>(0.0, (total, stint) => 
      total + stint.actualDuration.inMinutes + (stint.actualDuration.inSeconds % 60) / 60.0 + 
      stint.pitStopDuration.inMinutes + (stint.pitStopDuration.inSeconds % 60) / 60.0);
    final tempsRestantMinutes = tempsTotalCourseMinutes - tempsEcouleMinutes;
    
    // Nombre de relais et d'arrêts restants
    final nombreRelaisRestants = nombreTotalRelais - stintsCompleted.length;
    final nombreArretsRestants = config.requiredPitstops - stintsCompleted.length;
    
    // Temps restant avant fermeture pit lane (en minutes, puis converti en fraction de jour)
    final tempsAvantPitlaneClosedMinutes = tempsRestantMinutes - config.pitLaneClosedEndMinutes;
    final tempsAvantPitlaneClosedFraction = tempsAvantPitlaneClosedMinutes / 1440; // Conversion en fraction de jour (Excel)
    
    // FORMULE EXCEL KMRS EXACTE
    // =ENT((B7 - B12 * 'Start Page'!B2 - 'Main Page'!B11 * 'Main Page'!B10) / ('Start Page'!B3- 'Start Page'!B2))
    // Excel utilise les fractions de jour pour B10 (temps avant pitlane closed)
    final numerateur = tempsRestantMinutes - 
                      (nombreRelaisRestants * config.minStintTimeMinutes) - 
                      (nombreArretsRestants * tempsAvantPitlaneClosedFraction);
    final denominateur = config.maxStintTimeMinutes - config.minStintTimeMinutes;
    
    final regularStints = denominateur != 0 ? (numerateur / denominateur).floor().clamp(0, nombreRelaisRestants) : 0;
    final jokerStints = nombreRelaisRestants - regularStints;
    final avgJokerDuration = config.minStintTimeMinutes.toDouble(); // Durée théorique des jokers (15 min)
    
    // CALCUL DE LA DURÉE MAXIMUM DU RELAIS ACTUEL
    // Formule : TempsRestantTotal - (ArretsRestants × TempsArret) - ((RelaisRestants - 1) × TempsRelaisMin) - Marge
    final dureeMaxRelaisActuelBrute = tempsRestantMinutes - 
                                     (nombreArretsRestants * config.pitstopFixDuration.inMinutes) - 
                                     ((nombreRelaisRestants - 1) * config.minStintTimeMinutes);
    final dureeMaxRelaisActuel = dureeMaxRelaisActuelBrute - 0.5; // Marge de sécurité de 30 secondes
    final maxCurrentStint = dureeMaxRelaisActuel > 0 ? dureeMaxRelaisActuel : 0.0;
    
    return GlassmorphismSectionCardCompact(
      title: 'Calculs Stratégiques KMRS',
      subtitle: 'Optimisation des relais et temps maximum actuel',
      icon: Icons.calculate,
      accentColor: Colors.orange,
      trailingWidget: _buildStrategyBadges(nombreRelaisRestants, nombreArretsRestants),
      children: [
        _buildStrategyMetricsGrid(regularStints, jokerStints, maxCurrentStint),
      ],
    );
  }

  Widget _buildStrategyMetricsGrid(int regularStints, int jokerStints, double maxCurrentStint) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Long',
                    regularStints.toString(),
                    Icons.timer,
                    Colors.green,
                    'Relais optimaux (50min)',
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildMetricCard(
                    'Joker',
                    jokerStints.toString(),
                    Icons.timer_outlined,
                    Colors.amber,
                    'Relais jokers (15min)',
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildMetricCard(
                    'Durée Max Stint',
                    maxCurrentStint > 0 ? _formatMinutesToMMSS(maxCurrentStint) : 'N/A',
                    Icons.schedule,
                    maxCurrentStint > 0 ? Colors.lightGreen : Colors.grey,
                    maxCurrentStint > 0 ? 'Durée max recommandée' : 'Aucune contrainte',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isMobile ? 16 : 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: isMobile ? 8 : 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuiviDeCourseTable() {
    final session = widget.kmrsService.currentSession;
    final stints = session?.stints ?? [];
    final config = session?.configuration;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Headers et flexValues pour ce tableau
    final headers = ['#', 'Temps Rest.', 'Pilote', 'Durée', 'Pit Stop', 'Pit In', 'Pit Out'];
    final mobileHeaders = ['#', 'Temps Rest.', 'Pilote', 'Durée', 'Pit Stop', 'Pit In', 'Pit Out']; // Headers ultra-abrégés
    final flexValues = [8, 16, 20, 14, 14, 14, 14]; // Equilibrés pour mobile
    
    Widget tableContent = Column(
      children: [
        // Headers avec le système responsive
        _buildResponsiveTableHeader(headers, flexValues, Colors.purple, mobileHeaders: mobileHeaders),
        SizedBox(height: isMobile ? 2 : 6),
        
        // Data rows (derniers 5 relais - du plus récent au plus ancien)
        ...stints.reversed.map((stint) {
          final pilot = session?.pilots.firstWhere(
            (p) => p.id == stint.pilotId,
            orElse: () => PilotData.create('Unknown'),
          );
          
          // Calcul du temps restant (diminue avec chaque relais + pit stops) - Précision milliseconde
          final raceDurationMinutes = ((config?.raceDurationHours ?? 4) * 60).round();
          final stintIndex = stints.indexOf(stint);
          final elapsedMilliseconds = stints.take(stintIndex + 1).map((s) => 
            s.actualDuration.inMilliseconds + s.pitStopDuration.inMilliseconds
          ).fold(0, (a, b) => a + b);
          final remainingMilliseconds = (raceDurationMinutes * 60 * 1000) - elapsedMilliseconds;
          final remainingDuration = Duration(milliseconds: remainingMilliseconds.clamp(0, double.infinity).toInt());
          
          final rowData = [
            stint.stintNumber.toString(),
            _formatDurationResponsive(remainingDuration),
            pilot?.name ?? 'Unknown',
            _formatDurationResponsive(stint.actualDuration),
            isMobile ? _formatDurationMobile(stint.pitStopDuration) : _formatDurationPrecise(stint.pitStopDuration),
            stint.pitInTime != null 
              ? (isMobile ? _formatDurationMobile(stint.pitInTime!) : _formatDurationPrecise(stint.pitInTime!))
              : '--:--',
            stint.pitOutTime != null 
              ? (isMobile ? _formatDurationMobile(stint.pitOutTime!) : _formatDurationPrecise(stint.pitOutTime!))
              : '--:--',
          ];
          
          return _buildResponsiveTableRow(rowData, flexValues);
        }).toList(),
        
        if (stints.isEmpty)
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            child: Text(
              'Aucun relais enregistré',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: isMobile ? 8 : 14,
              ),
            ),
          ),
      ],
    );
    
    return GlassmorphismSectionCardCompact(
      title: 'Suivi de Course',
      subtitle: 'Historique des relais et temps restants',
      icon: Icons.list,
      accentColor: Colors.purple,
      trailingWidget: _buildRaceChronometer(),
      children: [
        // Plus de scroll horizontal : tout s'affiche en pleine largeur
        tableContent,
      ],
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationShort(Duration duration) {
    if (duration == Duration.zero) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}min';
    }
  }

  String _formatDurationPrecise(Duration duration) {
    if (duration == Duration.zero) return '--:--.-';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}.${(milliseconds ~/ 100)}';
  }

  String _formatDurationHMS(Duration duration) {
    if (duration == Duration.zero) return '--:--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatMinutesToHMS(int minutes) {
    if (minutes <= 0) return '--:--:--';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')}:00';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatMinutesToMMSS(double totalMinutes) {
    if (totalMinutes <= 0) return '00:00';
    final minutes = totalMinutes.floor();
    final seconds = ((totalMinutes - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Format duration pour mobile (plus compact)
  String _formatDurationMobile(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Format duration responsive (format complet HH:MM:SS partout)
  String _formatDurationResponsive(Duration duration) {
    return _formatDurationHMS(duration);
  }

  Widget _buildTimeInputField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != 'Secondes') ...[
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
        ),
      ],
    );
  }

  TextStyle _tableHeaderStyle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    
    return TextStyle(
      color: Colors.white,
      fontSize: isMobile ? 12 : (isTablet ? 13 : 14),
      fontWeight: FontWeight.bold,
    );
  }

  TextStyle _tableDataStyle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.8),
      fontSize: isMobile ? 10 : (isTablet ? 11 : 12),
    );
  }

  // Helper function pour créer des headers responsive
  Widget _buildResponsiveTableHeader(List<String> headers, List<int> flexValues, Color accentColor, {List<String>? mobileHeaders}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Utiliser des headers abrégés sur mobile si fournis
    final displayHeaders = (isMobile && mobileHeaders != null) ? mobileHeaders : headers;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 2 : 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: displayHeaders.asMap().entries.map((entry) {
          final index = entry.key;
          final header = entry.value;
          final flex = flexValues[index];
          
          // Toujours utiliser Expanded pour que toutes les colonnes soient visibles
          return Expanded(
            flex: flex,
            child: Text(
              header,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 10 : 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          );
        }).toList(),
      ),
    );
  }

  // Helper function pour créer des lignes de données responsive
  Widget _buildResponsiveTableRow(List<String> data, List<int> flexValues) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 1 : 3),
      padding: EdgeInsets.all(isMobile ? 2 : 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: data.asMap().entries.map((entry) {
          final index = entry.key;
          final cellData = entry.value;
          final flex = flexValues[index];
          
          // Toujours utiliser Expanded pour que toutes les colonnes soient visibles
          return Expanded(
            flex: flex,
            child: Text(
              cellData,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: isMobile ? 9 : 12,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPilotSelectionField(List<PilotData> pilots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, color: Colors.blue, size: 16),
            const SizedBox(width: 8),
            Text(
              '0. Sélection du Pilote',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPilotId,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: pilots.isEmpty ? 'Aucun pilote disponible' : 'Sélectionnez un pilote',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          dropdownColor: RacingTheme.racingBlack,
          items: pilots.map((pilot) {
            return DropdownMenuItem(
              value: pilot.id,
              child: Text(
                pilot.name,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: pilots.isEmpty ? null : (value) {
            setState(() {
              _selectedPilotId = value;
            });
          },
          validator: (value) {
            if (pilots.isNotEmpty && (value == null || value.isEmpty)) {
              return 'Sélectionnez un pilote';
            }
            return null;
          },
        ),
        if (pilots.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Ajoutez des pilotes dans la Start Page avant de créer des relais',
              style: TextStyle(
                color: Colors.orange.withValues(alpha: 0.8),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  void _saveRelayData() {
    // Valider que les champs requis sont remplis
    if (_selectedPilotId == null || _selectedPilotId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un pilote'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_lastStintDurationMinutesController.text.isEmpty ||
        _pitstopMinutesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir au minimum la durée du relais et du pitstop'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Construire les durées à partir des inputs
    final lastStintMinutes = int.tryParse(_lastStintDurationMinutesController.text) ?? 0;
    final lastStintSeconds = int.tryParse(_lastStintDurationSecondsController.text) ?? 0;
    final lastStintDuration = Duration(minutes: lastStintMinutes, seconds: lastStintSeconds);
    
    final pitstopMinutes = int.tryParse(_pitstopMinutesController.text) ?? 0;
    final pitstopSeconds = int.tryParse(_pitstopSecondsController.text) ?? 0;
    final pitstopDuration = Duration(minutes: pitstopMinutes, seconds: pitstopSeconds);
    
    final pitInMinutes = int.tryParse(_pitInMinutesController.text) ?? 0;
    final pitInSeconds = int.tryParse(_pitInSecondsController.text) ?? 0;
    final pitInTime = (pitInMinutes > 0 || pitInSeconds > 0) ? Duration(minutes: pitInMinutes, seconds: pitInSeconds) : null;
    
    final pitOutMinutes = int.tryParse(_pitOutMinutesController.text) ?? 0;
    final pitOutSeconds = int.tryParse(_pitOutSecondsController.text) ?? 0;
    final pitOutTime = (pitOutMinutes > 0 || pitOutSeconds > 0) ? Duration(minutes: pitOutMinutes, seconds: pitOutSeconds) : null;

    // Créer un nouveau stint avec le pilote sélectionné et les données saisies
    widget.onStintAdded(_selectedPilotId!, lastStintDuration, pitstopDuration, pitInTime, pitOutTime, 'KMRS data entry');

    // Réinitialiser les champs
    setState(() {
      _selectedPilotId = null; // Réinitialiser la sélection de pilote
      _lastStintDurationMinutesController.clear();
      _lastStintDurationSecondsController.clear();
      _pitstopMinutesController.clear();
      _pitstopSecondsController.clear();
      _pitInMinutesController.clear();
      _pitInSecondsController.clear();
      _pitOutMinutesController.clear();
      _pitOutSecondsController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Données du relais KMRS enregistrées avec succès'),
        backgroundColor: RacingTheme.racingGreen,
      ),
    );

    HapticFeedback.lightImpact();
  }

  // Widget pour afficher les badges du tableau de stratégie
  Widget _buildStrategyBadges(int nombreRelaisRestants, int nombreArretsRestants) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    if (isMobile) {
      // Version mobile : badges empilés verticalement
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoBadge(
            'RELAIS RESTANTS',
            nombreRelaisRestants.toString(),
            Colors.orange,
          ),
          const SizedBox(height: 4),
          _buildInfoBadge(
            'ARRÊTS RESTANTS',
            nombreArretsRestants.toString(),
            Colors.deepOrange,
          ),
        ],
      );
    } else {
      // Version desktop : badges côte à côte
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoBadge(
            'RELAIS RESTANTS',
            nombreRelaisRestants.toString(),
            Colors.orange,
          ),
          const SizedBox(width: 8),
          _buildInfoBadge(
            'ARRÊTS RESTANTS',
            nombreArretsRestants.toString(),
            Colors.deepOrange,
          ),
        ],
      );
    }
  }

  // Widget pour afficher un badge d'information
  Widget _buildInfoBadge(String label, String value, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: isMobile ? 8 : 10,
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour le chrono de course
  Widget _buildRaceChronometer() {
    final session = widget.kmrsService.currentSession;
    final config = session?.configuration;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    if (config == null) {
      return _buildInfoBadge('CHRONO', '--:--:--', Colors.grey);
    }
    
    // Calcul des temps
    final raceDurationMinutes = (config.raceDurationHours * 60).round();
    final raceDuration = Duration(minutes: raceDurationMinutes);
    final remainingRace = _isRaceRunning 
        ? raceDuration - _currentRaceDuration 
        : raceDuration;
    final remainingBeforePitClose = remainingRace - Duration(minutes: config.pitLaneClosedEndMinutes);
    
    if (isMobile) {
      // Version mobile : Layout vertical
      return Column(
        children: [
          _buildInfoBadge(
            'TEMPS RESTANT',
            _formatDurationHMS(remainingRace.isNegative ? Duration.zero : remainingRace),
            _isRaceRunning ? Colors.green : Colors.grey,
          ),
          const SizedBox(height: 4),
          _buildInfoBadge(
            'AVANT FERMETURE',
            _formatDurationHMS(remainingBeforePitClose.isNegative ? Duration.zero : remainingBeforePitClose),
            remainingBeforePitClose.inMinutes > 10 ? Colors.blue : Colors.orange,
          ),
          const SizedBox(height: 6),
          _buildRaceTimerButton(),
        ],
      );
    } else {
      // Version desktop : Layout horizontal
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoBadge(
            'TEMPS RESTANT',
            _formatDurationHMS(remainingRace.isNegative ? Duration.zero : remainingRace),
            _isRaceRunning ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          _buildInfoBadge(
            'AVANT FERMETURE',
            _formatDurationHMS(remainingBeforePitClose.isNegative ? Duration.zero : remainingBeforePitClose),
            remainingBeforePitClose.inMinutes > 10 ? Colors.blue : Colors.orange,
          ),
          const SizedBox(width: 12),
          _buildRaceTimerButton(),
        ],
      );
    }
  }

  // Bouton START/STOP pour le chrono
  Widget _buildRaceTimerButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isRaceRunning ? _stopRaceTimer : _startRaceTimer,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: isMobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isRaceRunning
                  ? [
                      Colors.red.withValues(alpha: 0.8),
                      Colors.red.withValues(alpha: 0.6),
                    ]
                  : [
                      RacingTheme.racingGreen.withValues(alpha: 0.8),
                      RacingTheme.racingGreen.withValues(alpha: 0.6),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (_isRaceRunning ? Colors.red : RacingTheme.racingGreen).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isRaceRunning ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: isMobile ? 16 : 18,
              ),
              const SizedBox(width: 4),
              Text(
                _isRaceRunning ? 'STOP' : 'START',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
