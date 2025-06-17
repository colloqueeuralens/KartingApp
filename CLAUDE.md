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

## Architecture

### Core Application Structure
The app follows a modular service-based architecture with proper separation of concerns:

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
│   └── live_timing/            # Live timing (planned)
├── services/                    # Business logic services
│   ├── circuit_service.dart    # Circuit management
│   ├── firebase_service.dart   # Firebase integration
│   └── session_service.dart    # Session management
└── widgets/                     # Reusable UI components
    ├── common/                 # Shared widgets
    └── dashboard/              # Dashboard-specific widgets
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
- **Mobile**: Full functionality including configuration and circuit management
- **Web**: Read-only dashboard mode with circuit name display
- **Responsive**: Uses `kIsWeb` to detect platform and adjust UI accordingly

### Navigation System
Centralized navigation with `AppBarActions` widget (`lib/widgets/common/app_bar_actions.dart`):
- Dashboard access
- Live Timing (planned feature)
- Configuration screen
- User logout functionality

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

### Live Timing Integration (Planned)
- WebSocket connections for real-time data
- HTTP endpoints for timing data retrieval
- C1-C14 column mapping system for data association
- Placeholder screen implemented at `lib/screens/live_timing/live_timing_screen.dart`

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

### Key Dependencies
- `firebase_core` & `firebase_auth`: Firebase integration
- `cloud_firestore`: Firestore database
- `rxdart: ^0.27.0`: Stream combining for multi-column synchronization
- `flutter/foundation.dart`: Platform detection (`kIsWeb`)

### Feature Completeness
- ✅ Authentication system
- ✅ Session configuration
- ✅ Kart performance tracking
- ✅ Circuit management
- ✅ Multi-platform support
- 🚧 Live timing integration (planned)
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
- **`main`**: Only stable, tested code
- **`dev`**: Active development, frequent commits encouraged
- **Pull Requests**: Consider using PRs for `dev` → `main` merges for better tracking

### Repository Structure
The repository contains the complete Flutter application with:
- Source code (`lib/` directory)
- Platform configurations (`android/`, `ios/`)
- Dependencies (`pubspec.yaml`)
- Documentation (`CLAUDE.md`, `README.md`)
- Firebase configuration (`firebase.json`)
- Build configuration (`analysis_options.yaml`)