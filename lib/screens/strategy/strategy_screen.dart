import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../../services/kmrs_service.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../widgets/common/glassmorphism_container.dart';
import '../../widgets/common/glassmorphism_tab_bar.dart';
import '../../theme/racing_theme.dart';
import '../../models/kmrs_models.dart';
import '../../widgets/kmrs/kmrs_start_page.dart';
import '../../widgets/kmrs/kmrs_main_page.dart';
import '../../widgets/kmrs/kmrs_calculations_page.dart';
import '../../widgets/kmrs/kmrs_racing_page.dart';
import '../../widgets/kmrs/kmrs_stints_page.dart';
import '../../widgets/kmrs/kmrs_pilots_page.dart';
import '../../widgets/kmrs/kmrs_simulator_page.dart';

/// Interface KMRS complète reproduisant KMRS.xlsm
class StrategyScreen extends StatefulWidget {
  final VoidCallback? onBackToConfig;

  const StrategyScreen({
    super.key,
    this.onBackToConfig,
  });

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final KmrsService _kmrsService = KmrsService();
  bool _isInitialized = false;
  
  // Onglets KMRS avec configuration glassmorphism
  late List<GlassmorphismTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const GlassmorphismTab(
        title: 'Configuration',
        subtitle: 'Paramètres KMRS',
        icon: Icons.settings,
      ),
      const GlassmorphismTab(
        title: 'Chronométrage',
        subtitle: 'Relais et calculs',
        icon: Icons.timer,
      ),
      const GlassmorphismTab(
        title: 'Course',
        subtitle: 'Interface 16x22',
        icon: Icons.sports_motorsports,
      ),
      const GlassmorphismTab(
        title: 'Historique',
        subtitle: 'Liste des relais',
        icon: Icons.list_alt,
      ),
      const GlassmorphismTab(
        title: 'Pilotes',
        subtitle: 'Statistiques équipe',
        icon: Icons.people,
      ),
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Force rebuild when tab changes
    });
    _initializeKmrs();
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeKmrs() async {
    if (_isInitialized) return;

    try {
      await _kmrsService.loadOrCreateSession();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur initialisation KMRS: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildGlassmorphismTitle(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                RacingTheme.racingBlack,
                RacingTheme.racingBlack.withValues(alpha: 0.9),
                Colors.grey[900]!.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: RacingTheme.racingGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: AppBarActions.getResponsiveActions(
          context,
          onBackToConfig: widget.onBackToConfig,
        ),
        bottom: _isInitialized
            ? GlassmorphismAppBarBottom(
                tabs: _tabs,
                controller: _tabController,
                accentColor: RacingTheme.racingGreen,
                onTap: (index) {
                  setState(() {}); // Force rebuild on tab tap
                },
              )
            : null,
      ),
      extendBodyBehindAppBar: true,
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
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 85,
          ),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildGlassmorphismTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RacingTheme.racingGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  RacingTheme.racingGreen.withValues(alpha: 0.2),
                  RacingTheme.racingGreen.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sports_motorsports,
                    color: RacingTheme.racingGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KMRS Racing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Stratégie Karting',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _kmrsService,
      builder: (context, _) {
        if (_kmrsService.isLoading) {
          return _buildLoadingState();
        }

        if (_kmrsService.error != null) {
          return _buildErrorState();
        }

        if (!_isInitialized) {
          return _buildInitializingState();
        }

        return _buildKmrsTabView();
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: GlassmorphismContainer(
        width: 400,
        blur: 15,
        opacity: 0.15,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(RacingTheme.racingGreen),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Initialisation KMRS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configuration du système de stratégie karting',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: GlassmorphismContainer(
        width: 450,
        blur: 15,
        opacity: 0.15,
        border: Border.all(
          color: RacingTheme.bad.withValues(alpha: 0.3),
          width: 1.5,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: RacingTheme.bad.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.error_outline,
                color: RacingTheme.bad,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur KMRS',
              style: TextStyle(
                color: RacingTheme.bad,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _kmrsService.error ?? 'Erreur inconnue lors de l\'initialisation',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildErrorButton(
                    label: 'Réessayer',
                    icon: Icons.refresh,
                    color: RacingTheme.racingGreen,
                    onPressed: () => _kmrsService.loadOrCreateSession(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildErrorButton(
                    label: 'Réinitialiser',
                    icon: Icons.restart_alt,
                    color: Colors.orange,
                    onPressed: () => _kmrsService.resetSession(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorButton({
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
              Icon(icon, color: color, size: 18),
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

  Widget _buildInitializingState() {
    return Center(
      child: GlassmorphismContainer(
        width: 500,
        blur: 20,
        opacity: 0.15,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    RacingTheme.racingGreen.withValues(alpha: 0.3),
                    RacingTheme.racingGreen.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: RacingTheme.racingGreen.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.sports_motorsports,
                color: RacingTheme.racingGreen,
                size: 56,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'KMRS Racing System',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Karting Management Racing System',
              style: TextStyle(
                color: RacingTheme.racingGreen,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Interface complète de gestion stratégique\npour courses d\'endurance karting',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await _kmrsService.loadOrCreateSession();
                  if (mounted) {
                    await _initializeKmrs();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        RacingTheme.racingGreen.withValues(alpha: 0.8),
                        RacingTheme.racingGreen.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: RacingTheme.racingGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: RacingTheme.racingGreen.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Lancer KMRS',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKmrsTabView() {
    return GlassmorphismTabBarView(
      controller: _tabController,
      animationDuration: const Duration(milliseconds: 250),
      children: [
        // Configuration KMRS
        KmrsStartPage(
          kmrsService: _kmrsService,
          onConfigurationChanged: (config) => _kmrsService.updateConfiguration(config),
        ),
        
        // Chronométrage et relais
        KmrsMainPage(
          kmrsService: _kmrsService,
          onStintAdded: (pilotId, duration, pitTime, pitInTime, pitOutTime, notes) => 
            _kmrsService.addStint(pilotId, duration, pitTime, pitInTime: pitInTime, pitOutTime: pitOutTime, notes: notes),
        ),
        
        // Interface de course
        KmrsRacingPage(
          kmrsService: _kmrsService,
        ),
        
        // Gestion des relais
        KmrsStintsPage(
          kmrsService: _kmrsService,
          onStintUpdated: (stint) => _kmrsService.updateStint(stint),
          onStintRemoved: (stintId) => _kmrsService.removeStint(stintId),
        ),
        
        // Statistiques des pilotes
        KmrsPilotsPage(
          kmrsService: _kmrsService,
          onPilotUpdated: (pilot) => _kmrsService.updatePilot(pilot),
        ),
      ],
    );
  }

}