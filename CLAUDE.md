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
│   └── session_service.dart    # Session management
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
- Service-based architecture with `CircuitService`, `SessionService`, and `FirebaseService`
- No additional state management library - relies on Firebase streams and services

### Performance Optimization Logic
The app calculates an "optimal moment" indicator based on performance thresholds:
- 2 columns: 100% threshold
- 3 columns: 66% threshold  
- 4 columns: 75% threshold
Shows green "C'EST LE MOMENT!" when percentage of good performances (++ or +) meets threshold.
Implementation: `lib/widgets/dashboard/kart_grid_view.dart:138-144`

### Live Timing Integration - SIMPLIFIED ARCHITECTURE ✅
**Direct WebSocket → KartingParser Flow**
- **Karting Message Parser** (`backend/app/analyzers/karting_parser.py`): Specialized parser for dual format support:
  - **HTML Grid Format**: Initial composite messages with `grid||<tbody>...` containing complete driver data
  - **Pipe Format**: Real-time updates in `r{driver_id}c{column}|code|value` format
- **Base Collector** (`backend/app/collectors/base_collector.py`): Simplified WebSocket listener that sends raw messages directly to karting parser
- **WebSocket Manager** (`backend/app/services/websocket_manager.py`): Direct processing without complex callbacks or state management
- **Circuit Mappings**: Uses predefined C1-C14 mappings from Firebase for optimal performance

**Simplified Key Features:**
- ✅ **Direct Flow**: `WebSocket.recv() → base_collector → karting_parser → JSON → clients`
- ✅ **Dual Format Support**: Handles both initial HTML grid and subsequent pipe messages
- ✅ **Simple JSON Output**: Produces clean `{"driver_id": {"field": "value"}}` format
- ✅ **No Complex State Management**: Removed driver_state_manager and callback complexity
- ✅ **Real-time Processing**: Immediate message processing and client broadcast
- ✅ **Circuit Mapping Integration**: Uses Firebase circuit configuration for C1-C14 field mapping
- ✅ **Intelligent Caching**: Frontend fusion system accumulates complete kart profiles over time
- ✅ **Comprehensive Logging**: Backend and frontend detailed state logging for debugging

**Data Caching Architecture:**
- **Backend Processing**: Processes only current message data, provides detailed logging after each message
- **Frontend Intelligence**: Implements smart cache fusion in `lib/services/backend_service.dart`:
  - Preserves existing kart data (Classement, Equipe, temps) across updates
  - Merges new data with existing using `addAll()` for intelligent accumulation
  - Simulates real timing board behavior where data builds up over time
  - Displays complete kart state in Chrome console for debugging

**Simplified API Endpoints:**
- `POST /circuits/{circuit_id}/start-timing` - Start WebSocket timing collection
- `POST /circuits/{circuit_id}/stop-timing` - Stop WebSocket timing collection
- `GET /circuits/{circuit_id}/status` - Get timing collector status
- `WebSocket /circuits/{circuit_id}/live` - Live timing data stream (simplified JSON format)

**Data Flow:**
```
WebSocket Message → BaseCollector._process_message() → 
WebSocketManager.broadcast_karting_data() → 
KartingMessageParser.parse_message() → 
Simple JSON Format → Connected Clients → 
Frontend Intelligent Cache Fusion
```

**Debugging & Monitoring:**
- **Backend Logs**: Complete kart state after each message processing via Docker logs
- **Frontend Logs**: Intelligent cache state in Chrome Console with complete kart profiles
- **Message Tracking**: Sequential message numbering and driver update counting
- **Real-time Visibility**: Compare backend message processing vs frontend accumulation

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
- ✅ Authentication system with racing theme
- ✅ Session configuration with improved UX
- ✅ Kart performance tracking with animated cards and configurable animations
- ✅ Circuit management with enhanced UX
- ✅ Multi-platform support with responsive navigation
- ✅ Modern UI with animations and micro-interactions
- ✅ Responsive design (hamburger menu on mobile, buttons on desktop)
- ✅ Racing green theme with consistent button colors
- ✅ Performance optimization (no pulse animation at 100% threshold)
- ✅ **Live timing integration with simplified architecture**
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