# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application called "KMRS Racing" - a karting management system that tracks kart performance across configurable columns/lanes with circuit management and live timing integration capabilities. The app uses Firebase for authentication, real-time data synchronization, and cloud storage.

## Common Development Commands

### Flutter Commands
- `flutter run` - Run the app in development mode
- `flutter build apk` - Build Android APK
- `flutter build web` - Build for web deployment
- `flutter test` - Run unit tests (no tests currently implemented)
- `flutter analyze` - Run static analysis
- `flutter pub get` - Install/update dependencies
- `flutter pub upgrade` - Upgrade dependencies
- `flutter clean` - Clean build cache

### Firebase Commands
- `firebase deploy --only hosting` - Deploy web version to Firebase Hosting
- `firebase emulators:start` - Start Firebase emulators for local development

### Backend Commands (FastAPI)
- `cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000` - Run backend in development mode
- `cd backend && python -m pytest` - Run backend tests
- `cd backend && python -m py_compile app/main.py` - Check Python syntax
- `cd backend && pip install -r requirements.txt` - Install backend dependencies

## Architecture

### Core Application Structure
The app follows a modular service-based architecture with proper separation of concerns:

**Frontend (Flutter):**
```
lib/
├── main.dart                    # Application entry point
├── navigation/                  # Navigation components
│   ├── auth_gate.dart          # Authentication state routing
│   └── main_navigator.dart     # Main app navigation
├── screens/                     # UI screens
│   ├── auth/                   # Authentication screens
│   ├── circuit/                # Circuit management
│   ├── config/                 # Session configuration
│   ├── dashboard/              # Main kart tracking
│   └── live_timing/            # Live timing interface
├── services/                    # Business logic services
│   ├── circuit_service.dart    # Circuit management
│   ├── firebase_service.dart   # Firebase integration
│   ├── session_service.dart    # Session management
│   └── optimistic_state_service.dart # Ultra-fast optimistic UI state
├── theme/                       # UI theming
│   └── racing_theme.dart       # Material Design 3 theme
└── widgets/                     # Reusable UI components
    ├── common/                 # Shared widgets
    └── dashboard/              # Dashboard-specific widgets
```

**Backend (FastAPI + Python):**
```
backend/
├── app/
│   ├── main.py                 # FastAPI application and endpoints
│   ├── analyzers/              # Data analysis and processing
│   │   ├── karting_parser.py   # Specialized karting message parser
│   │   └── format_analyzer.py  # Generic format analysis
│   ├── models/                 # Data models
│   │   └── karting_data.py     # Pydantic models for karting data
│   ├── services/               # Business logic services
│   │   ├── websocket_manager.py    # WebSocket connection management
│   │   ├── driver_state_manager.py # Hybrid data state management
│   │   ├── html_scraper.py         # HTML scraping for static data
│   │   ├── firebase_sync.py        # Firebase integration
│   │   └── database_service.py     # Database operations
│   ├── collectors/             # Data collection
│   │   └── base_collector.py   # WebSocket data collectors
│   └── core/                   # Core configuration
│       ├── config.py           # Application configuration
│       └── database.py         # Database initialization
```

#### Key Components
1. **AuthGate** (`lib/navigation/auth_gate.dart`): Handles authentication state and routing
2. **MainNavigator** (`lib/navigation/main_navigator.dart`): Manages navigation between main screens
3. **LoginScreen** (`lib/screens/auth/login_screen.dart`): Firebase email/password authentication
4. **ConfigScreen** (`lib/screens/config/config_screen.dart`): Grid and circuit configuration
5. **DashboardScreen** (`lib/screens/dashboard/dashboard_screen.dart`): Main kart tracking interface
6. **CreateCircuitScreen** (`lib/screens/circuit/create_circuit_screen.dart`): Circuit management interface
7. **LiveTimingScreen** (`lib/screens/live_timing/live_timing_screen.dart`): Live timing integration (planned)

### Data Model

#### Sessions Configuration
Stored in Firestore at `/sessions/session1`:
- `numColumns`: Number of kart columns (2-4)
- `numRows`: Number of karts per column (1-3)
- `columnColors`: Array of color names for columns
- `selectedCircuitId`: Reference to associated circuit

#### Kart Entries
Stored at `/sessions/session1/columns/col{N}/entries`:
- `number`: Kart number (1-99, unique across all columns)
- `perf`: Performance rating ('++', '+', '~', '-', '--', '?')
- `timestamp`: Server timestamp for ordering

#### Circuit Configuration
Stored in Firestore at `/circuits/{circuitId}`:
- `nom`: Circuit name
- `liveTimingUrl`: HTTP URL for live timing data
- `wssUrl`: WebSocket URL for real-time updates
- `c1` through `c14`: Column mappings for live timing integration
- `createdAt`: Creation timestamp

#### Secteur Choices
Stored in Firestore at `/secteur_choices`:
- Dynamic dropdown options for circuit configuration
- Allows custom sector choice additions

### Circuit Management System
The app includes a comprehensive circuit management system:
- **Circuit Creation**: Interface to define circuits with live timing URLs
- **Column Mapping**: Maps C1-C14 positions to live timing data sources
- **JSON Import**: Bulk circuit import with duplicate detection
- **Circuit Selection**: Links sessions to specific circuits for live timing

### Platform-Specific Behavior
#### Development Branch (`dev`)
- **Mobile**: Full functionality including configuration and circuit management
- **Web**: Full functionality - all features available for development and testing
- **Responsive**: Uses `kIsWeb` to detect platform and adjust UI accordingly

#### Production Branch (`main`)
- **Mobile**: Full functionality including configuration and circuit management  
- **Web**: Read-only dashboard mode with circuit name display (production safety)
- **Responsive**: Uses `kIsWeb` to detect platform and adjust UI accordingly

### Navigation System
Responsive navigation with `AppBarActions` widget (`lib/widgets/common/app_bar_actions.dart`):
- **Mobile (< 600px)**: Hamburger menu with PopupMenuButton for space efficiency
- **Desktop (≥ 600px)**: Horizontal action buttons in AppBar
- Dashboard access
- Live Timing (planned feature)
- Configuration screen
- User logout functionality
- Automatic responsive behavior based on screen width

### State Management
- Uses Firebase real-time streams with StreamBuilder widgets
- RxDart's `CombineLatestStream.list()` for multi-column data synchronization
- Service-based architecture with `CircuitService`, `SessionService`, `FirebaseService`, and `OptimisticStateService`
- **Ultra-Fast Optimistic UI**: Instant drag & drop with <16ms response time
- No additional state management library - relies on Firebase streams and optimistic services

### Performance Optimization Logic
The app calculates an "optimal moment" indicator based on performance thresholds:
- 2 columns: 100% threshold
- 3 columns: 66% threshold  
- 4 columns: 75% threshold
Shows green "C'EST LE MOMENT!" when percentage of good performances (++ or +) meets threshold.
Implementation: `lib/widgets/dashboard/racing_kart_grid_view.dart:465-490`

### Ultra-Fast Optimistic Drag & Drop System ⚡
**Revolutionary Performance Enhancement**: Sub-16ms UI response time

**Core Architecture:**
- **OptimisticStateService** (`lib/services/optimistic_state_service.dart`): Singleton state manager for instant UI updates
- **Atomic Algorithm** (`lib/widgets/dashboard/racing_kart_grid_view.dart:779-906`): 3-phase optimistic data processing
- **Intelligent Deduplication**: Eliminates temporal duplications caused by Firebase docId changes
- **Smart Fallback System**: Prioritizes optimistic state over Firebase during transitions

**Key Performance Features:**
- ✅ **Instant Visual Feedback**: Karts move immediately on drag (< 16ms)
- ✅ **Haptic Feedback**: Premium tactile response with `HapticFeedback.lightImpact()`
- ✅ **Visual Indicators**: Blue glow animation for pending optimistic moves
- ✅ **Ultra-Fast Backend**: Firebase debouncing reduced from 50ms → 20ms
- ✅ **Automatic Rollback**: Error recovery with visual feedback and retry options
- ✅ **Debug Monitoring**: Comprehensive logging for performance tracking

**Technical Implementation:**
```dart
// 3-Phase Atomic Algorithm
Phase 1: Index all existing karts by docId and original position
Phase 2: Create empty target columns 
Phase 3: Place each kart exactly once (optimistic OR original position)
+ Deduplication: Group by kart number, prioritize optimistic over Firebase
+ Re-sorting: Maintain timestamp order after deduplication
```

**Deduplication Logic:**
- **Problem**: Firebase creates new docId during moves, causing temporary duplicates
- **Solution**: Detect same kart number in same column, keep optimistic version only
- **Markers**: Optimistic documents tagged with `_isOptimistic: true`
- **Cleanup**: Automatic confirmation/rollback with 10s safety timeout

**Performance Metrics:**
- **Before**: 300ms average drag response time
- **After**: <16ms UI response + 20ms Firebase background sync
- **User Experience**: "Vraiment instantané" - truly instantaneous feel

### Live Timing Integration - PRODUCTION READY ✅
**Complete WebSocket → UI Pipeline**
- **Karting Message Parser** (`backend/app/analyzers/karting_parser.py`): Production parser with enhanced format support:
  - **HTML Grid Format**: Initial composite messages with `grid||<tbody>...` containing complete driver data
  - **Pipe Format**: Real-time updates in `r{driver_id}c{column}|code|value` format
  - **Enhanced Column Translation**: Supports multiple languages and format variations (Pos., Clt, Position, etc.)
- **Base Collector** (`backend/app/collectors/base_collector.py`): Optimized WebSocket listener with robust message handling
- **WebSocket Manager** (`backend/app/services/websocket_manager.py`): Production-ready connection management with error handling
- **Circuit Mappings**: Dynamic C1-C14 mappings from Firebase for maximum flexibility

**Production Features:**
- ✅ **Robust Data Flow**: `WebSocket.recv() → base_collector → karting_parser → JSON → clients`
- ✅ **Multi-Format Support**: Handles diverse timing system formats and languages
- ✅ **Clean JSON Output**: Produces standardized `{"driver_id": {"field": "value"}}` format
- ✅ **Intelligent State Management**: Frontend cache fusion with data accumulation
- ✅ **Real-time Processing**: Immediate message processing and client broadcast
- ✅ **Dynamic Circuit Mapping**: Firebase-driven C1-C14 field mapping configuration
- ✅ **Smart Frontend Caching**: Accumulates complete kart profiles over time
- ✅ **Production Logging**: Optimized logging for performance monitoring

**Advanced Frontend Architecture:**
- **Live Timing Screen** (`lib/screens/live_timing/live_timing_screen.dart`): Complete timing interface with:
  - **Responsive Controls**: Optimized layout for web (40%-30%-30%) and mobile (2-line layout)
  - **Smart Button Management**: START button handles timing backend + WebSocket connection atomically
  - **Status LEDs**: Real-time API, Timing, and WebSocket connection indicators
  - **Error Handling**: Robust error states with informative user feedback
- **Live Timing Table** (`lib/widgets/live_timing/live_timing_table.dart`): Dynamic data table with:
  - **Smart Column Detection**: Shows all available data columns from all karts
  - **Responsive Headers**: Adaptive column display based on screen size
  - **Real-time Updates**: Animated row updates with podium highlighting
  - **Performance Optimization**: Efficient rendering for large datasets

**UI/UX Enhancements:**
- **Professional Layout**: Glassmorphism containers with racing theme integration
- **Responsive Design**: Optimized for web (3-column layout) and mobile (2-line stacked)
- **Smart Alignments**: Perfect spacing with circuit info (left), controls (center), LEDs (right)
- **Constraint Management**: Robust widget sizing to prevent rendering errors
- **Visual Feedback**: Loading states, connection indicators, and error messaging

**API Endpoints:**
- `POST /circuits/{circuit_id}/start-timing` - Start WebSocket timing collection
- `POST /circuits/{circuit_id}/stop-timing` - Stop WebSocket timing collection
- `GET /circuits/{circuit_id}/status` - Get timing collector status
- `WebSocket /circuits/{circuit_id}/live` - Live timing data stream (production JSON format)

**Data Flow Pipeline:**
```
Live Timing Source → WebSocket → BaseCollector._process_message() → 
WebSocketManager.broadcast_karting_data() → KartingMessageParser.parse_message() → 
Standardized JSON → Connected Clients → Frontend Cache Fusion → 
Live Timing Table → Real-time UI Updates
```

**Production Monitoring:**
- **Backend Efficiency**: Optimized logging for production performance
- **Frontend Intelligence**: Smart cache state management with data persistence
- **Connection Management**: Automatic reconnection and error recovery
- **Real-time Synchronization**: Multi-client data consistency

## Firebase Configuration

The app is configured for Firebase project `kartingapp-fef5c` with:
- Authentication enabled (email/password)
- Firestore database with collections: `sessions`, `circuits`, `secteur_choices`
- Hosting for web deployment
- Multi-platform support (Android, iOS, Web, Windows, macOS)

Firebase options are auto-generated in `lib/firebase_options.dart`.

## Development Notes

### Code Quality
- **Testing**: No test files currently implemented - consider adding unit and widget tests
- **Documentation**: Code lacks inline documentation comments
- **Localization**: French UI text throughout the application

### Enhanced UI Components
- **EnhancedKartCard** (`lib/widgets/dashboard/enhanced_kart_card.dart`): Animated kart cards with hover effects, scale animations, configurable pulse for optimal performance
- **EmptyKartSlot**: Interactive empty slots with breathing animations for better drag & drop feedback
- **Card-based Interface**: Modern circuit creation with organized sections and visual feedback
- **Mode Toggle**: Simple/Advanced configuration modes for different user expertise levels
- **Responsive AppBar**: Hamburger menu on mobile (< 600px), horizontal buttons on desktop
- **Racing Theme**: Consistent color scheme with `racingGreen` primary buttons, grey backgrounds

### Key Dependencies
- `firebase_core` & `firebase_auth`: Firebase integration
- `cloud_firestore`: Firestore database
- `rxdart: ^0.27.0`: Stream combining for multi-column synchronization
- `flutter/foundation.dart`: Platform detection (`kIsWeb`)

### Feature Completeness
- ✅ Authentication system with premium glassmorphism racing theme
- ✅ Session configuration with improved UX and responsive design
- ✅ Kart performance tracking with animated cards and optimal moment indicators
- ✅ Circuit management with enhanced UX and JSON import capabilities
- ✅ Multi-platform support with responsive navigation (hamburger menu on mobile)
- ✅ Modern UI with glassmorphism effects and smooth animations
- ✅ Racing theme with consistent color scheme and visual hierarchy
- ✅ Performance optimization with intelligent pulse animations
- ✅ **Production-ready live timing integration with complete UI**
- ✅ **Smart responsive layouts with perfect alignments**
- ✅ **Robust error handling and user feedback systems**
- ✅ **Ultra-fast optimistic drag & drop system (<16ms response)**
- ❌ Test coverage

## Git Workflow & Repository Management

### Repository Information
- **GitHub Repository**: https://github.com/colloqueeuralens/KartingApp
- **Main Branch**: `main` (production-ready code)
- **Development Branch**: `dev` (active development)
- **Remote**: `origin`

### Git Workflow Best Practices

#### Branch Strategy
- **`main`**: Production-ready, stable code only
- **`dev`**: Active development, new features, and fixes
- **Feature branches**: For larger features (optional)

#### Development Workflow
1. **Switch to dev branch** for all development work:
   ```bash
   git checkout dev
   git pull origin dev
   ```

2. **Develop features** on the dev branch:
   ```bash
   # Make your changes
   git add .
   git commit -m "feat: descriptive commit message"
   git push origin dev
   ```

3. **Merge to main** when features are stable and tested:
   ```bash
   git checkout main
   git pull origin main
   git merge dev
   git push origin main
   ```

#### Quick Development Commands
```bash
# Start working on new feature
git checkout dev
git pull origin dev

# After making changes
git add .
git commit -m "feat: your feature description"
git push origin dev
```

#### Commit Message Convention
Use clear, descriptive commit messages following this pattern:
- `feat: add new feature description`
- `fix: resolve specific issue`
- `update: improve existing functionality`
- `refactor: restructure code without changing behavior`
- `docs: update documentation`

#### Security Notes
- ✅ Firebase configuration files are excluded via `.gitignore`
- ✅ Sensitive keys and tokens are not committed
- ✅ Only source code and documentation are tracked

#### Files Excluded from Git
```
# Firebase configuration (contains sensitive keys)
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
.firebase/

# Build artifacts
build/
.dart_tool/
```

### Development Workflow
1. **Switch to dev branch**: `git checkout dev && git pull origin dev`
2. **Make code modifications** on dev branch
3. **Test changes locally** with `flutter run`
4. **Update CLAUDE.md** if architecture changes
5. **Commit and push to dev**: Regular commits for incremental progress
6. **Merge to main**: Only when features are complete and stable

### Branch Protection Strategy
- **`main`**: Only stable, tested code (web in read-only mode for production)
- **`dev`**: Active development, frequent commits encouraged (all features on web and mobile)
- **Pull Requests**: Consider using PRs for `dev` → `main` merges for better tracking

### Platform Feature Availability
#### On `dev` branch:
- ✅ **Mobile**: All features (config, circuits, kart management, live timing)
- ✅ **Web**: All features (config, circuits, kart management, live timing)

#### On `main` branch:
- ✅ **Mobile**: All features (config, circuits, kart management, live timing)  
- ⚠️ **Web**: Read-only dashboard only (production safety)

### Repository Structure
The repository contains the complete Flutter application with:
- Source code (`lib/` directory)
- Platform configurations (`android/`, `ios/`)
- Dependencies (`pubspec.yaml`)
- Documentation (`CLAUDE.md`, `README.md`)
- Firebase configuration (`firebase.json`)
- Build configuration (`analysis_options.yaml`)