# Karting Timing Backend

A FastAPI-based backend that acts as an intelligent proxy between timing systems (Apex Timing, RaceMonitor) and the Flutter karting app. It provides automatic WebSocket format analysis, data persistence, and real-time streaming.

## Features

- **Automatic Format Detection**: Analyzes WebSocket data formats and generates parsers
- **Firebase Integration**: Syncs with existing Flutter app circuit data (C1-C14 mappings)
- **Real-time WebSocket Proxy**: Streams timing data to multiple clients
- **Data Persistence**: PostgreSQL storage for timing data and analysis results
- **RESTful API**: Complete CRUD operations for circuits and timing data
- **Docker Support**: Easy deployment with docker-compose

## Architecture

```
Timing Systems (Apex/RaceMonitor) → WebSocket → Backend → PostgreSQL
                                              ↓
                                    WebSocket Clients (Flutter App)
                                              ↓
                                         Firebase Sync
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Firebase credentials file (`firebase-credentials.json`)

### Development Setup

1. **Clone and setup environment**:
   ```bash
   cd backend
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Add Firebase credentials**:
   ```bash
   # Place your Firebase credentials file
   cp /path/to/your/firebase-credentials.json ./firebase-credentials.json
   ```

3. **Start services**:
   ```bash
   docker-compose up -d
   ```

4. **Verify installation**:
   ```bash
   curl http://localhost:8000/health
   ```

### Production Deployment

1. **Enable HTTPS with Nginx**:
   ```bash
   # Add SSL certificates to ./ssl/ directory
   docker-compose --profile production up -d
   ```

2. **Environment variables**:
   - Set `DEBUG=false`
   - Use strong `SECRET_KEY`
   - Configure proper `CORS_ORIGINS`

## API Endpoints

### Circuit Management
- `GET /circuits` - List all circuits
- `GET /circuits/{id}` - Get circuit details with mappings
- `GET /circuits/{id}/status` - Get timing status

### Timing Control
- `POST /circuits/{id}/start-timing` - Start data collection
- `POST /circuits/{id}/stop-timing` - Stop data collection

### Data Access
- `GET /circuits/{id}/data` - Get recent timing data
- `GET /circuits/{id}/statistics` - Get circuit statistics
- `GET /circuits/{id}/logs` - Get connection logs

### Analysis
- `POST /circuits/{id}/analyze-format` - Analyze WebSocket format
- `GET /circuits/{id}/analysis` - Get stored analysis results

### Real-time
- `WS /circuits/{id}/live` - WebSocket for live timing data

### System
- `GET /health` - Health check
- `GET /status` - System status

## WebSocket Message Format

### Client → Server
```json
{"type": "ping"}
```

### Server → Client
```json
{
  "type": "timing_data",
  "circuit_id": "circuit123",
  "data": {
    "mapped_data": {"C1": "driver1", "C2": "driver2"},
    "raw_data": {...},
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

## Configuration

Key environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection | See .env.example |
| `FIREBASE_PROJECT_ID` | Firebase project | kartingapp-fef5c |
| `FIREBASE_CREDENTIALS_PATH` | Path to credentials file | ./firebase-credentials.json |
| `CORS_ORIGINS` | Allowed origins | See .env.example |
| `WS_MAX_RECONNECT_ATTEMPTS` | Max reconnection tries | 10 |

## Database Schema

### timing_data
- Stores all incoming timing data with mapped and raw formats
- Indexed by circuit_id and timestamp for fast queries

### circuit_analysis
- Stores analysis results and generated parsers
- One record per circuit with UPSERT behavior

### connection_logs
- Logs all connection events for debugging
- Includes errors, reconnects, and status changes

## Development

### Local Development (without Docker)

1. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Setup PostgreSQL**:
   ```bash
   # Start PostgreSQL locally or use Docker
   docker run -d --name postgres -p 5432:5432 \
     -e POSTGRES_DB=timing_db \
     -e POSTGRES_USER=timing_user \
     -e POSTGRES_PASSWORD=timing_password \
     postgres:15-alpine
   ```

3. **Run the application**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

### Testing

```bash
# API health check
curl http://localhost:8000/health

# Get circuits
curl http://localhost:8000/circuits

# WebSocket test (using wscat)
npm install -g wscat
wscat -c ws://localhost:8000/circuits/CIRCUIT_ID/live
```

## Integration with Flutter App

The backend integrates seamlessly with the existing Flutter karting app:

1. **Circuit Data**: Reads C1-C14 mappings from Firebase
2. **Live Timing Screen**: Can be updated to connect to backend WebSocket
3. **Authentication**: Uses same Firebase project for consistency

### Flutter Integration Steps

1. Update `LiveTimingScreen` to connect to backend:
   ```dart
   // Connect to: ws://backend-url/circuits/{circuitId}/live
   ```

2. Backend handles all timing system complexity while providing clean data to Flutter

## Monitoring

- Health endpoint: `/health`
- System status: `/status`
- Connection logs: `/circuits/{id}/logs`
- Docker logs: `docker-compose logs -f api`

## Security

- Non-root Docker user
- Rate limiting via Nginx
- Firebase authentication integration
- CORS protection
- Input validation and sanitization

## Performance

- Async/await throughout
- Connection pooling for PostgreSQL
- Redis caching (optional)
- Efficient WebSocket management
- Data deduplication to reduce broadcasts